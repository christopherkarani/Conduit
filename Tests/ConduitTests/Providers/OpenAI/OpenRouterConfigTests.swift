// OpenRouterConfigTests.swift
// Conduit Tests
//
// Tests for OpenRouterRoutingConfig, OpenRouterProvider, and OpenRouterDataCollection.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("OpenRouterRoutingConfig Tests")
struct OpenRouterRoutingConfigTests {

    // MARK: - Default Initialization

    @Test("Default init has expected values")
    func defaultInit() {
        let config = OpenRouterRoutingConfig()
        #expect(config.providers == nil)
        #expect(config.fallbacks == true)
        #expect(config.routeByLatency == false)
        #expect(config.requireProvidersForJSON == false)
        #expect(config.siteURL == nil)
        #expect(config.appName == nil)
        #expect(config.routeTag == nil)
        #expect(config.dataCollection == nil)
    }

    // MARK: - Custom Initialization

    @Test("Custom init preserves all values")
    func customInit() {
        let siteURL = URL(string: "https://myapp.com")!
        let config = OpenRouterRoutingConfig(
            providers: [.anthropic, .openai],
            fallbacks: false,
            routeByLatency: true,
            requireProvidersForJSON: true,
            siteURL: siteURL,
            appName: "MyApp",
            routeTag: "production",
            dataCollection: .deny
        )

        #expect(config.providers == [.anthropic, .openai])
        #expect(config.fallbacks == false)
        #expect(config.routeByLatency == true)
        #expect(config.requireProvidersForJSON == true)
        #expect(config.siteURL == siteURL)
        #expect(config.appName == "MyApp")
        #expect(config.routeTag == "production")
        #expect(config.dataCollection == .deny)
    }

    // MARK: - Static Presets

    @Test("Default preset matches default init")
    func defaultPreset() {
        let config = OpenRouterRoutingConfig.default
        #expect(config.providers == nil)
        #expect(config.fallbacks == true)
        #expect(config.routeByLatency == false)
    }

    @Test("preferOpenAI preset routes to OpenAI")
    func preferOpenAIPreset() {
        let config = OpenRouterRoutingConfig.preferOpenAI
        #expect(config.providers == [.openai])
        #expect(config.fallbacks == true)
    }

    @Test("preferAnthropic preset routes to Anthropic")
    func preferAnthropicPreset() {
        let config = OpenRouterRoutingConfig.preferAnthropic
        #expect(config.providers == [.anthropic])
        #expect(config.fallbacks == true)
    }

    @Test("fastestProvider preset enables latency routing")
    func fastestProviderPreset() {
        let config = OpenRouterRoutingConfig.fastestProvider
        #expect(config.routeByLatency == true)
        #expect(config.fallbacks == true)
    }

    // MARK: - Header Generation

    @Test("headers returns empty dict when no site info")
    func headersEmptyNoSiteInfo() {
        let config = OpenRouterRoutingConfig()
        let headers = config.headers()
        #expect(headers.isEmpty)
    }

    @Test("headers includes HTTP-Referer when siteURL set")
    func headersIncludesReferer() {
        let config = OpenRouterRoutingConfig(siteURL: URL(string: "https://myapp.com")!)
        let headers = config.headers()
        #expect(headers["HTTP-Referer"] == "https://myapp.com")
    }

    @Test("headers includes X-Title when appName set")
    func headersIncludesTitle() {
        let config = OpenRouterRoutingConfig(appName: "TestApp")
        let headers = config.headers()
        #expect(headers["X-Title"] == "TestApp")
    }

    @Test("headers includes both site URL and app name")
    func headersIncludesBoth() {
        let config = OpenRouterRoutingConfig(
            siteURL: URL(string: "https://app.com")!,
            appName: "MyApp"
        )
        let headers = config.headers()
        #expect(headers["HTTP-Referer"] == "https://app.com")
        #expect(headers["X-Title"] == "MyApp")
    }

    // MARK: - Provider Routing

    @Test("providerRouting returns nil for default config")
    func providerRoutingNilForDefault() {
        let config = OpenRouterRoutingConfig.default
        #expect(config.providerRouting() == nil)
    }

    @Test("providerRouting includes order when providers set")
    func providerRoutingIncludesOrder() {
        let config = OpenRouterRoutingConfig(providers: [.anthropic, .openai])
        let routing = config.providerRouting()
        let order = routing?["order"] as? [String]
        #expect(order == ["anthropic", "openai"])
    }

    @Test("providerRouting includes allow_fallbacks false when disabled")
    func providerRoutingDisabledFallbacks() {
        let config = OpenRouterRoutingConfig(fallbacks: false)
        let routing = config.providerRouting()
        #expect(routing?["allow_fallbacks"] as? Bool == false)
    }

    @Test("providerRouting includes sort latency when enabled")
    func providerRoutingSortLatency() {
        let config = OpenRouterRoutingConfig(routeByLatency: true)
        let routing = config.providerRouting()
        #expect(routing?["sort"] as? String == "latency")
    }

    @Test("providerRouting includes require_parameters when JSON required")
    func providerRoutingRequireJSON() {
        let config = OpenRouterRoutingConfig(requireProvidersForJSON: true)
        let routing = config.providerRouting()
        #expect(routing?["require_parameters"] as? Bool == true)
    }

    @Test("providerRouting includes data_collection when set")
    func providerRoutingDataCollection() {
        let config = OpenRouterRoutingConfig(dataCollection: .deny)
        let routing = config.providerRouting()
        #expect(routing?["data_collection"] as? String == "deny")
    }

    @Test("providerRouting uses legacy routeTag as data_collection when valid")
    func providerRoutingLegacyRouteTag() {
        let config = OpenRouterRoutingConfig(routeTag: "allow")
        let routing = config.providerRouting()
        #expect(routing?["data_collection"] as? String == "allow")
    }

    @Test("providerRouting ignores invalid routeTag")
    func providerRoutingIgnoresInvalidRouteTag() {
        let config = OpenRouterRoutingConfig(routeTag: "custom-tag")
        let routing = config.providerRouting()
        // "custom-tag" is not a valid OpenRouterDataCollection, so it should not appear
        #expect(routing?["data_collection"] == nil)
    }

    @Test("providerRouting prefers dataCollection over routeTag")
    func providerRoutingPrefersDataCollection() {
        let config = OpenRouterRoutingConfig(routeTag: "allow", dataCollection: .deny)
        let routing = config.providerRouting()
        #expect(routing?["data_collection"] as? String == "deny")
    }

    // MARK: - Fluent API

    @Test("Fluent providers returns updated copy")
    func fluentProviders() {
        let config = OpenRouterRoutingConfig.default
            .providers([.google, .mistral])
        #expect(config.providers == [.google, .mistral])
    }

    @Test("Fluent fallbacks returns updated copy")
    func fluentFallbacks() {
        let config = OpenRouterRoutingConfig.default.fallbacks(false)
        #expect(config.fallbacks == false)
    }

    @Test("Fluent routeByLatency returns updated copy")
    func fluentRouteByLatency() {
        let config = OpenRouterRoutingConfig.default.routeByLatency(true)
        #expect(config.routeByLatency == true)
    }

    @Test("Fluent siteURL returns updated copy")
    func fluentSiteURL() {
        let url = URL(string: "https://test.com")!
        let config = OpenRouterRoutingConfig.default.siteURL(url)
        #expect(config.siteURL == url)
    }

    @Test("Fluent appName returns updated copy")
    func fluentAppName() {
        let config = OpenRouterRoutingConfig.default.appName("TestApp")
        #expect(config.appName == "TestApp")
    }

    @Test("Fluent routeTag returns updated copy")
    func fluentRouteTag() {
        let config = OpenRouterRoutingConfig.default.routeTag("prod")
        #expect(config.routeTag == "prod")
    }

    @Test("Fluent dataCollection returns updated copy")
    func fluentDataCollection() {
        let config = OpenRouterRoutingConfig.default.dataCollection(.deny)
        #expect(config.dataCollection == .deny)
    }

    @Test("Fluent chaining works correctly")
    func fluentChaining() {
        let config = OpenRouterRoutingConfig.default
            .providers([.anthropic])
            .fallbacks(false)
            .routeByLatency(true)
            .appName("ChainedApp")
            .dataCollection(.allow)

        #expect(config.providers == [.anthropic])
        #expect(config.fallbacks == false)
        #expect(config.routeByLatency == true)
        #expect(config.appName == "ChainedApp")
        #expect(config.dataCollection == .allow)
    }

    // MARK: - Codable

    @Test("OpenRouterRoutingConfig round-trips through JSON")
    func codableRoundTrip() throws {
        let original = OpenRouterRoutingConfig(
            providers: [.openai, .anthropic],
            fallbacks: false,
            routeByLatency: true,
            requireProvidersForJSON: true,
            siteURL: URL(string: "https://example.com"),
            appName: "TestApp",
            routeTag: "allow",
            dataCollection: .deny
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenRouterRoutingConfig.self, from: data)

        #expect(decoded.providers == original.providers)
        #expect(decoded.fallbacks == original.fallbacks)
        #expect(decoded.routeByLatency == original.routeByLatency)
        #expect(decoded.requireProvidersForJSON == original.requireProvidersForJSON)
        #expect(decoded.siteURL == original.siteURL)
        #expect(decoded.appName == original.appName)
        #expect(decoded.routeTag == original.routeTag)
        #expect(decoded.dataCollection == original.dataCollection)
    }

    @Test("Default preset round-trips through JSON")
    func codableDefaultRoundTrip() throws {
        let original = OpenRouterRoutingConfig.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenRouterRoutingConfig.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Hashable / Equatable

    @Test("Equal configs are equal")
    func equalConfigsEqual() {
        let a = OpenRouterRoutingConfig.default
        let b = OpenRouterRoutingConfig.default
        #expect(a == b)
    }

    @Test("Different configs are not equal")
    func differentConfigsNotEqual() {
        let a = OpenRouterRoutingConfig.preferOpenAI
        let b = OpenRouterRoutingConfig.preferAnthropic
        #expect(a != b)
    }

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let config: Sendable = OpenRouterRoutingConfig.default
        #expect(config is OpenRouterRoutingConfig)
    }
}

// MARK: - OpenRouterProvider Tests

@Suite("OpenRouterProvider Tests")
struct OpenRouterProviderTests {

    @Test("All CaseIterable providers exist")
    func allCasesExist() {
        let allCases = OpenRouterProvider.allCases
        #expect(allCases.contains(.openai))
        #expect(allCases.contains(.anthropic))
        #expect(allCases.contains(.google))
        #expect(allCases.contains(.googleAIStudio))
        #expect(allCases.contains(.together))
        #expect(allCases.contains(.fireworks))
        #expect(allCases.contains(.perplexity))
        #expect(allCases.contains(.mistral))
        #expect(allCases.contains(.groq))
        #expect(allCases.contains(.deepseek))
        #expect(allCases.contains(.cohere))
        #expect(allCases.contains(.ai21))
        #expect(allCases.contains(.bedrock))
        #expect(allCases.contains(.azure))
        #expect(allCases.count == 14)
    }

    @Test("Raw values are display names")
    func rawValuesAreDisplayNames() {
        #expect(OpenRouterProvider.openai.rawValue == "OpenAI")
        #expect(OpenRouterProvider.anthropic.rawValue == "Anthropic")
        #expect(OpenRouterProvider.google.rawValue == "Google")
        #expect(OpenRouterProvider.googleAIStudio.rawValue == "Google AI Studio")
        #expect(OpenRouterProvider.together.rawValue == "Together")
        #expect(OpenRouterProvider.fireworks.rawValue == "Fireworks")
        #expect(OpenRouterProvider.perplexity.rawValue == "Perplexity")
        #expect(OpenRouterProvider.mistral.rawValue == "Mistral")
        #expect(OpenRouterProvider.groq.rawValue == "Groq")
        #expect(OpenRouterProvider.deepseek.rawValue == "DeepSeek")
        #expect(OpenRouterProvider.cohere.rawValue == "Cohere")
        #expect(OpenRouterProvider.ai21.rawValue == "AI21")
        #expect(OpenRouterProvider.bedrock.rawValue == "Amazon Bedrock")
        #expect(OpenRouterProvider.azure.rawValue == "Azure")
    }

    @Test("Slugs are lowercase API identifiers")
    func slugsAreLowercase() {
        #expect(OpenRouterProvider.openai.slug == "openai")
        #expect(OpenRouterProvider.anthropic.slug == "anthropic")
        #expect(OpenRouterProvider.google.slug == "google")
        #expect(OpenRouterProvider.googleAIStudio.slug == "google-ai-studio")
        #expect(OpenRouterProvider.together.slug == "together")
        #expect(OpenRouterProvider.fireworks.slug == "fireworks")
        #expect(OpenRouterProvider.perplexity.slug == "perplexity")
        #expect(OpenRouterProvider.mistral.slug == "mistral")
        #expect(OpenRouterProvider.groq.slug == "groq")
        #expect(OpenRouterProvider.deepseek.slug == "deepseek")
        #expect(OpenRouterProvider.cohere.slug == "cohere")
        #expect(OpenRouterProvider.ai21.slug == "ai21")
        #expect(OpenRouterProvider.bedrock.slug == "bedrock")
        #expect(OpenRouterProvider.azure.slug == "azure")
    }

    @Test("displayName matches rawValue")
    func displayNameMatchesRawValue() {
        for provider in OpenRouterProvider.allCases {
            #expect(provider.displayName == provider.rawValue)
        }
    }

    @Test("Codable round-trip for all providers")
    func codableRoundTrip() throws {
        for provider in OpenRouterProvider.allCases {
            let data = try JSONEncoder().encode(provider)
            let decoded = try JSONDecoder().decode(OpenRouterProvider.self, from: data)
            #expect(decoded == provider)
        }
    }

    @Test("Can be used in a Set")
    func usableInSet() {
        let set: Set<OpenRouterProvider> = [.openai, .anthropic, .openai]
        #expect(set.count == 2)
    }
}

// MARK: - OpenRouterDataCollection Tests

@Suite("OpenRouterDataCollection Tests")
struct OpenRouterDataCollectionTests {

    @Test("allow has correct raw value")
    func allowRawValue() {
        #expect(OpenRouterDataCollection.allow.rawValue == "allow")
    }

    @Test("deny has correct raw value")
    func denyRawValue() {
        #expect(OpenRouterDataCollection.deny.rawValue == "deny")
    }

    @Test("CaseIterable includes both cases")
    func caseIterable() {
        let allCases = OpenRouterDataCollection.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.allow))
        #expect(allCases.contains(.deny))
    }

    @Test("Codable round-trip for both cases")
    func codableRoundTrip() throws {
        for policy in OpenRouterDataCollection.allCases {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(OpenRouterDataCollection.self, from: data)
            #expect(decoded == policy)
        }
    }

    @Test("Can initialize from valid raw values")
    func initFromRawValue() {
        #expect(OpenRouterDataCollection(rawValue: "allow") == .allow)
        #expect(OpenRouterDataCollection(rawValue: "deny") == .deny)
        #expect(OpenRouterDataCollection(rawValue: "invalid") == nil)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
