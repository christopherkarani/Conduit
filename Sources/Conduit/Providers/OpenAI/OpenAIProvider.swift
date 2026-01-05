// OpenAIProvider.swift
// Conduit
//
// OpenAI-compatible provider actor for text generation, embeddings, and more.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIProvider

/// A provider for OpenAI-compatible APIs.
///
/// `OpenAIProvider` provides unified access to multiple OpenAI-compatible backends:
/// - **OpenAI**: Official OpenAI API (GPT-4, DALL-E, Whisper)
/// - **OpenRouter**: Aggregator with access to multiple providers
/// - **Ollama**: Local inference server
/// - **Azure OpenAI**: Microsoft's enterprise OpenAI service
/// - **Custom**: Any OpenAI-compatible endpoint
///
/// ## Progressive Disclosure
///
/// ### Level 1: Simple
/// ```swift
/// let provider = OpenAIProvider(apiKey: "sk-...")
/// let response = try await provider.generate("Hello", model: .gpt4o)
/// ```
///
/// ### Level 2: Standard
/// ```swift
/// let provider = OpenAIProvider(endpoint: .openRouter, apiKey: "or-...")
/// let response = try await provider.generate(
///     messages: [.user("Hello")],
///     model: .openRouter("anthropic/claude-3-opus")
/// )
/// ```
///
/// ### Level 3: Expert
/// ```swift
/// let config = OpenAIConfiguration(
///     endpoint: .openRouter,
///     authentication: .bearer("or-..."),
///     timeout: 120,
///     openRouterConfig: OpenRouterRoutingConfig(
///         providers: [.anthropic],
///         fallbacks: true
///     )
/// )
/// let provider = OpenAIProvider(configuration: config)
/// ```
///
/// ## Thread Safety
///
/// `OpenAIProvider` is an actor, ensuring thread-safe access to all methods.
/// It can be safely shared across concurrent tasks.
///
/// ## Protocol Conformances
///
/// - `AIProvider`: Core provider protocol
/// - `TextGenerator`: Text generation capabilities
/// - `EmbeddingGenerator`: Embedding generation
/// - `TokenCounter`: Token counting (estimated)
/// - `ImageGenerator`: Image generation with DALL-E
///
/// ## Cancellation
///
/// All async methods support Swift's structured concurrency cancellation.
/// Use `cancelGeneration()` for explicit cancellation control.
public actor OpenAIProvider: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter, ImageGenerator {

    // MARK: - Type Aliases

    /// The response type for non-streaming generation.
    public typealias Response = GenerationResult

    /// The chunk type for streaming generation.
    public typealias StreamChunk = GenerationChunk

    /// The model identifier type for this provider.
    public typealias ModelID = OpenAIModelID

    // MARK: - Properties

    /// The configuration for this provider.
    public let configuration: OpenAIConfiguration

    /// The URLSession used for HTTP requests.
    internal let session: URLSession

    /// Active generation task for cancellation.
    private var activeTask: Task<Void, Never>?

    /// JSON encoder for request bodies.
    internal let encoder: JSONEncoder

    /// JSON decoder for response bodies.
    internal let decoder: JSONDecoder

    /// Active image generation task for cancellation.
    private var activeImageTask: Task<GeneratedImage, Error>?

    // MARK: - Initialization

    /// Creates a provider with a full configuration.
    ///
    /// - Parameter configuration: The provider configuration.
    public init(configuration: OpenAIConfiguration) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.session = URLSession(configuration: sessionConfig)

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Creates a provider for OpenAI with an API key.
    ///
    /// This is the simplest way to create an OpenAI provider.
    ///
    /// ```swift
    /// let provider = OpenAIProvider(apiKey: "sk-...")
    /// ```
    ///
    /// - Parameter apiKey: Your OpenAI API key.
    public init(apiKey: String) {
        self.init(configuration: .openAI(apiKey: apiKey))
    }

    /// Creates a provider for a specific endpoint with an API key.
    ///
    /// ```swift
    /// let provider = OpenAIProvider(endpoint: .openRouter, apiKey: "or-...")
    /// ```
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint to use.
    ///   - apiKey: The API key (optional for Ollama).
    public init(endpoint: OpenAIEndpoint, apiKey: String? = nil) {
        let auth = OpenAIAuthentication.for(endpoint: endpoint, apiKey: apiKey)
        self.init(configuration: OpenAIConfiguration(endpoint: endpoint, authentication: auth))
    }

    // MARK: - AIProvider Protocol

    /// Whether this provider is currently available.
    public var isAvailable: Bool {
        get async {
            // Check authentication
            guard configuration.hasValidAuthentication else {
                return false
            }

            // For Ollama, check server health
            if case .ollama = configuration.endpoint {
                if let ollamaConfig = configuration.ollamaConfig, ollamaConfig.healthCheck {
                    return await checkOllamaHealth()
                }
            }

            return true
        }
    }

    /// Detailed availability status.
    public var availabilityStatus: ProviderAvailability {
        get async {
            // Check authentication
            guard configuration.hasValidAuthentication else {
                return .unavailable(.apiKeyMissing)
            }

            // For Ollama, check server health
            if case .ollama = configuration.endpoint {
                if let ollamaConfig = configuration.ollamaConfig, ollamaConfig.healthCheck {
                    let healthy = await checkOllamaHealth()
                    if !healthy {
                        return .unavailable(.noNetwork)
                    }
                }
            }

            return .available
        }
    }

    /// Cancels any in-flight generation.
    public func cancelGeneration() async {
        activeTask?.cancel()
        activeTask = nil
        // Also cancel image generation
        activeImageTask?.cancel()
        activeImageTask = nil
    }

    // MARK: - TextGenerator Protocol

    /// Generates text from a simple string prompt.
    public func generate(
        _ prompt: String,
        model: OpenAIModelID,
        config: GenerateConfig
    ) async throws -> String {
        let messages = [Message.user(prompt)]
        let result = try await generate(messages: messages, model: model, config: config)
        return result.text
    }

    /// Generates text from a conversation.
    public func generate(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        try await performGeneration(messages: messages, model: model, config: config, stream: false)
    }

    // MARK: - TokenCounter Protocol

    /// Counts tokens in text (estimated).
    ///
    /// - Important: This method uses a rough estimate of approximately 4 characters per token,
    ///   which may be inaccurate for:
    ///   - Non-English text (typically uses more tokens)
    ///   - Code or technical content (variable token density)
    ///   - Text with many special characters or unicode
    ///   - Structured data formats (JSON, XML, etc.)
    ///
    /// For accurate token counting, consider:
    /// - Using OpenAI's `tiktoken` library for client-side counting
    /// - Calling the token counting API endpoint directly
    /// - Testing with your specific content and model to calibrate estimates
    ///
    /// - Parameters:
    ///   - text: The text to count tokens for.
    ///   - model: The model identifier (used for future model-specific counting).
    /// - Returns: An estimated token count.
    /// - Note: Estimates assume English prose. Actual counts may vary by ±50% or more.
    public func countTokens(
        in text: String,
        for model: OpenAIModelID
    ) async throws -> TokenCount {
        // Use a simple estimation: ~4 characters per token
        let estimatedTokens = max(1, text.count / 4)
        return TokenCount(count: estimatedTokens, isEstimate: true)
    }

    /// Counts tokens in messages (estimated).
    ///
    /// - Important: This method uses a rough estimate of approximately 4 characters per token,
    ///   plus 4 tokens of overhead per message, which may be inaccurate for:
    ///   - Non-English text (typically uses more tokens)
    ///   - Code or technical content (variable token density)
    ///   - Text with many special characters or unicode
    ///   - Structured data formats (JSON, XML, etc.)
    ///
    /// For accurate token counting, consider:
    /// - Using OpenAI's `tiktoken` library for client-side counting
    /// - Calling the token counting API endpoint directly
    /// - Testing with your specific content and model to calibrate estimates
    ///
    /// - Parameters:
    ///   - messages: The messages to count tokens for.
    ///   - model: The model identifier (used for future model-specific counting).
    /// - Returns: An estimated total token count including message overhead.
    /// - Note: Estimates assume English prose and include per-message formatting overhead.
    ///   Actual counts may vary by ±50% or more depending on content characteristics.
    public func countTokens(
        in messages: [Message],
        for model: OpenAIModelID
    ) async throws -> TokenCount {
        // Estimate tokens for each message plus overhead
        var totalTokens = 0
        for message in messages {
            let textTokens = max(1, message.content.textValue.count / 4)
            totalTokens += textTokens + 4  // 4 tokens overhead per message
        }
        return TokenCount(count: totalTokens, isEstimate: true)
    }

    /// Encodes text to tokens (not supported - throws error).
    public func encode(_ text: String, for model: OpenAIModelID) async throws -> [Int] {
        throw AIError.providerUnavailable(reason: .unknown("Token encoding not supported for OpenAI provider"))
    }

    /// Decodes tokens to text (not supported - throws error).
    public func decode(_ tokens: [Int], for model: OpenAIModelID, skipSpecialTokens: Bool) async throws -> String {
        throw AIError.providerUnavailable(reason: .unknown("Token decoding not supported for OpenAI provider"))
    }

    // MARK: - Capabilities

    /// The capabilities available for this provider.
    public var capabilities: OpenAICapabilities {
        get async {
            configuration.endpoint.defaultCapabilities
        }
    }
}
