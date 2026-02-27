// ProviderRuntimeCapabilitiesTests.swift
// ConduitTests

import XCTest
@testable import Conduit

final class ProviderRuntimeCapabilitiesTests: XCTestCase {
    func testFeatureFlagsDefaultEnabled() {
        let flags = ProviderRuntimeFeatureFlags()

        XCTAssertTrue(flags.isEnabled(.kvQuantization))
        XCTAssertTrue(flags.isEnabled(.attentionSinks))
        XCTAssertTrue(flags.isEnabled(.kvSwap))
        XCTAssertTrue(flags.isEnabled(.incrementalPrefill))
        XCTAssertTrue(flags.isEnabled(.speculativeScheduling))
    }

    func testAllowlistEmptyMeansUnrestricted() {
        let allowlist = ProviderRuntimeModelAllowlist()
        XCTAssertTrue(allowlist.isModelAllowed(feature: .kvQuantization, modelID: "mlx-community/foo"))
        XCTAssertTrue(allowlist.isModelAllowed(feature: .kvSwap, modelID: "mlx-community/bar"))
    }

    func testAllowlistRestrictsWhenSet() {
        let allowlist = ProviderRuntimeModelAllowlist(
            kvQuantizationModels: ["mlx-community/a"],
            attentionSinkModels: [],
            kvSwapModels: [],
            incrementalPrefillModels: [],
            speculativeSchedulingModels: []
        )

        XCTAssertTrue(allowlist.isModelAllowed(feature: .kvQuantization, modelID: "mlx-community/a"))
        XCTAssertFalse(allowlist.isModelAllowed(feature: .kvQuantization, modelID: "mlx-community/b"))
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

        XCTAssertFalse(merged.featureFlags.kvQuantization)
        XCTAssertTrue(merged.featureFlags.attentionSinks)
        XCTAssertTrue(merged.featureFlags.kvSwap)
        XCTAssertEqual(merged.modelAllowlist.kvQuantizationModels, ["mlx-community/request-allow"])
        XCTAssertEqual(merged.modelAllowlist.kvSwapModels, ["mlx-community/swap-only"])
    }
}
