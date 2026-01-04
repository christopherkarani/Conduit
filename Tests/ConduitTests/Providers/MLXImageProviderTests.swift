// MLXImageProviderTests.swift
// Conduit
//
// This file requires the MLX trait to be enabled.

#if canImport(MLX)

import Foundation
import Testing
@testable import Conduit

// MARK: - Model Loading Error Tests

@Suite("MLXImageProvider - Unsupported Model Errors")
struct MLXImageProviderUnsupportedModelTests {

    @Test("Throws error for unsupported SD 1.5 variant")
    func throwsForUnsupportedSD15() async throws {
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        do {
            try await provider.loadModel(from: fakePath, variant: .sd15)
            Issue.record("Expected unsupportedModel error to be thrown")
        } catch let error as AIError {
            guard case .unsupportedModel(let variant, let reason) = error else {
                Issue.record("Expected unsupportedModel error, got \(error)")
                return
            }

            // Verify variant name
            #expect(variant == "Stable Diffusion 1.5")

            // Verify reason mentions alternative
            #expect(reason.contains("not natively supported"))
            #expect(reason.contains("HuggingFaceProvider") || reason.contains("SDXL Turbo"))

            // Verify error metadata
            #expect(error.category == .provider)
            #expect(error.isRetryable == false)
            #expect(error.recoverySuggestion != nil)
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Throws error for unsupported Flux variant")
    func throwsForUnsupportedFlux() async throws {
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        do {
            try await provider.loadModel(from: fakePath, variant: .flux)
            Issue.record("Expected unsupportedModel error to be thrown")
        } catch let error as AIError {
            guard case .unsupportedModel(let variant, let reason) = error else {
                Issue.record("Expected unsupportedModel error, got \(error)")
                return
            }

            // Verify variant name
            #expect(variant == "Flux Schnell")

            // Verify reason mentions architecture
            #expect(reason.contains("different architecture"))
            #expect(reason.contains("HuggingFaceProvider"))

            // Verify error metadata
            #expect(error.category == .provider)
            #expect(error.isRetryable == false)
            #expect(error.recoverySuggestion != nil)
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Native support check happens before memory validation")
    func prioritizesNativeSupportCheck() async throws {
        // This test verifies that native support check happens BEFORE memory check
        // So even if device has insufficient memory, unsupportedModel error should be thrown first
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        do {
            try await provider.loadModel(from: fakePath, variant: .flux)
            Issue.record("Expected unsupportedModel error to be thrown")
        } catch let error as AIError {
            // Should get unsupportedModel, not insufficientMemory
            #expect(
                error.errorDescription?.contains("Unsupported model variant") ?? false,
                "Expected unsupportedModel error as first validation, got: \(error)"
            )
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Error provides actionable guidance for unsupported variants")
    func providesActionableGuidance() async throws {
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        do {
            try await provider.loadModel(from: fakePath, variant: .sd15)
            Issue.record("Expected error to be thrown")
        } catch let error as AIError {
            // Verify error description is helpful
            let description = error.errorDescription ?? ""
            #expect(description.contains("Stable Diffusion 1.5"))
            #expect(description.contains("not natively supported"))

            // Verify recovery suggestion is actionable
            let suggestion = error.recoverySuggestion ?? ""
            #expect(suggestion.contains("supported model variant") || suggestion.contains("cloud provider"))
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }
}

// MARK: - Error Recovery Integration Tests

@Suite("MLXImageProvider - Error Recovery Flow")
struct MLXImageProviderErrorRecoveryTests {

    @Test("User can recover from unsupported variant error by switching to supported variant")
    func errorRecoveryFlow() async throws {
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        // Step 1: Attempt unsupported variant
        do {
            try await provider.loadModel(from: fakePath, variant: .flux)
            Issue.record("Should have thrown unsupportedModel error")
        } catch let error as AIError {
            // Step 2: Verify error is actionable
            guard case .unsupportedModel(let variant, let reason) = error else {
                Issue.record("Wrong error type: \(error)")
                return
            }

            #expect(variant == "Flux Schnell")
            #expect(reason.contains("HuggingFaceProvider") || reason.contains("different architecture"))

            // Step 3: Error provides recovery path
            #expect(error.recoverySuggestion != nil)
            let suggestion = error.recoverySuggestion ?? ""
            #expect(suggestion.contains("supported model variant") || suggestion.contains("cloud provider"))

            // Step 4: Verify error details guide user to correct approach
            #expect(error.errorDescription?.contains("Unsupported model variant") ?? false)
            #expect(reason.contains("HuggingFaceProvider"), "Error should mention HuggingFaceProvider as alternative")
        }
    }

    @Test("Unsupported variant error takes priority over other validation errors")
    func errorPriorityVerification() async throws {
        // Even on a device with "insufficient memory", the unsupportedModel
        // error should be thrown first since it's checked before memory validation
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        do {
            try await provider.loadModel(from: fakePath, variant: .sd15)
            Issue.record("Should have thrown error")
        } catch let error as AIError {
            // Should be unsupportedModel, NOT insufficientMemory
            if case .unsupportedModel = error {
                // Correct - support check comes first (test passes)
            } else {
                Issue.record("Expected unsupportedModel, got \(error)")
            }
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Unsupported model error has correct metadata for error handling")
    func errorMetadataVerification() async throws {
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        do {
            try await provider.loadModel(from: fakePath, variant: .flux)
            Issue.record("Should have thrown error")
        } catch let error as AIError {
            // Verify error category
            #expect(error.category == .provider)

            // Verify not retryable (no point retrying same variant)
            #expect(error.isRetryable == false)

            // Verify has recovery suggestion
            #expect(error.recoverySuggestion != nil)

            // Verify error description is present and helpful
            let description = error.errorDescription ?? ""
            #expect(!description.isEmpty)
            #expect(description.contains("Flux Schnell"))
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Both SD 1.5 and Flux variants provide specific recovery guidance")
    func specificRecoveryGuidanceForEachVariant() async throws {
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        // Test SD 1.5
        do {
            try await provider.loadModel(from: fakePath, variant: .sd15)
            Issue.record("Should have thrown error for SD 1.5")
        } catch let error as AIError {
            guard case .unsupportedModel(let variant, let reason) = error else {
                Issue.record("Expected unsupportedModel error for SD 1.5")
                return
            }

            #expect(variant == "Stable Diffusion 1.5")
            #expect(reason.contains("SDXL Turbo") || reason.contains("HuggingFaceProvider"),
                    "SD 1.5 error should mention SDXL Turbo or HuggingFaceProvider")
        }

        // Test Flux
        do {
            try await provider.loadModel(from: fakePath, variant: .flux)
            Issue.record("Should have thrown error for Flux")
        } catch let error as AIError {
            guard case .unsupportedModel(let variant, let reason) = error else {
                Issue.record("Expected unsupportedModel error for Flux")
                return
            }

            #expect(variant == "Flux Schnell")
            #expect(reason.contains("HuggingFaceProvider"),
                    "Flux error should mention HuggingFaceProvider")
            #expect(reason.contains("different architecture"),
                    "Flux error should explain architectural difference")
        }
    }

    @Test("Error message clearly distinguishes between variants")
    func distinguishesBetweenVariants() async throws {
        let provider = MLXImageProvider()
        let fakePath = URL(fileURLWithPath: "/tmp/fake-model")

        var sd15Error: AIError?
        var fluxError: AIError?

        // Collect SD 1.5 error
        do {
            try await provider.loadModel(from: fakePath, variant: .sd15)
        } catch let error as AIError {
            sd15Error = error
        }

        // Collect Flux error
        do {
            try await provider.loadModel(from: fakePath, variant: .flux)
        } catch let error as AIError {
            fluxError = error
        }

        // Verify both errors were collected
        guard let sd15 = sd15Error, let flux = fluxError else {
            Issue.record("Failed to collect both errors")
            return
        }

        // Verify error descriptions are different and variant-specific
        let sd15Description = sd15.errorDescription ?? ""
        let fluxDescription = flux.errorDescription ?? ""

        #expect(sd15Description != fluxDescription, "Errors should have distinct descriptions")
        #expect(sd15Description.contains("Stable Diffusion 1.5"))
        #expect(fluxDescription.contains("Flux Schnell"))

        // Verify reasons are different
        if case .unsupportedModel(_, let sd15Reason) = sd15,
           case .unsupportedModel(_, let fluxReason) = flux {
            #expect(sd15Reason != fluxReason, "Errors should have distinct reasons")
        } else {
            Issue.record("Errors are not unsupportedModel type")
        }
    }
}

#endif // canImport(MLX)
