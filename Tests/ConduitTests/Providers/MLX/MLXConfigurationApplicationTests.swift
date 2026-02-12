// MLXConfigurationApplicationTests.swift
// ConduitTests
//
// This file requires the MLX trait to be enabled.

import Foundation
import Testing
@testable import Conduit

#if canImport(MLX)
@preconcurrency import MLXLMCommon

@Suite("MLXConfiguration Application - GenerateParameters")
struct MLXConfigurationGenerateParametersApplicationTests {

    @Test("GenerateParameters include MLXConfiguration prefill/KV settings")
    func testGenerateParametersIncludeMLXConfiguration() async throws {
        let mlxConfig = MLXConfiguration.default
            .prefillStepSize(256)
            .kvCacheLimit(4096)
            .withQuantizedKVCache(bits: 8)

        let generateConfig = GenerateConfig.default
            .maxTokens(123)
            .temperature(0.9)
            .topP(0.8)
            .repetitionPenalty(1.0)

        let params = MLXGenerateParametersBuilder().make(
            mlxConfiguration: mlxConfig,
            generateConfig: generateConfig
        )

        // GenerateConfig mappings
        #expect(params.maxTokens == 123)
        #expect(params.temperature == 0.9)
        #expect(params.topP == 0.8)

        // When the user keeps the default "no penalty" value, MLX should not enable
        // the repetition processor at all.
        #expect(params.repetitionPenalty == nil)

        // MLXConfiguration mappings
        #expect(params.prefillStepSize == 256)
        #expect(params.maxKVSize == 4096)
        #expect(params.kvBits == 8)
    }

    @Test("Quantized KV cache disabled yields kvBits nil")
    func testQuantizedKVCacheDisabled() async {
        let mlxConfig = MLXConfiguration.default.withoutQuantizedKVCache()
        let params = MLXGenerateParametersBuilder().make(
            mlxConfiguration: mlxConfig,
            generateConfig: .default
        )

        #expect(params.kvBits == nil)
    }

    @Test("memoryEfficient preset yields kvBits 4")
    func testMemoryEfficientPresetUsesQuantizedKVCache() async {
        let params = MLXGenerateParametersBuilder().make(
            mlxConfiguration: .memoryEfficient,
            generateConfig: .default
        )

        #expect(params.kvBits == 4)
    }
}

@Suite("MLXConfiguration Application - Model Cache")
struct MLXConfigurationModelCacheApplicationTests {

    @Test("MLXModelCache applies updated limits")
    func testCacheAppliesConfiguration() async {
        let cache = MLXModelCache(configuration: .default)
        let before = await cache._testing_limits()

        #expect(before.countLimit == 3)
        #expect(before.totalCostLimit == 0)

        await cache.apply(configuration: MLXConfiguration.lowMemory.cacheConfiguration())
        let after = await cache._testing_limits()

        #expect(after.countLimit == 1)
        #expect(after.totalCostLimit == Int(ByteCount.gigabytes(4).bytes))
    }

    @Test("cacheConfiguration() converts MLXConfiguration to cache config")
    func testCacheConfigurationConversion() async {
        let config = MLXConfiguration.lowMemory.cacheConfiguration()
        #expect(config.maxCachedModels == 1)
        #expect(config.maxCacheSize == .gigabytes(4))
    }
}

#else
@Suite("MLXConfiguration Application Tests (Skipped without MLX)")
struct MLXConfigurationApplicationTests {
    @Test("MLX tests skipped when MLX is unavailable")
    func testSkipped() {
        #expect(true)
    }
}
#endif

