// MiniMaxAuthentication.swift
// Conduit
//
// Authentication configuration for MiniMax API.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Foundation

struct MiniMaxAuthentication: Sendable, Hashable, Codable {

    enum AuthType: Sendable, Hashable, Codable {
        case apiKey(String)
        case auto
    }

    let type: AuthType

    init(type: AuthType) {
        self.type = type
    }

    static func apiKey(_ key: String) -> MiniMaxAuthentication {
        MiniMaxAuthentication(type: .apiKey(key))
    }

    static let auto = MiniMaxAuthentication(type: .auto)

    var apiKey: String? {
        switch type {
        case .apiKey(let key): return key
        case .auto: return ProcessInfo.processInfo.environment["MINIMAX_API_KEY"]
        }
    }

    var isValid: Bool {
        apiKey?.isEmpty == false
    }
}

extension MiniMaxAuthentication: CustomDebugStringConvertible {
    var debugDescription: String {
        switch type {
        case .apiKey: return "MiniMaxAuthentication.apiKey(***)"
        case .auto: return "MiniMaxAuthentication.auto"
        }
    }
}

#endif // CONDUIT_TRAIT_MINIMAX
