// IntContextExtensions.swift
// SwiftAI

import Foundation

// MARK: - Common Context Window Sizes

/// Extensions providing convenient context window size constants.
///
/// These constants represent common context window sizes used by various
/// LLM models, making it easy to reference standard sizes throughout
/// the framework.
///
/// ## Usage
/// ```swift
/// let count = try await provider.countTokens(in: text, for: model)
/// if count.fitsInContext(of: .context4K) {
///     // Use 4K context model
/// } else if count.fitsInContext(of: .context32K) {
///     // Use 32K context model
/// }
/// ```
extension Int {

    /// 4K context window (4,096 tokens).
    ///
    /// Common in older models and some efficient architectures.
    /// Examples: Original GPT-2, some Phi variants.
    public static let context4K = 4_096

    /// 8K context window (8,192 tokens).
    ///
    /// Standard context size for many mid-range models.
    /// Examples: Llama 2 base, some Mistral variants.
    public static let context8K = 8_192

    /// 16K context window (16,384 tokens).
    ///
    /// Extended context for longer conversations.
    /// Examples: GPT-3.5-turbo-16k.
    public static let context16K = 16_384

    /// 32K context window (32,768 tokens).
    ///
    /// Large context for document processing.
    /// Examples: Llama 2 32K, Claude 2.
    public static let context32K = 32_768

    /// 64K context window (65,536 tokens).
    ///
    /// Extra large context for extensive documents.
    public static let context64K = 65_536

    /// 128K context window (131,072 tokens).
    ///
    /// Modern large context models.
    /// Examples: GPT-4 Turbo, Claude 3, Llama 3.
    public static let context128K = 131_072

    /// 200K context window (200,000 tokens).
    ///
    /// Extended context models.
    /// Examples: Claude 3 Opus.
    public static let context200K = 200_000

    /// 1M context window (1,000,000 tokens).
    ///
    /// Experimental very large context models.
    /// Examples: Gemini 1.5.
    public static let context1M = 1_000_000
}

// MARK: - Context Size Helpers

extension Int {

    /// Returns a human-readable description of this context size.
    ///
    /// Uses standard colloquial names for known context sizes (e.g., "128K" for 131,072)
    /// and falls back to binary K (÷1024) for other values, matching how context
    /// window sizes are conventionally described in the ML community.
    ///
    /// - Returns: A string like "4K", "32K", or "128K".
    ///
    /// ## Example
    /// ```swift
    /// print(Int.context4K.contextDescription) // "4K"
    /// print(8192.contextDescription) // "8K"
    /// print(Int.context128K.contextDescription) // "128K"
    /// ```
    public var contextDescription: String {
        // Map standard context sizes to their colloquial names
        switch self {
        case Int.context4K: return "4K"
        case Int.context8K: return "8K"
        case Int.context16K: return "16K"
        case Int.context32K: return "32K"
        case Int.context64K: return "64K"
        case Int.context128K: return "128K"
        case Int.context200K: return "200K"
        case Int.context1M: return "1M"
        default:
            // For non-standard values, use binary K (1024) for context sizes
            if self >= 1_000_000 {
                return "\(self / 1_000_000)M"
            } else if self >= 1_024 {
                return "\(self / 1_024)K"
            } else {
                return "\(self)"
            }
        }
    }

    /// Checks if this value represents a standard context window size.
    public var isStandardContextSize: Bool {
        [
            Int.context4K,
            Int.context8K,
            Int.context16K,
            Int.context32K,
            Int.context64K,
            Int.context128K,
            Int.context200K,
            Int.context1M
        ].contains(self)
    }
}
