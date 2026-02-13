// KimiAuthentication.swift
// Conduit
//
// Authentication configuration for Moonshot Kimi API.

#if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
import Foundation

// MARK: - KimiAuthentication

/// Authentication configuration for Moonshot Kimi API.
///
/// Manages API key authentication for Kimi's API. Supports
/// explicit keys or automatic environment variable detection.
///
/// ## Usage
/// ```swift
/// let auth = KimiAuthentication.apiKey("sk-moonshot-...")
/// let auth = KimiAuthentication.auto  // Checks MOONSHOT_API_KEY
/// ```
public struct KimiAuthentication: Sendable, Hashable, Codable {

    public enum AuthType: Sendable, Hashable, Codable {
        case apiKey(String)
        case auto
    }

    public let type: AuthType

    public init(type: AuthType) {
        self.type = type
    }

    public static func apiKey(_ key: String) -> KimiAuthentication {
        KimiAuthentication(type: .apiKey(key))
    }

    /// Auto-detect from `MOONSHOT_API_KEY` environment variable.
    public static let auto = KimiAuthentication(type: .auto)

    public var apiKey: String? {
        switch type {
        case .apiKey(let key): return key
        case .auto: return ProcessInfo.processInfo.environment["MOONSHOT_API_KEY"]
        }
    }

    public var isValid: Bool {
        apiKey?.isEmpty == false
    }
}

// MARK: - Debug

extension KimiAuthentication: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch type {
        case .apiKey: return "KimiAuthentication.apiKey(***)"
        case .auto: return "KimiAuthentication.auto"
        }
    }
}

#endif // CONDUIT_TRAIT_KIMI
