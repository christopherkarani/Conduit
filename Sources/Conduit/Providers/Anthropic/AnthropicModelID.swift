// AnthropicModelID.swift
// Conduit
//
// Model identifiers for Anthropic Claude API.

#if CONDUIT_TRAIT_ANTHROPIC
import Foundation

// MARK: - AnthropicModelID

/// A model identifier for Anthropic Claude models.
///
/// `AnthropicModelID` provides type-safe model identification for Anthropic's
/// Claude API. Model identifiers follow Anthropic's naming convention with
/// date-stamped versions.
///
/// ## Usage
///
/// ### Using Static Properties
/// ```swift
/// let response = try await provider.generate(
///     "Hello",
///     model: .claudeOpus45
/// )
/// ```
///
/// ### Custom Model String
/// ```swift
/// let response = try await provider.generate(
///     "Hello",
///     model: AnthropicModelID("claude-opus-4-5-20251101")
/// )
/// ```
///
/// ## Model Naming Conventions
///
/// Anthropic uses versioned model identifiers:
/// - `claude-opus-4-5-20251101` (Claude Opus 4.5, November 2025)
/// - `claude-sonnet-4-5-20250929` (Claude Sonnet 4.5, September 2025)
/// - `claude-3-5-sonnet-20241022` (Claude 3.5 Sonnet, October 2024)
///
/// The display name automatically strips the date suffix for cleaner output.
public struct AnthropicModelID: ModelIdentifying {

    // MARK: - Properties

    /// The raw model identifier string.
    ///
    /// This string is sent directly to the API in the `model` field.
    public let rawValue: String

    /// The provider type for Anthropic models.
    ///
    /// All Anthropic models use `.anthropic` for routing purposes.
    public var provider: ProviderType {
        .anthropic
    }

    /// Human-readable display name for the model.
    ///
    /// Strips the date suffix from model identifiers:
    /// - `claude-opus-4-5-20251101` -> `claude-opus-4-5`
    /// - `claude-3-5-sonnet-20241022` -> `claude-3-5-sonnet`
    public var displayName: String {
        // Remove date suffix pattern (8 digits at the end)
        let components = rawValue.components(separatedBy: "-")
        if let lastComponent = components.last,
           lastComponent.count == 8,
           lastComponent.allSatisfy({ $0.isNumber }) {
            return components.dropLast().joined(separator: "-")
        }
        return rawValue
    }

    // MARK: - Initialization

    /// Creates a model identifier from a raw string.
    ///
    /// - Parameter rawValue: The model identifier string.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a model identifier from a raw string.
    ///
    /// - Parameter rawValue: The model identifier string.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        "[Anthropic] \(rawValue)"
    }
}

// MARK: - Claude 4.5 Models

extension AnthropicModelID {

    /// Claude Opus 4.5 - Most capable model.
    ///
    /// Highest intelligence for complex, multi-step tasks.
    /// Released: November 2025
    /// Context: 200K tokens
    public static let claudeOpus45 = AnthropicModelID("claude-opus-4-5-20251101")

    /// Claude Sonnet 4.5 - Balanced model.
    ///
    /// Intelligence and speed for demanding tasks.
    /// Released: September 2025
    /// Context: 200K tokens
    public static let claudeSonnet45 = AnthropicModelID("claude-sonnet-4-5-20250929")
}

// MARK: - Claude 3.5 Models

extension AnthropicModelID {

    /// Claude 3.5 Sonnet - Enhanced reasoning.
    ///
    /// Improved intelligence with vision capabilities.
    /// Released: October 2024
    /// Context: 200K tokens
    public static let claude35Sonnet = AnthropicModelID("claude-3-5-sonnet-20241022")
}

// MARK: - Claude 3 Models

extension AnthropicModelID {

    /// Claude 3 Opus - Previous flagship.
    ///
    /// High intelligence for complex tasks.
    /// Released: February 2024
    /// Context: 200K tokens
    public static let claude3Opus = AnthropicModelID("claude-3-opus-20240229")

    /// Claude 3 Sonnet - Previous balanced model.
    ///
    /// Balanced performance and speed.
    /// Released: February 2024
    /// Context: 200K tokens
    public static let claude3Sonnet = AnthropicModelID("claude-3-sonnet-20240229")

    /// Claude 3 Haiku - Fast model.
    ///
    /// Near-instant responses for simple tasks.
    /// Released: March 2024
    /// Context: 200K tokens
    public static let claude3Haiku = AnthropicModelID("claude-3-haiku-20240307")
}

// MARK: - Claude 4.x Opus Variants

extension AnthropicModelID {

    /// Claude Opus 4 (May 2025) - Alternative Opus 4 snapshot.
    ///
    /// High-capability model for complex tasks.
    /// Released: May 2025
    /// Context: 200K tokens
    public static let claudeOpus4 = AnthropicModelID("claude-opus-4-20250514")

    /// Claude Opus 4.1 (August 2025) - Enhanced Opus variant.
    ///
    /// Improved Opus with enhanced capabilities.
    /// Released: August 2025
    /// Context: 200K tokens
    public static let claudeOpus41 = AnthropicModelID("claude-opus-4-1-20250805")
}

// MARK: - Claude 4.x Sonnet Variants

extension AnthropicModelID {

    /// Claude Sonnet 4 (May 2025) - High-performance with extended thinking.
    ///
    /// Balanced model with extended thinking support.
    /// Released: May 2025
    /// Context: 200K tokens
    public static let claudeSonnet4 = AnthropicModelID("claude-sonnet-4-20250514")
}

// MARK: - Claude 3.7 Models

extension AnthropicModelID {

    /// Claude 3.7 Sonnet - High-performance with extended thinking support.
    ///
    /// Complex tasks requiring step-by-step reasoning.
    /// Released: February 2025
    /// Context: 200K tokens
    public static let claude37Sonnet = AnthropicModelID("claude-3-7-sonnet-20250219")
}

// MARK: - Claude Haiku 4.x

extension AnthropicModelID {

    /// Claude Haiku 4.5 - Hybrid model with near-instant responses and extended thinking.
    ///
    /// Fast responses with optional deep reasoning.
    /// Released: October 2025
    /// Context: 200K tokens
    public static let claudeHaiku45 = AnthropicModelID("claude-haiku-4-5-20251001")
}

// MARK: - Claude 3.5 Haiku

extension AnthropicModelID {

    /// Claude 3.5 Haiku - Fastest and most compact model.
    ///
    /// Speed-critical applications, cost optimization.
    /// Released: October 2024
    /// Context: 200K tokens
    public static let claude35Haiku = AnthropicModelID("claude-3-5-haiku-20241022")
}

// MARK: - ExpressibleByStringLiteral

extension AnthropicModelID: ExpressibleByStringLiteral {

    /// Creates a model ID from a string literal.
    ///
    /// ## Usage
    /// ```swift
    /// let model: AnthropicModelID = "claude-opus-4-5-20251101"
    /// ```
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: - Codable

extension AnthropicModelID: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

#endif // CONDUIT_TRAIT_ANTHROPIC
