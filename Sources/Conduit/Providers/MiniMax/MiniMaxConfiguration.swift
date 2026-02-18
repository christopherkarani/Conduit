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

// MARK: - Anthropic-Compatible Messages API

#if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI && CONDUIT_TRAIT_ANTHROPIC

extension MiniMaxConfiguration {

    /// Base URL for MiniMax's Anthropic-compatible Messages API.
    ///
    /// MiniMax hosts both an OpenAI-compatible Chat Completions endpoint
    /// and an Anthropic-compatible Messages endpoint. They use different
    /// authentication headers and request formats.
    ///
    /// Use this with ``AnthropicConfiguration`` to access the Messages endpoint.
    ///
    /// - SeeAlso: ``anthropicCompatible(apiKey:)``
    public static let messagesBaseURL = URL(string: "https://minimax-m2.com/api")!

    /// Creates an ``AnthropicConfiguration`` targeting MiniMax's Messages API.
    ///
    /// MiniMax's Messages API mirrors the Anthropic Claude API format and uses:
    /// - `x-api-key` header for authentication (not `Authorization: Bearer`)
    /// - `Anthropic-Version: 2023-06-01` header (required)
    /// - `POST /api/v1/messages` endpoint
    ///
    /// This is distinct from ``MiniMaxProvider``, which uses the OpenAI-compatible
    /// Chat Completions endpoint (`POST /api/v1/chat/completions`) with Bearer auth.
    ///
    /// - Note: The Messages API does **not** support streaming. Use non-streaming
    ///   `generate()` calls with an ``AnthropicProvider`` configured via this method.
    ///   For streaming, use ``MiniMaxProvider`` instead.
    ///
    /// ## Usage
    /// ```swift
    /// let config = try MiniMaxConfiguration.anthropicCompatible(apiKey: "your-key")
    /// let provider = AnthropicProvider(configuration: config)
    /// let result = try await provider.generate(
    ///     messages: [.user("Hello")],
    ///     model: AnthropicModelID("MiniMax-M2"),
    ///     config: .default
    /// )
    /// ```
    ///
    /// - Parameter apiKey: Your MiniMax API key.
    /// - Returns: An ``AnthropicConfiguration`` pointed at MiniMax's Messages API.
    /// - Throws: `AIError.invalidInput` if the base URL is invalid.
    public static func anthropicCompatible(apiKey: String) throws -> AnthropicConfiguration {
        try AnthropicConfiguration(
            authentication: .apiKey(apiKey),
            baseURL: messagesBaseURL
        )
    }
}

#endif // CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI && CONDUIT_TRAIT_ANTHROPIC
