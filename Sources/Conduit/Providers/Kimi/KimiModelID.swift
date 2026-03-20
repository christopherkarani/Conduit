// KimiModelID.swift
// Conduit
//
// Model identifiers for Moonshot Kimi API.

#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
import Foundation

// MARK: - KimiModelID

/// A model identifier for Moonshot Kimi models.
///
/// `KimiModelID` provides type-safe model identification for Moonshot's
/// Kimi API. Kimi models feature 256K context windows and strong
/// reasoning capabilities.
///
/// ## Usage
/// ```swift
/// let response = try await provider.generate(
///     "Hello",
///     model: .kimiK2_5
/// )
/// ```
///
/// ## Available Models
///
/// | Model | Context | Best For |
/// |-------|---------|----------|
/// | `kimi-k2-5` | 256K | Complex reasoning, coding |
/// | `kimi-k2` | 256K | General purpose |
/// | `kimi-k1-5` | 256K | Long context tasks |
public struct KimiModelID: ModelIdentifying {

    public let rawValue: String

    public var provider: ProviderType { .kimi }

    public var displayName: String {
        rawValue
            .replacingOccurrences(of: "kimi-", with: "Kimi ")
            .replacingOccurrences(of: "-", with: ".")
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { "[Kimi] \(rawValue)" }
}

// MARK: - Predefined Models

extension KimiModelID {
    /// Kimi K2.5 - Latest flagship with advanced reasoning.
    public static let kimiK2_5 = KimiModelID("kimi-k2-5")

    /// Kimi K2 - General-purpose model.
    public static let kimiK2 = KimiModelID("kimi-k2")

    /// Kimi K1.5 - Long context specialist.
    public static let kimiK1_5 = KimiModelID("kimi-k1-5")

    /// Kimi Latest - Platform alias for the latest general model.
    public static let kimiLatest = KimiModelID("kimi-latest")

    /// Kimi Thinking Preview - Original reasoning model.
    public static let kimiThinkingPreview = KimiModelID("kimi-thinking-preview")

    /// Kimi K2 preview snapshot released in July 2025.
    public static let kimiK2Preview = KimiModelID("kimi-k2-0711-preview")

    /// Kimi K2 preview snapshot released in September 2025.
    public static let kimiK2_0905Preview = KimiModelID("kimi-k2-0905-preview")

    /// Kimi K2 Turbo preview - fast K2 variant.
    public static let kimiK2TurboPreview = KimiModelID("kimi-k2-turbo-preview")

    /// Kimi K2 Thinking Turbo - current latest thinking model.
    public static let kimiK2ThinkingTurbo = KimiModelID("kimi-k2-thinking-turbo")
}

// MARK: - Conformances

extension KimiModelID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension KimiModelID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

#endif // CONDUIT_TRAIT_KIMI
