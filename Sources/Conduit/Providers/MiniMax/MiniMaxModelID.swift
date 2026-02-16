// MiniMaxModelID.swift
// Conduit
//
// Model identifiers for MiniMax API.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Foundation

public struct MiniMaxModelID: ModelIdentifying {

    public let rawValue: String

    public var provider: ProviderType { .minimax }

    public var displayName: String {
        rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { "[MiniMax] \(rawValue)" }
}

extension MiniMaxModelID {
    public static let minimaxM2 = MiniMaxModelID("MiniMax-M2")
    public static let minimaxM2_1 = MiniMaxModelID("MiniMax-M2.1")
    public static let minimaxM2_5 = MiniMaxModelID("MiniMax-M2.5")
}

extension MiniMaxModelID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

extension MiniMaxModelID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

#endif // CONDUIT_TRAIT_MINIMAX
