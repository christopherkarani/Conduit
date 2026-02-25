// OpenAIModelIDTests.swift
// Conduit Tests
//
// Tests for OpenAIModelID including static models, helpers, and protocol conformances.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("OpenAIModelID Tests")
struct OpenAIModelIDTests {

    // MARK: - Initialization

    @Test("Init from string stores raw value")
    func initFromString() {
        let model = OpenAIModelID("gpt-4o")
        #expect(model.rawValue == "gpt-4o")
    }

    @Test("Init from rawValue stores raw value")
    func initFromRawValue() {
        let model = OpenAIModelID(rawValue: "gpt-4-turbo")
        #expect(model.rawValue == "gpt-4-turbo")
    }

    @Test("String literal initialization")
    func stringLiteralInit() {
        let model: OpenAIModelID = "gpt-3.5-turbo"
        #expect(model.rawValue == "gpt-3.5-turbo")
    }

    // MARK: - Provider Type

    @Test("All OpenAI model IDs have .openAI provider type")
    func providerTypeIsOpenAI() {
        #expect(OpenAIModelID.gpt4o.provider == .openAI)
        #expect(OpenAIModelID.gpt4oMini.provider == .openAI)
        #expect(OpenAIModelID("custom-model").provider == .openAI)
    }

    // MARK: - Display Name

    @Test("Display name for simple model returns raw value")
    func displayNameSimple() {
        #expect(OpenAIModelID.gpt4o.displayName == "gpt-4o")
    }

    @Test("Display name extracts model from provider-prefixed format")
    func displayNameProviderPrefixed() {
        let model = OpenAIModelID("openai/gpt-4-turbo")
        #expect(model.displayName == "gpt-4-turbo")
    }

    @Test("Display name for Ollama format preserves tag")
    func displayNameOllamaFormat() {
        let model = OpenAIModelID("llama3.2:3b")
        #expect(model.displayName == "llama3.2:3b")
    }

    // MARK: - Description

    @Test("Description includes OpenAI-Compatible prefix")
    func descriptionFormat() {
        let model = OpenAIModelID.gpt4o
        #expect(model.description == "[OpenAI-Compatible] gpt-4o")
    }

    // MARK: - Static OpenAI Models

    @Test("GPT-4 series static models have correct raw values")
    func gpt4SeriesRawValues() {
        #expect(OpenAIModelID.gpt4o.rawValue == "gpt-4o")
        #expect(OpenAIModelID.gpt4oMini.rawValue == "gpt-4o-mini")
        #expect(OpenAIModelID.gpt4Turbo.rawValue == "gpt-4-turbo")
        #expect(OpenAIModelID.gpt4.rawValue == "gpt-4")
    }

    @Test("GPT-3.5 static model has correct raw value")
    func gpt35RawValue() {
        #expect(OpenAIModelID.gpt35Turbo.rawValue == "gpt-3.5-turbo")
    }

    @Test("Reasoning models have correct raw values")
    func reasoningModelsRawValues() {
        #expect(OpenAIModelID.o1.rawValue == "o1")
        #expect(OpenAIModelID.o1Mini.rawValue == "o1-mini")
        #expect(OpenAIModelID.o3Mini.rawValue == "o3-mini")
    }

    @Test("Embedding models have correct raw values")
    func embeddingModelsRawValues() {
        #expect(OpenAIModelID.textEmbedding3Small.rawValue == "text-embedding-3-small")
        #expect(OpenAIModelID.textEmbedding3Large.rawValue == "text-embedding-3-large")
        #expect(OpenAIModelID.textEmbeddingAda002.rawValue == "text-embedding-ada-002")
    }

    @Test("Image models have correct raw values")
    func imageModelsRawValues() {
        #expect(OpenAIModelID.dallE3.rawValue == "dall-e-3")
        #expect(OpenAIModelID.dallE2.rawValue == "dall-e-2")
    }

    @Test("Audio models have correct raw values")
    func audioModelsRawValues() {
        #expect(OpenAIModelID.whisper1.rawValue == "whisper-1")
        #expect(OpenAIModelID.tts1.rawValue == "tts-1")
        #expect(OpenAIModelID.tts1HD.rawValue == "tts-1-hd")
    }

    // MARK: - OpenRouter Helpers

    @Test("openRouter helper creates model ID from string")
    func openRouterHelper() {
        let model = OpenAIModelID.openRouter("anthropic/claude-3-opus")
        #expect(model.rawValue == "anthropic/claude-3-opus")
    }

    @Test("OpenRouter static models have correct raw values")
    func openRouterStaticModels() {
        #expect(OpenAIModelID.claudeOpus.rawValue == "anthropic/claude-3-opus")
        #expect(OpenAIModelID.claudeSonnet.rawValue == "anthropic/claude-3-sonnet")
        #expect(OpenAIModelID.claudeHaiku.rawValue == "anthropic/claude-3-haiku")
        #expect(OpenAIModelID.geminiPro.rawValue == "google/gemini-pro")
        #expect(OpenAIModelID.geminiPro15.rawValue == "google/gemini-pro-1.5")
        #expect(OpenAIModelID.mixtral8x7B.rawValue == "mistralai/mixtral-8x7b-instruct")
        #expect(OpenAIModelID.llama31B70B.rawValue == "meta-llama/llama-3.1-70b-instruct")
        #expect(OpenAIModelID.llama31B8B.rawValue == "meta-llama/llama-3.1-8b-instruct")
    }

    @Test("OpenRouter model display names extract model name from prefix")
    func openRouterDisplayNames() {
        #expect(OpenAIModelID.claudeOpus.displayName == "claude-3-opus")
        #expect(OpenAIModelID.geminiPro.displayName == "gemini-pro")
    }

    // MARK: - Ollama Helpers

    @Test("ollama helper creates model ID from string")
    func ollamaHelper() {
        let model = OpenAIModelID.ollama("llama3.2:3b")
        #expect(model.rawValue == "llama3.2:3b")
    }

    @Test("Ollama static models have correct raw values")
    func ollamaStaticModels() {
        #expect(OpenAIModelID.ollamaLlama32.rawValue == "llama3.2")
        #expect(OpenAIModelID.ollamaLlama32B3B.rawValue == "llama3.2:3b")
        #expect(OpenAIModelID.ollamaLlama32B1B.rawValue == "llama3.2:1b")
        #expect(OpenAIModelID.ollamaMistral.rawValue == "mistral")
        #expect(OpenAIModelID.ollamaCodeLlama.rawValue == "codellama")
        #expect(OpenAIModelID.ollamaPhi3.rawValue == "phi3")
        #expect(OpenAIModelID.ollamaGemma2.rawValue == "gemma2")
        #expect(OpenAIModelID.ollamaQwen25.rawValue == "qwen2.5")
        #expect(OpenAIModelID.ollamaDeepseekCoder.rawValue == "deepseek-coder")
        #expect(OpenAIModelID.ollamaNomicEmbed.rawValue == "nomic-embed-text")
    }

    // MARK: - Azure Helpers

    @Test("azure deployment helper creates model ID from string")
    func azureHelper() {
        let model = OpenAIModelID.azure(deployment: "my-gpt4-deployment")
        #expect(model.rawValue == "my-gpt4-deployment")
    }

    // MARK: - Equatable / Hashable

    @Test("Same raw values are equal")
    func sameRawValuesEqual() {
        let a = OpenAIModelID("gpt-4o")
        let b = OpenAIModelID("gpt-4o")
        #expect(a == b)
    }

    @Test("Different raw values are not equal")
    func differentRawValuesNotEqual() {
        let a = OpenAIModelID("gpt-4o")
        let b = OpenAIModelID("gpt-4")
        #expect(a != b)
    }

    @Test("Can be used in a Set")
    func usableInSet() {
        let set: Set<OpenAIModelID> = [.gpt4o, .gpt4oMini, .gpt4o]
        #expect(set.count == 2)
    }

    @Test("Can be used as dictionary key")
    func usableAsDictKey() {
        var dict: [OpenAIModelID: String] = [:]
        dict[.gpt4o] = "latest"
        dict[.gpt4] = "legacy"
        #expect(dict[.gpt4o] == "latest")
        #expect(dict[.gpt4] == "legacy")
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves raw value")
    func codableRoundTrip() throws {
        let original = OpenAIModelID.gpt4o
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OpenAIModelID.self, from: data)
        #expect(decoded == original)
        #expect(decoded.rawValue == "gpt-4o")
    }

    @Test("Decodes from plain string JSON")
    func decodesFromPlainString() throws {
        let json = Data(#""gpt-4-turbo""#.utf8)
        let decoded = try JSONDecoder().decode(OpenAIModelID.self, from: json)
        #expect(decoded.rawValue == "gpt-4-turbo")
    }

    @Test("Encodes to plain string JSON")
    func encodesToPlainString() throws {
        let model = OpenAIModelID.gpt4oMini
        let data = try JSONEncoder().encode(model)
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString == #""gpt-4o-mini""#)
    }

    // MARK: - Sendable

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let model: Sendable = OpenAIModelID.gpt4o
        #expect(model is OpenAIModelID)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
