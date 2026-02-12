// MLXRuntimeMemoryLimit.swift
// Conduit

#if CONDUIT_TRAIT_MLX
#if canImport(MLX)

import Foundation
@preconcurrency import MLX

/// Resolves MLX GPU memory limits while preserving the process default.
///
/// MLX GPU memory limits are process-global. We capture the initial value once so
/// `MLXConfiguration.memoryLimit == nil` can explicitly restore that baseline.
internal enum MLXRuntimeMemoryLimit {
    static let systemDefaultMemoryLimit: Int = MLX.GPU.memoryLimit

    static func resolved(
        memoryLimit: ByteCount?,
        systemDefault: Int = systemDefaultMemoryLimit
    ) -> Int {
        guard let memoryLimit else { return systemDefault }
        // ByteCount.bytes is UInt64, which could theoretically exceed Int.max on 32-bit systems.
        // Clamping ensures we never overflow, though in practice this is unlikely on arm64.
        return Int(clamping: memoryLimit.bytes)
    }

    static func resolved(
        from configuration: MLXConfiguration,
        systemDefault: Int = systemDefaultMemoryLimit
    ) -> Int {
        resolved(memoryLimit: configuration.memoryLimit, systemDefault: systemDefault)
    }
}

#endif // canImport(MLX)
#endif // CONDUIT_TRAIT_MLX
