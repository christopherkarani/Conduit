// KimiConfigurationTests.swift
// ConduitTests

#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI

import Foundation
import Testing
@testable import Conduit

@Suite("KimiConfiguration Tests")
struct KimiConfigurationTests {

    // MARK: - Default Initialization

    @Test("Default init uses auto authentication")
    func defaultInitAuthentication() {
        let config = KimiConfiguration()
        #expect(config.authentication.type == .auto)
    }

    @Test("Default init uses correct base URL")
    func defaultInitBaseURL() {
        let config = KimiConfiguration()
        #expect(config.baseURL == URL(string: "https://api.moonshot.cn/v1")!)
    }

    @Test("Default init uses 120 second timeout")
    func defaultInitTimeout() {
        let config = KimiConfiguration()
        #expect(config.timeout == 120.0)
    }

    @Test("Default init uses 3 max retries")
    func defaultInitMaxRetries() {
        let config = KimiConfiguration()
        #expect(config.maxRetries == 3)
    }

    // MARK: - Custom Initialization

    @Test("Init with all custom parameters")
    func customInit() {
        let auth = KimiAuthentication.apiKey("sk-test-key")
        let url = URL(string: "https://custom.api.com/v2")!
        let config = KimiConfiguration(
            authentication: auth,
            baseURL: url,
            timeout: 60.0,
            maxRetries: 5
        )

        #expect(config.authentication.apiKey == "sk-test-key")
        #expect(config.baseURL == url)
        #expect(config.timeout == 60.0)
        #expect(config.maxRetries == 5)
    }

    @Test("Init with only authentication parameter")
    func initWithAuthOnly() {
        let config = KimiConfiguration(authentication: .apiKey("sk-key"))
        #expect(config.authentication.apiKey == "sk-key")
        #expect(config.baseURL == URL(string: "https://api.moonshot.cn/v1")!)
        #expect(config.timeout == 120.0)
        #expect(config.maxRetries == 3)
    }

    // MARK: - Static Factory

    @Test("Standard factory creates config with API key")
    func standardFactory() {
        let config = KimiConfiguration.standard(apiKey: "sk-moonshot-abc123")

        #expect(config.authentication.apiKey == "sk-moonshot-abc123")
        #expect(config.baseURL == URL(string: "https://api.moonshot.cn/v1")!)
        #expect(config.timeout == 120.0)
        #expect(config.maxRetries == 3)
    }

    // MARK: - hasValidAuthentication

    @Test("hasValidAuthentication with API key returns true")
    func hasValidAuthenticationWithKey() {
        let config = KimiConfiguration.standard(apiKey: "sk-valid")
        #expect(config.hasValidAuthentication == true)
    }

    @Test("hasValidAuthentication with empty API key returns false")
    func hasValidAuthenticationEmptyKey() {
        let config = KimiConfiguration(authentication: .apiKey(""))
        #expect(config.hasValidAuthentication == false)
    }

    // MARK: - Fluent API: apiKey

    @Test("Fluent apiKey sets authentication")
    func fluentApiKey() {
        let config = KimiConfiguration().apiKey("sk-new-key")

        #expect(config.authentication.apiKey == "sk-new-key")
    }

    @Test("Fluent apiKey preserves other fields")
    func fluentApiKeyPreservesOther() {
        let original = KimiConfiguration(
            baseURL: URL(string: "https://custom.com")!,
            timeout: 60.0,
            maxRetries: 5
        )
        let updated = original.apiKey("sk-new-key")

        #expect(updated.baseURL == URL(string: "https://custom.com")!)
        #expect(updated.timeout == 60.0)
        #expect(updated.maxRetries == 5)
        #expect(updated.authentication.apiKey == "sk-new-key")
    }

    @Test("Fluent apiKey does not mutate original")
    func fluentApiKeyImmutability() {
        let original = KimiConfiguration()
        let _ = original.apiKey("sk-new-key")

        #expect(original.authentication.type == .auto)
    }

    // MARK: - Fluent API: timeout

    @Test("Fluent timeout sets timeout value")
    func fluentTimeout() {
        let config = KimiConfiguration().timeout(300.0)
        #expect(config.timeout == 300.0)
    }

    @Test("Fluent timeout clamps negative to zero")
    func fluentTimeoutClampsNegative() {
        let config = KimiConfiguration().timeout(-10.0)
        #expect(config.timeout == 0.0)
    }

    @Test("Fluent timeout preserves other fields")
    func fluentTimeoutPreservesOther() {
        let original = KimiConfiguration.standard(apiKey: "sk-key")
        let updated = original.timeout(45.0)

        #expect(updated.authentication.apiKey == "sk-key")
        #expect(updated.baseURL == URL(string: "https://api.moonshot.cn/v1")!)
        #expect(updated.maxRetries == 3)
        #expect(updated.timeout == 45.0)
    }

    @Test("Fluent timeout does not mutate original")
    func fluentTimeoutImmutability() {
        let original = KimiConfiguration()
        let _ = original.timeout(999.0)

        #expect(original.timeout == 120.0)
    }

    // MARK: - Fluent API: maxRetries

    @Test("Fluent maxRetries sets retry count")
    func fluentMaxRetries() {
        let config = KimiConfiguration().maxRetries(10)
        #expect(config.maxRetries == 10)
    }

    @Test("Fluent maxRetries clamps negative to zero")
    func fluentMaxRetriesClampsNegative() {
        let config = KimiConfiguration().maxRetries(-5)
        #expect(config.maxRetries == 0)
    }

    @Test("Fluent maxRetries preserves other fields")
    func fluentMaxRetriesPreservesOther() {
        let original = KimiConfiguration.standard(apiKey: "sk-key").timeout(60.0)
        let updated = original.maxRetries(7)

        #expect(updated.authentication.apiKey == "sk-key")
        #expect(updated.timeout == 60.0)
        #expect(updated.baseURL == URL(string: "https://api.moonshot.cn/v1")!)
        #expect(updated.maxRetries == 7)
    }

    @Test("Fluent maxRetries does not mutate original")
    func fluentMaxRetriesImmutability() {
        let original = KimiConfiguration()
        let _ = original.maxRetries(99)

        #expect(original.maxRetries == 3)
    }

    // MARK: - Fluent API: Chaining

    @Test("Fluent methods can be chained")
    func fluentChaining() {
        let config = KimiConfiguration()
            .apiKey("sk-chained")
            .timeout(90.0)
            .maxRetries(2)

        #expect(config.authentication.apiKey == "sk-chained")
        #expect(config.timeout == 90.0)
        #expect(config.maxRetries == 2)
    }

    // MARK: - Hashable

    @Test("Equal configurations have same hash")
    func hashableEquality() {
        let config1 = KimiConfiguration.standard(apiKey: "sk-test")
        let config2 = KimiConfiguration.standard(apiKey: "sk-test")

        #expect(config1 == config2)
        #expect(config1.hashValue == config2.hashValue)
    }

    @Test("Different configurations are not equal")
    func hashableInequality() {
        let config1 = KimiConfiguration.standard(apiKey: "sk-one")
        let config2 = KimiConfiguration.standard(apiKey: "sk-two")

        #expect(config1 != config2)
    }

    @Test("Configurations work in a Set")
    func configSet() {
        let config1 = KimiConfiguration.standard(apiKey: "sk-a")
        let config2 = KimiConfiguration.standard(apiKey: "sk-b")
        let config3 = KimiConfiguration.standard(apiKey: "sk-a") // duplicate

        var set: Set<KimiConfiguration> = []
        set.insert(config1)
        set.insert(config2)
        set.insert(config3)

        #expect(set.count == 2)
    }

    // MARK: - Codable Round-Trip

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = KimiConfiguration(
            authentication: .apiKey("sk-round-trip-test"),
            baseURL: URL(string: "https://custom.moonshot.cn/v2")!,
            timeout: 180.0,
            maxRetries: 7
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiConfiguration.self, from: data)

        #expect(decoded.authentication.apiKey == "sk-round-trip-test")
        #expect(decoded.baseURL == URL(string: "https://custom.moonshot.cn/v2")!)
        #expect(decoded.timeout == 180.0)
        #expect(decoded.maxRetries == 7)
        #expect(original == decoded)
    }

    @Test("Codable round-trip with default config")
    func codableRoundTripDefault() throws {
        let original = KimiConfiguration()

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiConfiguration.self, from: data)

        #expect(decoded.baseURL == original.baseURL)
        #expect(decoded.timeout == original.timeout)
        #expect(decoded.maxRetries == original.maxRetries)
        #expect(original == decoded)
    }

    @Test("Codable round-trip with standard factory")
    func codableRoundTripStandardFactory() throws {
        let original = KimiConfiguration.standard(apiKey: "sk-encode-me")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KimiConfiguration.self, from: data)

        #expect(decoded.authentication.apiKey == "sk-encode-me")
        #expect(original == decoded)
    }

    // MARK: - Sendable

    @Test("KimiConfiguration is Sendable")
    func sendableConformance() async {
        let config = KimiConfiguration.standard(apiKey: "sk-sendable")
        let task = Task { config.timeout }
        let result = await task.value
        #expect(result == 120.0)
    }
}

#endif // CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
