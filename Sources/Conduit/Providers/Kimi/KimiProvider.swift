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
    public typealias ModelID = KimiModelID

    // MARK: - Properties

    public let configuration: KimiConfiguration

    /// Internal OpenAI-compatible provider for request handling.
    private let internalProvider: OpenAIProvider

    // MARK: - Initialization

    /// Creates a provider with an API key.
    ///
    /// - Parameter apiKey: Your Moonshot API key (starts with "sk-moonshot-")
    public init(apiKey: String) {
        self.init(configuration: .standard(apiKey: apiKey))
    }

    /// Creates a provider with a full configuration.
    ///
    /// - Parameter configuration: The provider configuration.
    public init(configuration: KimiConfiguration) {
        self.configuration = configuration

        // Create OpenAI-compatible internal configuration
        let openAIConfig = OpenAIConfiguration(
            endpoint: .custom(configuration.baseURL),
            authentication: .bearer(configuration.authentication.apiKey ?? ""),
            timeout: configuration.timeout
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
        model: KimiModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        internalProvider.stream(messages: messages, model: OpenAIModelID(model.rawValue), config: config)
    }

    // MARK: - TextGenerator Protocol

    public func generate(
        _ prompt: String,
        model: KimiModelID,
        config: GenerateConfig
    ) async throws -> String {
        try await internalProvider.generate(prompt, model: OpenAIModelID(model.rawValue), config: config)
    }

    public func generate(
        messages: [Message],
        model: KimiModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        try await internalProvider.generate(messages: messages, model: OpenAIModelID(model.rawValue), config: config)
    }

    public nonisolated func stream(
        _ prompt: String,
        model: KimiModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        internalProvider.stream(prompt, model: OpenAIModelID(model.rawValue), config: config)
    }

    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: KimiModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        internalProvider.streamWithMetadata(messages: messages, model: OpenAIModelID(model.rawValue), config: config)
    }
}

#endif // CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
