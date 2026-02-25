//
//  MLXModelCache.swift
//  Conduit
//
//  Created on 2025-12-17.
//

#if CONDUIT_TRAIT_MLX
import Foundation

// MARK: - Linux Compatibility
// NOTE: MLX requires Metal GPU and Apple Silicon. Not available on Linux.
#if canImport(MLX)

@preconcurrency import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXLLM

// MARK: - CacheStats

/// Statistics about the model cache.
///
/// Provides insight into current cache state including memory usage,
/// cached model count, and active model information.
///
/// ## Usage
/// ```swift
/// let cache = MLXModelCache.shared
/// let stats = await cache.cacheStats()
/// print("Cached models: \(stats.cachedModelCount)")
/// print("Memory usage: \(stats.totalMemoryUsage)")
/// ```
public struct CacheStats: Sendable {
    /// Number of models currently in cache
    public let cachedModelCount: Int

    /// Total memory used by cached models
    public let totalMemoryUsage: ByteCount

    /// ID of the currently active model, if any
    public let currentModelId: String?

    /// List of all cached model IDs
    public let modelIds: [String]
}

// MARK: - MLXModelCache

/// Actor for caching loaded MLX models with NSCache-based lifecycle management.
///
/// Provides automatic memory management using NSCache's built-in eviction policies
/// while maintaining parallel tracking for statistics and cache queries.
///
/// ## Features
/// - **Automatic Eviction**: NSCache handles memory pressure automatically
/// - **Size Limits**: Configure max cached models and total memory usage
/// - **Statistics**: Track cache hits, memory usage, and active models
/// - **Thread-Safe**: Actor isolation ensures safe concurrent access
///
/// ## Usage
/// ```swift
/// let cache = MLXModelCache.shared
///
/// // Cache a model
/// let model = CachedModel(
///     modelId: "llama-3.2-1B",
///     container: container,
///     capabilities: caps,
///     weightsSize: .gigabytes(2)
/// )
/// await cache.set(model, forKey: "llama-3.2-1B")
///
/// // Retrieve a model
/// if let cached = await cache.get("llama-3.2-1B") {
///     print("Cache hit!")
/// }
///
/// // Check statistics
/// let stats = await cache.cacheStats()
/// print("Using \(stats.totalMemoryUsage) across \(stats.cachedModelCount) models")
/// ```
public actor MLXModelCache {

    // MARK: - Singleton

    /// Shared singleton instance
    public static let shared = MLXModelCache()

    // MARK: - CachedModel

    /// Cached model container with metadata.
    ///
    /// Wraps a ModelContainer along with capabilities, load time,
    /// and size information for cache management.
    ///
    /// Marked `@unchecked Sendable` because:
    /// - `ModelContainer` is from MLX (imported via `@preconcurrency`)
    /// - Access is always through the `MLXModelCache` actor, providing isolation
    /// - The container is immutable after initialization
    public final class CachedModel: NSObject, @unchecked Sendable {
        /// Model ID used to reconcile NSCache evictions with actor tracking.
        let modelId: String

        /// The loaded MLX model container
        let container: ModelContainer

        /// Model capabilities (text generation, embeddings, etc.)
        let capabilities: ModelCapabilities

        /// Timestamp when model was loaded into cache
        let loadedAt: Date

        /// Size of model weights in memory
        let weightsSize: ByteCount

        init(modelId: String, container: ModelContainer, capabilities: ModelCapabilities, weightsSize: ByteCount) {
            self.modelId = modelId
            self.container = container
            self.capabilities = capabilities
            self.loadedAt = Date()
            self.weightsSize = weightsSize
        }
    }

    // MARK: - Properties

    /// Thread-safe wrapper around NSCache
    ///
    /// Using `SendableNSCache` which provides `@unchecked Sendable` conformance
    /// for safe actor usage. As an immutable `let` property with a Sendable type,
    /// this can be safely accessed without `nonisolated(unsafe)`.
    private let cacheWrapper = SendableNSCache<NSString, CachedModel>()

    /// Convenience accessor for the underlying cache
    private var cache: NSCache<NSString, CachedModel> { cacheWrapper.cache }

    /// Tracks cached model IDs (NSCache doesn't provide enumeration)
    private var cachedModelIds: Set<String> = []

    /// Tracks memory usage per model for statistics
    private var modelSizes: [String: ByteCount] = [:]

    /// Currently active model ID
    private var currentModelId: String?

    /// Cache eviction delegate
    private let delegate: CacheDelegate

    /// NSCache delegate for handling eviction notifications
    private final class CacheDelegate: NSObject, NSCacheDelegate, @unchecked Sendable {
        /// Optional callback when NSCache evicts an object
        var onEviction: ((String) -> Void)?

        func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
            guard let model = obj as? CachedModel else { return }
            onEviction?(model.modelId)
        }
    }

    // MARK: - Configuration

    /// Configuration options for the model cache.
    ///
    /// Controls cache size limits and eviction behavior.
    public struct Configuration: Sendable {
        /// Maximum number of models to keep in cache
        public var maxCachedModels: Int

        /// Maximum total memory for cached models (nil = unlimited)
        public var maxCacheSize: ByteCount?

        /// Default configuration: 3 models, no size limit
        public static let `default` = Configuration(maxCachedModels: 3, maxCacheSize: nil)

        /// Low memory configuration: 1 model, 4GB limit
        public static let lowMemory = Configuration(maxCachedModels: 1, maxCacheSize: .gigabytes(4))

        public init(maxCachedModels: Int = 3, maxCacheSize: ByteCount? = nil) {
            self.maxCachedModels = maxCachedModels
            self.maxCacheSize = maxCacheSize
        }
    }

    // MARK: - Initialization

    /// Initialize a new cache with the given configuration.
    ///
    /// - Parameter configuration: Cache size and eviction settings
    ///
    /// - Important: This is `internal` to allow unit tests to create isolated
    /// caches without mutating the process-global `shared` singleton.
    internal init(configuration: Configuration = .default) {
        self.delegate = CacheDelegate()
        self.delegate.onEviction = { [weak self] modelId in
            Task { await self?.handleEviction(of: modelId) }
        }
        cacheWrapper.cache.delegate = delegate
        cacheWrapper.cache.countLimit = configuration.maxCachedModels
        if let maxSize = configuration.maxCacheSize {
            cacheWrapper.cache.totalCostLimit = Int(maxSize.bytes)
        }
    }

    // MARK: - Public Methods

    /// Retrieves a cached model by ID.
    ///
    /// Automatically cleans up tracking if the model was evicted by NSCache.
    ///
    /// - Parameter modelId: Unique identifier for the model
    /// - Returns: The cached model, or nil if not found or evicted
    public func get(_ modelId: String) -> CachedModel? {
        let key = modelId as NSString
        let model = cache.object(forKey: key)
        if model == nil {
            // Model was evicted by NSCache - clean up tracking
            cachedModelIds.remove(modelId)
            modelSizes.removeValue(forKey: modelId)
        }
        return model
    }

    /// Caches a model with the given ID.
    ///
    /// The model's weight size is used as the cost for NSCache eviction.
    /// NSCache may automatically evict older models if limits are exceeded.
    ///
    /// - Parameters:
    ///   - model: The cached model container
    ///   - modelId: Unique identifier for the model
    public func set(_ model: CachedModel, forKey modelId: String) {
        let key = modelId as NSString
        cache.setObject(model, forKey: key, cost: Int(model.weightsSize.bytes))
        cachedModelIds.insert(modelId)
        modelSizes[modelId] = model.weightsSize
    }

    /// Removes a model from the cache.
    ///
    /// - Parameter modelId: The model ID to remove
    public func remove(_ modelId: String) {
        let key = modelId as NSString
        cache.removeObject(forKey: key)
        cachedModelIds.remove(modelId)
        modelSizes.removeValue(forKey: modelId)
        if currentModelId == modelId {
            currentModelId = nil
        }
    }

    /// Removes all models from the cache.
    ///
    /// Clears both the NSCache and all tracking structures.
    public func removeAll() {
        cache.removeAllObjects()
        cachedModelIds.removeAll()
        modelSizes.removeAll()
        currentModelId = nil
    }

    /// Checks if a model is cached.
    ///
    /// Verifies the model is actually still in NSCache, not just in tracking.
    /// Automatically cleans up stale tracking if the model was evicted.
    ///
    /// - Parameter modelId: The model ID to check
    /// - Returns: true if the model is currently cached
    public func contains(_ modelId: String) -> Bool {
        // Verify it's actually still in cache (may have been evicted)
        let key = modelId as NSString
        if cache.object(forKey: key) != nil {
            return true
        }
        // Clean up tracking if evicted
        cachedModelIds.remove(modelId)
        modelSizes.removeValue(forKey: modelId)
        return false
    }

    /// Returns current cache statistics.
    ///
    /// Provides a snapshot of cache state including memory usage,
    /// cached model count, and the currently active model.
    ///
    /// - Returns: Cache statistics structure
    public func cacheStats() -> CacheStats {
        let totalMemory = modelSizes.values.reduce(ByteCount(0)) {
            ByteCount($0.bytes + $1.bytes)
        }
        return CacheStats(
            cachedModelCount: cachedModelIds.count,
            totalMemoryUsage: totalMemory,
            currentModelId: currentModelId,
            modelIds: Array(cachedModelIds)
        )
    }

    /// Sets the currently active model ID.
    ///
    /// Used to track which model is currently in use for statistics.
    ///
    /// - Parameter modelId: The model ID to mark as active, or nil to clear
    public func setCurrentModel(_ modelId: String?) {
        currentModelId = modelId
    }

    /// Gets the currently active model ID.
    ///
    /// - Returns: The active model ID, or nil if no model is active
    public func getCurrentModelId() -> String? {
        currentModelId
    }

    private func handleEviction(of modelId: String) {
        cachedModelIds.remove(modelId)
        modelSizes.removeValue(forKey: modelId)
        if currentModelId == modelId {
            currentModelId = nil
        }
    }

    // MARK: - Test Hooks

    /// Apply a cache configuration.
    internal func apply(configuration: Configuration) {
        let currentCountLimit = cache.countLimit
        let newCountLimit = max(1, configuration.maxCachedModels)

        if currentCountLimit == 0 {
            cache.countLimit = newCountLimit
        } else {
            cache.countLimit = min(currentCountLimit, newCountLimit)
        }

        if let maxSize = configuration.maxCacheSize, maxSize.bytes > 0 {
            let newCostLimit = Int(maxSize.bytes)
            let currentCostLimit = cache.totalCostLimit

            if currentCostLimit == 0 {
                cache.totalCostLimit = newCostLimit
            } else {
                cache.totalCostLimit = min(currentCostLimit, newCostLimit)
            }
        }
    }

    /// Returns the current underlying NSCache limits for unit tests.
    internal func _testing_limits() -> (countLimit: Int, totalCostLimit: Int) {
        (cache.countLimit, cache.totalCostLimit)
    }
}

#endif // canImport(MLX)

#endif // CONDUIT_TRAIT_MLX
