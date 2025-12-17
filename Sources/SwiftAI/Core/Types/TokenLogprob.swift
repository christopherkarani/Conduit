// TokenLogprob.swift
// SwiftAI

import Foundation

/// Log probability information for a token.
///
/// Contains the probability information for a single token during
/// generation, useful for analyzing model confidence and alternatives.
///
/// ## Usage
/// ```swift
/// for logprob in chunk.topLogprobs ?? [] {
///     print("\(logprob.token): \(logprob.probability * 100)%")
/// }
/// ```
public struct TokenLogprob: Sendable, Hashable, Codable {
    /// The token text.
    public let token: String

    /// Log probability of this token.
    ///
    /// This is the natural logarithm of the probability.
    /// Use `probability` for the actual probability value.
    public let logprob: Float

    /// Token ID in the model's vocabulary.
    public let tokenId: Int?

    /// The actual probability (computed from logprob).
    ///
    /// Converts the log probability to a regular probability
    /// value between 0 and 1.
    public var probability: Float {
        exp(logprob)
    }

    /// Creates a token log probability.
    ///
    /// - Parameters:
    ///   - token: The token text.
    ///   - logprob: The log probability value.
    ///   - tokenId: Optional token ID in the vocabulary.
    public init(token: String, logprob: Float, tokenId: Int? = nil) {
        self.token = token
        self.logprob = logprob
        self.tokenId = tokenId
    }
}
