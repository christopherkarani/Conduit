// AIProvider.swift
// SwiftAI

import Foundation

// MARK: - AIProvider Protocol

/// A provider capable of performing AI inference operations.
///
/// Conforming types must be actors to ensure thread-safe access to
/// underlying model resources. The protocol uses primary associated
/// types for cleaner generic constraints in Swift 6.2.
///
/// ## Thread Safety
///
/// All conforming types must be actors to guarantee safe concurrent
/// access to model state, preventing data races during inference
/// operations. This is enforced by the `Actor` conformance requirement.
///
/// ## Lifecycle Management
///
/// Providers are responsible for managing their own lifecycle,
/// including:
/// - Model loading and initialization
/// - Memory allocation and cleanup
/// - Resource pooling and reuse
/// - Graceful shutdown and cancellation
///
/// ## Usage Examples
///
/// ### Basic Text Generation
///
/// ```swift
/// let provider = MLXProvider()
/// let messages = [Message.user("What is Swift?")]
/// let response = try await provider.generate(
///     messages: messages,
///     model: .llama3_2_1b,
///     config: .default
/// )
/// print(response.text)
/// ```
///
/// ### Streaming Generation
///
/// ```swift
/// let provider = MLXProvider()
/// let messages = [Message.user("Explain concurrency")]
/// let stream = provider.stream(
///     messages: messages,
///     model: .llama3_2_1b,
///     config: .default
/// )
///
/// for try await chunk in stream {
///     print(chunk.text, terminator: "")
/// }
/// ```
///
/// ### Checking Availability
///
/// ```swift
/// let provider = MLXProvider()
/// if await provider.isAvailable {
///     // Provider is ready
/// } else {
///     let status = await provider.availabilityStatus
///     print("Provider unavailable: \(status.unavailableReason)")
/// }
/// ```
///
/// ### Cancellation Support
///
/// ```swift
/// let provider = MLXProvider()
/// Task {
///     let messages = [Message.user("Long request...")]
///     let response = try await provider.generate(
///         messages: messages,
///         model: .llama3_2_1b,
///         config: .default
///     )
/// }
///
/// // Cancel from another context
/// await provider.cancelGeneration()
/// ```
///
/// ## Associated Types
///
/// Providers define three associated types to customize behavior:
///
/// - `Response`: The complete result type for non-streaming generation
/// - `StreamChunk`: The incremental result type for streaming generation
/// - `ModelID`: The model identifier type accepted by this provider
///
/// These types allow each provider to return optimized data structures
/// while maintaining a consistent API surface.
///
/// ## Error Handling
///
/// All async methods can throw errors. Providers should throw:
/// - `AIError.providerUnavailable` if the provider cannot perform inference
/// - `AIError.modelNotFound` if the requested model doesn't exist
/// - `AIError.generationFailed` for runtime generation errors
/// - Provider-specific errors for detailed diagnostics
///
/// ## Conformance Requirements
///
/// To conform to `AIProvider`, a type must:
/// 1. Be declared as an `actor`
/// 2. Conform to `Sendable` (automatic for actors)
/// 3. Implement all required properties and methods
/// 4. Use `Sendable` types for all associated types
///
/// Example conformance:
///
/// ```swift
/// actor MyProvider: AIProvider {
///     typealias Response = GenerationResult
///     typealias StreamChunk = GenerationChunk
///     typealias ModelID = MyModelIdentifier
///
///     var isAvailable: Bool {
///         get async {
///             // Check availability
///             return true
///         }
///     }
///
///     var availabilityStatus: ProviderAvailability {
///         get async {
///             await isAvailable ? .available : .unavailable(.deviceNotSupported)
///         }
///     }
///
///     func generate(
///         messages: [Message],
///         model: ModelID,
///         config: GenerateConfig
///     ) async throws -> Response {
///         // Implementation
///     }
///
///     func stream(
///         messages: [Message],
///         model: ModelID,
///         config: GenerateConfig
///     ) -> AsyncThrowingStream<StreamChunk, Error> {
///         // Implementation
///     }
///
///     func cancelGeneration() async {
///         // Implementation
///     }
/// }
/// ```
///
/// - Note: This protocol is part of SwiftAI's core abstraction layer,
///   enabling unified access to MLX, HuggingFace, and Apple Foundation Models.
public protocol AIProvider<Response>: Actor, Sendable {

    // MARK: - Associated Types

    /// The type returned from non-streaming generation.
    ///
    /// This type represents the complete result of a generation
    /// operation, including the generated text and any metadata
    /// such as token counts and performance metrics.
    ///
    /// Must be `Sendable` to safely cross actor boundaries.
    associatedtype Response: Sendable

    /// The type yielded during streaming generation.
    ///
    /// This type represents a single incremental chunk of the
    /// generation output, typically containing one or more tokens.
    ///
    /// Must be `Sendable` to safely cross actor boundaries.
    associatedtype StreamChunk: Sendable

    /// The model identifier type this provider accepts.
    ///
    /// Each provider has its own model identifier type that
    /// conforms to `ModelIdentifying`. This allows type-safe
    /// model selection at compile time.
    ///
    /// Must conform to `ModelIdentifying` protocol.
    associatedtype ModelID: ModelIdentifying

    // MARK: - Availability

    /// Whether this provider is currently available for inference.
    ///
    /// Returns `true` if the provider is ready to perform inference
    /// operations. This is a quick check that doesn't provide detailed
    /// diagnostic information.
    ///
    /// For example, a provider might be unavailable if:
    /// - Required models are not downloaded
    /// - The device doesn't meet system requirements
    /// - Network connectivity is required but unavailable
    /// - API credentials are missing or invalid
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let provider = MLXProvider()
    /// if await provider.isAvailable {
    ///     let response = try await provider.generate(...)
    /// } else {
    ///     print("Provider not ready")
    /// }
    /// ```
    ///
    /// - Note: This property must be `async` because checking availability
    ///   may require querying system state or network resources.
    var isAvailable: Bool { get async }

    /// Detailed availability status with reason if unavailable.
    ///
    /// Provides comprehensive information about the provider's
    /// availability state, including:
    /// - Whether the provider is available
    /// - The specific reason if unavailable
    /// - Actionable information for resolving unavailability
    ///
    /// Use this property when you need to provide detailed feedback
    /// to users about why inference cannot proceed.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let provider = MLXProvider()
    /// let status = await provider.availabilityStatus
    ///
    /// if status.isAvailable {
    ///     // Ready to generate
    /// } else if let reason = status.unavailableReason {
    ///     switch reason {
    ///     case .modelNotDownloaded:
    ///         print("Please download the model first")
    ///     case .deviceNotSupported:
    ///         print("This device is not supported")
    ///     case .noNetwork:
    ///         print("Network connection required")
    ///     default:
    ///         print("Provider unavailable: \(reason)")
    ///     }
    /// }
    /// ```
    ///
    /// - Note: This property must be `async` because determining the
    ///   detailed status may require I/O operations.
    var availabilityStatus: ProviderAvailability { get async }

    // MARK: - Text Generation

    /// Generates a complete response for the given messages.
    ///
    /// Performs non-streaming text generation, waiting until the
    /// entire response is complete before returning. This is suitable
    /// for use cases where you need the full result before proceeding.
    ///
    /// ## Behavior
    ///
    /// 1. Validates that the provider is available
    /// 2. Loads the specified model (if not already loaded)
    /// 3. Processes the input messages
    /// 4. Generates tokens until completion
    /// 5. Returns the complete result with metadata
    ///
    /// ## Cancellation
    ///
    /// This method supports task cancellation. If the enclosing task
    /// is cancelled, generation will stop and a `CancellationError`
    /// will be thrown.
    ///
    /// ```swift
    /// let task = Task {
    ///     try await provider.generate(
    ///         messages: longMessages,
    ///         model: .llama3_2_1b,
    ///         config: .default
    ///     )
    /// }
    ///
    /// // Cancel the task
    /// task.cancel()
    /// ```
    ///
    /// ## Configuration
    ///
    /// The `config` parameter controls generation behavior:
    /// - `temperature`: Randomness (0.0 = deterministic, 1.0+ = creative)
    /// - `maxTokens`: Maximum tokens to generate
    /// - `topP`: Nucleus sampling threshold
    /// - `stopSequences`: Sequences that stop generation
    ///
    /// ## Error Handling
    ///
    /// This method throws errors in the following cases:
    /// - Provider is unavailable
    /// - Model not found or failed to load
    /// - Generation failed during processing
    /// - Task was cancelled
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXProvider()
    /// let messages = [
    ///     Message.system("You are a helpful assistant."),
    ///     Message.user("What is the capital of France?")
    /// ]
    ///
    /// do {
    ///     let response = try await provider.generate(
    ///         messages: messages,
    ///         model: .llama3_2_1b,
    ///         config: GenerateConfig.default
    ///             .temperature(0.7)
    ///             .maxTokens(100)
    ///     )
    ///     print("Response: \(response.text)")
    ///     print("Tokens: \(response.tokenCount)")
    /// } catch {
    ///     print("Generation failed: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - messages: The conversation history to process. Must contain
    ///     at least one message. Messages are processed in order.
    ///   - model: The model identifier specifying which model to use
    ///     for generation. Must be a valid model for this provider.
    ///   - config: Configuration options controlling generation behavior.
    ///     Use `.default` for standard settings.
    ///
    /// - Returns: The complete generation result, including the generated
    ///   text and performance metadata.
    ///
    /// - Throws: `AIError` if generation fails, or `CancellationError` if
    ///   the task is cancelled.
    func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> Response

    /// Streams tokens as they are generated.
    ///
    /// Performs streaming text generation, yielding chunks of output
    /// as they are produced. This provides a better user experience
    /// for long-form generation by allowing incremental display.
    ///
    /// ## Behavior
    ///
    /// 1. Validates that the provider is available
    /// 2. Loads the specified model (if not already loaded)
    /// 3. Processes the input messages
    /// 4. Yields chunks as tokens are generated
    /// 5. Completes the stream when generation finishes
    ///
    /// ## Stream Lifecycle
    ///
    /// The returned `AsyncThrowingStream` follows standard Swift
    /// async sequence semantics:
    /// - Iteration begins when you start the `for await` loop
    /// - Chunks are yielded incrementally as generation proceeds
    /// - The stream completes when generation finishes
    /// - Errors are thrown into the stream on failure
    ///
    /// ## Cancellation
    ///
    /// Streaming supports task cancellation:
    /// - Breaking out of the loop stops generation
    /// - Task cancellation aborts the stream
    /// - The provider cleans up resources automatically
    ///
    /// ```swift
    /// let task = Task {
    ///     let stream = provider.stream(...)
    ///     for try await chunk in stream {
    ///         print(chunk.text, terminator: "")
    ///         if shouldStop {
    ///             break // Stops generation
    ///         }
    ///     }
    /// }
    ///
    /// // Cancel from outside
    /// task.cancel()
    /// ```
    ///
    /// ## Error Handling
    ///
    /// Errors are thrown during iteration:
    /// - Provider becomes unavailable
    /// - Model loading fails
    /// - Generation encounters an error
    /// - Stream is cancelled
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXProvider()
    /// let messages = [Message.user("Write a short story")]
    ///
    /// let stream = provider.stream(
    ///     messages: messages,
    ///     model: .llama3_2_1b,
    ///     config: .default
    /// )
    ///
    /// var fullText = ""
    /// do {
    ///     for try await chunk in stream {
    ///         print(chunk.text, terminator: "")
    ///         fullText += chunk.text
    ///
    ///         if chunk.isComplete {
    ///             print("\n\nGeneration complete!")
    ///         }
    ///     }
    /// } catch {
    ///     print("\nStreaming failed: \(error)")
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// Streaming is typically more efficient than non-streaming generation
    /// for interactive use cases because:
    /// - Users see output immediately
    /// - Perceived latency is lower
    /// - Generation can be cancelled early without wasting resources
    ///
    /// - Parameters:
    ///   - messages: The conversation history to process. Must contain
    ///     at least one message. Messages are processed in order.
    ///   - model: The model identifier specifying which model to use
    ///     for generation. Must be a valid model for this provider.
    ///   - config: Configuration options controlling generation behavior.
    ///     Use `.default` for standard settings.
    ///
    /// - Returns: An async throwing stream that yields chunks of generated
    ///   text. The stream completes when generation finishes or throws
    ///   if an error occurs.
    ///
    /// - Note: Implementations may mark this method as `nonisolated` since
    ///   it returns an `AsyncThrowingStream` synchronously. The actual
    ///   generation work happens asynchronously when the stream is iterated.
    ///   This allows the method to be called without crossing actor boundaries.
    func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<StreamChunk, Error>

    // MARK: - Cancellation

    /// Cancels any in-flight generation request.
    ///
    /// Attempts to immediately stop any ongoing generation operation.
    /// This is useful when:
    /// - The user wants to abort a long-running generation
    /// - You need to switch to a different request
    /// - Resources need to be freed urgently
    ///
    /// ## Behavior
    ///
    /// Calling this method:
    /// 1. Signals the provider to stop generating
    /// 2. Cleans up any temporary resources
    /// 3. Returns immediately (non-blocking)
    ///
    /// If no generation is in progress, this method has no effect.
    ///
    /// ## Cancellation Guarantees
    ///
    /// - **Non-blocking**: This method returns quickly without waiting
    ///   for the generation to fully stop
    /// - **Best-effort**: The provider will attempt to cancel, but
    ///   completion is not guaranteed (depends on underlying implementation)
    /// - **Safe**: Can be called multiple times without side effects
    ///
    /// ## Relationship to Task Cancellation
    ///
    /// This method provides explicit cancellation control that works
    /// alongside Swift's structured concurrency:
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
    /// Use this method when you need to cancel from within the same
    /// actor context or when task cancellation is not available.
    ///
    /// ## Example
    ///
    /// ```swift
    /// actor GenerationController {
    ///     let provider: MLXProvider
    ///     var currentTask: Task<GenerationResult, Error>?
    ///
    ///     func startGeneration() {
    ///         currentTask = Task {
    ///             try await provider.generate(...)
    ///         }
    ///     }
    ///
    ///     func stopGeneration() async {
    ///         currentTask?.cancel()
    ///         await provider.cancelGeneration()
    ///         currentTask = nil
    ///     }
    /// }
    /// ```
    ///
    /// - Note: After calling this method, any pending `generate()` or
    ///   `stream()` calls should throw `CancellationError` or complete
    ///   with partial results.
    func cancelGeneration() async
}
