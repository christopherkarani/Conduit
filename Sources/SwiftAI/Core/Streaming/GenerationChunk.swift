// GenerationChunk.swift
// SwiftAI

import Foundation

/// A single chunk of streamed generation output.
///
/// Represents one or more tokens yielded during streaming generation.
/// Each chunk contains the generated text, timing information, and
/// optional probability data.
///
/// ## Usage
/// ```swift
/// for try await chunk in stream {
///     print(chunk.text, terminator: "")
///     if chunk.isComplete {
///         print("\nFinished: \(chunk.finishReason ?? .stop)")
///     }
/// }
/// ```
public struct GenerationChunk: Sendable, Hashable {
    /// The generated text in this chunk.
    public let text: String

    /// Number of tokens in this chunk (usually 1).
    public let tokenCount: Int

    /// Token ID if available.
    public let tokenId: Int?

    /// Log probability of this token.
    public let logprob: Float?

    /// Top alternative tokens with their probabilities.
    public let topLogprobs: [TokenLogprob]?

    /// Generation speed at this point (tokens per second).
    public let tokensPerSecond: Double?

    /// Whether this is the final chunk.
    public let isComplete: Bool

    /// Reason generation stopped (only set on final chunk).
    public let finishReason: FinishReason?

    /// Timestamp when this chunk was generated.
    public let timestamp: Date

    /// Creates a generation chunk.
    ///
    /// - Parameters:
    ///   - text: The generated text in this chunk.
    ///   - tokenCount: Number of tokens (default: 1).
    ///   - tokenId: Optional token ID.
    ///   - logprob: Optional log probability.
    ///   - topLogprobs: Optional top alternative tokens.
    ///   - tokensPerSecond: Optional generation speed.
    ///   - isComplete: Whether this is the final chunk.
    ///   - finishReason: Reason generation stopped (for final chunk).
    ///   - timestamp: Chunk creation time (default: now).
    public init(
        text: String,
        tokenCount: Int = 1,
        tokenId: Int? = nil,
        logprob: Float? = nil,
        topLogprobs: [TokenLogprob]? = nil,
        tokensPerSecond: Double? = nil,
        isComplete: Bool = false,
        finishReason: FinishReason? = nil,
        timestamp: Date = Date()
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.tokenId = tokenId
        self.logprob = logprob
        self.topLogprobs = topLogprobs
        self.tokensPerSecond = tokensPerSecond
        self.isComplete = isComplete
        self.finishReason = finishReason
        self.timestamp = timestamp
    }

    // MARK: - Factory Methods

    /// Creates a completion chunk indicating generation has finished.
    ///
    /// - Parameter finishReason: The reason generation stopped.
    /// - Returns: A chunk marking the end of generation.
    public static func completion(finishReason: FinishReason) -> GenerationChunk {
        GenerationChunk(
            text: "",
            tokenCount: 0,
            isComplete: true,
            finishReason: finishReason
        )
    }
}

// MARK: - Hashable Conformance

extension GenerationChunk {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(tokenCount)
        hasher.combine(tokenId)
        hasher.combine(logprob)
        hasher.combine(topLogprobs)
        hasher.combine(tokensPerSecond)
        hasher.combine(isComplete)
        hasher.combine(finishReason)
        hasher.combine(timestamp)
    }

    public static func == (lhs: GenerationChunk, rhs: GenerationChunk) -> Bool {
        lhs.text == rhs.text &&
        lhs.tokenCount == rhs.tokenCount &&
        lhs.tokenId == rhs.tokenId &&
        lhs.logprob == rhs.logprob &&
        lhs.topLogprobs == rhs.topLogprobs &&
        lhs.tokensPerSecond == rhs.tokensPerSecond &&
        lhs.isComplete == rhs.isComplete &&
        lhs.finishReason == rhs.finishReason &&
        lhs.timestamp == rhs.timestamp
    }
}
