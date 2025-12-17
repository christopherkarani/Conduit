// TokenCount.swift
// SwiftAI

import Foundation

/// The result of a token counting operation.
///
/// Contains the count of tokens along with optional metadata about
/// the tokenization, including the original text and token breakdown.
///
/// ## Usage
/// ```swift
/// let count = try await provider.countTokens(in: "Hello, world!", for: .llama3_2_1B)
/// print("Token count: \(count.count)")
/// print("Fits in 4K context: \(count.fitsInContext(of: .context4K))")
/// ```
public struct TokenCount: Sendable, Hashable {

    /// Total number of tokens.
    public let count: Int

    /// The text that was counted.
    public let text: String

    /// The model/tokenizer identifier used for counting.
    public let tokenizer: String

    /// Individual token IDs (if requested during counting).
    public let tokenIds: [Int]?

    /// Individual token strings (if requested during counting).
    public let tokens: [String]?

    /// Number of tokens in the prompt/input portion.
    public let promptTokens: Int?

    /// Number of special tokens (BOS, EOS, chat template overhead).
    public let specialTokens: Int?

    // MARK: - Initialization

    /// Creates a token count result.
    ///
    /// - Parameters:
    ///   - count: Total number of tokens.
    ///   - text: The text that was counted.
    ///   - tokenizer: The tokenizer identifier used.
    ///   - tokenIds: Optional array of token IDs.
    ///   - tokens: Optional array of token strings.
    ///   - promptTokens: Optional count of prompt tokens.
    ///   - specialTokens: Optional count of special tokens.
    public init(
        count: Int,
        text: String = "",
        tokenizer: String = "",
        tokenIds: [Int]? = nil,
        tokens: [String]? = nil,
        promptTokens: Int? = nil,
        specialTokens: Int? = nil
    ) {
        self.count = count
        self.text = text
        self.tokenizer = tokenizer
        self.tokenIds = tokenIds
        self.tokens = tokens
        self.promptTokens = promptTokens
        self.specialTokens = specialTokens
    }

    // MARK: - Context Window Helpers

    /// Checks if this token count fits within a context window.
    ///
    /// - Parameter size: The context window size in tokens.
    /// - Returns: `true` if the token count fits within the context.
    ///
    /// ## Example
    /// ```swift
    /// let count = TokenCount(count: 2000, text: "...", tokenizer: "llama")
    /// if count.fitsInContext(of: .context4K) {
    ///     print("Fits in 4K context!")
    /// }
    /// ```
    public func fitsInContext(of size: Int) -> Bool {
        count <= size
    }

    /// Calculates remaining tokens available in a context window.
    ///
    /// - Parameter size: The context window size in tokens.
    /// - Returns: The number of tokens remaining (never negative).
    ///
    /// ## Example
    /// ```swift
    /// let count = TokenCount(count: 1000, text: "...", tokenizer: "llama")
    /// let remaining = count.remainingIn(context: .context4K)
    /// print("Can add \(remaining) more tokens")
    /// ```
    public func remainingIn(context size: Int) -> Int {
        max(0, size - count)
    }

    /// Returns the percentage of context window used.
    ///
    /// - Parameter size: The context window size in tokens.
    /// - Returns: Percentage (0-100+) of context used.
    ///
    /// ## Example
    /// ```swift
    /// let count = TokenCount(count: 2048, text: "...", tokenizer: "llama")
    /// let percentage = count.percentageOf(context: .context4K)
    /// print("Using \(String(format: "%.1f", percentage))% of context")
    /// ```
    public func percentageOf(context size: Int) -> Double {
        guard size > 0 else { return 0 }
        return Double(count) / Double(size) * 100
    }

    /// Checks if adding more tokens would exceed the context window.
    ///
    /// - Parameters:
    ///   - additionalTokens: Number of tokens to add.
    ///   - contextSize: The context window size.
    /// - Returns: `true` if adding the tokens would exceed the context.
    public func wouldExceed(adding additionalTokens: Int, contextSize: Int) -> Bool {
        count + additionalTokens > contextSize
    }
}

// MARK: - CustomStringConvertible

extension TokenCount: CustomStringConvertible {
    public var description: String {
        var parts = ["\(count) tokens"]
        if let prompt = promptTokens {
            parts.append("prompt: \(prompt)")
        }
        if let special = specialTokens {
            parts.append("special: \(special)")
        }
        if !tokenizer.isEmpty {
            parts.append("tokenizer: \(tokenizer)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Codable

extension TokenCount: Codable {
    // Default Codable synthesis works for all stored properties
}

// MARK: - Convenience Initializers

extension TokenCount {
    /// Creates a simple token count with just the count value.
    ///
    /// - Parameter count: The number of tokens.
    /// - Returns: A TokenCount with minimal metadata.
    public static func simple(_ count: Int) -> TokenCount {
        TokenCount(count: count)
    }

    /// Creates a token count from a message array count operation.
    ///
    /// - Parameters:
    ///   - count: Total tokens.
    ///   - promptTokens: Tokens from prompts.
    ///   - specialTokens: Special/template tokens.
    ///   - tokenizer: The tokenizer used.
    /// - Returns: A TokenCount for message-based counting.
    public static func fromMessages(
        count: Int,
        promptTokens: Int,
        specialTokens: Int,
        tokenizer: String
    ) -> TokenCount {
        TokenCount(
            count: count,
            text: "",
            tokenizer: tokenizer,
            promptTokens: promptTokens,
            specialTokens: specialTokens
        )
    }
}
