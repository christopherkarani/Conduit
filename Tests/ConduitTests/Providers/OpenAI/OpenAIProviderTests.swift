// OpenAIProviderTests.swift
// Conduit
//
// Unit tests for OpenAI provider components.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Testing
import Foundation
@testable import Conduit

// MARK: - Configuration Tests

@Suite("OpenAI Configuration Tests")
struct OpenAIConfigurationTests {

    @Test("Default configuration uses OpenAI endpoint")
    func defaultConfiguration() {
        let config = OpenAIConfiguration.default
        #expect(config.endpoint == .openAI)
        #expect(config.timeout == 60.0)
        #expect(config.maxRetries == 3)
    }

    @Test("Fluent API creates modified copies")
    func fluentAPI() {
        let config = OpenAIConfiguration.default
            .timeout(120.0)
            .maxRetries(5)
            .noRetries()

        #expect(config.timeout == 120.0)
        #expect(config.maxRetries == 0)
        // Original unchanged
        #expect(OpenAIConfiguration.default.timeout == 60.0)
    }

    @Test("Static presets are correctly configured")
    func staticPresets() {
        let openRouter = OpenAIConfiguration.openRouter
        #expect(openRouter.endpoint == .openRouter)

        let ollama = OpenAIConfiguration.ollama
        #expect(ollama.endpoint == .ollama())
        #expect(ollama.authentication == .none)
    }

    @Test("Negative timeout is clamped to zero")
    func timeoutClamping() {
        let config = OpenAIConfiguration(timeout: -10)
        #expect(config.timeout == 0)
    }

    @Test("Negative retries is clamped to zero")
    func retriesClamping() {
        let config = OpenAIConfiguration(maxRetries: -5)
        #expect(config.maxRetries == 0)
    }
}

// MARK: - Authentication Tests

@Suite("OpenAI Authentication Tests")
struct OpenAIAuthenticationTests {

    @Test("Bearer token resolves correctly")
    func bearerToken() {
        let auth = OpenAIAuthentication.bearer("sk-test123")
        #expect(auth.resolve() == "sk-test123")
        #expect(auth.headerName == "Authorization")
        #expect(auth.headerValue == "Bearer sk-test123")
        #expect(auth.isConfigured == true)
    }

    @Test("API key with custom header")
    func apiKeyCustomHeader() {
        let auth = OpenAIAuthentication.apiKey("azure-key", headerName: "api-key")
        #expect(auth.resolve() == "azure-key")
        #expect(auth.headerName == "api-key")
        #expect(auth.headerValue == "azure-key")
    }

    @Test("None authentication returns nil values")
    func noneAuth() {
        let auth = OpenAIAuthentication.none
        #expect(auth.resolve() == nil)
        #expect(auth.headerName == nil)
        #expect(auth.headerValue == nil)
        #expect(auth.isConfigured == true) // None is intentionally "configured"
    }

    @Test("Empty bearer token is not configured")
    func emptyBearerNotConfigured() {
        let auth = OpenAIAuthentication.bearer("")
        #expect(auth.isConfigured == false)
    }

    @Test("Debug description redacts credentials")
    func credentialRedaction() {
        let auth = OpenAIAuthentication.bearer("sk-secret-key-12345")
        #expect(auth.debugDescription.contains("***"))
        #expect(!auth.debugDescription.contains("secret"))
    }

    @Test("Endpoint-specific authentication factory")
    func endpointFactory() {
        let ollamaAuth = OpenAIAuthentication.for(endpoint: .ollama())
        #expect(ollamaAuth == .none)

        let openAIAuth = OpenAIAuthentication.for(endpoint: .openAI, apiKey: "sk-test")
        #expect(openAIAuth == .bearer("sk-test"))

        let endpoint = OpenAIEndpoint.azure(resource: "r", deployment: "d", apiVersion: "v")
        let azureAuth = OpenAIAuthentication.for(endpoint: endpoint, apiKey: "key")
        if case .apiKey(let key, let header) = azureAuth {
            #expect(key == "key")
            #expect(header == "api-key")
        } else {
            Issue.record("Expected apiKey authentication")
        }
    }
}

// MARK: - Endpoint Tests

@Suite("OpenAI Endpoint Tests")
struct OpenAIEndpointTests {

    @Test("OpenAI endpoint URLs")
    func openAIURLs() {
        let endpoint = OpenAIEndpoint.openAI
        #expect(endpoint.baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(endpoint.chatCompletionsURL.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(endpoint.embeddingsURL.absoluteString == "https://api.openai.com/v1/embeddings")
    }

    @Test("OpenRouter endpoint URLs")
    func openRouterURLs() {
        let endpoint = OpenAIEndpoint.openRouter
        #expect(endpoint.baseURL.absoluteString == "https://openrouter.ai/api/v1")
    }

    @Test("Ollama endpoint with default values")
    func ollamaDefault() {
        let endpoint = OpenAIEndpoint.ollama()
        #expect(endpoint.baseURL.absoluteString == "http://localhost:11434/v1")
        #expect(endpoint.isLocal == true)
        #expect(endpoint.requiresAuthentication == false)
    }

    @Test("Ollama endpoint with custom host and port")
    func ollamaCustom() {
        let endpoint = OpenAIEndpoint.ollama(host: "192.168.1.10", port: 8080)
        #expect(endpoint.baseURL.absoluteString == "http://192.168.1.10:8080/v1")
    }

    @Test("Ollama validated constructor")
    func ollamaValidated() throws {
        // Valid config
        let valid = OpenAIEndpoint.ollamaValidated(host: "localhost", port: 11434)
        #expect(valid == .ollama(host: "localhost", port: 11434))

        // Empty host falls back to localhost
        let emptyHost = OpenAIEndpoint.ollamaValidated(host: "", port: 11434)
        #expect(emptyHost == .ollama(host: "localhost", port: 11434))

        // Invalid port falls back to default
        let invalidPort = OpenAIEndpoint.ollamaValidated(host: "localhost", port: 99999)
        #expect(invalidPort == .ollama(host: "localhost", port: 11434))
    }

    @Test("Ollama validation throws for invalid config")
    func ollamaValidationThrows() {
        #expect(throws: OpenAIEndpoint.ValidationError.self) {
            try OpenAIEndpoint.validateOllamaConfig(host: "", port: 11434)
        }

        #expect(throws: OpenAIEndpoint.ValidationError.self) {
            try OpenAIEndpoint.validateOllamaConfig(host: "localhost", port: 99999)
        }
    }

    @Test("Azure endpoint URLs")
    func azureURLs() {
        let endpoint = OpenAIEndpoint.azure(
            resource: "my-resource",
            deployment: "gpt-4",
            apiVersion: "2024-02-15-preview"
        )

        #expect(endpoint.baseURL.absoluteString == "https://my-resource.openai.azure.com/openai")
        #expect(endpoint.chatCompletionsURL.absoluteString.contains("deployments/gpt-4"))
        #expect(endpoint.chatCompletionsURL.absoluteString.contains("api-version=2024-02-15-preview"))
    }

    @Test("Endpoint display names")
    func displayNames() {
        #expect(OpenAIEndpoint.openAI.displayName == "OpenAI")
        #expect(OpenAIEndpoint.openRouter.displayName == "OpenRouter")
        #expect(OpenAIEndpoint.ollama().displayName == "Ollama (Local)")
    }
}

// MARK: - Model ID Tests

@Suite("OpenAI Model ID Tests")
struct OpenAIModelIDTests {

    @Test("Static model properties")
    func staticModels() {
        #expect(OpenAIModelID.gpt4o.rawValue == "gpt-4o")
        #expect(OpenAIModelID.gpt4oMini.rawValue == "gpt-4o-mini")
        #expect(OpenAIModelID.gpt35Turbo.rawValue == "gpt-3.5-turbo")
    }

    @Test("String literal initialization")
    func stringLiteral() {
        let model: OpenAIModelID = "custom-model"
        #expect(model.rawValue == "custom-model")
    }

    @Test("Display name extraction")
    func displayName() {
        // Simple model
        #expect(OpenAIModelID.gpt4o.displayName == "gpt-4o")

        // OpenRouter format extracts after slash
        let orModel = OpenAIModelID.openRouter("anthropic/claude-3-opus")
        #expect(orModel.displayName == "claude-3-opus")
    }

    @Test("Provider type is openAI")
    func providerType() {
        #expect(OpenAIModelID.gpt4o.provider == .openAI)
        #expect(OpenAIModelID.ollamaLlama32.provider == .openAI)
    }

    @Test("Ollama model helpers")
    func ollamaModels() {
        #expect(OpenAIModelID.ollamaLlama32.rawValue == "llama3.2")
        #expect(OpenAIModelID.ollamaLlama32B3B.rawValue == "llama3.2:3b")

        let custom = OpenAIModelID.ollama("mistral:7b-instruct")
        #expect(custom.rawValue == "mistral:7b-instruct")
    }

    @Test("Azure deployment helper")
    func azureDeployment() {
        let model = OpenAIModelID.azure(deployment: "my-gpt4-deployment")
        #expect(model.rawValue == "my-gpt4-deployment")
    }

    @Test("Codable round-trip")
    func codable() throws {
        let original = OpenAIModelID.gpt4o
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIModelID.self, from: data)
        #expect(decoded == original)
    }
}

// MARK: - TokenCount isEstimate Tests

@Suite("TokenCount isEstimate Tests")
struct TokenCountIsEstimateTests {

    @Test("Default isEstimate is false")
    func defaultIsEstimateFalse() {
        let count = TokenCount(count: 100)
        #expect(count.isEstimate == false)
    }

    @Test("Explicit isEstimate true")
    func explicitIsEstimateTrue() {
        let count = TokenCount(count: 100, isEstimate: true)
        #expect(count.isEstimate == true)
    }

    @Test("Description includes estimated when true")
    func descriptionIncludesEstimated() {
        let estimate = TokenCount(count: 100, isEstimate: true)
        #expect(estimate.description.contains("estimated"))

        let precise = TokenCount(count: 100, isEstimate: false)
        #expect(!precise.description.contains("estimated"))
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
