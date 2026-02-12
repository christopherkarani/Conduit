// LlamaProviderTests.swift
// Conduit

import XCTest
@testable import Conduit

final class LlamaProviderTests: XCTestCase {

    // MARK: - LlamaConfiguration

    func testLlamaConfigurationDefaults() {
        let config = LlamaConfiguration.default

        XCTAssertEqual(config.contextSize, 4096)
        XCTAssertEqual(config.batchSize, 512)
        XCTAssertGreaterThan(config.threadCount, 0)
        XCTAssertEqual(config.gpuLayers, 0)
        XCTAssertTrue(config.useMemoryMapping)
        XCTAssertFalse(config.lockMemory)
        XCTAssertEqual(config.defaultMaxTokens, 512)
        XCTAssertEqual(config.repeatLastTokens, -1)
        XCTAssertNil(config.mirostat)
    }

    func testLlamaConfigurationPresets() {
        let lowMemory = LlamaConfiguration.lowMemory
        XCTAssertEqual(lowMemory.contextSize, 2048)
        XCTAssertEqual(lowMemory.batchSize, 256)
        XCTAssertGreaterThan(lowMemory.threadCount, 0)
        XCTAssertEqual(lowMemory.gpuLayers, 0)
        XCTAssertEqual(lowMemory.defaultMaxTokens, 256)
        XCTAssertEqual(lowMemory.repeatLastTokens, -1)
        XCTAssertNil(lowMemory.mirostat)

        let cpuOnly = LlamaConfiguration.cpuOnly
        XCTAssertEqual(cpuOnly.contextSize, 2048)
        XCTAssertEqual(cpuOnly.batchSize, 512)
        XCTAssertGreaterThan(cpuOnly.threadCount, 0)
        XCTAssertEqual(cpuOnly.gpuLayers, 0)
        XCTAssertEqual(cpuOnly.defaultMaxTokens, 512)
        XCTAssertEqual(cpuOnly.repeatLastTokens, -1)
        XCTAssertNil(cpuOnly.mirostat)
    }

    func testLlamaConfigurationCodableRoundTrip() throws {
        let original = LlamaConfiguration(
            contextSize: 8192,
            batchSize: 1024,
            threadCount: 8,
            gpuLayers: 12,
            useMemoryMapping: false,
            lockMemory: true,
            defaultMaxTokens: 2048,
            repeatLastTokens: 64,
            mirostat: .v2(tau: 5.0, eta: 0.1)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LlamaConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testLlamaConfigurationMirostatV1CodableRoundTrip() throws {
        let original = LlamaConfiguration(
            contextSize: 4096,
            batchSize: 512,
            threadCount: 4,
            gpuLayers: 0,
            useMemoryMapping: true,
            lockMemory: false,
            defaultMaxTokens: 512,
            repeatLastTokens: 128,
            mirostat: .v1(tau: 4.0, eta: 0.2)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LlamaConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.repeatLastTokens, 128)
    }

    // MARK: - Provider Availability

    func testProviderAvailabilityMatchesBuildMode() async {
        let provider = LlamaProvider()
        let isAvailable = await provider.isAvailable

        #if Llama && canImport(LlamaSwift)
        XCTAssertTrue(isAvailable)
        let status = await provider.availabilityStatus
        XCTAssertTrue(status.isAvailable)
        XCTAssertNil(status.unavailableReason)
        #else
        XCTAssertFalse(isAvailable)
        let status = await provider.availabilityStatus
        XCTAssertFalse(status.isAvailable)
        XCTAssertEqual(status.unavailableReason, .deviceNotSupported)
        #endif
    }

    // MARK: - Generate Validation

    func testGenerateRejectsNonLlamaModelIdentifier() async {
        let provider = LlamaProvider()

        do {
            _ = try await provider.generate(
                messages: [.user("Hello")],
                model: .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit"),
                config: .default
            )
            XCTFail("Expected generation to fail")
        } catch let error as AIError {
            #if Llama && canImport(LlamaSwift)
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("only supports .llama()"))
            } else {
                XCTFail("Expected invalidInput, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                // Expected fallback behavior
            } else {
                XCTFail("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            XCTFail("Expected AIError, got \(error)")
        }
    }

    func testGenerateWithMissingGGUFPathFails() async {
        let provider = LlamaProvider()
        let missingPath = "/tmp/conduit-llama-missing-\(UUID().uuidString).gguf"

        do {
            _ = try await provider.generate(
                messages: [.user("Hello")],
                model: .llama(missingPath),
                config: .default
            )
            XCTFail("Expected generation to fail")
        } catch let error as AIError {
            #if Llama && canImport(LlamaSwift)
            if case .modelNotFound(let model) = error {
                XCTAssertEqual(model, .llama(missingPath))
            } else {
                XCTFail("Expected modelNotFound, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                // Expected fallback behavior
            } else {
                XCTFail("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            XCTFail("Expected AIError, got \(error)")
        }
    }

    // MARK: - Streaming Validation

    func testStreamRejectsNonLlamaModelIdentifier() async {
        let provider = LlamaProvider()
        let stream = provider.stream(
            "Hello",
            model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct"),
            config: .default
        )

        do {
            for try await _ in stream {}
            XCTFail("Expected stream to fail")
        } catch let error as AIError {
            #if Llama && canImport(LlamaSwift)
            if case .invalidInput(let message) = error {
                XCTAssertTrue(message.contains("only supports .llama()"))
            } else {
                XCTFail("Expected invalidInput, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                // Expected fallback behavior
            } else {
                XCTFail("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            XCTFail("Expected AIError, got \(error)")
        }
    }

    func testStreamWithMissingGGUFPathFails() async {
        let provider = LlamaProvider()
        let missingPath = "/tmp/conduit-llama-missing-\(UUID().uuidString).gguf"
        let stream = provider.stream(
            "Hello",
            model: .llama(missingPath),
            config: .default
        )

        do {
            for try await _ in stream {}
            XCTFail("Expected stream to fail")
        } catch let error as AIError {
            #if Llama && canImport(LlamaSwift)
            if case .modelNotFound(let model) = error {
                XCTAssertEqual(model, .llama(missingPath))
            } else {
                XCTFail("Expected modelNotFound, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                // Expected fallback behavior
            } else {
                XCTFail("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            XCTFail("Expected AIError, got \(error)")
        }
    }

    func testCancelGenerationIsCallable() async {
        let provider = LlamaProvider()
        await provider.cancelGeneration()
        await provider.cancelGeneration()
    }
}
