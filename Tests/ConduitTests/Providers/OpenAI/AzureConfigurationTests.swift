// AzureConfigurationTests.swift
// Conduit Tests
//
// Tests for AzureConfiguration, ContentFilteringMode, and related types.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("AzureConfiguration Tests")
struct AzureConfigurationTests {

    // MARK: - Initialization

    @Test("Default init has expected values")
    func defaultInit() {
        let config = AzureConfiguration(resource: "my-resource", deployment: "gpt4-deploy")
        #expect(config.resource == "my-resource")
        #expect(config.deployment == "gpt4-deploy")
        #expect(config.apiVersion == "2024-02-15-preview")
        #expect(config.contentFiltering == .default)
        #expect(config.enableStreaming == true)
        #expect(config.region == nil)
    }

    @Test("Custom init preserves all values")
    func customInit() {
        let config = AzureConfiguration(
            resource: "res",
            deployment: "dep",
            apiVersion: "2024-02-01",
            contentFiltering: .strict,
            enableStreaming: false,
            region: "eastus"
        )
        #expect(config.resource == "res")
        #expect(config.deployment == "dep")
        #expect(config.apiVersion == "2024-02-01")
        #expect(config.contentFiltering == .strict)
        #expect(config.enableStreaming == false)
        #expect(config.region == "eastus")
    }

    // MARK: - URL Generation

    @Test("baseURL includes resource name")
    func baseURLIncludesResource() {
        let config = AzureConfiguration(resource: "my-company-openai", deployment: "dep")
        #expect(config.baseURL.absoluteString == "https://my-company-openai.openai.azure.com/openai")
    }

    @Test("chatCompletionsURL includes deployment and api-version")
    func chatCompletionsURL() {
        let config = AzureConfiguration(
            resource: "res",
            deployment: "gpt4-deploy",
            apiVersion: "2024-02-15-preview"
        )
        let url = config.chatCompletionsURL
        #expect(url.absoluteString.contains("deployments/gpt4-deploy/chat/completions"))
        #expect(url.absoluteString.contains("api-version=2024-02-15-preview"))
    }

    @Test("embeddingsURL includes deployment and api-version")
    func embeddingsURL() {
        let config = AzureConfiguration(
            resource: "res",
            deployment: "embed-deploy",
            apiVersion: "2024-02-01"
        )
        let url = config.embeddingsURL
        #expect(url.absoluteString.contains("deployments/embed-deploy/embeddings"))
        #expect(url.absoluteString.contains("api-version=2024-02-01"))
    }

    @Test("imagesGenerationsURL includes deployment and api-version")
    func imagesGenerationsURL() {
        let config = AzureConfiguration(
            resource: "res",
            deployment: "dalle-deploy",
            apiVersion: "2024-02-15-preview"
        )
        let url = config.imagesGenerationsURL
        #expect(url.absoluteString.contains("deployments/dalle-deploy/images/generations"))
        #expect(url.absoluteString.contains("api-version=2024-02-15-preview"))
    }

    // MARK: - Fluent API

    @Test("Fluent apiVersion returns updated copy")
    func fluentApiVersion() {
        let config = AzureConfiguration(resource: "res", deployment: "dep")
            .apiVersion("2024-02-01")
        #expect(config.apiVersion == "2024-02-01")
    }

    @Test("Fluent contentFiltering returns updated copy")
    func fluentContentFiltering() {
        let config = AzureConfiguration(resource: "res", deployment: "dep")
            .contentFiltering(.strict)
        #expect(config.contentFiltering == .strict)
    }

    @Test("Fluent withStrictFiltering sets strict mode")
    func fluentWithStrictFiltering() {
        let config = AzureConfiguration(resource: "res", deployment: "dep")
            .withStrictFiltering()
        #expect(config.contentFiltering == .strict)
    }

    @Test("Fluent streaming returns updated copy")
    func fluentStreaming() {
        let config = AzureConfiguration(resource: "res", deployment: "dep")
            .streaming(false)
        #expect(config.enableStreaming == false)
    }

    @Test("Fluent region returns updated copy")
    func fluentRegion() {
        let config = AzureConfiguration(resource: "res", deployment: "dep")
            .region("westus2")
        #expect(config.region == "westus2")
    }

    // MARK: - API Versions

    @Test("Known API versions have expected values")
    func knownApiVersions() {
        #expect(AzureConfiguration.APIVersion.latestStable == "2024-02-15-preview")
        #expect(AzureConfiguration.APIVersion.ga2024 == "2024-02-01")
        #expect(AzureConfiguration.APIVersion.legacy == "2023-05-15")
    }

    // MARK: - Codable

    @Test("AzureConfiguration round-trips through JSON")
    func codableRoundTrip() throws {
        let original = AzureConfiguration(
            resource: "my-resource",
            deployment: "gpt4",
            apiVersion: "2024-02-15-preview",
            contentFiltering: .strict,
            enableStreaming: false,
            region: "eastus"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AzureConfiguration.self, from: data)

        #expect(decoded.resource == original.resource)
        #expect(decoded.deployment == original.deployment)
        #expect(decoded.apiVersion == original.apiVersion)
        #expect(decoded.contentFiltering == original.contentFiltering)
        #expect(decoded.enableStreaming == original.enableStreaming)
        #expect(decoded.region == original.region)
    }

    @Test("AzureConfiguration with nil region round-trips")
    func codableRoundTripNilRegion() throws {
        let original = AzureConfiguration(resource: "res", deployment: "dep")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AzureConfiguration.self, from: data)
        #expect(decoded.region == nil)
    }

    // MARK: - Hashable / Equatable

    @Test("Equal configurations are equal")
    func equalConfigurationsEqual() {
        let a = AzureConfiguration(resource: "res", deployment: "dep")
        let b = AzureConfiguration(resource: "res", deployment: "dep")
        #expect(a == b)
    }

    @Test("Different configurations are not equal")
    func differentConfigurationsNotEqual() {
        let a = AzureConfiguration(resource: "res1", deployment: "dep")
        let b = AzureConfiguration(resource: "res2", deployment: "dep")
        #expect(a != b)
    }

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let config: Sendable = AzureConfiguration(resource: "r", deployment: "d")
        #expect(config is AzureConfiguration)
    }
}

// MARK: - ContentFilteringMode Tests

@Suite("ContentFilteringMode Tests")
struct ContentFilteringModeTests {

    @Test("All cases have correct raw values")
    func rawValues() {
        #expect(ContentFilteringMode.default.rawValue == "default")
        #expect(ContentFilteringMode.strict.rawValue == "strict")
        #expect(ContentFilteringMode.reduced.rawValue == "reduced")
        #expect(ContentFilteringMode.none.rawValue == "none")
    }

    @Test("Description returns human-readable string")
    func descriptions() {
        #expect(ContentFilteringMode.default.description == "Default filtering")
        #expect(ContentFilteringMode.strict.description == "Strict filtering")
        #expect(ContentFilteringMode.reduced.description == "Reduced filtering")
        #expect(ContentFilteringMode.none.description == "No filtering")
    }

    @Test("Codable round-trip for all cases")
    func codableRoundTrip() throws {
        let cases: [ContentFilteringMode] = [.default, .strict, .reduced, .none]
        for mode in cases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(ContentFilteringMode.self, from: data)
            #expect(decoded == mode)
        }
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
