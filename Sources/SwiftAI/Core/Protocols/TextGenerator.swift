// TextGenerator.swift
// SwiftAI

import Foundation

// MARK: - TextGenerator Protocol

/// A protocol that defines text generation capabilities for AI providers.
///
/// Conforming types can generate text responses from prompts or conversations,
/// with support for both synchronous responses and streaming output.
///
/// ## Overview
///
/// The `TextGenerator` protocol provides a unified interface for text generation
/// across different AI providers (MLX, HuggingFace, Apple Foundation Models).
/// It supports both simple string prompts and structured conversations with
/// message history.
///
/// ## Usage
///
/// ### Simple Text Generation
///
/// ```swift
/// let provider = MLXProvider()
/// let response = try await provider.generate(
///     "Explain quantum computing",
///     model: .llama3_2_1B,
///     config: .default
/// )
/// print(response)
/// ```
///
/// ### Conversation Generation
///
/// ```swift
/// let messages = [
///     Message(role: .system, content: "You are a helpful assistant."),
///     Message(role: .user, content: "What is Swift?")
/// ]
/// let result = try await provider.generate(
///     messages: messages,
///     model: .llama3_2_1B,
///     config: .default
/// )
/// print(result.text)
/// print("Tokens used: \(result.usage.totalTokens)")
/// ```
///
/// ### Streaming Generation
///
/// ```swift
/// let stream = provider.stream(
///     "Write a poem about AI",
///     model: .llama3_2_1B,
///     config: .default
/// )
///
/// for try await token in stream {
///     print(token, terminator: "")
/// }
/// ```
///
/// ### Streaming with Metadata
///
/// ```swift
/// let stream = provider.streamWithMetadata(
///     messages: messages,
///     model: .llama3_2_1B,
///     config: .default
/// )
///
/// for try await chunk in stream {
///     if let text = chunk.text {
///         print(text, terminator: "")
///     }
///     if chunk.finishReason != nil {
///         print("\nGeneration complete: \(chunk.finishReason!)")
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// Implementations of this protocol must be `Sendable` and thread-safe.
/// All methods can be called concurrently from different tasks.
///
/// ## Error Handling
///
/// All generation methods throw `AIError` when:
/// - The model is not available or fails to load
/// - Network requests fail (for cloud providers)
/// - Token limits are exceeded
/// - Invalid parameters are provided
///
/// - SeeAlso: `AIProvider`, `GenerateConfig`, `GenerationResult`
public protocol TextGenerator: Sendable {

    // MARK: - Associated Types

    /// The type used to identify models for this provider.
    ///
    /// This allows each provider to use its own model identification system
    /// while maintaining a consistent API across providers.
    associatedtype ModelID: ModelIdentifying

    // MARK: - Simple Generation

    /// Generates text from a simple string prompt.
    ///
    /// This is the simplest form of text generation, suitable for single-turn
    /// interactions without conversation history.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let response = try await provider.generate(
    ///     "What is the capital of France?",
    ///     model: .llama3_2_1B,
    ///     config: .default
    /// )
    /// print(response) // "The capital of France is Paris."
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: The input text to generate a response for.
    ///   - model: The model identifier to use for generation.
    ///   - config: Configuration parameters for generation (temperature, max tokens, etc.).
    ///            Defaults to `.default` when not specified by implementers.
    /// - Returns: The generated text response as a string.
    /// - Throws: `AIError` if generation fails due to model errors, network issues,
    ///           or invalid parameters.
    func generate(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) async throws -> String

    // MARK: - Conversation Generation

    /// Generates text from a conversation with message history.
    ///
    /// This method supports multi-turn conversations by accepting a full message
    /// history. The response includes metadata such as token usage and finish reason.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let messages = [
    ///     Message(role: .system, content: "You are a Swift expert."),
    ///     Message(role: .user, content: "What are actors?"),
    ///     Message(role: .assistant, content: "Actors are reference types..."),
    ///     Message(role: .user, content: "Show me an example.")
    /// ]
    ///
    /// let result = try await provider.generate(
    ///     messages: messages,
    ///     model: .llama3_2_1B,
    ///     config: GenerateConfig(temperature: 0.7, maxTokens: 500)
    /// )
    ///
    /// print(result.text)
    /// print("Prompt tokens: \(result.usage.promptTokens)")
    /// print("Completion tokens: \(result.usage.completionTokens)")
    /// ```
    ///
    /// - Parameters:
    ///   - messages: An array of messages representing the conversation history.
    ///              Must contain at least one message.
    ///   - model: The model identifier to use for generation.
    ///   - config: Configuration parameters for generation (temperature, max tokens, etc.).
    ///            Defaults to `.default` when not specified by implementers.
    /// - Returns: A `GenerationResult` containing the generated text and metadata.
    /// - Throws: `AIError.invalidInput` if the messages array is empty,
    ///           or other `AIError` variants for model/network failures.
    func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult

    // MARK: - Streaming Generation

    /// Streams text generation token by token from a simple prompt.
    ///
    /// This method returns an asynchronous stream that emits tokens as they are
    /// generated, allowing for real-time display of output. Each element in the
    /// stream is a string fragment (token or partial text).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let stream = provider.stream(
    ///     "Write a haiku about programming",
    ///     model: .llama3_2_1B,
    ///     config: .default
    /// )
    ///
    /// var fullText = ""
    /// for try await token in stream {
    ///     print(token, terminator: "")
    ///     fullText += token
    /// }
    /// print("\n\nComplete text: \(fullText)")
    /// ```
    ///
    /// ## Stream Behavior
    ///
    /// - The stream emits text fragments as they become available
    /// - The stream completes when generation finishes
    /// - The stream throws if an error occurs during generation
    /// - Canceling the task that iterates the stream will stop generation
    ///
    /// - Parameters:
    ///   - prompt: The input text to generate a response for.
    ///   - model: The model identifier to use for generation.
    ///   - config: Configuration parameters for generation (temperature, max tokens, etc.).
    ///            Defaults to `.default` when not specified by implementers.
    /// - Returns: An `AsyncThrowingStream` that emits text fragments as they are generated.
    /// - Throws: Errors are thrown within the stream as `AIError` when generation fails.
    func stream(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error>

    // MARK: - Streaming with Metadata

    /// Streams text generation with full chunk metadata.
    ///
    /// This method provides the most detailed streaming interface, emitting
    /// `GenerationChunk` objects that include not only the text but also metadata
    /// such as finish reasons, token usage, and chunk indices.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let messages = [
    ///     Message(role: .user, content: "Explain async/await")
    /// ]
    ///
    /// let stream = provider.streamWithMetadata(
    ///     messages: messages,
    ///     model: .llama3_2_1B,
    ///     config: .default
    /// )
    ///
    /// var chunks: [GenerationChunk] = []
    /// for try await chunk in stream {
    ///     chunks.append(chunk)
    ///
    ///     if let text = chunk.text {
    ///         print(text, terminator: "")
    ///     }
    ///
    ///     if let finishReason = chunk.finishReason {
    ///         print("\n\nFinished: \(finishReason)")
    ///         if let usage = chunk.usage {
    ///             print("Total tokens: \(usage.totalTokens)")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## Chunk Structure
    ///
    /// Each `GenerationChunk` may contain:
    /// - `text`: The text fragment for this chunk (may be nil for metadata-only chunks)
    /// - `finishReason`: Present in the final chunk, indicates why generation stopped
    /// - `usage`: Token usage statistics (typically only in the final chunk)
    /// - `index`: The sequential position of this chunk in the stream
    ///
    /// - Parameters:
    ///   - messages: An array of messages representing the conversation history.
    ///              Must contain at least one message.
    ///   - model: The model identifier to use for generation.
    ///   - config: Configuration parameters for generation (temperature, max tokens, etc.).
    ///            Defaults to `.default` when not specified by implementers.
    /// - Returns: An `AsyncThrowingStream` that emits `GenerationChunk` objects.
    /// - Throws: Errors are thrown within the stream as `AIError` when generation fails
    ///           or if the messages array is empty.
    func streamWithMetadata(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error>
}

// MARK: - Default Implementations

extension TextGenerator {

    /// Convenience method for generating text with default configuration.
    ///
    /// This allows omitting the `config` parameter when default settings are acceptable.
    ///
    /// - Parameters:
    ///   - prompt: The input text to generate a response for.
    ///   - model: The model identifier to use for generation.
    /// - Returns: The generated text response as a string.
    /// - Throws: `AIError` if generation fails.
    public func generate(
        _ prompt: String,
        model: ModelID
    ) async throws -> String {
        try await generate(prompt, model: model, config: .default)
    }

    /// Convenience method for conversation generation with default configuration.
    ///
    /// This allows omitting the `config` parameter when default settings are acceptable.
    ///
    /// - Parameters:
    ///   - messages: An array of messages representing the conversation history.
    ///   - model: The model identifier to use for generation.
    /// - Returns: A `GenerationResult` containing the generated text and metadata.
    /// - Throws: `AIError` if generation fails.
    public func generate(
        messages: [Message],
        model: ModelID
    ) async throws -> GenerationResult {
        try await generate(messages: messages, model: model, config: .default)
    }

    /// Convenience method for streaming with default configuration.
    ///
    /// This allows omitting the `config` parameter when default settings are acceptable.
    ///
    /// - Parameters:
    ///   - prompt: The input text to generate a response for.
    ///   - model: The model identifier to use for generation.
    /// - Returns: An `AsyncThrowingStream` that emits text fragments.
    public func stream(
        _ prompt: String,
        model: ModelID
    ) -> AsyncThrowingStream<String, Error> {
        stream(prompt, model: model, config: .default)
    }

    /// Convenience method for streaming with metadata using default configuration.
    ///
    /// This allows omitting the `config` parameter when default settings are acceptable.
    ///
    /// - Parameters:
    ///   - messages: An array of messages representing the conversation history.
    ///   - model: The model identifier to use for generation.
    /// - Returns: An `AsyncThrowingStream` that emits `GenerationChunk` objects.
    public func streamWithMetadata(
        messages: [Message],
        model: ModelID
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        streamWithMetadata(messages: messages, model: model, config: .default)
    }
}
