// GenerationResult.swift
// SwiftAI

import Foundation

/// The result of a complete (non-streaming) generation.
///
/// Contains the generated text along with performance metrics,
/// token usage statistics, and the reason generation completed.
///
/// ## Usage
/// ```swift
/// let result = try await provider.generate(messages: messages, model: .llama3_2_1B, config: .default)
/// print(result.text)
/// print("Generated \(result.tokenCount) tokens in \(result.generationTime)s")
/// print("Speed: \(result.tokensPerSecond) tok/s")
/// ```
public struct GenerationResult: Sendable, Hashable {
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
    public init(
        text: String,
        tokenCount: Int,
        generationTime: TimeInterval,
        tokensPerSecond: Double,
        finishReason: FinishReason,
        logprobs: [TokenLogprob]? = nil,
        usage: UsageStats? = nil
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.generationTime = generationTime
        self.tokensPerSecond = tokensPerSecond
        self.finishReason = finishReason
        self.logprobs = logprobs
        self.usage = usage
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
            finishReason: .stop
        )
    }
}

// MARK: - Hashable Conformance

extension GenerationResult {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(tokenCount)
        hasher.combine(generationTime)
        hasher.combine(tokensPerSecond)
        hasher.combine(finishReason)
        hasher.combine(usage)
    }

    public static func == (lhs: GenerationResult, rhs: GenerationResult) -> Bool {
        lhs.text == rhs.text &&
        lhs.tokenCount == rhs.tokenCount &&
        lhs.generationTime == rhs.generationTime &&
        lhs.tokensPerSecond == rhs.tokensPerSecond &&
        lhs.finishReason == rhs.finishReason &&
        lhs.usage == rhs.usage
    }
}
