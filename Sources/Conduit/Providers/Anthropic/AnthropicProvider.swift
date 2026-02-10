// AnthropicProvider.swift
// Conduit
//
// Actor-based provider for Anthropic Claude API.

#if CONDUIT_TRAIT_ANTHROPIC
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - AnthropicProvider

/// A provider for Anthropic Claude models.
///
/// `AnthropicProvider` provides unified access to Anthropic's Claude API,
/// supporting the full family of Claude 3, 3.5, and 4 models with streaming,
/// vision, and extended thinking capabilities.
///
/// ## Progressive Disclosure
///
/// ### Level 1: Simple (One-liner)
/// ```swift
/// let provider = AnthropicProvider(apiKey: "sk-ant-...")
/// let response = try await provider.generate("Hello", model: .claudeOpus45)
/// ```
///
/// ### Level 2: Standard
/// ```swift
/// let provider = AnthropicProvider(apiKey: "sk-ant-...")
/// let response = try await provider.generate(
///     messages: [.user("Hello")],
///     model: .claudeSonnet45,
///     config: .default
/// )
/// ```
///
/// ### Level 3: Expert (Full Control)
/// ```swift
/// let config = try AnthropicConfiguration(
///     authentication: .apiKey("sk-ant-..."),
///     timeout: 120,
///     maxRetries: 5,
///     supportsExtendedThinking: true
/// )
/// let provider = AnthropicProvider(configuration: config)
/// ```
///
/// ## Thread Safety
///
/// `AnthropicProvider` is an actor, ensuring thread-safe access to all methods.
/// It can be safely shared across concurrent tasks without risk of data races.
///
/// ## Protocol Conformances
///
/// - `AIProvider`: Core provider protocol with availability checking
/// - `TextGenerator`: Text generation with streaming support
/// - `Sendable`: Thread-safe across concurrency boundaries
///
/// ## Features
///
/// - **Streaming**: Server-Sent Events (SSE) streaming support
/// - **Vision**: Claude 3+ models support image inputs
/// - **Extended Thinking**: Advanced reasoning mode for complex tasks
/// - **Cancellation**: Full support for task cancellation
/// - **Retry Logic**: Automatic retry with exponential backoff
///
/// ## Error Handling
///
/// All async methods can throw `AIError` variants:
/// - `.authenticationFailed`: Invalid or missing API key
/// - `.rateLimited`: Rate limit exceeded (includes retry-after)
/// - `.serverError`: Anthropic API error (includes status code)
/// - `.networkError`: Network connectivity issues
/// - `.generationFailed`: Generation encountered an error
///
/// ## Availability
///
/// The provider is available when:
/// - Valid API key is configured
/// - Network connectivity is available
///
/// Check availability with:
/// ```swift
/// let provider = AnthropicProvider(apiKey: "sk-ant-...")
/// if await provider.isAvailable {
///     // Ready to generate
/// }
/// ```
///
/// ## Cancellation
///
/// Support for both explicit and structured cancellation:
/// ```swift
/// // Structured cancellation
/// let task = Task {
///     try await provider.generate("Long request", model: .claudeOpus45)
/// }
/// task.cancel()
///
/// // Explicit cancellation
/// await provider.cancelGeneration()
/// ```
///
/// - Note: This provider is part of Conduit's unified abstraction layer,
///   providing consistent API access across MLX, HuggingFace, OpenAI, and
///   Anthropic backends.
public actor AnthropicProvider: AIProvider, TextGenerator {

    // MARK: - Type Aliases

    /// The response type for non-streaming generation.
    public typealias Response = GenerationResult

    /// The chunk type for streaming generation.
    public typealias StreamChunk = GenerationChunk

    /// The model identifier type for this provider.
    public typealias ModelID = AnthropicModelID

    // MARK: - Properties

    /// The configuration for this provider.
    ///
    /// Contains authentication, endpoint configuration, timeout settings,
    /// retry policy, and feature flags.
    public let configuration: AnthropicConfiguration

    /// The URLSession used for HTTP requests.
    ///
    /// Configured with timeout and resource limits from the configuration.
    internal let session: URLSession

    /// JSON encoder for request bodies.
    ///
    /// Used to serialize `AnthropicRequest` to JSON for API calls.
    internal let encoder: JSONEncoder

    /// JSON decoder for response bodies.
    ///
    /// Used to deserialize `AnthropicResponse` and `AnthropicError` from JSON.
    internal let decoder: JSONDecoder

    /// Active generation task for explicit cancellation.
    ///
    /// Tracks the current generation task to support `cancelGeneration()`.
    /// Set to `nil` when no generation is in progress.
    private var activeTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a provider with a simple API key.
    ///
    /// This is the simplest way to create an Anthropic provider.
    /// Uses standard configuration with default settings.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// let response = try await provider.generate("Hello", model: .claudeOpus45)
    /// ```
    ///
    /// - Parameter apiKey: Your Anthropic API key (starts with "sk-ant-").
    ///
    /// - Note: For advanced configuration (custom timeouts, retries, etc.),
    ///   use `init(configuration:)` instead.
    public init(apiKey: String) {
        self.init(configuration: .standard(apiKey: apiKey))
    }

    /// Creates a provider with a full configuration.
    ///
    /// This initializer provides complete control over provider behavior,
    /// including authentication, network settings, and feature flags.
    ///
    /// ## Usage
    /// ```swift
    /// let config = try AnthropicConfiguration(
    ///     authentication: .apiKey("sk-ant-..."),
    ///     timeout: 120,
    ///     maxRetries: 5,
    ///     supportsExtendedThinking: true
    /// )
    /// let provider = AnthropicProvider(configuration: config)
    /// ```
    ///
    /// ## Configuration Options
    ///
    /// - **authentication**: API key or environment variable
    /// - **baseURL**: Custom API endpoint (for proxies)
    /// - **apiVersion**: Anthropic API version string
    /// - **timeout**: Request timeout in seconds
    /// - **maxRetries**: Retry attempts for failed requests
    /// - **supportsStreaming**: Enable SSE streaming
    /// - **supportsVision**: Enable image inputs
    /// - **supportsExtendedThinking**: Enable extended thinking mode
    ///
    /// - Parameter configuration: The provider configuration.
    public init(configuration: AnthropicConfiguration) {
        self.configuration = configuration

        // Configure URLSession with timeout settings
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.session = URLSession(configuration: sessionConfig)

        // Set up JSON encoding/decoding
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - AIProvider Protocol

    /// Whether this provider is currently available.
    ///
    /// Returns `true` if the provider has valid authentication configured.
    /// For cloud providers like Anthropic, this is a quick check that doesn't
    /// make network requests.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// if await provider.isAvailable {
    ///     let response = try await provider.generate("Hello", model: .claudeOpus45)
    /// } else {
    ///     print("Provider not available - check API key")
    /// }
    /// ```
    ///
    /// - Note: This is a lightweight check. For detailed diagnostics,
    ///   use `availabilityStatus` instead.
    public var isAvailable: Bool {
        get async {
            configuration.hasValidAuthentication
        }
    }

    /// Detailed availability status with reason if unavailable.
    ///
    /// Provides comprehensive information about the provider's availability,
    /// including the specific reason if unavailable and recommended actions.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// let status = await provider.availabilityStatus
    ///
    /// if status.isAvailable {
    ///     // Ready to generate
    /// } else if let reason = status.unavailableReason {
    ///     switch reason {
    ///     case .apiKeyMissing:
    ///         print("Please configure your Anthropic API key")
    ///     case .noNetwork:
    ///         print("Network connection required")
    ///     default:
    ///         print("Provider unavailable: \(reason)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Availability Reasons
    ///
    /// The provider may be unavailable due to:
    /// - `.apiKeyMissing`: No API key configured
    /// - `.noNetwork`: Network connectivity required but unavailable
    /// - `.unknown`: Other configuration issues
    ///
    /// - Returns: A `ProviderAvailability` struct with detailed status.
    public var availabilityStatus: ProviderAvailability {
        get async {
            guard configuration.hasValidAuthentication else {
                return .unavailable(.apiKeyMissing)
            }

            return .available
        }
    }

    /// Cancels any in-flight generation request.
    ///
    /// Attempts to immediately stop any ongoing generation operation and
    /// clean up resources. This method is safe to call even when no
    /// generation is in progress.
    ///
    /// ## Usage
    /// ```swift
    /// // Start a long-running generation
    /// Task {
    ///     try await provider.generate("Complex request", model: .claudeOpus45)
    /// }
    ///
    /// // Cancel from another context
    /// await provider.cancelGeneration()
    /// ```
    ///
    /// ## Behavior
    ///
    /// - Returns immediately (non-blocking)
    /// - Safe to call multiple times
    /// - Cleans up active task references
    ///
    /// ## Relationship to Task Cancellation
    ///
    /// This method provides explicit cancellation that works alongside
    /// Swift's structured concurrency:
    ///
    /// ```swift
    /// // Task cancellation (automatic)
    /// let task = Task {
    ///     try await provider.generate(...)
    /// }
    /// task.cancel() // Triggers CancellationError
    ///
    /// // Explicit cancellation (manual control)
    /// await provider.cancelGeneration()
    /// ```
    ///
    /// - Note: After calling this method, pending `generate()` or `stream()`
    ///   calls should throw `CancellationError` or complete with partial results.
    public func cancelGeneration() async {
        activeTask?.cancel()
        activeTask = nil
    }

    // MARK: - TextGenerator Protocol

    /// Generates text from a simple string prompt.
    ///
    /// This is the simplest form of text generation, suitable for single-turn
    /// interactions without conversation history.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// let response = try await provider.generate(
    ///     "Explain quantum computing in simple terms",
    ///     model: .claudeSonnet45,
    ///     config: .default
    /// )
    /// print(response) // "Quantum computing is..."
    /// ```
    ///
    /// ## Implementation
    ///
    /// This convenience method:
    /// 1. Wraps the prompt in a user message
    /// 2. Calls the full `generate(messages:model:config:)` method
    /// 3. Extracts and returns just the text from the result
    ///
    /// For access to metadata (token counts, timing, etc.), use
    /// `generate(messages:model:config:)` instead.
    ///
    /// - Parameters:
    ///   - prompt: The input text to generate a response for.
    ///   - model: The Claude model to use (e.g., `.claudeOpus45`).
    ///   - config: Configuration parameters (temperature, max tokens, etc.).
    ///
    /// - Returns: The generated text response as a string.
    ///
    /// - Throws: `AIError` if generation fails due to authentication,
    ///   network issues, or API errors.
    public func generate(
        _ prompt: String,
        model: AnthropicModelID,
        config: GenerateConfig
    ) async throws -> String {
        let result = try await generate(
            messages: [.user(prompt)],
            model: model,
            config: config
        )
        return result.text
    }

    /// Generates text from a conversation with message history.
    ///
    /// This method supports multi-turn conversations by accepting a full
    /// message history. The response includes metadata such as token usage
    /// and finish reason.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// let messages = [
    ///     Message.system("You are a helpful coding assistant."),
    ///     Message.user("What are Swift actors?"),
    ///     Message.assistant("Actors are reference types..."),
    ///     Message.user("Show me an example.")
    /// ]
    ///
    /// let result = try await provider.generate(
    ///     messages: messages,
    ///     model: .claudeSonnet45,
    ///     config: GenerateConfig.default.temperature(0.7)
    /// )
    ///
    /// print(result.text)
    /// print("Tokens used: \(result.usage?.totalTokens ?? 0)")
    /// ```
    ///
    /// ## Implementation
    ///
    /// This method:
    /// 1. Validates that the messages array is not empty
    /// 2. Builds an Anthropic API request from the messages
    /// 3. Executes the HTTP request to `/v1/messages`
    /// 4. Converts the response to a `GenerationResult`
    /// 5. Returns the result with timing and token usage metadata
    ///
    /// ## Cancellation
    ///
    /// This method supports Swift's structured concurrency and will throw
    /// `CancellationError` if the task is cancelled. The underlying HTTP
    /// request will be cancelled as well.
    ///
    /// - Parameters:
    ///   - messages: The conversation history. Must contain at least one message.
    ///   - model: The Claude model to use (e.g., `.claudeOpus45`).
    ///   - config: Configuration parameters (temperature, max tokens, etc.).
    ///
    /// - Returns: A `GenerationResult` containing the generated text and metadata.
    ///
    /// - Throws: `AIError.invalidInput` if messages array is empty,
    ///   or other `AIError` variants for API/network failures.
    public func generate(
        messages: [Message],
        model: AnthropicModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        // Validate input
        guard !messages.isEmpty else {
            throw AIError.invalidInput("Messages array cannot be empty")
        }

        // Record start time for performance metrics
        let startTime = Date()

        // Build API request
        let request = buildRequestBody(
            messages: messages,
            model: model,
            config: config,
            stream: false
        )

        // Execute HTTP request with retry logic
        let (response, rateLimitInfo) = try await executeRequest(request)

        // Convert to GenerationResult with rate limit info
        return try convertToGenerationResult(response, startTime: startTime, rateLimitInfo: rateLimitInfo)
    }

    // NOTE: Streaming methods are implemented in AnthropicProvider+Streaming.swift
    // - stream(_:model:config:) -> AsyncThrowingStream<String, Error>
    // - streamWithMetadata(messages:model:config:) -> AsyncThrowingStream<GenerationChunk, Error>
    // - stream(messages:model:config:) -> AsyncThrowingStream<GenerationChunk, Error>
}

#endif // CONDUIT_TRAIT_ANTHROPIC
