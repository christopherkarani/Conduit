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
    public typealias ModelID = ModelIdentifier

    let configuration: MiniMaxConfiguration

    private let internalProvider: OpenAIProvider

    public init(apiKey: String? = nil) {
        self.init(configuration: .standard(apiKey: apiKey))
    }

    /// Creates a provider with explicit network tuning settings.
    public init(
        apiKey: String? = nil,
        baseURL: URL,
        timeout: TimeInterval = 120,
        maxRetries: Int = 3
    ) {
        self.init(
            configuration: MiniMaxConfiguration(
                authentication: apiKey.map(MiniMaxAuthentication.apiKey) ?? .auto,
                baseURL: baseURL,
                timeout: timeout,
                maxRetries: maxRetries
            )
        )
    }

    init(configuration: MiniMaxConfiguration) {
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
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        do {
            try validateModel(model)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        return internalProvider.stream(messages: messages, model: .openAI(model.rawValue), config: config)
    }

    public func generate(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> String {
        try validateModel(model)
        return try await internalProvider.generate(prompt, model: .openAI(model.rawValue), config: config)
    }

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        try validateModel(model)
        return try await internalProvider.generate(messages: messages, model: .openAI(model.rawValue), config: config)
    }

    public nonisolated func stream(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        do {
            try validateModel(model)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        return internalProvider.stream(prompt, model: .openAI(model.rawValue), config: config)
    }

    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        do {
            try validateModel(model)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        return internalProvider.streamWithMetadata(messages: messages, model: .openAI(model.rawValue), config: config)
    }

    private nonisolated func validateModel(_ model: ModelIdentifier) throws {
        guard model.provider == .minimax else {
            throw AIError.invalidInput("MiniMaxProvider only supports MiniMax model identifiers")
        }
    }
}

#endif // CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
