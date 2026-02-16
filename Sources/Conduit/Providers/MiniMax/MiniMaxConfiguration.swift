// MiniMaxConfiguration.swift
// Conduit
//
// Configuration for MiniMax API.

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
import Foundation

public struct MiniMaxConfiguration: Sendable, Hashable, Codable {

    public var authentication: MiniMaxAuthentication
    public var baseURL: URL
    public var timeout: TimeInterval
    public var maxRetries: Int

    public init(
        authentication: MiniMaxAuthentication = .auto,
        baseURL: URL = URL(string: "https://minimax-m2.com/api/v1")!,
        timeout: TimeInterval = 120.0,
        maxRetries: Int = 3
    ) {
        self.authentication = authentication
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
    }

    public static func standard(apiKey: String) -> MiniMaxConfiguration {
        MiniMaxConfiguration(authentication: .apiKey(apiKey))
    }

    public var hasValidAuthentication: Bool {
        authentication.isValid
    }
}

extension MiniMaxConfiguration {
    public func apiKey(_ key: String) -> MiniMaxConfiguration {
        var copy = self
        copy.authentication = .apiKey(key)
        return copy
    }

    public func timeout(_ seconds: TimeInterval) -> MiniMaxConfiguration {
        var copy = self
        copy.timeout = max(0, seconds)
        return copy
    }

    public func maxRetries(_ count: Int) -> MiniMaxConfiguration {
        var copy = self
        copy.maxRetries = max(0, count)
        return copy
    }
}

#endif // CONDUIT_TRAIT_MINIMAX
