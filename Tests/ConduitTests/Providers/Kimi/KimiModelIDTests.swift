// KimiModelIDTests.swift
// ConduitTests

#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI

import Foundation
import Testing
@testable import Conduit

@Suite("KimiModelID Tests")
struct KimiModelIDTests {

    // MARK: - Predefined Model Cases

    @Test("Predefined model kimiK2_5 has correct raw value")
    func kimiK2_5RawValue() {
        #expect(KimiModelID.kimiK2_5.rawValue == "kimi-k2-5")
    }

    @Test("Predefined model kimiK2 has correct raw value")
    func kimiK2RawValue() {
        #expect(KimiModelID.kimiK2.rawValue == "kimi-k2")
    }

    @Test("Predefined model kimiK1_5 has correct raw value")
    func kimiK1_5RawValue() {
        #expect(KimiModelID.kimiK1_5.rawValue == "kimi-k1-5")
    }

    // MARK: - Initialization

    @Test("Init with raw string")
    func initWithRawString() {
        let model = KimiModelID("custom-model")
        #expect(model.rawValue == "custom-model")
    }

    @Test("Init with rawValue parameter")
    func initWithRawValueParameter() {
        let model = KimiModelID(rawValue: "custom-model-2")
        #expect(model.rawValue == "custom-model-2")
    }

    @Test("String literal initialization")
    func stringLiteralInit() {
        let model: KimiModelID = "my-custom-kimi"
        #expect(model.rawValue == "my-custom-kimi")
    }

    // MARK: - ModelIdentifying Conformance

    @Test("Provider is kimi")
    func providerIsKimi() {
        #expect(KimiModelID.kimiK2_5.provider == .kimi)
        #expect(KimiModelID.kimiK2.provider == .kimi)
        #expect(KimiModelID.kimiK1_5.provider == .kimi)
    }

    @Test("Custom model provider is kimi")
    func customModelProviderIsKimi() {
        let model = KimiModelID("anything")
        #expect(model.provider == .kimi)
    }

    // MARK: - Display Name

    @Test("Display name strips kimi- prefix and replaces dashes with dots")
    func displayNameFormatting() {
        #expect(KimiModelID.kimiK2_5.displayName == "Kimi k2.5")
        #expect(KimiModelID.kimiK2.displayName == "Kimi k2")
        #expect(KimiModelID.kimiK1_5.displayName == "Kimi k1.5")
    }

    @Test("Display name for custom model without kimi prefix")
    func displayNameCustomModel() {
        let model = KimiModelID("some-other-model")
        #expect(model.displayName == "some.other.model")
    }

    // MARK: - Description

    @Test("Description includes provider tag and raw value")
    func descriptionFormat() {
        #expect(KimiModelID.kimiK2_5.description == "[Kimi] kimi-k2-5")
        #expect(KimiModelID.kimiK2.description == "[Kimi] kimi-k2")
        #expect(KimiModelID.kimiK1_5.description == "[Kimi] kimi-k1-5")
    }

    @Test("Description for custom model")
    func descriptionCustomModel() {
        let model = KimiModelID("my-model")
        #expect(model.description == "[Kimi] my-model")
    }

    // MARK: - Hashable

    @Test("Equal models have same hash")
    func hashableEquality() {
        let model1 = KimiModelID("kimi-k2-5")
        let model2 = KimiModelID.kimiK2_5
        #expect(model1 == model2)
        #expect(model1.hashValue == model2.hashValue)
    }

    @Test("Different models are not equal")
    func hashableInequality() {
        #expect(KimiModelID.kimiK2_5 != KimiModelID.kimiK2)
        #expect(KimiModelID.kimiK2 != KimiModelID.kimiK1_5)
    }

    @Test("Models work in a Set")
    func modelSet() {
        var set: Set<KimiModelID> = []
        set.insert(.kimiK2_5)
        set.insert(.kimiK2)
        set.insert(.kimiK1_5)
        set.insert(.kimiK2_5) // duplicate

        #expect(set.count == 3)
        #expect(set.contains(.kimiK2_5))
        #expect(set.contains(.kimiK2))
        #expect(set.contains(.kimiK1_5))
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip for predefined models")
    func codableRoundTripPredefined() throws {
        let models: [KimiModelID] = [.kimiK2_5, .kimiK2, .kimiK1_5]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for original in models {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(KimiModelID.self, from: data)
            #expect(original == decoded)
            #expect(original.rawValue == decoded.rawValue)
        }
    }

    @Test("Codable round-trip for custom model")
    func codableRoundTripCustom() throws {
        let original = KimiModelID("my-custom-kimi-model")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiModelID.self, from: data)

        #expect(original == decoded)
        #expect(decoded.rawValue == "my-custom-kimi-model")
    }

    @Test("Encodes as single string value")
    func encodesAsSingleValue() throws {
        let model = KimiModelID.kimiK2_5
        let data = try JSONEncoder().encode(model)
        let jsonString = String(data: data, encoding: .utf8)!

        #expect(jsonString == "\"kimi-k2-5\"")
    }

    @Test("Decodes from single string value")
    func decodesFromSingleValue() throws {
        let json = "\"kimi-k2\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KimiModelID.self, from: json)

        #expect(decoded == KimiModelID.kimiK2)
        #expect(decoded.rawValue == "kimi-k2")
    }

    // MARK: - ExpressibleByStringLiteral

    @Test("String literal creates correct model")
    func stringLiteralCreation() {
        let model: KimiModelID = "kimi-k2-5"
        #expect(model == KimiModelID.kimiK2_5)
    }

    @Test("String literal preserves arbitrary strings")
    func stringLiteralArbitrary() {
        let model: KimiModelID = "totally-custom-id"
        #expect(model.rawValue == "totally-custom-id")
        #expect(model.provider == .kimi)
    }

    // MARK: - Sendable

    @Test("KimiModelID is Sendable")
    func sendableConformance() async {
        let model = KimiModelID.kimiK2_5
        let task = Task { model.rawValue }
        let result = await task.value
        #expect(result == "kimi-k2-5")
    }
}

#endif // CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
