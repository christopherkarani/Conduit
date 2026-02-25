// OpenAIEndpointTests.swift
// Conduit Tests
//
// Tests for OpenAIEndpoint URL construction, properties, validation, and Codable.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("OpenAIEndpoint Tests")
struct OpenAIEndpointTests {

    // MARK: - Base URLs

    @Test("OpenAI base URL is correct")
    func openAIBaseURL() {
        #expect(OpenAIEndpoint.openAI.baseURL.absoluteString == "https://api.openai.com/v1")
    }

    @Test("OpenRouter base URL is correct")
    func openRouterBaseURL() {
        #expect(OpenAIEndpoint.openRouter.baseURL.absoluteString == "https://openrouter.ai/api/v1")
    }

    @Test("Ollama default base URL is correct")
    func ollamaDefaultBaseURL() {
        let endpoint = OpenAIEndpoint.ollama()
        #expect(endpoint.baseURL.absoluteString == "http://localhost:11434/v1")
    }

    @Test("Ollama custom host and port base URL is correct")
    func ollamaCustomBaseURL() {
        let endpoint = OpenAIEndpoint.ollama(host: "192.168.1.10", port: 8080)
        #expect(endpoint.baseURL.absoluteString == "http://192.168.1.10:8080/v1")
    }

    @Test("Azure base URL includes resource name")
    func azureBaseURL() {
        let endpoint = OpenAIEndpoint.azure(
            resource: "my-resource",
            deployment: "gpt4",
            apiVersion: "2024-02-15-preview"
        )
        #expect(endpoint.baseURL.absoluteString == "https://my-resource.openai.azure.com/openai")
    }

    @Test("Custom endpoint base URL is the provided URL")
    func customBaseURL() {
        let url = URL(string: "https://my-proxy.com/v1")!
        let endpoint = OpenAIEndpoint.custom(url)
        #expect(endpoint.baseURL == url)
    }

    // MARK: - Chat Completions URL

    @Test("OpenAI chat completions URL")
    func openAIChatCompletionsURL() {
        let url = OpenAIEndpoint.openAI.chatCompletionsURL
        #expect(url.absoluteString == "https://api.openai.com/v1/chat/completions")
    }

    @Test("OpenRouter chat completions URL")
    func openRouterChatCompletionsURL() {
        let url = OpenAIEndpoint.openRouter.chatCompletionsURL
        #expect(url.absoluteString == "https://openrouter.ai/api/v1/chat/completions")
    }

    @Test("Ollama chat completions URL")
    func ollamaChatCompletionsURL() {
        let url = OpenAIEndpoint.ollama().chatCompletionsURL
        #expect(url.absoluteString == "http://localhost:11434/v1/chat/completions")
    }

    @Test("Azure chat completions URL includes deployment and api-version")
    func azureChatCompletionsURL() {
        let endpoint = OpenAIEndpoint.azure(
            resource: "my-resource",
            deployment: "gpt4-deploy",
            apiVersion: "2024-02-15-preview"
        )
        let url = endpoint.chatCompletionsURL
        #expect(url.absoluteString.contains("deployments/gpt4-deploy/chat/completions"))
        #expect(url.absoluteString.contains("api-version=2024-02-15-preview"))
    }

    // MARK: - Responses URL

    @Test("OpenAI responses URL")
    func openAIResponsesURL() {
        let url = OpenAIEndpoint.openAI.responsesURL
        #expect(url.absoluteString == "https://api.openai.com/v1/responses")
    }

    @Test("Azure responses URL includes deployment and api-version")
    func azureResponsesURL() {
        let endpoint = OpenAIEndpoint.azure(
            resource: "res",
            deployment: "dep",
            apiVersion: "2024-02-15-preview"
        )
        let url = endpoint.responsesURL
        #expect(url.absoluteString.contains("deployments/dep/responses"))
        #expect(url.absoluteString.contains("api-version=2024-02-15-preview"))
    }

    // MARK: - Text Generation URL

    @Test("textGenerationURL returns chat completions for .chatCompletions variant")
    func textGenerationURLChatCompletions() {
        let url = OpenAIEndpoint.openAI.textGenerationURL(for: .chatCompletions)
        #expect(url == OpenAIEndpoint.openAI.chatCompletionsURL)
    }

    @Test("textGenerationURL returns responses for .responses variant")
    func textGenerationURLResponses() {
        let url = OpenAIEndpoint.openAI.textGenerationURL(for: .responses)
        #expect(url == OpenAIEndpoint.openAI.responsesURL)
    }

    // MARK: - Embeddings URL

    @Test("OpenAI embeddings URL")
    func openAIEmbeddingsURL() {
        let url = OpenAIEndpoint.openAI.embeddingsURL
        #expect(url.absoluteString == "https://api.openai.com/v1/embeddings")
    }

    @Test("Azure embeddings URL includes deployment and api-version")
    func azureEmbeddingsURL() {
        let endpoint = OpenAIEndpoint.azure(
            resource: "res",
            deployment: "embed-dep",
            apiVersion: "2024-02-15-preview"
        )
        let url = endpoint.embeddingsURL
        #expect(url.absoluteString.contains("deployments/embed-dep/embeddings"))
        #expect(url.absoluteString.contains("api-version=2024-02-15-preview"))
    }

    // MARK: - Images Generations URL

    @Test("Images generations URL appends correct path")
    func imagesGenerationsURL() {
        let url = OpenAIEndpoint.openAI.imagesGenerationsURL
        #expect(url.absoluteString == "https://api.openai.com/v1/images/generations")
    }

    // MARK: - Audio Transcriptions URL

    @Test("Audio transcriptions URL appends correct path")
    func audioTranscriptionsURL() {
        let url = OpenAIEndpoint.openAI.audioTranscriptionsURL
        #expect(url.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
    }

    // MARK: - isLocal

    @Test("Ollama is local")
    func ollamaIsLocal() {
        #expect(OpenAIEndpoint.ollama().isLocal)
    }

    @Test("OpenAI is not local")
    func openAIIsNotLocal() {
        #expect(!OpenAIEndpoint.openAI.isLocal)
    }

    @Test("OpenRouter is not local")
    func openRouterIsNotLocal() {
        #expect(!OpenAIEndpoint.openRouter.isLocal)
    }

    @Test("Azure is not local")
    func azureIsNotLocal() {
        #expect(!OpenAIEndpoint.azure(resource: "r", deployment: "d", apiVersion: "v").isLocal)
    }

    @Test("Custom is not local")
    func customIsNotLocal() {
        let url = URL(string: "https://custom.com")!
        #expect(!OpenAIEndpoint.custom(url).isLocal)
    }

    // MARK: - requiresAuthentication

    @Test("Ollama does not require authentication")
    func ollamaNoAuthRequired() {
        #expect(!OpenAIEndpoint.ollama().requiresAuthentication)
    }

    @Test("OpenAI requires authentication")
    func openAIRequiresAuth() {
        #expect(OpenAIEndpoint.openAI.requiresAuthentication)
    }

    @Test("OpenRouter requires authentication")
    func openRouterRequiresAuth() {
        #expect(OpenAIEndpoint.openRouter.requiresAuthentication)
    }

    @Test("Azure requires authentication")
    func azureRequiresAuth() {
        #expect(OpenAIEndpoint.azure(resource: "r", deployment: "d", apiVersion: "v").requiresAuthentication)
    }

    @Test("Custom requires authentication")
    func customRequiresAuth() {
        let url = URL(string: "https://custom.com")!
        #expect(OpenAIEndpoint.custom(url).requiresAuthentication)
    }

    // MARK: - Display Name

    @Test("OpenAI display name")
    func openAIDisplayName() {
        #expect(OpenAIEndpoint.openAI.displayName == "OpenAI")
    }

    @Test("OpenRouter display name")
    func openRouterDisplayName() {
        #expect(OpenAIEndpoint.openRouter.displayName == "OpenRouter")
    }

    @Test("Ollama default display name")
    func ollamaDefaultDisplayName() {
        #expect(OpenAIEndpoint.ollama().displayName == "Ollama (Local)")
    }

    @Test("Ollama custom host display name")
    func ollamaCustomDisplayName() {
        let endpoint = OpenAIEndpoint.ollama(host: "192.168.1.5", port: 8080)
        #expect(endpoint.displayName == "Ollama (192.168.1.5:8080)")
    }

    @Test("Azure display name includes resource")
    func azureDisplayName() {
        let endpoint = OpenAIEndpoint.azure(resource: "my-resource", deployment: "d", apiVersion: "v")
        #expect(endpoint.displayName == "Azure OpenAI (my-resource)")
    }

    @Test("Custom display name includes host")
    func customDisplayName() {
        let url = URL(string: "https://my-proxy.com/v1")!
        let endpoint = OpenAIEndpoint.custom(url)
        #expect(endpoint.displayName.contains("my-proxy.com"))
    }

    // MARK: - Description

    @Test("description matches displayName")
    func descriptionMatchesDisplayName() {
        #expect(OpenAIEndpoint.openAI.description == OpenAIEndpoint.openAI.displayName)
        #expect(OpenAIEndpoint.openRouter.description == OpenAIEndpoint.openRouter.displayName)
    }

    // MARK: - Convenience Initializers

    @Test("ollama(url:) parses host and port from URL")
    func ollamaFromURL() {
        let url = URL(string: "http://192.168.1.10:8080/v1")!
        let endpoint = OpenAIEndpoint.ollama(url: url)
        #expect(endpoint.baseURL.absoluteString.contains("192.168.1.10"))
        #expect(endpoint.baseURL.absoluteString.contains("8080"))
    }

    @Test("azure convenience initializer uses default API version")
    func azureConvenienceDefaultVersion() {
        let endpoint = OpenAIEndpoint.azure(resource: "res", deployment: "dep")
        if case .azure(_, _, let version) = endpoint {
            #expect(version == "2024-02-15-preview")
        } else {
            Issue.record("Expected azure endpoint")
        }
    }

    // MARK: - Validated Constructors

    @Test("ollamaValidated with valid values works")
    func ollamaValidatedValid() {
        let endpoint = OpenAIEndpoint.ollamaValidated(host: "myhost", port: 9090)
        if case .ollama(let host, let port) = endpoint {
            #expect(host == "myhost")
            #expect(port == 9090)
        } else {
            Issue.record("Expected ollama endpoint")
        }
    }

    @Test("ollamaValidated with empty host falls back to localhost")
    func ollamaValidatedEmptyHost() {
        let endpoint = OpenAIEndpoint.ollamaValidated(host: "", port: 11434)
        if case .ollama(let host, _) = endpoint {
            #expect(host == "localhost")
        } else {
            Issue.record("Expected ollama endpoint")
        }
    }

    @Test("ollamaValidated with invalid port falls back to 11434")
    func ollamaValidatedInvalidPort() {
        let endpoint = OpenAIEndpoint.ollamaValidated(host: "localhost", port: 99999)
        if case .ollama(_, let port) = endpoint {
            #expect(port == 11434)
        } else {
            Issue.record("Expected ollama endpoint")
        }
    }

    @Test("ollamaValidated with negative port falls back to 11434")
    func ollamaValidatedNegativePort() {
        let endpoint = OpenAIEndpoint.ollamaValidated(host: "localhost", port: -1)
        if case .ollama(_, let port) = endpoint {
            #expect(port == 11434)
        } else {
            Issue.record("Expected ollama endpoint")
        }
    }

    // MARK: - Validation

    @Test("validateOllamaConfig succeeds with valid values")
    func validateOllamaConfigValid() throws {
        try OpenAIEndpoint.validateOllamaConfig(host: "localhost", port: 11434)
    }

    @Test("validateOllamaConfig throws emptyHost for empty host")
    func validateOllamaConfigEmptyHost() {
        #expect(throws: OpenAIEndpoint.ValidationError.self) {
            try OpenAIEndpoint.validateOllamaConfig(host: "", port: 11434)
        }
    }

    @Test("validateOllamaConfig throws invalidPort for port 0")
    func validateOllamaConfigInvalidPortZero() {
        #expect(throws: OpenAIEndpoint.ValidationError.self) {
            try OpenAIEndpoint.validateOllamaConfig(host: "localhost", port: 0)
        }
    }

    @Test("validateOllamaConfig throws invalidPort for port above 65535")
    func validateOllamaConfigInvalidPortAbove() {
        #expect(throws: OpenAIEndpoint.ValidationError.self) {
            try OpenAIEndpoint.validateOllamaConfig(host: "localhost", port: 70000)
        }
    }

    @Test("ValidationError has localized descriptions")
    func validationErrorDescriptions() {
        let emptyHost = OpenAIEndpoint.ValidationError.emptyHost
        #expect(emptyHost.errorDescription?.contains("empty") == true)

        let invalidPort = OpenAIEndpoint.ValidationError.invalidPort(99999)
        #expect(invalidPort.errorDescription?.contains("99999") == true)
        #expect(invalidPort.errorDescription?.contains("65535") == true)
    }

    // MARK: - Ollama Host Sanitization

    @Test("Ollama sanitizes host by removing scheme prefixes")
    func ollamaSanitizesScheme() {
        let endpoint = OpenAIEndpoint.ollama(host: "http://myhost", port: 11434)
        #expect(endpoint.baseURL.host == "myhost")
    }

    @Test("Ollama sanitizes empty host to localhost")
    func ollamaSanitizesEmptyHost() {
        let endpoint = OpenAIEndpoint.ollama(host: "", port: 11434)
        #expect(endpoint.baseURL.host == "localhost")
    }

    @Test("Ollama clamps invalid port to default 11434")
    func ollamaClampsInvalidPort() {
        let endpoint = OpenAIEndpoint.ollama(host: "localhost", port: 99999)
        #expect(endpoint.baseURL.port == 11434)
    }

    // MARK: - Equatable / Hashable

    @Test("Same endpoints are equal")
    func sameEndpointsEqual() {
        #expect(OpenAIEndpoint.openAI == .openAI)
        #expect(OpenAIEndpoint.openRouter == .openRouter)
        #expect(OpenAIEndpoint.ollama() == .ollama())
    }

    @Test("Different endpoints are not equal")
    func differentEndpointsNotEqual() {
        #expect(OpenAIEndpoint.openAI != .openRouter)
        #expect(OpenAIEndpoint.openAI != .ollama())
    }

    @Test("Ollama endpoints with different hosts are not equal")
    func ollamaDifferentHosts() {
        #expect(OpenAIEndpoint.ollama(host: "a", port: 11434) != .ollama(host: "b", port: 11434))
    }

    @Test("Can be used in a Set")
    func hashableForSet() {
        var set: Set<OpenAIEndpoint> = []
        set.insert(.openAI)
        set.insert(.openRouter)
        set.insert(.openAI)
        #expect(set.count == 2)
    }

    // MARK: - Codable

    @Test("OpenAI endpoint round-trips through JSON")
    func codableOpenAI() throws {
        let original = OpenAIEndpoint.openAI
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: data)
        #expect(decoded == original)
    }

    @Test("OpenRouter endpoint round-trips through JSON")
    func codableOpenRouter() throws {
        let original = OpenAIEndpoint.openRouter
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: data)
        #expect(decoded == original)
    }

    @Test("Ollama endpoint round-trips through JSON")
    func codableOllama() throws {
        let original = OpenAIEndpoint.ollama(host: "192.168.1.5", port: 8080)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: data)
        #expect(decoded == original)
    }

    @Test("Azure endpoint round-trips through JSON")
    func codableAzure() throws {
        let original = OpenAIEndpoint.azure(
            resource: "my-resource",
            deployment: "gpt4",
            apiVersion: "2024-02-15-preview"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: data)
        #expect(decoded == original)
    }

    @Test("Custom endpoint round-trips through JSON")
    func codableCustom() throws {
        let url = URL(string: "https://custom-api.example.com/v1")!
        let original = OpenAIEndpoint.custom(url)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: data)
        #expect(decoded == original)
    }

    @Test("Ollama endpoint decodes with defaults when host/port missing")
    func codableOllamaDefaults() throws {
        let json = #"{"type":"ollama"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(OpenAIEndpoint.self, from: json)
        if case .ollama(let host, let port) = decoded {
            #expect(host == "localhost")
            #expect(port == 11434)
        } else {
            Issue.record("Expected ollama endpoint")
        }
    }

    // MARK: - Sendable

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let endpoint: Sendable = OpenAIEndpoint.openAI
        #expect(endpoint is OpenAIEndpoint)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
