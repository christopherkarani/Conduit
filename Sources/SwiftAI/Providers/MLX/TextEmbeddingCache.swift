// TextEmbeddingCache.swift
// SwiftAI
//
// Caches text embeddings to avoid re-encoding repeated prompts.

import Foundation
@preconcurrency import MLX

// MARK: - TextEmbeddingCache

/// Actor for caching text embeddings from diffusion models.
///
/// Provides automatic memory management using NSCache's built-in eviction policies.
/// Caches are invalidated when the model changes to prevent stale embeddings.
///
/// ## Features
///
/// - **Automatic Eviction**: NSCache handles memory pressure automatically
/// - **Model Awareness**: Cache invalidates when model changes
/// - **Size Limits**: Configure max cached embeddings and total memory usage
/// - **Thread-Safe**: Actor isolation ensures safe concurrent access
///
/// ## Usage
///
/// ```swift
/// let cache = TextEmbeddingCache()
///
/// // Create cache key
/// let key = cache.makeKey(
///     prompt: "A serene mountain landscape",
///     negativePrompt: "blurry",
///     modelId: "sdxl-turbo"
/// )
///
/// // Check if cached
/// if let cached = await cache.get(key) {
///     print("Cache hit!")
/// } else {
///     // Generate and cache
///     let embedding = generateEmbedding(...)
///     await cache.put(embedding, forKey: key)
/// }
/// ```
///
/// ## Performance
///
/// Text encoding can take 100-300ms per prompt. Caching provides:
/// - 100% speedup for repeated prompts
/// - Reduced GPU memory pressure
/// - Lower power consumption
///
/// ## Memory Management
///
/// The default configuration caches up to 50 embeddings with a 100MB limit.
/// NSCache automatically evicts old entries when memory pressure increases.
public actor TextEmbeddingCache {

    // MARK: - Types

    /// Key for caching text embeddings.
    ///
    /// Uniquely identifies an embedding based on the prompt, negative prompt,
    /// and model used. All three must match for a cache hit.
    public struct CacheKey: Hashable, Sendable {
        /// The positive prompt text
        public let prompt: String

        /// The negative prompt text (empty string if none)
        public let negativePrompt: String

        /// The model identifier
        public let modelId: String

        public init(prompt: String, negativePrompt: String, modelId: String) {
            self.prompt = prompt
            self.negativePrompt = negativePrompt
            self.modelId = modelId
        }
    }

    /// Wrapper for cached MLXArray embeddings.
    ///
    /// Wraps the embedding along with size information for NSCache cost tracking.
    private final class EmbeddingWrapper: NSObject {
        let embedding: MLXArray
        let cost: Int

        init(embedding: MLXArray, cost: Int) {
            self.embedding = embedding
            self.cost = cost
        }
    }

    /// NSObject wrapper for CacheKey to use with NSCache.
    ///
    /// NSCache requires keys to be NSObject subclasses.
    private final class KeyWrapper: NSObject {
        let key: CacheKey

        init(_ key: CacheKey) {
            self.key = key
        }

        override var hash: Int { key.hashValue }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? KeyWrapper else { return false }
            return key == other.key
        }
    }


    // MARK: - Properties

    /// The underlying NSCache for embeddings
    ///
    /// Using `SendableNSCache` which provides `@unchecked Sendable` conformance
    /// for safe actor usage. As an immutable `let` property with a Sendable type,
    /// this can be safely accessed without `nonisolated(unsafe)`.
    private let cacheWrapper = SendableNSCache<KeyWrapper, EmbeddingWrapper>()

    /// Convenience accessor for the cache
    private var cache: NSCache<KeyWrapper, EmbeddingWrapper> { cacheWrapper.cache }

    /// The current model ID for cache invalidation
    private var currentModelId: String?

    // MARK: - Initialization

    /// Creates a new text embedding cache.
    ///
    /// - Parameters:
    ///   - countLimit: Maximum number of embeddings to cache (default: 50)
    ///   - costLimit: Maximum total memory in bytes (default: 100MB)
    public init(countLimit: Int = 50, costLimit: Int = 100 * 1024 * 1024) {
        // Access the cache directly through cacheWrapper since `cache` is actor-isolated
        cacheWrapper.cache.countLimit = countLimit
        cacheWrapper.cache.totalCostLimit = costLimit
    }

    // MARK: - Public Methods

    /// Creates a cache key for the given parameters.
    ///
    /// Use this key to check for cached embeddings or store new ones.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let key = cache.makeKey(
    ///     prompt: "A fantasy castle",
    ///     negativePrompt: "blurry, low quality",
    ///     modelId: "sdxl-turbo"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: The positive prompt text
    ///   - negativePrompt: The negative prompt text (use empty string if none)
    ///   - modelId: The model identifier
    /// - Returns: A cache key for this combination
    public nonisolated func makeKey(prompt: String, negativePrompt: String, modelId: String) -> CacheKey {
        CacheKey(prompt: prompt, negativePrompt: negativePrompt, modelId: modelId)
    }

    /// Retrieves a cached embedding.
    ///
    /// Returns `nil` if the embedding is not cached or was evicted.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let cached = await cache.get(key) {
    ///     // Use cached embedding
    /// } else {
    ///     // Generate new embedding
    /// }
    /// ```
    ///
    /// - Parameter key: The cache key to look up
    /// - Returns: The cached embedding, or nil if not found
    public func get(_ key: CacheKey) -> MLXArray? {
        let wrapper = KeyWrapper(key)
        return cache.object(forKey: wrapper)?.embedding
    }

    /// Caches an embedding.
    ///
    /// The cost is calculated from the embedding's memory footprint.
    /// NSCache may automatically evict old entries if limits are exceeded.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let embedding = generator.encode(prompt)
    /// await cache.put(embedding, forKey: key)
    /// ```
    ///
    /// - Parameters:
    ///   - embedding: The MLXArray embedding to cache
    ///   - key: The cache key
    public func put(_ embedding: MLXArray, forKey key: CacheKey) {
        let cost = estimateCost(embedding)
        let wrapper = EmbeddingWrapper(embedding: embedding, cost: cost)
        let keyWrapper = KeyWrapper(key)
        cache.setObject(wrapper, forKey: keyWrapper, cost: cost)
    }

    /// Clears all cached embeddings.
    ///
    /// Use this when memory is low or when switching between models.
    ///
    /// ## Example
    ///
    /// ```swift
    /// await cache.clear()
    /// ```
    public func clear() {
        cache.removeAllObjects()
    }

    /// Notifies the cache that the model has changed.
    ///
    /// This clears all cached embeddings because embeddings from different
    /// models are incompatible.
    ///
    /// Call this whenever you load a new diffusion model.
    ///
    /// ## Example
    ///
    /// ```swift
    /// await provider.loadModel(from: path, variant: .sdxlTurbo)
    /// await cache.modelDidChange(to: path.lastPathComponent)
    /// ```
    ///
    /// - Parameter modelId: The new model identifier
    public func modelDidChange(to modelId: String) {
        if currentModelId != modelId {
            clear()
            currentModelId = modelId
        }
    }

    // MARK: - Private Helpers

    /// Estimates the memory cost of an MLXArray.
    ///
    /// Calculates bytes based on shape and data type.
    ///
    /// - Parameter array: The MLXArray to estimate
    /// - Returns: Estimated size in bytes
    private func estimateCost(_ array: MLXArray) -> Int {
        // MLXArray shape gives us dimensions
        // For embeddings, typical shape is [batch, sequence_length, embedding_dim]
        // Cost = total_elements * bytes_per_element

        let totalElements = array.shape.reduce(1, *)

        // Most embeddings use float32 (4 bytes per element)
        // Some models use float16 (2 bytes per element)
        let bytesPerElement: Int
        switch array.dtype {
        case .float32:
            bytesPerElement = 4
        case .float16:
            bytesPerElement = 2
        default:
            bytesPerElement = 4 // Default to float32
        }

        return totalElements * bytesPerElement
    }
}
