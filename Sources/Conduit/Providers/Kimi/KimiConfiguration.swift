// KimiConfiguration.swift
// Conduit
//
// Configuration for Moonshot Kimi API.

#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
import Foundation

// MARK: - KimiConfiguration

/// Configuration for Moonshot Kimi API.
///
/// Provides unified configuration for the Kimi API with sensible
/// defaults for the 256K context window.
///
/// ## Usage
/// ```swift
/// let config = KimiConfiguration.standard(apiKey: "sk-moonshot-...")
/// let provider = KimiProvider(configuration: config)
/// ```
public struct KimiConfiguration: Sendable, Hashable, Codable {

    // MARK: - Properties

    public var authentication: KimiAuthentication
    public var baseURL: URL
    public var timeout: TimeInterval
    public var maxRetries: Int

    // MARK: - Initialization

    public init(
        authentication: KimiAuthentication = .auto,
        baseURL: URL = URL(string: "https://api.moonshot.cn/v1")!,
        timeout: TimeInterval = 120.0,
        maxRetries: Int = 3
    ) {
        self.authentication = authentication
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
    }

    // MARK: - Static Factories

    public static func standard(apiKey: String) -> KimiConfiguration {
        KimiConfiguration(authentication: .apiKey(apiKey))
    }

    // MARK: - Computed

    public var hasValidAuthentication: Bool {
        authentication.isValid
    }
}

// MARK: - Fluent API

extension KimiConfiguration {
    public func apiKey(_ key: String) -> KimiConfiguration {
        var copy = self
        copy.authentication = .apiKey(key)
        return copy
    }

    public func timeout(_ seconds: TimeInterval) -> KimiConfiguration {
        var copy = self
        copy.timeout = max(0, seconds)
        return copy
    }

    public func maxRetries(_ count: Int) -> KimiConfiguration {
        var copy = self
        copy.maxRetries = max(0, count)
        return copy
    }
}

#endif // CONDUIT_TRAIT_KIMI
