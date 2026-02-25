// MiniMaxModelIDTests.swift
// ConduitTests
//
// Unit tests for MiniMax model identifiers.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Testing
import Foundation
@testable import Conduit

@Suite("MiniMax Model ID Tests")
struct MiniMaxModelIDTests {

    // MARK: - Static Model Constants

    @Test("minimaxM2 has correct raw value")
    func minimaxM2RawValue() {
        #expect(MiniMaxModelID.minimaxM2.rawValue == "MiniMax-M2")
    }

    @Test("minimaxM2_1 has correct raw value")
    func minimaxM2_1RawValue() {
        #expect(MiniMaxModelID.minimaxM2_1.rawValue == "MiniMax-M2.1")
    }

    @Test("minimaxM2_5 has correct raw value")
    func minimaxM2_5RawValue() {
        #expect(MiniMaxModelID.minimaxM2_5.rawValue == "MiniMax-M2.5")
    }

    // MARK: - Initialization

    @Test("Init with raw value string")
    func initWithRawValue() {
        let model = MiniMaxModelID(rawValue: "custom-model")
        #expect(model.rawValue == "custom-model")
    }

    @Test("Init with positional string")
    func initWithPositionalString() {
        let model = MiniMaxModelID("my-model")
        #expect(model.rawValue == "my-model")
    }

    // MARK: - ModelIdentifying Conformance

    @Test("Provider is minimax for all static models")
    func providerIsMiniMax() {
        #expect(MiniMaxModelID.minimaxM2.provider == .minimax)
        #expect(MiniMaxModelID.minimaxM2_1.provider == .minimax)
        #expect(MiniMaxModelID.minimaxM2_5.provider == .minimax)
    }

    @Test("Provider is minimax for custom model")
    func providerIsMiniMaxCustom() {
        let model = MiniMaxModelID("anything")
        #expect(model.provider == .minimax)
    }

    @Test("Display name equals raw value")
    func displayNameEqualsRawValue() {
        let model = MiniMaxModelID("test-model")
        #expect(model.displayName == "test-model")
        #expect(model.displayName == model.rawValue)
    }

    @Test("Display name for static models")
    func displayNameStaticModels() {
        #expect(MiniMaxModelID.minimaxM2.displayName == "MiniMax-M2")
        #expect(MiniMaxModelID.minimaxM2_1.displayName == "MiniMax-M2.1")
        #expect(MiniMaxModelID.minimaxM2_5.displayName == "MiniMax-M2.5")
    }

    // MARK: - CustomStringConvertible

    @Test("Description includes provider prefix and raw value")
    func descriptionFormat() {
        let model = MiniMaxModelID("MiniMax-M2")
        #expect(model.description == "[MiniMax] MiniMax-M2")
    }

    @Test("Description for custom model")
    func descriptionCustomModel() {
        let model = MiniMaxModelID("my-fine-tuned-model")
        #expect(model.description == "[MiniMax] my-fine-tuned-model")
    }

    // MARK: - ExpressibleByStringLiteral

    @Test("String literal initialization")
    func stringLiteralInit() {
        let model: MiniMaxModelID = "literal-model"
        #expect(model.rawValue == "literal-model")
    }

    @Test("String literal produces same result as explicit init")
    func stringLiteralEquivalence() {
        let fromLiteral: MiniMaxModelID = "MiniMax-M2"
        let fromInit = MiniMaxModelID("MiniMax-M2")
        #expect(fromLiteral == fromInit)
    }

    // MARK: - Hashable

    @Test("Equal models have same hash")
    func hashableEquality() {
        let model1 = MiniMaxModelID("MiniMax-M2")
        let model2 = MiniMaxModelID("MiniMax-M2")
        #expect(model1.hashValue == model2.hashValue)
    }

    @Test("Can be used in a Set")
    func hashableInSet() {
        var modelSet: Set<MiniMaxModelID> = []
        modelSet.insert(.minimaxM2)
        modelSet.insert(.minimaxM2_1)
        modelSet.insert(.minimaxM2_5)
        modelSet.insert(.minimaxM2) // duplicate

        #expect(modelSet.count == 3)
        #expect(modelSet.contains(.minimaxM2))
        #expect(modelSet.contains(.minimaxM2_1))
        #expect(modelSet.contains(.minimaxM2_5))
    }

    @Test("Can be used as Dictionary key")
    func hashableAsDictionaryKey() {
        var dict: [MiniMaxModelID: String] = [:]
        dict[.minimaxM2] = "M2"
        dict[.minimaxM2_1] = "M2.1"

        #expect(dict[.minimaxM2] == "M2")
        #expect(dict[.minimaxM2_1] == "M2.1")
        #expect(dict[.minimaxM2_5] == nil)
    }

    // MARK: - Equatable

    @Test("Same raw values are equal")
    func equatable() {
        let a = MiniMaxModelID("MiniMax-M2")
        let b = MiniMaxModelID("MiniMax-M2")
        #expect(a == b)
    }

    @Test("Different raw values are not equal")
    func notEquatable() {
        let a = MiniMaxModelID("MiniMax-M2")
        let b = MiniMaxModelID("MiniMax-M2.1")
        #expect(a != b)
    }

    @Test("Static constant equals manually created instance with same value")
    func staticEqualsManual() {
        let manual = MiniMaxModelID("MiniMax-M2")
        #expect(MiniMaxModelID.minimaxM2 == manual)
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip for static model")
    func codableRoundTripStatic() throws {
        let original = MiniMaxModelID.minimaxM2
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxModelID.self, from: data)
        #expect(original == decoded)
        #expect(decoded.rawValue == "MiniMax-M2")
    }

    @Test("Codable round-trip for custom model")
    func codableRoundTripCustom() throws {
        let original = MiniMaxModelID("my-custom-model")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxModelID.self, from: data)
        #expect(original == decoded)
        #expect(decoded.rawValue == "my-custom-model")
    }

    @Test("Codable round-trip preserves all static models")
    func codableRoundTripAllStatic() throws {
        let models: [MiniMaxModelID] = [.minimaxM2, .minimaxM2_1, .minimaxM2_5]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for model in models {
            let data = try encoder.encode(model)
            let decoded = try decoder.decode(MiniMaxModelID.self, from: data)
            #expect(model == decoded, "Round-trip failed for \(model.rawValue)")
        }
    }

    @Test("Encodes as single string value")
    func encodesAsSingleValue() throws {
        let model = MiniMaxModelID.minimaxM2
        let data = try JSONEncoder().encode(model)
        let jsonString = String(data: data, encoding: .utf8)!
        #expect(jsonString == "\"MiniMax-M2\"")
    }

    @Test("Decodes from bare string")
    func decodesFromBareString() throws {
        let json = "\"MiniMax-M2.5\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MiniMaxModelID.self, from: json)
        #expect(decoded.rawValue == "MiniMax-M2.5")
        #expect(decoded == .minimaxM2_5)
    }

    @Test("Codable round-trip in array context")
    func codableRoundTripArray() throws {
        let models: [MiniMaxModelID] = [.minimaxM2, .minimaxM2_1, .minimaxM2_5]
        let data = try JSONEncoder().encode(models)
        let decoded = try JSONDecoder().decode([MiniMaxModelID].self, from: data)
        #expect(decoded == models)
    }

    // MARK: - Edge Cases

    @Test("Empty string model ID")
    func emptyStringModelID() {
        let model = MiniMaxModelID("")
        #expect(model.rawValue == "")
        #expect(model.displayName == "")
        #expect(model.description == "[MiniMax] ")
    }

    @Test("Model ID with special characters")
    func specialCharactersModelID() {
        let model = MiniMaxModelID("model/v2.0-beta+rc1")
        #expect(model.rawValue == "model/v2.0-beta+rc1")
    }
}

#endif // CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
