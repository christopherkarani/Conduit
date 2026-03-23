// MiniMaxConfiguration.swift
// Conduit
//
// Configuration for MiniMax API.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Foundation

struct MiniMaxConfiguration: Sendable, Hashable, Codable {

    var authentication: MiniMaxAuthentication
    var baseURL: URL
    var timeout: TimeInterval
    var maxRetries: Int

    init(
        authentication: MiniMaxAuthentication = .auto,
        baseURL: URL = URL(string: "https://api.minimax.io/v1")!,
        timeout: TimeInterval = 120.0,
        maxRetries: Int = 3
    ) {
        self.authentication = authentication
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
    }

    static func standard(apiKey: String? = nil) -> MiniMaxConfiguration {
        MiniMaxConfiguration(authentication: apiKey.map(MiniMaxAuthentication.apiKey) ?? .auto)
    }

    var hasValidAuthentication: Bool {
        authentication.isValid
    }
}

extension MiniMaxConfiguration {
    func apiKey(_ key: String) -> MiniMaxConfiguration {
        var copy = self
        copy.authentication = .apiKey(key)
        return copy
    }

    func timeout(_ seconds: TimeInterval) -> MiniMaxConfiguration {
        var copy = self
        copy.timeout = max(0, seconds)
        return copy
    }

    func maxRetries(_ count: Int) -> MiniMaxConfiguration {
        var copy = self
        copy.maxRetries = max(0, count)
        return copy
    }
}

#endif // CONDUIT_TRAIT_MINIMAX
