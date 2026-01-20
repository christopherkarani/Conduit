// GenerationResult.swift
// Conduit

import Foundation

/// The result of a complete (non-streaming) generation.
///
/// Contains the generated text along with performance metrics,
/// token usage statistics, and the reason generation completed.
///
/// ## Usage
/// ```swift
/// let result = try await provider.generate(messages: messages, model: .llama3_2_1b, config: .default)
/// print(result.text)
/// print("Generated \(result.tokenCount) tokens in \(result.generationTime)s")
/// print("Speed: \(result.tokensPerSecond) tok/s")
/// ```
public struct GenerationResult: Sendable, Equatable {
    /// The generated text.
    public let text: String

    /// Total number of tokens generated.
    public let tokenCount: Int

    /// Time taken to generate (seconds).
    public let generationTime: TimeInterval

    /// Average tokens per second.
    public let tokensPerSecond: Double

    /// Why generation stopped.
    ///
    /// This is required for every generation result, as there must
    /// always be a reason why generation terminated.
    public let finishReason: FinishReason

    /// Log probabilities (if requested in config).
    public let logprobs: [TokenLogprob]?

    /// Usage statistics (if available from provider).
    public let usage: UsageStats?

    /// Rate limit information (if available from provider).
    public let rateLimitInfo: RateLimitInfo?

    /// Tool calls requested by the model.
    ///
    /// When `finishReason == .toolCall`, this array contains the tools
    /// the model wants to invoke. Execute each tool and provide results
    /// via `Message.toolOutput()` in the next request.
    public let toolCalls: [Transcript.ToolCall]

    /// Reasoning details from extended thinking models.
    ///
    /// When using models with reasoning/thinking mode enabled (e.g., Claude 3.7 Sonnet
    /// with thinking, o1 models), this array contains the model's reasoning process.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.reasoning(.high)
    /// let result = try await provider.generate(messages: messages, model: model, config: config)
    ///
    /// if !result.reasoningDetails.isEmpty {
    ///     print("Model reasoning:")
    ///     for detail in result.reasoningDetails {
    ///         if let content = detail.content {
    ///             print(content)
    ///         }
    ///     }
    /// }
    /// ```
    public let reasoningDetails: [ReasoningDetail]

    /// Whether the model requested tool calls.
    public var hasToolCalls: Bool {
        !toolCalls.isEmpty
    }

    /// Whether the response includes reasoning details.
    public var hasReasoningDetails: Bool {
        !reasoningDetails.isEmpty
    }

    /// Creates a generation result.
    ///
    /// - Parameters:
    ///   - text: The generated text.
    ///   - tokenCount: Number of tokens generated.
    ///   - generationTime: Time taken in seconds.
    ///   - tokensPerSecond: Generation speed.
    ///   - finishReason: Why generation stopped.
    ///   - logprobs: Optional log probabilities.
    ///   - usage: Optional usage statistics.
    ///   - rateLimitInfo: Optional rate limit information.
    ///   - toolCalls: Tool calls requested by the model.
    ///   - reasoningDetails: Reasoning details from extended thinking models.
    public init(
        text: String,
        tokenCount: Int,
        generationTime: TimeInterval,
        tokensPerSecond: Double,
        finishReason: FinishReason,
        logprobs: [TokenLogprob]? = nil,
        usage: UsageStats? = nil,
        rateLimitInfo: RateLimitInfo? = nil,
        toolCalls: [Transcript.ToolCall] = [],
        reasoningDetails: [ReasoningDetail] = []
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.generationTime = generationTime
        self.tokensPerSecond = tokensPerSecond
        self.finishReason = finishReason
        self.logprobs = logprobs
        self.usage = usage
        self.rateLimitInfo = rateLimitInfo
        self.toolCalls = toolCalls
        self.reasoningDetails = reasoningDetails
    }

    // MARK: - Factory Methods

    /// Creates a simple text result with minimal metadata.
    ///
    /// Useful for testing or when detailed metrics aren't needed.
    ///
    /// - Parameter content: The generated text.
    /// - Returns: A GenerationResult with default metadata.
    public static func text(_ content: String) -> GenerationResult {
        GenerationResult(
            text: content,
            tokenCount: 0,
            generationTime: 0,
            tokensPerSecond: 0,
            finishReason: .stop,
            toolCalls: [],
            reasoningDetails: []
        )
    }
}

// MARK: - Equatable Conformance

extension GenerationResult {
    public static func == (lhs: GenerationResult, rhs: GenerationResult) -> Bool {
        lhs.text == rhs.text &&
        lhs.tokenCount == rhs.tokenCount &&
        lhs.generationTime == rhs.generationTime &&
        lhs.tokensPerSecond == rhs.tokensPerSecond &&
        lhs.finishReason == rhs.finishReason &&
        lhs.usage == rhs.usage &&
        lhs.rateLimitInfo == rhs.rateLimitInfo &&
        lhs.toolCalls == rhs.toolCalls &&
        lhs.reasoningDetails == rhs.reasoningDetails
    }
}

// MARK: - Message Bridge

extension GenerationResult {
    /// Creates an assistant message carrying this result's text and tool calls.
    ///
    /// This preserves tool call metadata for providers that require tool_use
    /// blocks in conversation history (e.g. Anthropic).
    public func assistantMessage() -> Message {
        Message(
            role: .assistant,
            content: .text(text),
            metadata: MessageMetadata(
                tokenCount: tokenCount,
                generationTime: generationTime,
                tokensPerSecond: tokensPerSecond,
                toolCalls: toolCalls.isEmpty ? nil : toolCalls
            )
        )
    }
}
