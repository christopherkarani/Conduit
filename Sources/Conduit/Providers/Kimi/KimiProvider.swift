// KimiProvider.swift
// Conduit
//
// Actor-based provider for Moonshot Kimi API.

#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - KimiProvider

/// A provider for Moonshot Kimi models.
///
/// `KimiProvider` provides unified access to Moonshot's Kimi API,
/// featuring models with 256K context windows and strong reasoning.
///
/// ## Usage
///
/// ### Simple
/// ```swift
/// let provider = KimiProvider(apiKey: "sk-moonshot-...")
/// let response = try await provider.generate("Hello", model: .kimiK2_5)
/// ```
///
/// ### With Configuration
/// ```swift
/// let config = KimiConfiguration.standard(apiKey: "sk-moonshot-...")
///     .timeout(180)
/// let provider = KimiProvider(configuration: config)
/// ```
///
/// ## Features
///
/// - **256K Context**: All Kimi models support 256K token context
/// - **Streaming**: Server-Sent Events (SSE) streaming support
/// - **Cancellation**: Full support for task cancellation
///
/// ## Authentication
///
/// Set the `MOONSHOT_API_KEY` environment variable or pass an API key explicitly.
public actor KimiProvider: AIProvider, TextGenerator {

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    // MARK: - Properties

    let configuration: KimiConfiguration

    /// Internal OpenAI-compatible provider for request handling.
    private let internalProvider: OpenAIProvider

    // MARK: - Initialization

    /// Creates a provider with an API key.
    ///
    /// - Parameter apiKey: Your Moonshot API key (starts with "sk-moonshot-")
    public init(apiKey: String) {
        self.init(configuration: .standard(apiKey: apiKey))
    }

    /// Creates a provider with explicit network tuning settings.
    public init(
        apiKey: String,
        baseURL: URL,
        timeout: TimeInterval = 120,
        maxRetries: Int = 3
    ) {
        self.init(
            configuration: KimiConfiguration(
                authentication: .apiKey(apiKey),
                baseURL: baseURL,
                timeout: timeout,
                maxRetries: maxRetries
            )
        )
    }

    /// Creates a provider with a full configuration.
    ///
    /// - Parameter configuration: The provider configuration.
    init(configuration: KimiConfiguration) {
        self.configuration = configuration

        // Create OpenAI-compatible internal configuration
        let openAIConfig = OpenAIConfiguration(
            endpoint: .custom(configuration.baseURL),
            authentication: .bearer(configuration.authentication.apiKey ?? ""),
            timeout: configuration.timeout,
            maxRetries: configuration.maxRetries
        )
        self.internalProvider = OpenAIProvider(configuration: openAIConfig)
    }

    // MARK: - AIProvider Protocol

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

    // MARK: - AIProvider Streaming (nonisolated)

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
        internalProvider.stream(messages: messages, model: .openAI(model.rawValue), config: config)
    }

    // MARK: - TextGenerator Protocol

    public func generate(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> String {
        try validateModel(model)
        try await internalProvider.generate(prompt, model: .openAI(model.rawValue), config: config)
    }

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        try validateModel(model)
        try await internalProvider.generate(messages: messages, model: .openAI(model.rawValue), config: config)
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
        internalProvider.stream(prompt, model: .openAI(model.rawValue), config: config)
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
        internalProvider.streamWithMetadata(messages: messages, model: .openAI(model.rawValue), config: config)
    }

    private nonisolated func validateModel(_ model: ModelIdentifier) throws {
        guard model.provider == .kimi else {
            throw AIError.invalidInput("KimiProvider only supports Kimi model identifiers")
        }
    }
}

#endif // CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
