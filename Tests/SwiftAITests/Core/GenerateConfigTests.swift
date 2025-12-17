// GenerateConfigTests.swift
// SwiftAI Tests

import XCTest
@testable import SwiftAI

/// Comprehensive test suite for GenerateConfig.
///
/// Tests cover:
/// - Default values
/// - Presets (default, creative, precise, code)
/// - Fluent API (immutability, chaining)
/// - Clamping (temperature, topP)
/// - Codable (round-trip, presets)
/// - Hashable/Equatable (equality, hashing)
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

    // MARK: - Hashable/Equatable Tests

    func testEquality() {
        let config1 = GenerateConfig.default
            .temperature(0.8)
            .maxTokens(500)

        let config2 = GenerateConfig.default
            .temperature(0.8)
            .maxTokens(500)

        XCTAssertEqual(config1, config2, "Configs with same values should be equal")
    }

    func testInequalityDifferentTemperature() {
        let config1 = GenerateConfig.default.temperature(0.7)
        let config2 = GenerateConfig.default.temperature(0.8)

        XCTAssertNotEqual(config1, config2, "Configs with different temperatures should not be equal")
    }

    func testInequalityDifferentMaxTokens() {
        let config1 = GenerateConfig.default.maxTokens(500)
        let config2 = GenerateConfig.default.maxTokens(1000)

        XCTAssertNotEqual(config1, config2, "Configs with different maxTokens should not be equal")
    }

    func testInequalityDifferentStopSequences() {
        let config1 = GenerateConfig.default.stopSequences(["END"])
        let config2 = GenerateConfig.default.stopSequences(["STOP"])

        XCTAssertNotEqual(config1, config2, "Configs with different stopSequences should not be equal")
    }

    func testHashableInSet() {
        let config1 = GenerateConfig.default.temperature(0.7)
        let config2 = GenerateConfig.default.temperature(0.8)
        let config3 = GenerateConfig.default.temperature(0.7) // Same as config1

        let set: Set<GenerateConfig> = [config1, config2, config3]

        XCTAssertEqual(set.count, 2, "Set should contain 2 unique configs")
        XCTAssertTrue(set.contains(config1), "Set should contain config1")
        XCTAssertTrue(set.contains(config2), "Set should contain config2")
    }

    func testHashableInDictionary() {
        let config1 = GenerateConfig.default
        let config2 = GenerateConfig.creative

        var dict: [GenerateConfig: String] = [:]
        dict[config1] = "default"
        dict[config2] = "creative"

        XCTAssertEqual(dict[config1], "default")
        XCTAssertEqual(dict[config2], "creative")
        XCTAssertEqual(dict.count, 2)
    }

    // MARK: - Edge Cases

    func testWithLogprobs() {
        let config = GenerateConfig.default.withLogprobs(top: 10)

        XCTAssertTrue(config.returnLogprobs, "withLogprobs should enable returnLogprobs")
        XCTAssertEqual(config.topLogprobs, 10, "withLogprobs should set topLogprobs")
    }

    func testWithLogprobsDefaultTop() {
        let config = GenerateConfig.default.withLogprobs()

        XCTAssertTrue(config.returnLogprobs, "withLogprobs should enable returnLogprobs")
        XCTAssertEqual(config.topLogprobs, 5, "withLogprobs default should be 5")
    }

    func testStopSequences() {
        let sequences = ["END", "STOP", "\n\n\n"]
        let config = GenerateConfig.default.stopSequences(sequences)

        XCTAssertEqual(config.stopSequences, sequences, "Stop sequences should be properly set")
    }

    func testEmptyStopSequences() {
        let config = GenerateConfig.default.stopSequences([])

        XCTAssertTrue(config.stopSequences.isEmpty, "Empty stop sequences should be allowed")
    }

    func testNilMaxTokens() {
        let config = GenerateConfig.default.maxTokens(nil)

        XCTAssertNil(config.maxTokens, "maxTokens should be nil when explicitly set to nil")
    }

    func testNilSeed() {
        let config = GenerateConfig.default.seed(nil)

        XCTAssertNil(config.seed, "seed should be nil when explicitly set to nil")
    }

    func testZeroTemperature() {
        let config = GenerateConfig.default.temperature(0.0)

        XCTAssertEqual(config.temperature, 0.0, accuracy: 0.001, "Temperature can be 0.0")
    }

    func testMaxTemperature() {
        let config = GenerateConfig.default.temperature(2.0)

        XCTAssertEqual(config.temperature, 2.0, accuracy: 0.001, "Temperature can be 2.0")
    }

    func testComplexChaining() {
        let config = GenerateConfig.default
            .temperature(0.8)
            .topP(0.95)
            .maxTokens(1000)
            .minTokens(100)
            .topK(50)
            .repetitionPenalty(1.1)
            .frequencyPenalty(0.2)
            .presencePenalty(0.3)
            .stopSequences(["END", "STOP"])
            .seed(12345)
            .withLogprobs(top: 3)

        XCTAssertEqual(config.temperature, 0.8, accuracy: 0.001)
        XCTAssertEqual(config.topP, 0.95, accuracy: 0.001)
        XCTAssertEqual(config.maxTokens, 1000)
        XCTAssertEqual(config.minTokens, 100)
        XCTAssertEqual(config.topK, 50)
        XCTAssertEqual(config.repetitionPenalty, 1.1, accuracy: 0.001)
        XCTAssertEqual(config.frequencyPenalty, 0.2, accuracy: 0.001)
        XCTAssertEqual(config.presencePenalty, 0.3, accuracy: 0.001)
        XCTAssertEqual(config.stopSequences, ["END", "STOP"])
        XCTAssertEqual(config.seed, 12345)
        XCTAssertTrue(config.returnLogprobs)
        XCTAssertEqual(config.topLogprobs, 3)
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        let config = GenerateConfig.default.temperature(0.8)

        // Test that config can be sent across concurrency boundaries
        await Task {
            XCTAssertEqual(config.temperature, 0.8, accuracy: 0.001)
        }.value
    }
}
