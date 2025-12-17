// FinishReason.swift
// SwiftAI

import Foundation

/// Reason why generation stopped.
///
/// Every generation operation terminates for a specific reason,
/// whether natural completion, hitting limits, or external factors.
///
/// ## Usage
/// ```swift
/// switch result.finishReason {
/// case .stop:
///     print("Completed naturally")
/// case .maxTokens:
///     print("Hit token limit")
/// case .cancelled:
///     print("User cancelled")
/// default:
///     break
/// }
/// ```
public enum FinishReason: String, Sendable, Codable {
    /// Natural end of generation (EOS token).
    case stop

    /// Reached maximum token limit.
    case maxTokens = "max_tokens"

    /// Hit a stop sequence.
    case stopSequence = "stop_sequence"

    /// User cancelled generation.
    case cancelled

    /// Content filtered by safety systems.
    case contentFilter = "content_filter"

    /// Tool call requested (for future use).
    case toolCall = "tool_call"
}
