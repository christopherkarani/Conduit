// GenerateConfigTests.swift
// Conduit Tests

import XCTest
@testable import Conduit

@Generable
private struct PromptBridgeFixture {
    let answer: String
}

/// Comprehensive test suite for GenerateConfig.
///
/// Tests cover:
/// - Default values
/// - Presets (default, creative, precise, code)
/// - Fluent API (immutability, chaining)
/// - Clamping (temperature, topP)
/// - Codable (round-trip, presets)
/// - Equatable (equality)
/// - Edge cases (logprobs, stop sequences)
final class GenerateConfigTests: XCTestCase {

    // MARK: - Default Values Tests

    func testDefaultMaxTokens() {
        let config = GenerateConfig.default
        XCTAssertEqual(config.maxTokens, 1024, "Default maxTokens should be 1024")
    }

    func testDefaultTemperature() {
        let config = GenerateConfig.default
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.001, "Default temperature should be 0.7")
    }

    func testDefaultTopP() {
        let config = GenerateConfig.default
        XCTAssertEqual(config.topP, 0.9, accuracy: 0.001, "Default topP should be 0.9")
    }

    func testDefaultRepetitionPenalty() {
        let config = GenerateConfig.default
        XCTAssertEqual(config.repetitionPenalty, 1.0, accuracy: 0.001, "Default repetitionPenalty should be 1.0")
    }

    func testDefaultFrequencyPenalty() {
        let config = GenerateConfig.default
        XCTAssertEqual(config.frequencyPenalty, 0.0, accuracy: 0.001, "Default frequencyPenalty should be 0.0")
    }

    func testDefaultPresencePenalty() {
        let config = GenerateConfig.default
        XCTAssertEqual(config.presencePenalty, 0.0, accuracy: 0.001, "Default presencePenalty should be 0.0")
    }

    func testDefaultStopSequences() {
        let config = GenerateConfig.default
        XCTAssertTrue(config.stopSequences.isEmpty, "Default stopSequences should be empty")
    }

    func testDefaultReturnLogprobs() {
        let config = GenerateConfig.default
        XCTAssertFalse(config.returnLogprobs, "Default returnLogprobs should be false")
    }

    func testDefaultMinTokens() {
        let config = GenerateConfig.default
        XCTAssertNil(config.minTokens, "Default minTokens should be nil")
    }

    func testDefaultTopK() {
        let config = GenerateConfig.default
        XCTAssertNil(config.topK, "Default topK should be nil")
    }

    func testDefaultSeed() {
        let config = GenerateConfig.default
        XCTAssertNil(config.seed, "Default seed should be nil")
    }

    func testDefaultTopLogprobs() {
        let config = GenerateConfig.default
        XCTAssertNil(config.topLogprobs, "Default topLogprobs should be nil")
    }

    // MARK: - Preset Tests

    func testCreativePreset() {
        let config = GenerateConfig.creative
        XCTAssertEqual(config.temperature, 0.9, accuracy: 0.001, "Creative temperature should be 0.9")
        XCTAssertEqual(config.topP, 0.95, accuracy: 0.001, "Creative topP should be 0.95")
        XCTAssertEqual(config.frequencyPenalty, 0.5, accuracy: 0.001, "Creative frequencyPenalty should be 0.5")
    }

    func testPrecisePreset() {
        let config = GenerateConfig.precise
        XCTAssertEqual(config.temperature, 0.1, accuracy: 0.001, "Precise temperature should be 0.1")
        XCTAssertEqual(config.topP, 0.5, accuracy: 0.001, "Precise topP should be 0.5")
        XCTAssertEqual(config.repetitionPenalty, 1.1, accuracy: 0.001, "Precise repetitionPenalty should be 1.1")
    }

    func testCodePreset() {
        let config = GenerateConfig.code
        XCTAssertEqual(config.temperature, 0.2, accuracy: 0.001, "Code temperature should be 0.2")
        XCTAssertEqual(config.topP, 0.9, accuracy: 0.001, "Code topP should be 0.9")
        XCTAssertEqual(config.stopSequences, ["```", "\n\n\n"], "Code should have appropriate stop sequences")
    }

    // MARK: - Fluent API Tests

    func testFluentTemperatureReturnsNewInstance() {
        let original = GenerateConfig.default
        let modified = original.temperature(0.5)

        XCTAssertEqual(original.temperature, 0.7, accuracy: 0.001, "Original should remain unchanged")
        XCTAssertEqual(modified.temperature, 0.5, accuracy: 0.001, "Modified should have new temperature")
    }

    func testFluentTopPReturnsNewInstance() {
        let original = GenerateConfig.default
        let modified = original.topP(0.8)

        XCTAssertEqual(original.topP, 0.9, accuracy: 0.001, "Original should remain unchanged")
        XCTAssertEqual(modified.topP, 0.8, accuracy: 0.001, "Modified should have new topP")
    }

    func testFluentMaxTokensReturnsNewInstance() {
        let original = GenerateConfig.default
        let modified = original.maxTokens(500)

        XCTAssertEqual(original.maxTokens, 1024, "Original should remain unchanged")
        XCTAssertEqual(modified.maxTokens, 500, "Modified should have new maxTokens")
    }

    func testFluentChaining() {
        let config = GenerateConfig.default
            .temperature(0.8)
            .maxTokens(500)
            .topP(0.95)
            .stopSequences(["END"])

        XCTAssertEqual(config.temperature, 0.8, accuracy: 0.001, "Chained temperature should be set")
        XCTAssertEqual(config.maxTokens, 500, "Chained maxTokens should be set")
        XCTAssertEqual(config.topP, 0.95, accuracy: 0.001, "Chained topP should be set")
        XCTAssertEqual(config.stopSequences, ["END"], "Chained stopSequences should be set")
    }

    func testFluentMinTokens() {
        let config = GenerateConfig.default.minTokens(50)
        XCTAssertEqual(config.minTokens, 50, "MinTokens should be set")
    }

    func testFluentTopK() {
        let config = GenerateConfig.default.topK(40)
        XCTAssertEqual(config.topK, 40, "TopK should be set")
    }

    func testFluentRepetitionPenalty() {
        let config = GenerateConfig.default.repetitionPenalty(1.2)
        XCTAssertEqual(config.repetitionPenalty, 1.2, accuracy: 0.001, "RepetitionPenalty should be set")
    }

    func testFluentFrequencyPenalty() {
        let config = GenerateConfig.default.frequencyPenalty(0.3)
        XCTAssertEqual(config.frequencyPenalty, 0.3, accuracy: 0.001, "FrequencyPenalty should be set")
    }

    func testFluentPresencePenalty() {
        let config = GenerateConfig.default.presencePenalty(0.4)
        XCTAssertEqual(config.presencePenalty, 0.4, accuracy: 0.001, "PresencePenalty should be set")
    }

    func testFluentSeed() {
        let config = GenerateConfig.default.seed(42)
        XCTAssertEqual(config.seed, 42, "Seed should be set")
    }

    // MARK: - Clamping Tests

    func testTemperatureClampedToMax() {
        let config = GenerateConfig.default.temperature(5.0)
        XCTAssertEqual(config.temperature, 2.0, accuracy: 0.001, "Temperature above 2.0 should be clamped to 2.0")
    }

    func testTemperatureClampedToMin() {
        let config = GenerateConfig.default.temperature(-1.0)
        XCTAssertEqual(config.temperature, 0.0, accuracy: 0.001, "Temperature below 0.0 should be clamped to 0.0")
    }

    func testTemperatureWithinRange() {
        let config = GenerateConfig.default.temperature(0.5)
        XCTAssertEqual(config.temperature, 0.5, accuracy: 0.001, "Temperature within range should not be clamped")
    }

    func testTopPClampedToMax() {
        let config = GenerateConfig.default.topP(1.5)
        XCTAssertEqual(config.topP, 1.0, accuracy: 0.001, "TopP above 1.0 should be clamped to 1.0")
    }

    func testTopPClampedToMin() {
        let config = GenerateConfig.default.topP(-0.5)
        XCTAssertEqual(config.topP, 0.0, accuracy: 0.001, "TopP below 0.0 should be clamped to 0.0")
    }

    func testTopPWithinRange() {
        let config = GenerateConfig.default.topP(0.5)
        XCTAssertEqual(config.topP, 0.5, accuracy: 0.001, "TopP within range should not be clamped")
    }

    func testInitializerClampsTemperature() {
        let config = GenerateConfig(temperature: 3.0)
        XCTAssertEqual(config.temperature, 2.0, accuracy: 0.001, "Initializer should clamp temperature")
    }

    func testInitializerClampsTopP() {
        let config = GenerateConfig(topP: 2.0)
        XCTAssertEqual(config.topP, 1.0, accuracy: 0.001, "Initializer should clamp topP")
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let original = GenerateConfig(
            maxTokens: 500,
            minTokens: 10,
            temperature: 0.8,
            topP: 0.95,
            topK: 40,
            repetitionPenalty: 1.1,
            frequencyPenalty: 0.3,
            presencePenalty: 0.2,
            stopSequences: ["END", "STOP"],
            seed: 42,
            returnLogprobs: true,
            topLogprobs: 5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GenerateConfig.self, from: data)

        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertEqual(decoded.minTokens, original.minTokens)
        XCTAssertEqual(decoded.temperature, original.temperature, accuracy: 0.001)
        XCTAssertEqual(decoded.topP, original.topP, accuracy: 0.001)
        XCTAssertEqual(decoded.topK, original.topK)
        XCTAssertEqual(decoded.repetitionPenalty, original.repetitionPenalty, accuracy: 0.001)
        XCTAssertEqual(decoded.frequencyPenalty, original.frequencyPenalty, accuracy: 0.001)
        XCTAssertEqual(decoded.presencePenalty, original.presencePenalty, accuracy: 0.001)
        XCTAssertEqual(decoded.stopSequences, original.stopSequences)
        XCTAssertEqual(decoded.seed, original.seed)
        XCTAssertEqual(decoded.returnLogprobs, original.returnLogprobs)
        XCTAssertEqual(decoded.topLogprobs, original.topLogprobs)
    }

    func testDefaultPresetCodable() throws {
        let original = GenerateConfig.default

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GenerateConfig.self, from: data)

        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
        XCTAssertEqual(decoded.temperature, original.temperature, accuracy: 0.001)
        XCTAssertEqual(decoded.topP, original.topP, accuracy: 0.001)
    }

    func testCustomConfigCodable() throws {
        let original = GenerateConfig.default
            .temperature(0.6)
            .maxTokens(800)
            .stopSequences(["DONE"])

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GenerateConfig.self, from: data)

        XCTAssertEqual(decoded.maxTokens, 800)
        XCTAssertEqual(decoded.temperature, 0.6, accuracy: 0.001)
        XCTAssertEqual(decoded.stopSequences, ["DONE"])
    }

    // MARK: - Equatable Tests


    func testEqualityLikePropertiesMatch() {
        let config1 = GenerateConfig.default
            .temperature(0.8)
            .maxTokens(500)

        let config2 = GenerateConfig.default
            .temperature(0.8)
            .maxTokens(500)

        XCTAssertEqual(config1.temperature, config2.temperature, accuracy: 0.001)
        XCTAssertEqual(config1.maxTokens, config2.maxTokens)
        XCTAssertEqual(config1.topP, config2.topP, accuracy: 0.001)
    }

    func testInequalityDifferentTemperature() {
        let config1 = GenerateConfig.default.temperature(0.7)
        let config2 = GenerateConfig.default.temperature(0.8)

        XCTAssertNotEqual(config1.temperature, config2.temperature)
    }

    func testInequalityDifferentMaxTokens() {
        let config1 = GenerateConfig.default.maxTokens(500)
        let config2 = GenerateConfig.default.maxTokens(1000)

        XCTAssertNotEqual(config1.maxTokens, config2.maxTokens)
    }

    func testInequalityDifferentStopSequences() {
        let config1 = GenerateConfig.default.stopSequences(["END"])
        let config2 = GenerateConfig.default.stopSequences(["STOP"])

        XCTAssertNotEqual(config1.stopSequences, config2.stopSequences)
    }

    // MARK: - GenerationOptions Bridge Tests

    func testInitFromGenerationOptionsMapsTemperatureAndMaximumResponseTokens() {
        let options = GenerationOptions(
            sampling: nil,
            temperature: 0.35,
            maximumResponseTokens: 321
        )

        let config = GenerateConfig(options: options)

        XCTAssertEqual(config.temperature, 0.35, accuracy: 0.001)
        XCTAssertEqual(config.maxTokens, 321)
        XCTAssertEqual(config.topP, GenerateConfig.default.topP, accuracy: 0.001)
        XCTAssertNil(config.topK)
    }

    func testInitFromGenerationOptionsMapsTopKSamplingAndSeed() {
        let options = GenerationOptions(
            sampling: .random(top: 24, seed: 99),
            temperature: 0.5,
            maximumResponseTokens: nil
        )

        let config = GenerateConfig(options: options)

        XCTAssertEqual(config.topK, 24)
        XCTAssertEqual(config.topP, 0.0, accuracy: 0.001)
        XCTAssertEqual(config.seed, 99)
        XCTAssertEqual(config.temperature, 0.5, accuracy: 0.001)
    }

    func testInitFromGenerationOptionsMapsNucleusSamplingAndSeed() {
        let options = GenerationOptions(
            sampling: .random(probabilityThreshold: 0.42, seed: 77),
            temperature: nil,
            maximumResponseTokens: nil
        )

        let config = GenerateConfig(options: options)

        XCTAssertEqual(config.topP, 0.42, accuracy: 0.001)
        XCTAssertNil(config.topK)
        XCTAssertEqual(config.seed, 77)
    }

    func testInitFromGenerationOptionsGreedySetsDeterministicConfig() {
        let options = GenerationOptions(
            sampling: .greedy,
            temperature: 0.8,
            maximumResponseTokens: nil
        )

        let config = GenerateConfig(options: options)

        XCTAssertEqual(config.temperature, 0.0, accuracy: 0.001)
        XCTAssertEqual(config.topP, 0.0, accuracy: 0.001)
        XCTAssertNil(config.topK)
    }

    func testInitFromGenerationOptionsCanSetResponseFormat() {
        let options = GenerationOptions(maximumResponseTokens: 100)

        let config = GenerateConfig(options: options, responseFormat: .jsonObject)

        if case .jsonObject? = config.responseFormat {
            // Expected
        } else {
            XCTFail("Expected jsonObject response format")
        }
    }

    func testGenerationOptionsToGenerateConfigUsesBridge() {
        let options = GenerationOptions(
            sampling: .random(probabilityThreshold: 0.61, seed: 88),
            temperature: 0.2,
            maximumResponseTokens: 444
        )

        let config = options.toGenerateConfig(responseFormat: .jsonObject)

        XCTAssertEqual(config.maxTokens, 444)
        XCTAssertEqual(config.temperature, 0.2, accuracy: 0.001)
        XCTAssertEqual(config.topP, 0.61, accuracy: 0.001)
        XCTAssertEqual(config.seed, 88)
        if case .jsonObject? = config.responseFormat {
            // Expected
        } else {
            XCTFail("Expected jsonObject response format")
        }
    }

    func testTranscriptPromptGenerateConfigBridgesOptionsAndResponseFormat() {
        let prompt = Transcript.Prompt(
            segments: [.text(.init(content: "Hello"))],
            options: GenerationOptions(
                sampling: .random(top: 12, seed: 1234),
                temperature: 0.4,
                maximumResponseTokens: 222
            ),
            responseFormat: Transcript.ResponseFormat(type: PromptBridgeFixture.self)
        )

        let config = prompt.generateConfig

        XCTAssertEqual(config.maxTokens, 222)
        XCTAssertEqual(config.temperature, 0.4, accuracy: 0.001)
        XCTAssertEqual(config.topK, 12)
        XCTAssertEqual(config.seed, 1234)
        if case .jsonSchema(_, let schema)? = config.responseFormat {
            XCTAssertTrue(schema.debugDescription.contains("object"))
        } else {
            XCTFail("Expected prompt response format to bridge to generate config")
        }
    }

}
