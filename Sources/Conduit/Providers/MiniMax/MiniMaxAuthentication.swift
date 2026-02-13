// MiniMaxAuthentication.swift
// Conduit
//
// Authentication configuration for MiniMax API.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Foundation

public struct MiniMaxAuthentication: Sendable, Hashable, Codable {

    public enum AuthType: Sendable, Hashable, Codable {
        case apiKey(String)
        case auto
    }

    public let type: AuthType

    public init(type: AuthType) {
        self.type = type
    }

    public static func apiKey(_ key: String) -> MiniMaxAuthentication {
        MiniMaxAuthentication(type: .apiKey(key))
    }

    public static let auto = MiniMaxAuthentication(type: .auto)

    public var apiKey: String? {
        switch type {
        case .apiKey(let key): return key
        case .auto: return ProcessInfo.processInfo.environment["MINIMAX_API_KEY"]
        }
    }

    public var isValid: Bool {
        apiKey?.isEmpty == false
    }
}

extension MiniMaxAuthentication: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch type {
        case .apiKey: return "MiniMaxAuthentication.apiKey(***)"
        case .auto: return "MiniMaxAuthentication.auto"
        }
    }
}

#endif // CONDUIT_TRAIT_MINIMAX
