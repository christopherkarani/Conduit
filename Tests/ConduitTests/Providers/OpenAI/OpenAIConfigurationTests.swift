// OpenAIConfigurationTests.swift
// Conduit Tests
//
// Tests for OpenAIConfiguration initialization, defaults, fluent API, and Codable.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("OpenAIConfiguration Tests")
struct OpenAIConfigurationTests {

    // MARK: - Default Initialization

    @Test("Default init has expected values")
    func defaultInit() {
        let config = OpenAIConfiguration()
        #expect(config.endpoint == .openAI)
        #expect(config.authentication == .auto)
        #expect(config.apiVariant == .chatCompletions)
        #expect(config.timeout == 60.0)
        #expect(config.maxRetries == 3)
        #expect(config.retryConfig == .default)
        #expect(config.defaultHeaders.isEmpty)
        #expect(config.userAgent == nil)
        #expect(config.organizationID == nil)
        #expect(config.openRouterConfig == nil)
        #expect(config.azureConfig == nil)
        #expect(config.ollamaConfig == nil)
    }

    @Test("Default static property matches default init")
    func defaultStaticProperty() {
        let config = OpenAIConfiguration.default
        #expect(config.endpoint == .openAI)
        #expect(config.authentication == .auto)
        #expect(config.timeout == 60.0)
        #expect(config.maxRetries == 3)
    }

    // MARK: - Clamping

    @Test("Negative timeout is clamped to zero")
    func negativeTimeoutClamped() {
        let config = OpenAIConfiguration(timeout: -10)
        #expect(config.timeout == 0)
    }

    @Test("Negative maxRetries is clamped to zero")
    func negativeMaxRetriesClamped() {
        let config = OpenAIConfiguration(maxRetries: -3)
        #expect(config.maxRetries == 0)
    }

    // MARK: - Static Presets

    @Test("openRouter preset has correct endpoint and authentication")
    func openRouterPreset() {
        let config = OpenAIConfiguration.openRouter
        #expect(config.endpoint == .openRouter)
        #expect(config.authentication == .environment("OPENROUTER_API_KEY"))
        #expect(config.openRouterConfig != nil)
    }

    @Test("ollama preset has correct endpoint and no auth")
    func ollamaPreset() {
        let config = OpenAIConfiguration.ollama
        #expect(config.authentication == .none)
        #expect(config.ollamaConfig != nil)
    }

    @Test("longRunning preset has extended timeout and aggressive retry")
    func longRunningPreset() {
        let config = OpenAIConfiguration.longRunning
        #expect(config.timeout == 120.0)
        #expect(config.maxRetries == 5)
        #expect(config.retryConfig == .aggressive)
    }

    @Test("noRetry preset has zero retries")
    func noRetryPreset() {
        let config = OpenAIConfiguration.noRetry
        #expect(config.maxRetries == 0)
        #expect(config.retryConfig == .none)
    }

    // MARK: - Convenience Initializers

    @Test("openAI(apiKey:) creates bearer auth with openAI endpoint")
    func openAIConvenience() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test123")
        #expect(config.endpoint == .openAI)
        #expect(config.authentication == .bearer("sk-test123"))
    }

    @Test("openRouter(apiKey:) creates bearer auth with openRouter endpoint")
    func openRouterConvenience() {
        let config = OpenAIConfiguration.openRouter(apiKey: "or-test456")
        #expect(config.endpoint == .openRouter)
        #expect(config.authentication == .bearer("or-test456"))
        #expect(config.openRouterConfig != nil)
    }

    @Test("ollama(host:port:) creates config with no auth")
    func ollamaConvenience() {
        let config = OpenAIConfiguration.ollama(host: "192.168.1.5", port: 8080)
        #expect(config.authentication == .none)
        #expect(config.ollamaConfig != nil)
    }

    @Test("azure convenience creates apiKey auth with correct endpoint")
    func azureConvenience() {
        let config = OpenAIConfiguration.azure(
            resource: "my-resource",
            deployment: "gpt4-deploy",
            apiKey: "azure-key-123"
        )
        #expect(config.authentication == .apiKey("azure-key-123", headerName: "api-key"))
        #expect(config.azureConfig != nil)
        #expect(config.azureConfig?.resource == "my-resource")
        #expect(config.azureConfig?.deployment == "gpt4-deploy")
    }

    @Test("custom(url:) creates config with auto auth when no key")
    func customConvenienceNoKey() {
        let url = URL(string: "https://my-proxy.com/v1")!
        let config = OpenAIConfiguration.custom(url: url)
        #expect(config.endpoint == .custom(url))
        #expect(config.authentication == .auto)
    }

    @Test("custom(url:apiKey:) creates config with bearer auth")
    func customConvenienceWithKey() {
        let url = URL(string: "https://my-proxy.com/v1")!
        let config = OpenAIConfiguration.custom(url: url, apiKey: "my-key")
        #expect(config.authentication == .bearer("my-key"))
    }

    // MARK: - Computed Properties

    @Test("hasValidAuthentication returns true for ollama (no auth required)")
    func hasValidAuthOllama() {
        let config = OpenAIConfiguration.ollama
        #expect(config.hasValidAuthentication)
    }

    @Test("hasValidAuthentication returns true for bearer with non-empty token")
    func hasValidAuthBearer() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test")
        #expect(config.hasValidAuthentication)
    }

    @Test("hasValidAuthentication returns false for bearer with empty token")
    func hasInvalidAuthEmptyBearer() {
        let config = OpenAIConfiguration(
            endpoint: .openAI,
            authentication: .bearer("")
        )
        #expect(!config.hasValidAuthentication)
    }

    @Test("capabilities returns endpoint default capabilities")
    func capabilitiesReturnsEndpointDefaults() {
        let openAI = OpenAIConfiguration.default
        #expect(openAI.capabilities == OpenAICapabilities.openAI)

        let openRouter = OpenAIConfiguration.openRouter
        #expect(openRouter.capabilities == OpenAICapabilities.openRouter)
    }

    // MARK: - Fluent API

    @Test("Fluent endpoint returns updated copy")
    func fluentEndpoint() {
        let config = OpenAIConfiguration.default.endpoint(.openRouter)
        #expect(config.endpoint == .openRouter)
    }

    @Test("Fluent authentication returns updated copy")
    func fluentAuthentication() {
        let config = OpenAIConfiguration.default.authentication(.bearer("sk-test"))
        #expect(config.authentication == .bearer("sk-test"))
    }

    @Test("Fluent apiVariant returns updated copy")
    func fluentApiVariant() {
        let config = OpenAIConfiguration.default.apiVariant(.responses)
        #expect(config.apiVariant == .responses)
    }

    @Test("Fluent apiKey sets bearer authentication")
    func fluentApiKey() {
        let config = OpenAIConfiguration.default.apiKey("sk-new-key")
        #expect(config.authentication == .bearer("sk-new-key"))
    }

    @Test("Fluent timeout returns updated copy and clamps negative")
    func fluentTimeout() {
        let config = OpenAIConfiguration.default.timeout(120.0)
        #expect(config.timeout == 120.0)

        let clamped = OpenAIConfiguration.default.timeout(-5.0)
        #expect(clamped.timeout == 0.0)
    }

    @Test("Fluent maxRetries returns updated copy and clamps negative")
    func fluentMaxRetries() {
        let config = OpenAIConfiguration.default.maxRetries(10)
        #expect(config.maxRetries == 10)

        let clamped = OpenAIConfiguration.default.maxRetries(-1)
        #expect(clamped.maxRetries == 0)
    }

    @Test("Fluent retryConfig returns updated copy")
    func fluentRetryConfig() {
        let config = OpenAIConfiguration.default.retryConfig(.aggressive)
        #expect(config.retryConfig == .aggressive)
    }

    @Test("Fluent noRetries sets maxRetries to zero")
    func fluentNoRetries() {
        let config = OpenAIConfiguration.default.noRetries()
        #expect(config.maxRetries == 0)
    }

    @Test("Fluent headers returns updated copy")
    func fluentHeaders() {
        let config = OpenAIConfiguration.default.headers(["X-Custom": "value"])
        #expect(config.defaultHeaders == ["X-Custom": "value"])
    }

    @Test("Fluent header adds a single header")
    func fluentHeader() {
        let config = OpenAIConfiguration.default.header("X-Custom", value: "test")
        #expect(config.defaultHeaders["X-Custom"] == "test")
    }

    @Test("Fluent userAgent returns updated copy")
    func fluentUserAgent() {
        let config = OpenAIConfiguration.default.userAgent("MyApp/1.0")
        #expect(config.userAgent == "MyApp/1.0")
    }

    @Test("Fluent organization returns updated copy")
    func fluentOrganization() {
        let config = OpenAIConfiguration.default.organization("org-123")
        #expect(config.organizationID == "org-123")
    }

    @Test("Fluent openRouter routing returns updated copy")
    func fluentOpenRouterRouting() {
        let routing = OpenRouterRoutingConfig(providers: [.anthropic], fallbacks: true)
        let config = OpenAIConfiguration.default.openRouter(routing)
        #expect(config.openRouterConfig?.providers == [.anthropic])
    }

    @Test("Fluent routing alias works")
    func fluentRoutingAlias() {
        let config = OpenAIConfiguration.openRouter(apiKey: "test")
            .routing(.preferAnthropic)
        #expect(config.openRouterConfig?.providers == [.anthropic])
    }

    @Test("Fluent preferring sets provider routing")
    func fluentPreferring() {
        let config = OpenAIConfiguration.openRouter(apiKey: "test")
            .preferring(.openai, .anthropic)
        #expect(config.openRouterConfig?.providers == [.openai, .anthropic])
        #expect(config.openRouterConfig?.fallbacks == true)
    }

    @Test("Fluent routeByLatency enables latency routing")
    func fluentRouteByLatency() {
        let config = OpenAIConfiguration.openRouter(apiKey: "test")
            .routeByLatency()
        #expect(config.openRouterConfig?.routeByLatency == true)
    }

    @Test("Fluent routeByLatency creates default config if nil")
    func fluentRouteByLatencyCreatesDefault() {
        let config = OpenAIConfiguration.default.routeByLatency()
        #expect(config.openRouterConfig != nil)
        #expect(config.openRouterConfig?.routeByLatency == true)
    }

    @Test("Fluent ollama returns updated copy")
    func fluentOllama() {
        let ollamaConfig = OllamaConfiguration(keepAlive: "10m")
        let config = OpenAIConfiguration.default.ollama(ollamaConfig)
        #expect(config.ollamaConfig?.keepAlive == "10m")
    }

    @Test("Fluent azure returns updated copy")
    func fluentAzure() {
        let azureConfig = AzureConfiguration(resource: "res", deployment: "dep")
        let config = OpenAIConfiguration.default.azure(azureConfig)
        #expect(config.azureConfig?.resource == "res")
    }

    // MARK: - Build Headers

    @Test("buildHeaders includes Content-Type")
    func buildHeadersIncludesContentType() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test")
        let headers = config.buildHeaders()
        #expect(headers["Content-Type"] == "application/json")
    }

    @Test("buildHeaders includes bearer auth")
    func buildHeadersIncludesAuth() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test")
        let headers = config.buildHeaders()
        #expect(headers["Authorization"] == "Bearer sk-test")
    }

    @Test("buildHeaders includes default User-Agent when custom not set")
    func buildHeadersDefaultUserAgent() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test")
        let headers = config.buildHeaders()
        #expect(headers["User-Agent"]?.hasPrefix("Conduit/") == true)
    }

    @Test("buildHeaders uses custom User-Agent when set")
    func buildHeadersCustomUserAgent() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test")
            .userAgent("MyApp/2.0")
        let headers = config.buildHeaders()
        #expect(headers["User-Agent"] == "MyApp/2.0")
    }

    @Test("buildHeaders includes organization ID for OpenAI endpoint")
    func buildHeadersIncludesOrgId() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test")
            .organization("org-abc")
        let headers = config.buildHeaders()
        #expect(headers["OpenAI-Organization"] == "org-abc")
    }

    @Test("buildHeaders does not include organization ID for non-OpenAI endpoint")
    func buildHeadersOmitsOrgIdForNonOpenAI() {
        let config = OpenAIConfiguration.openRouter(apiKey: "or-test")
            .organization("org-abc")
        let headers = config.buildHeaders()
        #expect(headers["OpenAI-Organization"] == nil)
    }

    @Test("buildHeaders includes default headers")
    func buildHeadersIncludesDefaultHeaders() {
        let config = OpenAIConfiguration.openAI(apiKey: "sk-test")
            .headers(["X-Custom": "value"])
        let headers = config.buildHeaders()
        #expect(headers["X-Custom"] == "value")
    }

    @Test("buildHeaders includes OpenRouter site headers")
    func buildHeadersIncludesOpenRouterHeaders() {
        let routing = OpenRouterRoutingConfig(
            siteURL: URL(string: "https://myapp.com"),
            appName: "MyApp"
        )
        let config = OpenAIConfiguration.openRouter(apiKey: "or-test")
            .openRouter(routing)
        let headers = config.buildHeaders()
        #expect(headers["HTTP-Referer"] == "https://myapp.com")
        #expect(headers["X-Title"] == "MyApp")
    }

    // MARK: - Codable

    @Test("OpenAIConfiguration round-trips through JSON with default values")
    func codableRoundTripDefaults() throws {
        let original = OpenAIConfiguration.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIConfiguration.self, from: data)

        #expect(decoded.endpoint == original.endpoint)
        #expect(decoded.timeout == original.timeout)
        #expect(decoded.maxRetries == original.maxRetries)
        #expect(decoded.defaultHeaders == original.defaultHeaders)
        // Authentication is not encoded (security) - decoded should be .auto
        #expect(decoded.authentication == .auto)
    }

    @Test("OpenAIConfiguration authentication is not persisted in JSON for security")
    func codableDoesNotPersistAuth() throws {
        let original = OpenAIConfiguration.openAI(apiKey: "sk-secret-key")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIConfiguration.self, from: data)

        // Authentication should be .auto after decoding, not bearer
        #expect(decoded.authentication == .auto)
    }

    @Test("OpenAIConfiguration azureConfig is not persisted in JSON for security")
    func codableDoesNotPersistAzureConfig() throws {
        let original = OpenAIConfiguration.azure(
            resource: "res",
            deployment: "dep",
            apiKey: "key"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIConfiguration.self, from: data)

        #expect(decoded.azureConfig == nil)
    }

    @Test("OpenAIConfiguration preserves optional fields through encoding")
    func codablePreservesOptionalFields() throws {
        let original = OpenAIConfiguration(
            userAgent: "TestAgent",
            organizationID: "org-test",
            openRouterConfig: .default,
            ollamaConfig: .default
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIConfiguration.self, from: data)

        #expect(decoded.userAgent == "TestAgent")
        #expect(decoded.organizationID == "org-test")
        #expect(decoded.openRouterConfig != nil)
        #expect(decoded.ollamaConfig != nil)
    }

    @Test("OpenAIConfiguration apiVariant round-trips")
    func codableRoundTripApiVariant() throws {
        let original = OpenAIConfiguration.default.apiVariant(.responses)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIConfiguration.self, from: data)
        #expect(decoded.apiVariant == .responses)
    }

    // MARK: - Hashable / Equatable

    @Test("Equal configurations are equal")
    func equalConfigurationsAreEqual() {
        let a = OpenAIConfiguration.default
        let b = OpenAIConfiguration.default
        #expect(a == b)
    }

    @Test("Different configurations are not equal")
    func differentConfigurationsAreNotEqual() {
        let a = OpenAIConfiguration.default
        let b = OpenAIConfiguration.longRunning
        #expect(a != b)
    }
}

// MARK: - OpenAIAPIVariant Tests

@Suite("OpenAIAPIVariant Type Tests")
struct OpenAIAPIVariantTypeTests {

    @Test("chatCompletions raw value is correct")
    func chatCompletionsRawValue() {
        #expect(OpenAIAPIVariant.chatCompletions.rawValue == "chatCompletions")
    }

    @Test("responses raw value is correct")
    func responsesRawValue() {
        #expect(OpenAIAPIVariant.responses.rawValue == "responses")
    }

    @Test("Codable round-trip for both variants")
    func codableRoundTrip() throws {
        for variant in [OpenAIAPIVariant.chatCompletions, .responses] {
            let data = try JSONEncoder().encode(variant)
            let decoded = try JSONDecoder().decode(OpenAIAPIVariant.self, from: data)
            #expect(decoded == variant)
        }
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
