// UsageStats.swift
// SwiftAI

import Foundation

/// Token usage statistics for a generation request.
///
/// Tracks the number of tokens consumed in both the input prompt
/// and the generated output, useful for cost estimation and
/// context window management.
///
/// ## Usage
/// ```swift
/// if let usage = result.usage {
///     print("Prompt: \(usage.promptTokens) tokens")
///     print("Output: \(usage.completionTokens) tokens")
///     print("Total: \(usage.totalTokens) tokens")
/// }
/// ```
public struct UsageStats: Sendable, Hashable, Codable {
    /// Tokens in the prompt/input.
    public let promptTokens: Int

    /// Tokens in the completion/output.
    public let completionTokens: Int

    /// Total tokens used (prompt + completion).
    ///
    /// This is a computed property that sums prompt and completion tokens.
    public var totalTokens: Int {
        promptTokens + completionTokens
    }

    /// Creates usage statistics.
    ///
    /// - Parameters:
    ///   - promptTokens: Number of tokens in the input prompt.
    ///   - completionTokens: Number of tokens in the generated output.
    public init(promptTokens: Int, completionTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }
}
