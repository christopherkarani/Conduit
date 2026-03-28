// ProviderRuntimeCapabilitiesTests.swift
// ConduitTests

import XCTest
@testable import ConduitAdvanced

final class ProviderRuntimeCapabilitiesTests: XCTestCase {
    func testFeatureFlagsDefaultEnabled() {
        let flags = ProviderRuntimeFeatureFlags()

        XCTAssertTrue(flags[.kvQuantization])
        XCTAssertTrue(flags[.attentionSinks])
        XCTAssertTrue(flags[.kvSwap])
        XCTAssertTrue(flags[.incrementalPrefill])
        XCTAssertTrue(flags[.speculativeScheduling])
    }

    func testAllowlistEmptyMeansUnrestricted() {
        let allowlist = ProviderRuntimeModelAllowlist()
        XCTAssertTrue(allowlist[.kvQuantization].isEmpty || allowlist[.kvQuantization].contains("mlx-community/foo"))
        XCTAssertTrue(allowlist[.kvSwap].isEmpty || allowlist[.kvSwap].contains("mlx-community/bar"))
    }

    func testAllowlistRestrictsWhenSet() {
        let allowlist = ProviderRuntimeModelAllowlist(
            kvQuantizationModels: ["mlx-community/a"],
            attentionSinkModels: [],
            kvSwapModels: [],
            incrementalPrefillModels: [],
            speculativeSchedulingModels: []
        )

        XCTAssertTrue(allowlist[.kvQuantization].contains("mlx-community/a"))
        XCTAssertFalse(allowlist[.kvQuantization].contains("mlx-community/b"))
    }

    func testPolicyRespectsFlagsAndAllowlist() {
        let policy = ProviderRuntimePolicy(
            featureFlags: ProviderRuntimeFeatureFlags(
                kvQuantization: false,
                attentionSinks: true,
                kvSwap: true,
                incrementalPrefill: true,
                speculativeScheduling: true
            ),
            modelAllowlist: ProviderRuntimeModelAllowlist(
                kvQuantizationModels: ["mlx-community/allowed"],
                attentionSinkModels: [],
                kvSwapModels: [],
                incrementalPrefillModels: [],
                speculativeSchedulingModels: []
            )
        )

        XCTAssertFalse(policy.isEnabled(feature: .kvQuantization))
        XCTAssertTrue(policy.isModelAllowed(feature: .kvQuantization, modelID: "mlx-community/allowed"))
        XCTAssertFalse(policy.isModelAllowed(feature: .kvQuantization, modelID: "mlx-community/blocked"))
    }

    func testPolicyAppliesPartialOverridesWithoutDroppingUnspecifiedFields() {
        let base = ProviderRuntimePolicy(
            featureFlags: ProviderRuntimeFeatureFlags(
                kvQuantization: true,
                attentionSinks: true,
                kvSwap: false,
                incrementalPrefill: true,
                speculativeScheduling: true
            ),
            modelAllowlist: ProviderRuntimeModelAllowlist(
                kvQuantizationModels: ["mlx-community/base-allow"],
                attentionSinkModels: [],
                kvSwapModels: ["mlx-community/swap-only"],
                incrementalPrefillModels: [],
                speculativeSchedulingModels: []
            )
        )

        let override = ProviderRuntimePolicyOverride(
            featureFlags: ProviderRuntimeFeatureFlagOverride(
                kvQuantization: false,
                attentionSinks: nil,
                kvSwap: true
            ),
            modelAllowlist: ProviderRuntimeModelAllowlistOverride(
                kvQuantizationModels: ["mlx-community/request-allow"]
            )
        )

        let merged = base.applying(overrides: override)

        XCTAssertFalse(merged.featureFlags[.kvQuantization])
        XCTAssertTrue(merged.featureFlags[.attentionSinks])
        XCTAssertTrue(merged.featureFlags[.kvSwap])
        XCTAssertEqual(merged.modelAllowlist[.kvQuantization], ["mlx-community/request-allow"])
        XCTAssertEqual(merged.modelAllowlist[.kvSwap], ["mlx-community/swap-only"])
    }
}
