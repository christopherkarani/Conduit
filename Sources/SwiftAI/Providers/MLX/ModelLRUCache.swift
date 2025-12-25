// ModelLRUCache.swift
// SwiftAI
//
// LRU cache for diffusion models to improve performance when switching between models.

import Foundation
@preconcurrency import MLX
import StableDiffusion

/// An LRU (Least Recently Used) cache for loaded diffusion models.
///
/// This cache improves performance when switching between models by keeping
/// recently used models in memory. When the cache reaches capacity, the least
/// recently used model is automatically evicted and its GPU resources are freed.
///
/// ## Features
///
/// - **Thread-Safe**: Implemented as an actor for safe concurrent access
/// - **Automatic Eviction**: Removes least recently used models when capacity is reached
/// - **GPU Cleanup**: Automatically clears GPU cache when evicting models
/// - **Configurable Capacity**: Set maximum number of cached models (default 2)
///
/// ## Usage
///
/// ```swift
/// let cache = ModelLRUCache(capacity: 3)
///
/// // Cache a model
/// await cache.put(modelId: "sdxl-turbo", variant: .sdxlTurbo, container: model)
///
/// // Retrieve a model
/// if let model = await cache.get(modelId: "sdxl-turbo", variant: .sdxlTurbo) {
///     // Model found in cache
/// }
/// ```
///
/// ## Memory Management
///
/// Each cached model consumes significant RAM (2-8GB depending on variant).
/// The default capacity of 2 models is suitable for most use cases. Increase
/// capacity only if you have sufficient RAM and frequently switch between
/// multiple models.
public actor ModelLRUCache {

    // MARK: - Types

    /// Cache entry containing a model container and its last access time.
    private struct CacheEntry {
        let container: ModelContainer<TextToImageGenerator>
        var lastAccessed: Date

        init(container: ModelContainer<TextToImageGenerator>) {
            self.container = container
            self.lastAccessed = Date()
        }

        mutating func updateAccessTime() {
            lastAccessed = Date()
        }
    }

    /// Cache key combining model ID and variant.
    private struct CacheKey: Hashable, Sendable {
        let modelId: String
        let variant: DiffusionVariant
    }

    // MARK: - Properties

    /// Maximum number of models to keep in cache.
    private let capacity: Int

    /// The cache storage mapping keys to entries.
    private var cache: [CacheKey: CacheEntry] = [:]

    // MARK: - Initialization

    /// Creates a new LRU cache with the specified capacity.
    ///
    /// - Parameter capacity: Maximum number of models to cache (default 2).
    ///   Must be at least 1.
    ///
    /// - Note: Each cached model consumes 2-8GB of RAM. Ensure your device
    ///   has sufficient memory before increasing capacity.
    public init(capacity: Int = 2) {
        self.capacity = max(1, capacity)
    }

    // MARK: - Public Methods

    /// Retrieves a cached model if available.
    ///
    /// If the model is found, its last access time is updated to mark it
    /// as recently used.
    ///
    /// - Parameters:
    ///   - modelId: The identifier of the model.
    ///   - variant: The diffusion variant.
    ///
    /// - Returns: The cached model container, or `nil` if not found.
    public func get(
        modelId: String,
        variant: DiffusionVariant
    ) -> ModelContainer<TextToImageGenerator>? {
        let key = CacheKey(modelId: modelId, variant: variant)

        guard var entry = cache[key] else {
            return nil
        }

        // Update access time
        entry.updateAccessTime()
        cache[key] = entry

        return entry.container
    }

    /// Stores a model in the cache.
    ///
    /// If the cache is at capacity, the least recently used model is evicted
    /// and its GPU resources are freed before adding the new model.
    ///
    /// - Parameters:
    ///   - modelId: The identifier of the model.
    ///   - variant: The diffusion variant.
    ///   - container: The model container to cache.
    public func put(
        modelId: String,
        variant: DiffusionVariant,
        container: ModelContainer<TextToImageGenerator>
    ) {
        let key = CacheKey(modelId: modelId, variant: variant)

        // If already cached, just update the entry
        if cache[key] != nil {
            var entry = CacheEntry(container: container)
            entry.updateAccessTime()
            cache[key] = entry
            return
        }

        // Evict LRU entry if at capacity
        if cache.count >= capacity {
            evictLRU()
        }

        // Add new entry
        cache[key] = CacheEntry(container: container)
    }

    /// Removes a specific model from the cache.
    ///
    /// If the model is found and removed, its GPU resources are freed.
    ///
    /// - Parameters:
    ///   - modelId: The identifier of the model.
    ///   - variant: The diffusion variant.
    public func remove(modelId: String, variant: DiffusionVariant) {
        let key = CacheKey(modelId: modelId, variant: variant)

        if cache.removeValue(forKey: key) != nil {
            clearGPUCache()
        }
    }

    /// Removes all models from the cache and clears GPU resources.
    public func clear() {
        cache.removeAll()
        clearGPUCache()
    }

    /// The current number of models in the cache.
    public var count: Int {
        cache.count
    }

    /// Checks if a specific model is cached.
    ///
    /// - Parameters:
    ///   - modelId: The identifier of the model.
    ///   - variant: The diffusion variant.
    ///
    /// - Returns: `true` if the model is in the cache, `false` otherwise.
    public func contains(modelId: String, variant: DiffusionVariant) -> Bool {
        let key = CacheKey(modelId: modelId, variant: variant)
        return cache[key] != nil
    }

    // MARK: - Private Methods

    /// Evicts the least recently used model from the cache.
    ///
    /// Finds the entry with the oldest access time, removes it, and
    /// clears GPU cache to free resources.
    private func evictLRU() {
        guard !cache.isEmpty else { return }

        // Find the entry with the oldest access time
        let lruKey = cache.min { a, b in
            a.value.lastAccessed < b.value.lastAccessed
        }?.key

        if let key = lruKey {
            cache.removeValue(forKey: key)
            clearGPUCache()
        }
    }

    /// Clears the GPU cache to free resources.
    ///
    /// This should be called after evicting or removing models to ensure
    /// GPU memory is properly released.
    private func clearGPUCache() {
        #if arch(arm64)
        MLX.GPU.clearCache()
        #endif
    }
}
