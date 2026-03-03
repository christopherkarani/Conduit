// KimiAuthenticationTests.swift
// ConduitTests

#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI

import Foundation
import Testing
@testable import Conduit

@Suite("KimiAuthentication Tests")
struct KimiAuthenticationTests {

    // MARK: - AuthType Cases

    @Test("apiKey case stores the key")
    func apiKeyCaseStoresKey() {
        let auth = KimiAuthentication(type: .apiKey("sk-test-123"))
        if case .apiKey(let key) = auth.type {
            #expect(key == "sk-test-123")
        } else {
            Issue.record("Expected .apiKey case")
        }
    }

    @Test("auto case exists")
    func autoCaseExists() {
        let auth = KimiAuthentication(type: .auto)
        if case .auto = auth.type {
            // success
        } else {
            Issue.record("Expected .auto case")
        }
    }

    // MARK: - Static Factory: apiKey

    @Test("Static apiKey factory creates correct type")
    func staticApiKeyFactory() {
        let auth = KimiAuthentication.apiKey("sk-moonshot-abc")

        if case .apiKey(let key) = auth.type {
            #expect(key == "sk-moonshot-abc")
        } else {
            Issue.record("Expected .apiKey case from static factory")
        }
    }

    @Test("Static apiKey factory resolves apiKey property")
    func staticApiKeyFactoryResolvesApiKey() {
        let auth = KimiAuthentication.apiKey("sk-resolve-me")
        #expect(auth.apiKey == "sk-resolve-me")
    }

    // MARK: - Static Factory: auto

    @Test("Static auto creates auto type")
    func staticAutoFactory() {
        let auth = KimiAuthentication.auto
        if case .auto = auth.type {
            // success
        } else {
            Issue.record("Expected .auto case from static property")
        }
    }

    // MARK: - apiKey Property

    @Test("apiKey property returns key for apiKey type")
    func apiKeyPropertyWithApiKeyType() {
        let auth = KimiAuthentication.apiKey("sk-my-key")
        #expect(auth.apiKey == "sk-my-key")
    }

    @Test("apiKey property checks environment for auto type")
    func apiKeyPropertyWithAutoType() {
        // auto type reads from ProcessInfo.processInfo.environment["MOONSHOT_API_KEY"]
        // In test environment, this is likely nil unless explicitly set
        let auth = KimiAuthentication.auto
        let envKey = ProcessInfo.processInfo.environment["MOONSHOT_API_KEY"]
        #expect(auth.apiKey == envKey)
    }

    // MARK: - isValid

    @Test("isValid returns true for non-empty API key")
    func isValidWithNonEmptyKey() {
        let auth = KimiAuthentication.apiKey("sk-valid-key")
        #expect(auth.isValid == true)
    }

    @Test("isValid returns false for empty API key")
    func isValidWithEmptyKey() {
        let auth = KimiAuthentication.apiKey("")
        #expect(auth.isValid == false)
    }

    @Test("isValid for auto depends on environment")
    func isValidAutoType() {
        let auth = KimiAuthentication.auto
        let envKey = ProcessInfo.processInfo.environment["MOONSHOT_API_KEY"]
        let expectedValid = envKey?.isEmpty == false
        #expect(auth.isValid == expectedValid)
    }

    // MARK: - Hashable

    @Test("Equal authentications have same hash")
    func hashableEquality() {
        let auth1 = KimiAuthentication.apiKey("sk-same-key")
        let auth2 = KimiAuthentication.apiKey("sk-same-key")

        #expect(auth1 == auth2)
        #expect(auth1.hashValue == auth2.hashValue)
    }

    @Test("Different API keys are not equal")
    func hashableInequalityDifferentKeys() {
        let auth1 = KimiAuthentication.apiKey("sk-key-1")
        let auth2 = KimiAuthentication.apiKey("sk-key-2")

        #expect(auth1 != auth2)
    }

    @Test("apiKey and auto are not equal")
    func hashableInequalityDifferentTypes() {
        let auth1 = KimiAuthentication.apiKey("sk-some-key")
        let auth2 = KimiAuthentication.auto

        #expect(auth1 != auth2)
    }

    @Test("auto instances are equal")
    func hashableAutoEquality() {
        let auth1 = KimiAuthentication.auto
        let auth2 = KimiAuthentication(type: .auto)

        #expect(auth1 == auth2)
    }

    @Test("Authentications work in a Set")
    func authenticationSet() {
        var set: Set<KimiAuthentication> = []
        set.insert(.apiKey("sk-a"))
        set.insert(.apiKey("sk-b"))
        set.insert(.auto)
        set.insert(.apiKey("sk-a")) // duplicate

        #expect(set.count == 3)
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip for apiKey type")
    func codableRoundTripApiKey() throws {
        let original = KimiAuthentication.apiKey("sk-codable-test")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiAuthentication.self, from: data)

        #expect(original == decoded)
        #expect(decoded.apiKey == "sk-codable-test")
    }

    @Test("Codable round-trip for auto type")
    func codableRoundTripAuto() throws {
        let original = KimiAuthentication.auto
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiAuthentication.self, from: data)

        #expect(original == decoded)
    }

    @Test("Codable round-trip preserves AuthType apiKey case")
    func codableRoundTripAuthTypeApiKey() throws {
        let original = KimiAuthentication.AuthType.apiKey("sk-inner")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiAuthentication.AuthType.self, from: data)

        if case .apiKey(let key) = decoded {
            #expect(key == "sk-inner")
        } else {
            Issue.record("Expected decoded .apiKey case")
        }
    }

    @Test("Codable round-trip preserves AuthType auto case")
    func codableRoundTripAuthTypeAuto() throws {
        let original = KimiAuthentication.AuthType.auto
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiAuthentication.AuthType.self, from: data)

        if case .auto = decoded {
            // success
        } else {
            Issue.record("Expected decoded .auto case")
        }
    }

    // MARK: - CustomDebugStringConvertible

    @Test("Debug description for apiKey masks the key")
    func debugDescriptionApiKey() {
        let auth = KimiAuthentication.apiKey("sk-secret-should-not-appear")
        #expect(auth.debugDescription == "KimiAuthentication.apiKey(***)")
        #expect(!auth.debugDescription.contains("sk-secret-should-not-appear"))
    }

    @Test("Debug description for auto shows auto")
    func debugDescriptionAuto() {
        let auth = KimiAuthentication.auto
        #expect(auth.debugDescription == "KimiAuthentication.auto")
    }

    // MARK: - Sendable

    @Test("KimiAuthentication is Sendable")
    func sendableConformance() async {
        let auth = KimiAuthentication.apiKey("sk-sendable-test")
        let task = Task { auth.apiKey }
        let result = await task.value
        #expect(result == "sk-sendable-test")
    }

    @Test("KimiAuthentication.AuthType is Sendable")
    func authTypeSendableConformance() async {
        let authType = KimiAuthentication.AuthType.apiKey("sk-sendable")
        let task = Task { authType }
        let result = await task.value
        if case .apiKey(let key) = result {
            #expect(key == "sk-sendable")
        } else {
            Issue.record("Expected .apiKey case from Task result")
        }
    }
}

#endif // CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
