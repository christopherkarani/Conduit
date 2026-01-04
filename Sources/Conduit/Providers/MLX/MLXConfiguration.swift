// MLXConfiguration.swift
// Conduit

import Foundation

// MARK: - Linux Compatibility
// NOTE: MLX requires Metal GPU and Apple Silicon. Not available on Linux.
#if canImport(MLX)

/// Configuration options for MLX local inference on Apple Silicon.
///
/// `MLXConfiguration` controls memory management, compute preferences,
/// and KV cache settings for optimal performance on different Apple Silicon devices.
///
/// ## Usage
/// ```swift
/// // Use defaults
/// let config = MLXConfiguration.default
///
/// // Use a preset optimized for your device
/// let config = MLXConfiguration.m1Optimized
///
/// // Customize with fluent API
/// let config = MLXConfiguration.default
///     .memoryLimit(.gigabytes(8))
///     .prefillStepSize(256)
///     .withQuantizedKVCache(bits: 4)
/// ```
///
/// ## Presets
/// - `default`: Balanced configuration for general use
/// - `memoryEfficient`: Uses quantized KV cache for memory-constrained devices
/// - `highPerformance`: Large prefill steps for maximum throughput
/// - `m1Optimized`: Tuned for M1 chips (~8GB RAM)
/// - `mProOptimized`: Tuned for M1/M2/M3 Pro/Max (~16-32GB RAM)
/// - `lowMemory`: Aggressively limits memory and caching (4GB, 1 model)
/// - `multiModel`: Optimized for multi-model workflows (5 models, no limit)
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
public struct MLXConfiguration: Sendable, Hashable {

    // MARK: - Memory Management

    /// Maximum memory the model can use.
    ///
    /// If `nil`, uses system default based on available memory.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.memoryLimit(.gigabytes(8))
    /// ```
    public var memoryLimit: ByteCount?

    /// Whether to use memory mapping for model weights.
    ///
    /// Memory mapping reduces initial load time but may increase memory pressure.
    ///
    /// - Note: Default is `true`.
    public var useMemoryMapping: Bool

    /// Maximum entries in the KV cache.
    ///
    /// Limits context length to control memory usage.
    /// If `nil`, no explicit limit is set.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.kvCacheLimit(4096)
    /// ```
    public var kvCacheLimit: Int?

    // MARK: - Compute Preferences

    /// Number of tokens to process in each prefill step.
    ///
    /// Larger values improve throughput but use more memory.
    ///
    /// - Note: Must be at least 1. Invalid values are clamped.
    /// - Default: 512
    public var prefillStepSize: Int

    /// Whether to use quantized (compressed) KV cache.
    ///
    /// Reduces memory usage at slight quality cost.
    ///
    /// - Note: Default is `false`.
    public var useQuantizedKVCache: Bool

    /// Bit depth for KV cache quantization (4 or 8).
    ///
    /// Only used when `useQuantizedKVCache` is `true`.
    ///
    /// - Note: Values outside 4-8 range are automatically clamped.
    /// - Default: 4
    public var kvQuantizationBits: Int

    // MARK: - Model Cache Configuration

    /// Maximum number of models to keep in cache.
    ///
    /// Controls how many loaded models are retained in memory.
    /// When exceeded, least recently used models are evicted.
    ///
    /// - Note: Default is 3.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.maxCachedModels(5)
    /// ```
    public var maxCachedModels: Int

    /// Maximum total memory for cached models.
    ///
    /// If `nil`, no limit is imposed on total cache size.
    /// When exceeded, models are evicted to free memory.
    ///
    /// - Note: Default is `nil` (no limit).
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.maxCacheSize(.gigabytes(8))
    /// ```
    public var maxCacheSize: ByteCount?

    // MARK: - Initialization

    /// Creates an MLX configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - memoryLimit: Maximum memory the model can use (default: nil).
    ///   - useMemoryMapping: Whether to use memory mapping for weights (default: true).
    ///   - kvCacheLimit: Maximum entries in KV cache (default: nil).
    ///   - prefillStepSize: Tokens per prefill step (default: 512).
    ///   - useQuantizedKVCache: Use compressed KV cache (default: false).
    ///   - kvQuantizationBits: Bit depth for quantization, 4 or 8 (default: 4).
    ///   - maxCachedModels: Maximum number of models to keep in cache (default: 3).
    ///   - maxCacheSize: Maximum total memory for cached models (default: nil).
    public init(
        memoryLimit: ByteCount? = nil,
        useMemoryMapping: Bool = true,
        kvCacheLimit: Int? = nil,
        prefillStepSize: Int = 512,
        useQuantizedKVCache: Bool = false,
        kvQuantizationBits: Int = 4,
        maxCachedModels: Int = 3,
        maxCacheSize: ByteCount? = nil
    ) {
        self.memoryLimit = memoryLimit
        self.useMemoryMapping = useMemoryMapping
        self.kvCacheLimit = kvCacheLimit
        self.prefillStepSize = max(1, prefillStepSize)
        self.useQuantizedKVCache = useQuantizedKVCache
        self.kvQuantizationBits = max(4, min(8, kvQuantizationBits)) // Clamp to valid range
        self.maxCachedModels = maxCachedModels
        self.maxCacheSize = maxCacheSize
    }

    // MARK: - Static Presets

    /// Default balanced configuration.
    ///
    /// Good for general-purpose inference on most Apple Silicon devices.
    ///
    /// ## Configuration
    /// - memoryLimit: nil (system default)
    /// - useMemoryMapping: true
    /// - prefillStepSize: 512
    /// - useQuantizedKVCache: false
    public static let `default` = MLXConfiguration()

    /// Memory-efficient configuration using quantized KV cache.
    ///
    /// Good for devices with limited RAM (8GB or less).
    ///
    /// ## Configuration
    /// - useQuantizedKVCache: true
    /// - kvQuantizationBits: 4
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .memoryEfficient)
    /// ```
    public static let memoryEfficient = MLXConfiguration(
        useQuantizedKVCache: true,
        kvQuantizationBits: 4
    )

    /// High-performance configuration with large prefill steps.
    ///
    /// Best for devices with ample RAM (32GB+).
    ///
    /// ## Configuration
    /// - prefillStepSize: 1024
    /// - useQuantizedKVCache: false
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .highPerformance)
    /// ```
    public static let highPerformance = MLXConfiguration(
        prefillStepSize: 1024,
        useQuantizedKVCache: false
    )

    /// Optimized for M1 chips with ~8GB RAM.
    ///
    /// Uses conservative memory limits and quantized KV cache
    /// to maximize compatibility on base M1 devices.
    ///
    /// ## Configuration
    /// - memoryLimit: 6 GB
    /// - prefillStepSize: 256
    /// - useQuantizedKVCache: true
    /// - kvQuantizationBits: 4
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .m1Optimized)
    /// ```
    public static let m1Optimized = MLXConfiguration(
        memoryLimit: .gigabytes(6),
        prefillStepSize: 256,
        useQuantizedKVCache: true,
        kvQuantizationBits: 4
    )

    /// Optimized for M1/M2/M3 Pro/Max with ~16-32GB RAM.
    ///
    /// Uses larger memory limits and disables quantization
    /// for better quality on Pro/Max devices.
    ///
    /// ## Configuration
    /// - memoryLimit: 12 GB
    /// - prefillStepSize: 512
    /// - useQuantizedKVCache: false
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .mProOptimized)
    /// ```
    public static let mProOptimized = MLXConfiguration(
        memoryLimit: .gigabytes(12),
        prefillStepSize: 512,
        useQuantizedKVCache: false
    )

    /// Configuration optimized for low memory devices.
    ///
    /// Aggressively limits memory usage for devices with constrained resources.
    /// Caches only one model and enforces a strict memory limit.
    ///
    /// ## Configuration
    /// - memoryLimit: 4 GB
    /// - useQuantizedKVCache: true
    /// - kvQuantizationBits: 4
    /// - maxCachedModels: 1
    /// - maxCacheSize: 4 GB
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .lowMemory)
    /// ```
    public static let lowMemory = MLXConfiguration(
        memoryLimit: .gigabytes(4),
        useQuantizedKVCache: true,
        kvQuantizationBits: 4,
        maxCachedModels: 1,
        maxCacheSize: .gigabytes(4)
    )

    /// Configuration for multi-model workflows.
    ///
    /// Allows caching multiple models simultaneously without size limits.
    /// Good for applications that switch between different models frequently.
    ///
    /// ## Configuration
    /// - maxCachedModels: 5
    /// - maxCacheSize: nil (no limit)
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider(configuration: .multiModel)
    /// ```
    public static let multiModel = MLXConfiguration(
        maxCachedModels: 5,
        maxCacheSize: nil
    )
}

// MARK: - Fluent API

extension MLXConfiguration {

    /// Returns a copy with the specified memory limit.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.memoryLimit(.gigabytes(8))
    /// ```
    ///
    /// - Parameter limit: Maximum memory the model can use, or `nil` for system default.
    /// - Returns: A new configuration with the updated memory limit.
    public func memoryLimit(_ limit: ByteCount?) -> MLXConfiguration {
        var copy = self
        copy.memoryLimit = limit
        return copy
    }

    /// Returns a copy with the specified memory mapping setting.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.useMemoryMapping(false)
    /// ```
    ///
    /// - Parameter enabled: Whether to use memory mapping for model weights.
    /// - Returns: A new configuration with the updated setting.
    public func useMemoryMapping(_ enabled: Bool) -> MLXConfiguration {
        var copy = self
        copy.useMemoryMapping = enabled
        return copy
    }

    /// Returns a copy with the specified KV cache limit.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.kvCacheLimit(4096)
    /// ```
    ///
    /// - Parameter limit: Maximum entries in KV cache, or `nil` for no limit.
    /// - Returns: A new configuration with the updated KV cache limit.
    public func kvCacheLimit(_ limit: Int?) -> MLXConfiguration {
        var copy = self
        copy.kvCacheLimit = limit
        return copy
    }

    /// Returns a copy with the specified prefill step size.
    ///
    /// Prefill step size is automatically clamped to at least 1.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.prefillStepSize(256)
    /// ```
    ///
    /// - Parameter size: Number of tokens to process in each prefill step.
    /// - Returns: A new configuration with the clamped prefill step size.
    public func prefillStepSize(_ size: Int) -> MLXConfiguration {
        var copy = self
        copy.prefillStepSize = max(1, size)
        return copy
    }

    /// Returns a copy configured for quantized KV cache.
    ///
    /// Bit depth is automatically clamped to the valid range [4, 8].
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.withQuantizedKVCache(bits: 4)
    /// ```
    ///
    /// - Parameter bits: Bit depth for quantization (4 or 8, default: 4).
    /// - Returns: A new configuration with quantized KV cache enabled.
    public func withQuantizedKVCache(bits: Int = 4) -> MLXConfiguration {
        var copy = self
        copy.useQuantizedKVCache = true
        copy.kvQuantizationBits = max(4, min(8, bits))
        return copy
    }

    /// Returns a copy with quantized KV cache disabled.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.withoutQuantizedKVCache()
    /// ```
    ///
    /// - Returns: A new configuration with quantized KV cache disabled.
    public func withoutQuantizedKVCache() -> MLXConfiguration {
        var copy = self
        copy.useQuantizedKVCache = false
        return copy
    }

    /// Returns a copy with the specified maximum number of cached models.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.maxCachedModels(5)
    /// ```
    ///
    /// - Parameter count: Maximum number of models to keep in cache.
    /// - Returns: A new configuration with the updated cache limit.
    public func maxCachedModels(_ count: Int) -> MLXConfiguration {
        var copy = self
        copy.maxCachedModels = count
        return copy
    }

    /// Returns a copy with the specified maximum cache size.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.default.maxCacheSize(.gigabytes(8))
    /// ```
    ///
    /// - Parameter size: Maximum total memory for cached models, or `nil` for no limit.
    /// - Returns: A new configuration with the updated cache size limit.
    public func maxCacheSize(_ size: ByteCount?) -> MLXConfiguration {
        var copy = self
        copy.maxCacheSize = size
        return copy
    }

    /// Creates cache configuration from provider configuration.
    ///
    /// Converts this MLXConfiguration into an MLXModelCache.Configuration
    /// for initializing the model cache.
    ///
    /// ## Usage
    /// ```swift
    /// let config = MLXConfiguration.lowMemory
    /// let cacheConfig = config.cacheConfiguration()
    /// let cache = MLXModelCache(configuration: cacheConfig)
    /// ```
    ///
    /// - Returns: A cache configuration with matching settings.
    public func cacheConfiguration() -> MLXModelCache.Configuration {
        MLXModelCache.Configuration(
            maxCachedModels: maxCachedModels,
            maxCacheSize: maxCacheSize
        )
    }
}

#endif // canImport(MLX)
