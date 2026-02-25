// MiniMaxConfigurationTests.swift
// ConduitTests
//
// Unit tests for MiniMax configuration.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Testing
import Foundation
@testable import Conduit

@Suite("MiniMax Configuration Tests")
struct MiniMaxConfigurationTests {

    // MARK: - Default Initialization

    @Test("Default init uses expected values")
    func defaultInit() {
        let config = MiniMaxConfiguration()
        #expect(config.authentication.type == .auto)
        #expect(config.baseURL == URL(string: "https://minimax-m2.com/api/v1")!)
        #expect(config.timeout == 120.0)
        #expect(config.maxRetries == 3)
    }

    @Test("Default authentication is auto")
    func defaultAuthenticationIsAuto() {
        let config = MiniMaxConfiguration()
        #expect(config.authentication == .auto)
    }

    // MARK: - Custom Initialization

    @Test("Init with custom authentication")
    func customAuthentication() {
        let config = MiniMaxConfiguration(authentication: .apiKey("test-key"))
        #expect(config.authentication.apiKey == "test-key")
    }

    @Test("Init with custom base URL")
    func customBaseURL() {
        let url = URL(string: "https://custom.example.com/api")!
        let config = MiniMaxConfiguration(baseURL: url)
        #expect(config.baseURL == url)
    }

    @Test("Init with custom timeout")
    func customTimeout() {
        let config = MiniMaxConfiguration(timeout: 30.0)
        #expect(config.timeout == 30.0)
    }

    @Test("Init with custom max retries")
    func customMaxRetries() {
        let config = MiniMaxConfiguration(maxRetries: 5)
        #expect(config.maxRetries == 5)
    }

    @Test("Init with all custom values")
    func allCustomValues() {
        let url = URL(string: "https://custom.example.com")!
        let config = MiniMaxConfiguration(
            authentication: .apiKey("my-key"),
            baseURL: url,
            timeout: 60.0,
            maxRetries: 10
        )
        #expect(config.authentication.apiKey == "my-key")
        #expect(config.baseURL == url)
        #expect(config.timeout == 60.0)
        #expect(config.maxRetries == 10)
    }

    // MARK: - Static Factory Methods

    @Test("standard(apiKey:) sets API key authentication")
    func standardFactoryMethod() {
        let config = MiniMaxConfiguration.standard(apiKey: "sk-test-123")
        #expect(config.authentication.apiKey == "sk-test-123")
    }

    @Test("standard(apiKey:) uses default base URL")
    func standardFactoryMethodBaseURL() {
        let config = MiniMaxConfiguration.standard(apiKey: "key")
        #expect(config.baseURL == URL(string: "https://minimax-m2.com/api/v1")!)
    }

    @Test("standard(apiKey:) uses default timeout and retries")
    func standardFactoryMethodDefaults() {
        let config = MiniMaxConfiguration.standard(apiKey: "key")
        #expect(config.timeout == 120.0)
        #expect(config.maxRetries == 3)
    }

    // MARK: - hasValidAuthentication

    @Test("hasValidAuthentication is true with API key")
    func hasValidAuthWithKey() {
        let config = MiniMaxConfiguration(authentication: .apiKey("valid-key"))
        #expect(config.hasValidAuthentication == true)
    }

    @Test("hasValidAuthentication is false with empty API key")
    func hasValidAuthEmptyKey() {
        let config = MiniMaxConfiguration(authentication: .apiKey(""))
        #expect(config.hasValidAuthentication == false)
    }

    // MARK: - Fluent API

    @Test("apiKey fluent method sets authentication")
    func fluentApiKey() {
        let config = MiniMaxConfiguration().apiKey("fluent-key")
        #expect(config.authentication.apiKey == "fluent-key")
    }

    @Test("apiKey fluent method returns new instance")
    func fluentApiKeyNewInstance() {
        let original = MiniMaxConfiguration()
        let modified = original.apiKey("new-key")
        // Original unchanged
        #expect(original.authentication == .auto)
        #expect(modified.authentication.apiKey == "new-key")
    }

    @Test("timeout fluent method sets timeout")
    func fluentTimeout() {
        let config = MiniMaxConfiguration().timeout(45.0)
        #expect(config.timeout == 45.0)
    }

    @Test("timeout fluent method clamps negative to zero")
    func fluentTimeoutClampsNegative() {
        let config = MiniMaxConfiguration().timeout(-10.0)
        #expect(config.timeout == 0.0)
    }

    @Test("timeout fluent method allows zero")
    func fluentTimeoutAllowsZero() {
        let config = MiniMaxConfiguration().timeout(0.0)
        #expect(config.timeout == 0.0)
    }

    @Test("timeout fluent method returns new instance")
    func fluentTimeoutNewInstance() {
        let original = MiniMaxConfiguration()
        let modified = original.timeout(30.0)
        #expect(original.timeout == 120.0)
        #expect(modified.timeout == 30.0)
    }

    @Test("maxRetries fluent method sets max retries")
    func fluentMaxRetries() {
        let config = MiniMaxConfiguration().maxRetries(7)
        #expect(config.maxRetries == 7)
    }

    @Test("maxRetries fluent method clamps negative to zero")
    func fluentMaxRetriesClampsNegative() {
        let config = MiniMaxConfiguration().maxRetries(-3)
        #expect(config.maxRetries == 0)
    }

    @Test("maxRetries fluent method allows zero")
    func fluentMaxRetriesAllowsZero() {
        let config = MiniMaxConfiguration().maxRetries(0)
        #expect(config.maxRetries == 0)
    }

    @Test("maxRetries fluent method returns new instance")
    func fluentMaxRetriesNewInstance() {
        let original = MiniMaxConfiguration()
        let modified = original.maxRetries(1)
        #expect(original.maxRetries == 3)
        #expect(modified.maxRetries == 1)
    }

    @Test("Fluent methods can be chained")
    func fluentChaining() {
        let config = MiniMaxConfiguration()
            .apiKey("chain-key")
            .timeout(90.0)
            .maxRetries(2)

        #expect(config.authentication.apiKey == "chain-key")
        #expect(config.timeout == 90.0)
        #expect(config.maxRetries == 2)
    }

    // MARK: - Hashable

    @Test("Equal configurations have same hash")
    func hashableEquality() {
        let config1 = MiniMaxConfiguration.standard(apiKey: "key")
        let config2 = MiniMaxConfiguration.standard(apiKey: "key")
        #expect(config1.hashValue == config2.hashValue)
    }

    @Test("Can be used in a Set")
    func hashableInSet() {
        let config1 = MiniMaxConfiguration.standard(apiKey: "key1")
        let config2 = MiniMaxConfiguration.standard(apiKey: "key2")
        var configSet: Set<MiniMaxConfiguration> = []
        configSet.insert(config1)
        configSet.insert(config2)
        #expect(configSet.count == 2)
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip with default config")
    func codableRoundTripDefault() throws {
        let original = MiniMaxConfiguration()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxConfiguration.self, from: data)
        #expect(original == decoded)
    }

    @Test("Codable round-trip with API key")
    func codableRoundTripWithApiKey() throws {
        let original = MiniMaxConfiguration.standard(apiKey: "test-key-123")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxConfiguration.self, from: data)
        #expect(original == decoded)
        #expect(decoded.authentication.apiKey == "test-key-123")
    }

    @Test("Codable round-trip with custom values")
    func codableRoundTripCustom() throws {
        let original = MiniMaxConfiguration(
            authentication: .apiKey("custom"),
            baseURL: URL(string: "https://example.com")!,
            timeout: 42.0,
            maxRetries: 7
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxConfiguration.self, from: data)
        #expect(original == decoded)
        #expect(decoded.baseURL == URL(string: "https://example.com")!)
        #expect(decoded.timeout == 42.0)
        #expect(decoded.maxRetries == 7)
    }

    @Test("Codable round-trip preserves base URL")
    func codableRoundTripBaseURL() throws {
        let url = URL(string: "https://custom-minimax.example.com/v2")!
        let original = MiniMaxConfiguration(baseURL: url)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MiniMaxConfiguration.self, from: data)
        #expect(decoded.baseURL == url)
    }

    // MARK: - Sendable

    @Test("Configuration is Sendable across tasks")
    func sendableConformance() async {
        let config = MiniMaxConfiguration.standard(apiKey: "sendable-key")
        let result = await Task { config.authentication.apiKey }.value
        #expect(result == "sendable-key")
    }
}

#endif // CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
