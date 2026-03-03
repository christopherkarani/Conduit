// MLXCompatibilityCheckerTests.swift
// ConduitTests

import Testing
@testable import Conduit

@Suite("MLXCompatibilityChecker Tests")
struct MLXCompatibilityCheckerTests {

    @Test("Checker singleton is accessible")
    func testSingletonAccess() {
        let checker = MLXCompatibilityChecker.shared
        #expect(checker === MLXCompatibilityChecker.shared)
    }

    @Test("Checker validates non-MLX models correctly")
    func testNonMLXModels() async {
        let checker = MLXCompatibilityChecker.shared

        // HuggingFace models should not be checked
        let hfModel = ModelIdentifier.huggingFace("meta-llama/Llama-3.2-1B-Instruct")
        let result = await checker.checkCompatibility(hfModel)

        // Should return .unknown or skip checking for non-MLX models
        switch result {
        case .compatible, .unknown:
            break
        case .incompatible:
            // Should not be marked incompatible just because it's not MLX
            Issue.record("Non-MLX model should not be marked incompatible")
        }
    }

    @Test("Checker handles known compatible MLX models", .disabled())
    func testKnownCompatibleModel() async {
        // This test is disabled by default as it requires network access

        let checker = MLXCompatibilityChecker.shared

        let compatibleModel = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
        let result = await checker.checkCompatibility(compatibleModel)

        switch result {
        case .compatible:
            break
        case .incompatible(let reasons):
            Issue.record("Expected compatible model, got incompatible with reasons: \(reasons)")
        case .unknown:
            // Acceptable if network/metadata is unavailable
            break
        }
    }

    @Test("Checker provides detailed incompatibility reasons")
    func testIncompatibilityReasons() async {
        let checker = MLXCompatibilityChecker.shared

        // Test with a model that might have compatibility issues
        let model = ModelIdentifier.mlx("some-org/unsupported-architecture-model")
        let result = await checker.checkCompatibility(model)

        switch result {
        case .incompatible(let reasons):
            // Should provide at least one reason
            #expect(!reasons.isEmpty)
            // Reasons should be descriptive
            for reason in reasons {
                #expect(!reason.description.isEmpty)
            }
        case .compatible, .unknown:
            break
        }
    }

    @Test("Compatibility result types are well-defined")
    func testCompatibilityResultTypes() {
        // Ensure all result types can be created
        let compatible = CompatibilityResult.compatible(confidence: .high)
        let unknown = CompatibilityResult.unknown(nil)
        let incompatible = CompatibilityResult.incompatible(reasons: [])

        // Verify we can switch on results
        switch compatible {
        case .compatible(let confidence):
            #expect(confidence == .high)
        default:
            Issue.record("Expected compatible result")
        }

        switch unknown {
        case .unknown:
            break
        default:
            Issue.record("Expected unknown result")
        }

        switch incompatible {
        case .incompatible(let reasons):
            #expect(reasons.isEmpty)
        default:
            Issue.record("Expected incompatible result")
        }
    }
}
