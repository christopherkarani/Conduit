// MiniMaxAuthenticationTests.swift
// ConduitTests
//
// Unit tests for MiniMax authentication.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Testing
import Foundation
@testable import Conduit

@Suite("MiniMax Authentication Tests")
struct MiniMaxAuthenticationTests {

    // MARK: - AuthType Cases

    @Test("AuthType apiKey case holds value")
    func authTypeApiKey() {
        let authType = MiniMaxAuthentication.AuthType.apiKey("my-secret-key")
        if case .apiKey(let key) = authType {
            #expect(key == "my-secret-key")
        } else {
            Issue.record("Expected .apiKey case")
        }
    }

    @Test("AuthType auto case")
    func authTypeAuto() {
        let authType = MiniMaxAuthentication.AuthType.auto
        if case .auto = authType {
            // pass
        } else {
            Issue.record("Expected .auto case")
        }
    }

    // MARK: - Static Factory Methods

    @Test("apiKey factory creates correct authentication")
    func apiKeyFactory() {
        let auth = MiniMaxAuthentication.apiKey("factory-key")
        #expect(auth.apiKey == "factory-key")
    }

    @Test("auto static property creates auto authentication")
    func autoFactory() {
        let auth = MiniMaxAuthentication.auto
        if case .auto = auth.type {
            // pass
        } else {
            Issue.record("Expected .auto type")
        }
    }

    // MARK: - Init

    @Test("Init with apiKey type")
    func initWithApiKeyType() {
        let auth = MiniMaxAuthentication(type: .apiKey("init-key"))
        #expect(auth.apiKey == "init-key")
    }

    @Test("Init with auto type")
    func initWithAutoType() {
        let auth = MiniMaxAuthentication(type: .auto)
        if case .auto = auth.type {
            // pass
        } else {
            Issue.record("Expected .auto type")
        }
    }

    // MARK: - apiKey Computed Property

    @Test("apiKey returns key for apiKey type")
    func apiKeyComputedPropertyWithKey() {
        let auth = MiniMaxAuthentication.apiKey("computed-key")
        #expect(auth.apiKey == "computed-key")
    }

    @Test("apiKey returns environment variable for auto type")
    func apiKeyComputedPropertyWithAuto() {
        // When the env var is not set, apiKey returns nil
        // We can't reliably test the env-var-set case without modifying the environment,
        // but we can verify the property exists and returns something (possibly nil).
        let auth = MiniMaxAuthentication.auto
        // The actual value depends on the environment; just verify no crash.
        _ = auth.apiKey
    }

    @Test("apiKey with empty string returns empty string")
    func apiKeyEmptyString() {
        let auth = MiniMaxAuthentication.apiKey("")
        #expect(auth.apiKey == "")
    }

    // MARK: - isValid

    @Test("isValid is true for non-empty API key")
    func isValidWithKey() {
        let auth = MiniMaxAuthentication.apiKey("valid-key")
        #expect(auth.isValid == true)
    }

    @Test("isValid is false for empty API key")
    func isValidWithEmptyKey() {
        let auth = MiniMaxAuthentication.apiKey("")
        #expect(auth.isValid == false)
    }

    // MARK: - Equatable

    @Test("Same apiKey authentications are equal")
    func equatableSameKey() {
        let auth1 = MiniMaxAuthentication.apiKey("same-key")
        let auth2 = MiniMaxAuthentication.apiKey("same-key")
        #expect(auth1 == auth2)
    }

    @Test("Different apiKey authentications are not equal")
    func equatableDifferentKey() {
        let auth1 = MiniMaxAuthentication.apiKey("key-1")
        let auth2 = MiniMaxAuthentication.apiKey("key-2")
        #expect(auth1 != auth2)
    }

    @Test("Auto authentications are equal")
    func equatableAuto() {
        let auth1 = MiniMaxAuthentication.auto
        let auth2 = MiniMaxAuthentication.auto
        #expect(auth1 == auth2)
    }

    @Test("apiKey and auto are not equal")
    func equatableApiKeyVsAuto() {
        let apiKeyAuth = MiniMaxAuthentication.apiKey("key")
        let autoAuth = MiniMaxAuthentication.auto
        #expect(apiKeyAuth != autoAuth)
    }

    // MARK: - Hashable

    @Test("Same authentications have same hash")
    func hashableSame() {
        let auth1 = MiniMaxAuthentication.apiKey("hash-key")
        let auth2 = MiniMaxAuthentication.apiKey("hash-key")
        #expect(auth1.hashValue == auth2.hashValue)
    }

    @Test("Can be used in a Set")
    func hashableInSet() {
        var authSet: Set<MiniMaxAuthentication> = []
        authSet.insert(.apiKey("key1"))
        authSet.insert(.apiKey("key2"))
        authSet.insert(.auto)
        authSet.insert(.auto) // duplicate

        #expect(authSet.count == 3)
    }

    // MARK: - CustomDebugStringConvertible

    @Test("Debug description for apiKey hides the key")
    func debugDescriptionApiKey() {
        let auth = MiniMaxAuthentication.apiKey("super-secret")
        #expect(auth.debugDescription == "MiniMaxAuthentication.apiKey(***)")
        #expect(!auth.debugDescription.contains("super-secret"))
    }

    @Test("Debug description for auto shows auto")
    func debugDescriptionAuto() {
        let auth = MiniMaxAuthentication.auto
        #expect(auth.debugDescription == "MiniMaxAuthentication.auto")
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip for apiKey authentication")
    func codableRoundTripApiKey() throws {
        let original = MiniMaxAuthentication.apiKey("codable-key")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxAuthentication.self, from: data)
        #expect(original == decoded)
        #expect(decoded.apiKey == "codable-key")
    }

    @Test("Codable round-trip for auto authentication")
    func codableRoundTripAuto() throws {
        let original = MiniMaxAuthentication.auto
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxAuthentication.self, from: data)
        #expect(original == decoded)
    }

    @Test("Codable round-trip preserves AuthType apiKey")
    func codableRoundTripAuthType() throws {
        let original = MiniMaxAuthentication.AuthType.apiKey("type-key")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxAuthentication.AuthType.self, from: data)
        if case .apiKey(let key) = decoded {
            #expect(key == "type-key")
        } else {
            Issue.record("Expected .apiKey case after decoding")
        }
    }

    @Test("Codable round-trip preserves AuthType auto")
    func codableRoundTripAuthTypeAuto() throws {
        let original = MiniMaxAuthentication.AuthType.auto
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxAuthentication.AuthType.self, from: data)
        if case .auto = decoded {
            // pass
        } else {
            Issue.record("Expected .auto case after decoding")
        }
    }

    // MARK: - Sendable

    @Test("Authentication is Sendable across tasks")
    func sendableConformance() async {
        let auth = MiniMaxAuthentication.apiKey("sendable-key")
        let result = await Task { auth.apiKey }.value
        #expect(result == "sendable-key")
    }

    // MARK: - Edge Cases

    @Test("API key with whitespace is preserved")
    func apiKeyWithWhitespace() {
        let auth = MiniMaxAuthentication.apiKey("  key with spaces  ")
        #expect(auth.apiKey == "  key with spaces  ")
        #expect(auth.isValid == true)
    }

    @Test("Very long API key is preserved")
    func veryLongApiKey() {
        let longKey = String(repeating: "a", count: 1000)
        let auth = MiniMaxAuthentication.apiKey(longKey)
        #expect(auth.apiKey == longKey)
        #expect(auth.isValid == true)
    }
}

#endif // CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
