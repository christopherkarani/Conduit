// ModelCache.swift
// Conduit

import Foundation

/// Actor managing the model cache with LRU (Least Recently Used) eviction.
///
/// The cache stores metadata about downloaded models and provides
/// LRU eviction when space limits are exceeded. All operations are
/// thread-safe due to actor isolation.
///
/// ## Usage
/// ```swift
/// // Initialize with default cache directory
/// let cache = try await ModelCache()
///
/// // Add a model to the cache
/// let info = CachedModelInfo(
///     identifier: .llama3_2_1b,
///     path: modelDirectory,
///     size: .gigabytes(4)
/// )
/// try cache.add(info)
///
/// // Check if a model is cached
/// if cache.isCached(.llama3_2_1b) {
///     if let path = cache.localPath(for: .llama3_2_1b) {
///         // Use the model
///     }
/// }
///
/// // Mark a model as accessed (updates LRU)
/// cache.markAccessed(.llama3_2_1b)
///
/// // Evict old models to fit within size limit
/// let evicted = try cache.evictToFit(maxSize: .gigabytes(20))
/// ```
///
/// ## Cache Persistence
///
/// The cache persists metadata to disk as JSON, allowing the cache
/// to survive app restarts. The metadata file is stored in the
/// cache directory as `cache-metadata.json`.
///
/// ## Thread Safety
///
/// As an actor, ModelCache provides automatic thread safety. All
/// methods are isolated to the actor's executor, ensuring safe
/// concurrent access.
public actor ModelCache {

    // MARK: - Properties

    /// Default cache directory: ~/Library/Caches/Conduit/Models/
    ///
    /// This directory is used when no custom cache directory is provided
    /// during initialization. It follows Apple's guidelines for cache
    /// storage and is subject to automatic cleanup by the system.
    public static let defaultCacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("Conduit/Models", isDirectory: true)
    }()

    /// Legacy cache directory from SwiftAI (for migration)
    private static let legacyCacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("SwiftAI/Models", isDirectory: true)
    }()

    /// Migrates cache from legacy SwiftAI location to new Conduit location.
    ///
    /// Call this during app initialization to preserve existing cached models.
    /// The migration is safe to call multiple times - it only runs if the
    /// legacy cache exists and the new cache doesn't.
    ///
    /// - Throws: `AIError.file` if migration fails
    public static func migrateFromLegacyCache() throws {
        let fileManager = FileManager.default
        let legacyPath = legacyCacheDirectory
        let newPath = defaultCacheDirectory

        // Check if legacy cache exists and new cache doesn't
        guard fileManager.fileExists(atPath: legacyPath.path),
              !fileManager.fileExists(atPath: newPath.path) else {
            return
        }

        // Create parent directory for new path
        try fileManager.createDirectory(
            at: newPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Move legacy cache to new location
        try fileManager.moveItem(at: legacyPath, to: newPath)

        // Clean up empty legacy directory
        let legacyParent = legacyPath.deletingLastPathComponent()
        if let contents = try? fileManager.contentsOfDirectory(atPath: legacyParent.path),
           contents.isEmpty {
            try? fileManager.removeItem(at: legacyParent)
        }
    }

    /// The directory where models are cached.
    ///
    /// Model files are stored in subdirectories within this directory,
    /// organized by model identifier.
    public let cacheDirectory: URL

    /// In-memory cache of model metadata.
    ///
    /// This dictionary maps model identifiers to their cached information,
    /// providing fast lookups without disk access.
    private var cache: [ModelIdentifier: CachedModelInfo]

    /// Path to the metadata JSON file for persistence.
    ///
    /// This file stores the cache state across app launches.
    private let metadataPath: URL

    // MARK: - Initialization

    /// Initializes the model cache.
    ///
    /// Creates the cache directory if it doesn't exist and loads
    /// any existing metadata from disk.
    ///
    /// - Parameter cacheDirectory: Optional custom cache directory.
    ///   If `nil`, uses the default cache directory.
    /// - Throws: `AIError.fileError` if the directory cannot be created
    ///   or metadata cannot be loaded.
    ///
    /// ## Example
    /// ```swift
    /// // Use default cache directory
    /// let cache = try await ModelCache()
    ///
    /// // Use custom cache directory
    /// let customCache = try await ModelCache(
    ///     cacheDirectory: URL(fileURLWithPath: "/custom/path")
    /// )
    /// ```
    public init(cacheDirectory: URL? = nil) async throws {
        self.cacheDirectory = cacheDirectory ?? Self.defaultCacheDirectory
        self.metadataPath = self.cacheDirectory.appendingPathComponent("cache-metadata.json")

        // Create cache directory if it doesn't exist
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: self.cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw AIError.file(error)
        }

        // Initialize cache first, then load metadata
        self.cache = [:]

        // Load existing metadata or keep empty cache
        do {
            self.cache = try loadMetadata()
        } catch {
            // If metadata file doesn't exist or is corrupted, keep empty cache
        }
    }

    // MARK: - Query Methods

    /// Returns all cached models sorted by last accessed date (most recent first).
    ///
    /// This is useful for displaying cached models in a UI or for
    /// diagnostics.
    ///
    /// - Returns: Array of cached model info sorted by recency.
    ///
    /// ## Example
    /// ```swift
    /// let cachedModels = cache.allCachedModels()
    /// for model in cachedModels {
    ///     print("\(model.identifier.displayName): \(model.size.formatted)")
    ///     print("Last used: \(model.lastAccessedAt)")
    /// }
    /// ```
    public func allCachedModels() -> [CachedModelInfo] {
        cache.values.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    /// Checks if a model is cached.
    ///
    /// This is a fast lookup that only checks the in-memory cache.
    /// It validates that the files still exist on disk and prunes
    /// stale entries if the OS has evicted the cache.
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: `true` if the model is in the cache, `false` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// if cache.isCached(.llama3_2_1b) {
    ///     print("Model is available locally")
    /// } else {
    ///     print("Model needs to be downloaded")
    /// }
    /// ```
    public func isCached(_ model: ModelIdentifier) -> Bool {
        guard let info = cache[model] else {
            return false
        }
        return validateCachedEntry(info)
    }

    /// Gets the cached model info for a model.
    ///
    /// Returns detailed information about a cached model including
    /// its path, size, and access history.
    ///
    /// - Parameter model: The model identifier to look up.
    /// - Returns: The cached model info if available, `nil` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// if let info = cache.info(for: .llama3_2_1b) {
    ///     print("Size: \(info.size.formatted)")
    ///     print("Downloaded: \(info.downloadedAt)")
    ///     print("Last used: \(info.lastAccessedAt)")
    /// }
    /// ```
    public func info(for model: ModelIdentifier) -> CachedModelInfo? {
        guard let info = cache[model] else {
            return nil
        }
        return validateCachedEntry(info) ? info : nil
    }

    /// Gets the local file path for a cached model.
    ///
    /// Returns the directory path where the model's files are stored.
    /// This is a convenience method equivalent to `info(for:)?.path`.
    ///
    /// - Parameter model: The model identifier to look up.
    /// - Returns: The local path URL if the model is cached, `nil` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// if let path = cache.localPath(for: .llama3_2_1b) {
    ///     // Load model from path
    ///     let modelFiles = try FileManager.default.contentsOfDirectory(at: path)
    /// }
    /// ```
    public func localPath(for model: ModelIdentifier) -> URL? {
        guard let info = cache[model] else {
            return nil
        }
        return validateCachedEntry(info) ? info.path : nil
    }

    /// Validates a cached entry exists on disk and prunes stale metadata.
    ///
    /// Returns `true` when the cache entry still exists on disk.
    private func validateCachedEntry(_ info: CachedModelInfo) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: info.path.path) else {
            cache.removeValue(forKey: info.identifier)
            try? saveMetadata()
            return false
        }
        return true
    }

    /// Returns the total size of all cached models.
    ///
    /// Sums the size of all models in the cache. This is useful for
    /// determining how much space can be freed by clearing the cache.
    ///
    /// - Returns: The total size of all cached models.
    ///
    /// ## Example
    /// ```swift
    /// let totalSize = cache.totalSize()
    /// print("Cache is using \(totalSize.formatted)")
    ///
    /// if totalSize > .gigabytes(50) {
    ///     // Consider evicting old models
    /// }
    /// ```
    public func totalSize() -> ByteCount {
        let totalBytes = cache.values.reduce(0) { $0 + $1.size.bytes }
        return ByteCount(totalBytes)
    }

    // MARK: - Cache Modification

    /// Adds a model to the cache.
    ///
    /// Stores the model's metadata in the cache and persists it to disk.
    /// If a model with the same identifier already exists, it is replaced.
    ///
    /// - Parameter info: The cached model information to add.
    /// - Throws: `AIError.fileError` if metadata cannot be saved.
    ///
    /// ## Example
    /// ```swift
    /// let info = CachedModelInfo(
    ///     identifier: .llama3_2_1b,
    ///     path: downloadPath,
    ///     size: .gigabytes(4),
    ///     downloadedAt: Date(),
    ///     lastAccessedAt: Date(),
    ///     revision: "main"
    /// )
    /// try cache.add(info)
    /// ```
    public func add(_ info: CachedModelInfo) throws {
        cache[info.identifier] = info
        try saveMetadata()
    }

    /// Updates the last accessed time for a model (call when model is used).
    ///
    /// This method should be called whenever a model is loaded for inference
    /// to maintain accurate LRU information. The cache metadata is persisted
    /// after updating.
    ///
    /// If the model is not in the cache, this method does nothing.
    ///
    /// - Parameter model: The model identifier that was accessed.
    ///
    /// ## Example
    /// ```swift
    /// // When loading a model for inference
    /// if let info = cache.info(for: .llama3_2_1b) {
    ///     let mlxModel = try MLX.load(from: info.path)
    ///     cache.markAccessed(.llama3_2_1b) // Update LRU
    ///     // Use the model...
    /// }
    /// ```
    public func markAccessed(_ model: ModelIdentifier) {
        guard let info = cache[model] else { return }

        // Create updated info with new last accessed time
        let updatedInfo = CachedModelInfo(
            identifier: info.identifier,
            path: info.path,
            size: info.size,
            downloadedAt: info.downloadedAt,
            lastAccessedAt: Date(),
            revision: info.revision
        )

        cache[model] = updatedInfo

        // Persist the update (ignore errors as this is non-critical)
        try? saveMetadata()
    }

    /// Removes a model from the cache.
    ///
    /// Removes the model's metadata from the cache and deletes its
    /// files from disk. The cache metadata is persisted after removal.
    ///
    /// - Parameter model: The model identifier to remove.
    /// - Throws: `AIError.fileError` if files cannot be deleted or
    ///   metadata cannot be saved.
    ///
    /// ## Example
    /// ```swift
    /// // Remove a specific model
    /// try cache.remove(.llama3_2_1b)
    /// print("Model removed and disk space freed")
    /// ```
    public func remove(_ model: ModelIdentifier) throws {
        guard let info = cache[model] else {
            // Model not in cache, nothing to do
            return
        }

        // Remove from in-memory cache first
        cache.removeValue(forKey: model)

        // Delete the model files from disk
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: info.path.path) {
                try fileManager.removeItem(at: info.path)
            }
        } catch {
            // Re-add to cache if deletion failed
            cache[model] = info
            throw AIError.file(error)
        }

        // Persist the updated cache
        try saveMetadata()
    }

    /// Clears all cached models.
    ///
    /// Removes all models from the cache and deletes all model files
    /// from disk. The cache directory structure is preserved.
    ///
    /// - Throws: `AIError.fileError` if files cannot be deleted or
    ///   metadata cannot be saved.
    ///
    /// ## Example
    /// ```swift
    /// // Clear all cached models to free space
    /// try cache.clearAll()
    /// print("All models removed from cache")
    /// ```
    public func clearAll() throws {
        let fileManager = FileManager.default
        var errors: [Error] = []

        // Delete all model directories
        for info in cache.values {
            do {
                if fileManager.fileExists(atPath: info.path.path) {
                    try fileManager.removeItem(at: info.path)
                }
            } catch {
                errors.append(error)
            }
        }

        // Clear the in-memory cache
        cache.removeAll()

        // Persist the empty cache
        try saveMetadata()

        // If any deletions failed, throw an error
        if let firstError = errors.first {
            throw AIError.file(firstError)
        }
    }

    // MARK: - LRU Eviction

    /// Evicts models until total size is under the limit.
    ///
    /// Uses a Least Recently Used (LRU) algorithm to determine which
    /// models to evict. Models are sorted by last accessed time (oldest
    /// first) and removed until the total cache size is under the
    /// specified maximum.
    ///
    /// - Parameter maxSize: The maximum allowed cache size.
    /// - Returns: Array of evicted model info.
    /// - Throws: `AIError.fileError` if models cannot be removed.
    ///
    /// ## Example
    /// ```swift
    /// // Limit cache to 20GB
    /// let evicted = try cache.evictToFit(maxSize: .gigabytes(20))
    ///
    /// if !evicted.isEmpty {
    ///     print("Evicted \(evicted.count) models:")
    ///     for model in evicted {
    ///         print("- \(model.identifier.displayName) (\(model.size.formatted))")
    ///     }
    /// }
    /// ```
    @discardableResult
    public func evictToFit(maxSize: ByteCount) throws -> [CachedModelInfo] {
        var evicted: [CachedModelInfo] = []
        var currentSize = totalSize()

        // If we're already under the limit, no eviction needed
        guard currentSize > maxSize else {
            return []
        }

        // Sort models by lastAccessedAt (oldest first) for LRU eviction
        let sorted = cache.values.sorted { $0.lastAccessedAt < $1.lastAccessedAt }

        // Evict models until we're under the limit
        for info in sorted {
            guard currentSize > maxSize else { break }

            // Remove the model
            try remove(info.identifier)

            // Update current size
            currentSize = ByteCount(currentSize.bytes - info.size.bytes)

            // Track evicted models
            evicted.append(info)
        }

        return evicted
    }

    // MARK: - Persistence

    /// Saves cache metadata to disk.
    ///
    /// Persists the current cache state to a JSON file in the cache
    /// directory. This allows the cache to survive app restarts.
    ///
    /// - Throws: `AIError.fileError` if the metadata cannot be saved.
    private func saveMetadata() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            // Convert cache dictionary to array for JSON encoding
            let metadataArray = Array(cache.values)
            let data = try encoder.encode(metadataArray)
            try data.write(to: metadataPath, options: .atomic)
        } catch {
            throw AIError.file(error)
        }
    }

    /// Loads cache metadata from disk.
    ///
    /// Reads the cache metadata JSON file and reconstructs the
    /// in-memory cache dictionary.
    ///
    /// - Returns: Dictionary mapping model identifiers to cached info.
    /// - Throws: `AIError.fileError` if the metadata cannot be loaded.
    private func loadMetadata() throws -> [ModelIdentifier: CachedModelInfo] {
        let fileManager = FileManager.default

        // If metadata file doesn't exist, return empty cache
        guard fileManager.fileExists(atPath: metadataPath.path) else {
            return [:]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: metadataPath)
            let metadataArray = try decoder.decode([CachedModelInfo].self, from: data)

            // Convert array to dictionary keyed by identifier
            var cache: [ModelIdentifier: CachedModelInfo] = [:]
            for info in metadataArray {
                cache[info.identifier] = info
            }

            return cache
        } catch {
            throw AIError.file(error)
        }
    }
}

// MARK: - Convenience Extensions

extension ModelCache {

    /// Returns the number of cached models.
    ///
    /// - Returns: The count of models in the cache.
    public var count: Int {
        cache.count
    }

    /// Whether the cache is empty.
    ///
    /// - Returns: `true` if no models are cached, `false` otherwise.
    public var isEmpty: Bool {
        cache.isEmpty
    }
}
