// LlamaConfiguration.swift
// Conduit

import Foundation

/// Configuration for native llama.cpp inference via `LlamaProvider`.
///
/// These values map directly to llama.cpp runtime parameters through `LlamaSwift`.
public struct LlamaConfiguration: Sendable, Hashable, Codable {

    /// Mirostat sampling mode for adaptive perplexity control.
    public enum MirostatMode: Hashable, Codable, Sendable {
        /// Mirostat v1 with target entropy (`tau`) and learning rate (`eta`).
        case v1(tau: Float, eta: Float)

        /// Mirostat v2 with target entropy (`tau`) and learning rate (`eta`).
        case v2(tau: Float, eta: Float)
    }

    /// Context window size (`n_ctx`) for inference.
    ///
    /// Larger values increase memory use.
    public var contextSize: UInt32

    /// Batch size (`n_batch`) for prompt evaluation.
    ///
    /// Larger values can improve throughput at the cost of memory.
    public var batchSize: UInt32

    /// Number of CPU threads used by llama.cpp.
    public var threadCount: Int32

    /// Number of layers to offload to GPU (`n_gpu_layers`).
    ///
    /// Use `0` for CPU-only execution.
    public var gpuLayers: Int32

    /// Whether to use memory-mapped model loading (`use_mmap`).
    public var useMemoryMapping: Bool

    /// Whether to lock model pages in RAM (`use_mlock`).
    public var lockMemory: Bool

    /// Default maximum completion tokens when `GenerateConfig.maxTokens` is not set.
    public var defaultMaxTokens: Int

    /// Number of trailing tokens considered for repetition penalty (`penalty_last_n`).
    ///
    /// Set to `-1` to consider the entire generated context.
    public var repeatLastTokens: Int32

    /// Optional mirostat sampling configuration.
    public var mirostat: MirostatMode?

    /// Creates a llama.cpp configuration.
    public init(
        contextSize: UInt32 = 4096,
        batchSize: UInt32 = 512,
        threadCount: Int32 = Int32(ProcessInfo.processInfo.processorCount),
        gpuLayers: Int32 = 0,
        useMemoryMapping: Bool = true,
        lockMemory: Bool = false,
        defaultMaxTokens: Int = 512,
        repeatLastTokens: Int32 = -1,
        mirostat: MirostatMode? = nil
    ) {
        self.contextSize = max(1, contextSize)
        self.batchSize = max(1, batchSize)
        self.threadCount = max(1, threadCount)
        self.gpuLayers = max(0, gpuLayers)
        self.useMemoryMapping = useMemoryMapping
        self.lockMemory = lockMemory
        self.defaultMaxTokens = max(1, defaultMaxTokens)
        self.repeatLastTokens = max(-1, repeatLastTokens)
        self.mirostat = mirostat
    }
}

public extension LlamaConfiguration {
    /// Default balanced llama.cpp configuration.
    static let `default` = LlamaConfiguration()

    /// Conservative memory profile for constrained devices.
    static let lowMemory = LlamaConfiguration(
        contextSize: 2048,
        batchSize: 256,
        threadCount: max(1, Int32(ProcessInfo.processInfo.processorCount / 2)),
        gpuLayers: 0,
        useMemoryMapping: true,
        lockMemory: false,
        defaultMaxTokens: 256,
        repeatLastTokens: -1,
        mirostat: nil
    )

    /// CPU-only profile matching AnyLanguageModel's conservative defaults.
    static let cpuOnly = LlamaConfiguration(
        contextSize: 2048,
        batchSize: 512,
        threadCount: Int32(ProcessInfo.processInfo.processorCount),
        gpuLayers: 0,
        useMemoryMapping: true,
        lockMemory: false,
        defaultMaxTokens: 512,
        repeatLastTokens: -1,
        mirostat: nil
    )
}
