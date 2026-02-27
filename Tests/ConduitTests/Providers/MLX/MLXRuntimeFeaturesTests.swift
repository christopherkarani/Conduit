// MLXRuntimeFeaturesTests.swift
// ConduitTests

import Testing
@testable import Conduit

#if canImport(MLX)
@Suite("MLX Runtime Features")
struct MLXRuntimeFeaturesTests {
    @Test("runtime capabilities declare quantization support and deny unsupported advanced features")
    func runtimeCapabilitiesExposeFeatureSurface() async {
        let provider = MLXProvider()
        let caps = await provider.runtimeCapabilities(for: .mlx("mlx-community/test-model"))

        #expect(caps.kvQuantization.isSupported == true)
        #expect(caps.kvQuantization.supportedBits == [4, 8])
        #expect(caps.attentionSinks.isSupported == false)
        #expect(caps.kvSwap.isSupported == false)
        #expect(caps.incrementalPrefill.isSupported == false)
        #expect(caps.speculativeScheduling.isSupported == false)
    }

    @Test("runtime configuration denies unsupported quantization bit-depth and records fallback diagnostics")
    func runtimeConfigurationDeniesUnsupportedBitDepth() async {
        let provider = MLXProvider(configuration: .default)
        await provider.clearRuntimeDiagnostics()

        let config = GenerateConfig.default.runtimeFeatures(
            ProviderRuntimeFeatureConfiguration(
                kvQuantization: .init(enabled: true, bits: 6)
            )
        )

        let resolved = await provider._testing_resolveRuntimeConfiguration(
            model: .mlx("mlx-community/test-model"),
            generateConfig: config
        )
        let diagnostics = await provider.runtimeDiagnosticsSnapshot()

        #expect(resolved.useQuantizedKVCache == false)
        #expect(diagnostics.contains {
            $0.feature == .kvQuantization &&
            $0.kind == .capabilityDenied &&
            $0.reason == "unsupportedBitDepth"
        })
        #expect(diagnostics.contains {
            $0.feature == .kvQuantization &&
            $0.kind == .fallbackUsed
        })
    }

    @Test("runtime policy can disable quantized kv cache and emits deterministic deny diagnostics")
    func runtimePolicyDisablesQuantizedKV() async {
        let policy = ProviderRuntimePolicy(
            featureFlags: ProviderRuntimeFeatureFlags(
                kvQuantization: false,
                attentionSinks: true,
                kvSwap: true,
                incrementalPrefill: true,
                speculativeScheduling: true
            )
        )
        let provider = MLXProvider(
            configuration: .memoryEfficient.runtimePolicy(policy)
        )
        await provider.clearRuntimeDiagnostics()

        let resolved = await provider._testing_resolveRuntimeConfiguration(
            model: .mlx("mlx-community/test-model"),
            generateConfig: .default
        )
        let diagnostics = await provider.runtimeDiagnosticsSnapshot()

        #expect(resolved.useQuantizedKVCache == false)
        #expect(diagnostics.contains {
            $0.feature == .kvQuantization &&
            $0.kind == .capabilityDenied &&
            $0.reason == "policyDisabled"
        })
    }

    @Test("runtime policy override can disable quantized kv cache for a single request")
    func runtimePolicyOverrideDisablesQuantizedKVPerRequest() async {
        let provider = MLXProvider(configuration: .memoryEfficient)
        await provider.clearRuntimeDiagnostics()

        let config = GenerateConfig.default.runtimePolicyOverride(
            ProviderRuntimePolicyOverride(
                featureFlags: ProviderRuntimeFeatureFlagOverride(kvQuantization: false)
            )
        )

        let resolved = await provider._testing_resolveRuntimeConfiguration(
            model: .mlx("mlx-community/test-model"),
            generateConfig: config
        )
        let diagnostics = await provider.runtimeDiagnosticsSnapshot()

        #expect(resolved.useQuantizedKVCache == false)
        #expect(diagnostics.contains {
            $0.feature == .kvQuantization &&
            $0.kind == .capabilityDenied &&
            $0.reason == "policyDisabled"
        })
    }

    @Test("runtime policy override allowlist can deny non-allowlisted model")
    func runtimePolicyOverrideAllowlistDeniesModel() async {
        let provider = MLXProvider(configuration: .memoryEfficient)
        await provider.clearRuntimeDiagnostics()

        let config = GenerateConfig.default.runtimePolicyOverride(
            ProviderRuntimePolicyOverride(
                modelAllowlist: ProviderRuntimeModelAllowlistOverride(
                    kvQuantizationModels: ["mlx-community/allowlisted-model"]
                )
            )
        )

        let resolved = await provider._testing_resolveRuntimeConfiguration(
            model: .mlx("mlx-community/not-allowlisted"),
            generateConfig: config
        )
        let diagnostics = await provider.runtimeDiagnosticsSnapshot()

        #expect(resolved.useQuantizedKVCache == false)
        #expect(diagnostics.contains {
            $0.feature == .kvQuantization &&
            $0.kind == .capabilityDenied &&
            $0.reason == "modelNotAllowlisted"
        })
    }
}
#endif
