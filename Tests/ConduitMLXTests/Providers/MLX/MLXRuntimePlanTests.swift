// MLXRuntimePlanTests.swift
// ConduitTests

import Testing
@testable import ConduitAdvanced

#if CONDUIT_TRAIT_MLX && canImport(MLX)
@Suite("MLX Runtime Plan")
struct MLXRuntimePlanTests {
    @Test("runtime plan selects advanced engine when supported advanced feature is requested")
    func runtimePlanSelectsAdvancedEngine() async {
        let provider = MLXProvider(configuration: .default)
        await provider.clearRuntimeDiagnostics()

        let config = GenerateConfig.default.runtimeFeatures(
            ProviderRuntimeFeatureConfiguration(
                attentionSinks: .init(enabled: true, sinkTokenCount: 32)
            )
        )

        let plan = await provider._testing_resolveRuntimePlan(
            model: .mlx("mlx-community/test-model"),
            generateConfig: config
        )
        let diagnostics = await provider.runtimeDiagnosticsSnapshot()

        #expect(plan.engineKind == .advanced)
        #expect(plan.runtimeFeatures.attentionSinks.enabled == true)
        #expect(diagnostics.contains {
            $0.feature == .attentionSinks &&
            $0.kind == .capabilitySelected
        })
    }

    @Test("invalid speculative divergence threshold auto-disables and falls back deterministically")
    func invalidSpeculativeThresholdAutoDisables() async {
        let provider = MLXProvider(configuration: .default)
        await provider.clearRuntimeDiagnostics()

        let config = GenerateConfig.default.runtimeFeatures(
            ProviderRuntimeFeatureConfiguration(
                speculativeScheduling: .init(
                    enabled: true,
                    draftStreamCount: 2,
                    draftAheadTokens: 8,
                    verificationBatchTokens: 4,
                    rollbackTokenBudgetPerTurn: 32,
                    autoDisableDivergenceRate: 1.5
                )
            )
        )

        let plan = await provider._testing_resolveRuntimePlan(
            model: .mlx("mlx-community/test-model"),
            generateConfig: config
        )
        let diagnostics = await provider.runtimeDiagnosticsSnapshot()

        #expect(plan.runtimeFeatures.speculativeScheduling.enabled == false)
        #expect(plan.engineKind == .baseline)
        #expect(diagnostics.contains {
            $0.feature == .speculativeScheduling &&
            $0.kind == .autoDisabled &&
            $0.reason == "invalidAutoDisableDivergenceRate"
        })
    }
}
#endif
