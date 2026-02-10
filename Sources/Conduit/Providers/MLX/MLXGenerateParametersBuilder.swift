// MLXGenerateParametersBuilder.swift
// Conduit

// MARK: - Linux Compatibility
// NOTE: MLX requires Metal GPU and Apple Silicon. Not available on Linux.
#if canImport(MLX)

#if CONDUIT_TRAIT_MLX
import Foundation
@preconcurrency import MLXLMCommon

/// Internal helper for mapping Conduit configs into mlx-swift-lm `GenerateParameters`.
///
/// This is intentionally a small, pure mapping surface so it can be tested
/// without loading a model.
internal struct MLXGenerateParametersBuilder: Sendable {
    internal init() {}

    internal func make(
        mlxConfiguration: MLXConfiguration,
        generateConfig: GenerateConfig
    ) -> GenerateParameters {
        var params = GenerateParameters()

        if let maxTokens = generateConfig.maxTokens {
            params.maxTokens = maxTokens
        }

        params.temperature = generateConfig.temperature
        params.topP = generateConfig.topP

        if generateConfig.repetitionPenalty != 1.0 {
            params.repetitionPenalty = generateConfig.repetitionPenalty
        }

        params.prefillStepSize = max(1, mlxConfiguration.prefillStepSize)

        if let kvLimit = mlxConfiguration.kvCacheLimit, kvLimit > 0 {
            params.maxKVSize = kvLimit
        }

        if mlxConfiguration.useQuantizedKVCache {
            params.kvBits = max(4, min(8, mlxConfiguration.kvQuantizationBits))
        } else {
            params.kvBits = nil
        }

        return params
    }
}

#endif // canImport(MLX)

#endif // CONDUIT_TRAIT_MLX
