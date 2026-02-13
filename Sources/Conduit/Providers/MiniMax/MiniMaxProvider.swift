// MiniMaxProvider.swift
// Conduit
//
// Actor-based provider for MiniMax API.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor MiniMaxProvider: AIProvider, TextGenerator {

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = MiniMaxModelID

    public let configuration: MiniMaxConfiguration

    private let internalProvider: OpenAIProvider

    public init(apiKey: String) {
        self.init(configuration: .standard(apiKey: apiKey))
    }

    public init(configuration: MiniMaxConfiguration) {
        self.configuration = configuration

        let openAIConfig = OpenAIConfiguration(
            endpoint: .custom(configuration.baseURL),
            authentication: .bearer(configuration.authentication.apiKey ?? ""),
            timeout: configuration.timeout,
            maxRetries: configuration.maxRetries
        )
        self.internalProvider = OpenAIProvider(configuration: openAIConfig)
    }

    public var isAvailable: Bool {
        get async {
            configuration.hasValidAuthentication
        }
    }

    public var availabilityStatus: ProviderAvailability {
        get async {
            guard configuration.hasValidAuthentication else {
                return .unavailable(.apiKeyMissing)
            }
            return .available
        }
    }

    public func cancelGeneration() async {
        await internalProvider.cancelGeneration()
    }

    public nonisolated func stream(
        messages: [Message],
        model: MiniMaxModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        internalProvider.stream(messages: messages, model: OpenAIModelID(model.rawValue), config: config)
    }

    public func generate(
        _ prompt: String,
        model: MiniMaxModelID,
        config: GenerateConfig
    ) async throws -> String {
        try await internalProvider.generate(prompt, model: OpenAIModelID(model.rawValue), config: config)
    }

    public func generate(
        messages: [Message],
        model: MiniMaxModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        try await internalProvider.generate(messages: messages, model: OpenAIModelID(model.rawValue), config: config)
    }

    public nonisolated func stream(
        _ prompt: String,
        model: MiniMaxModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        internalProvider.stream(prompt, model: OpenAIModelID(model.rawValue), config: config)
    }

    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: MiniMaxModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        internalProvider.streamWithMetadata(messages: messages, model: OpenAIModelID(model.rawValue), config: config)
    }
}

#endif // CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
