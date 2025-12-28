// AnthropicAuthentication.swift
// SwiftAI
//
// Authentication configuration for Anthropic API.

import Foundation

// MARK: - AnthropicAuthentication

/// Authentication configuration for Anthropic Claude API.
///
/// Manages API key authentication for Anthropic's API. Supports
/// explicit keys or automatic environment variable detection.
///
/// ## Usage
///
/// ### Explicit API Key
/// ```swift
/// let auth = AnthropicAuthentication.apiKey("sk-ant-...")
/// ```
///
/// ### Environment Variable
/// ```swift
/// let auth = AnthropicAuthentication.auto
/// // Checks ANTHROPIC_API_KEY environment variable
/// ```
///
/// ## Security
///
/// API keys are automatically redacted in debug output to prevent
/// accidental exposure in logs.
public struct AnthropicAuthentication: Sendable, Hashable, Codable {

    // MARK: - AuthType

    /// The authentication type.
    public enum AuthType: Sendable, Hashable, Codable {
        /// Explicit API key.
        ///
        /// - Parameter key: The Anthropic API key (starts with "sk-ant-").
        case apiKey(String)

        /// Auto-detect from environment.
        ///
        /// Checks the `ANTHROPIC_API_KEY` environment variable.
        case auto
    }

    // MARK: - Properties

    /// The authentication type.
    public let type: AuthType

    // MARK: - Initialization

    /// Creates authentication with the specified type.
    ///
    /// - Parameter type: The authentication type.
    public init(type: AuthType) {
        self.type = type
    }

    // MARK: - Static Factories

    /// Creates authentication with an explicit API key.
    ///
    /// - Parameter key: The Anthropic API key.
    /// - Returns: An authentication instance.
    public static func apiKey(_ key: String) -> AnthropicAuthentication {
        AnthropicAuthentication(type: .apiKey(key))
    }

    /// Auto-detect authentication from environment variables.
    ///
    /// Checks the `ANTHROPIC_API_KEY` environment variable.
    public static let auto = AnthropicAuthentication(type: .auto)

    // MARK: - Computed Properties

    /// The resolved API key.
    ///
    /// For `.apiKey`, returns the explicit key.
    /// For `.auto`, checks the `ANTHROPIC_API_KEY` environment variable.
    ///
    /// - Returns: The API key, or `nil` if not configured.
    public var apiKey: String? {
        switch type {
        case .apiKey(let key):
            return key
        case .auto:
            return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        }
    }

    /// Whether this authentication is configured with a valid key.
    ///
    /// Returns `true` if the API key is non-nil and non-empty.
    public var isValid: Bool {
        guard let key = apiKey else {
            return false
        }
        return !key.isEmpty
    }
}

// MARK: - Constant-Time Comparison

private extension String {
    /// Constant-time comparison to prevent timing attacks on credentials.
    ///
    /// Standard string comparison can leak information about how many characters
    /// match before a mismatch is found. This implementation compares all bytes
    /// regardless of where differences occur.
    func constantTimeCompare(to other: String) -> Bool {
        let lhs = Array(self.utf8)
        let rhs = Array(other.utf8)

        // Length mismatch - still do constant-time work to avoid length leak
        guard lhs.count == rhs.count else {
            // XOR all bytes anyway to maintain constant time
            var result: UInt8 = 1  // Start with 1 to indicate length mismatch
            let maxLen = max(lhs.count, rhs.count)
            for i in 0..<maxLen {
                let a = i < lhs.count ? lhs[i] : 0
                let b = i < rhs.count ? rhs[i] : 0
                result |= a ^ b
            }
            return false
        }

        var result: UInt8 = 0
        for i in 0..<lhs.count {
            result |= lhs[i] ^ rhs[i]
        }
        return result == 0
    }
}

// MARK: - Equatable

extension AnthropicAuthentication.AuthType: Equatable {
    /// Compares two authentication types for equality.
    ///
    /// **Security**: Uses constant-time comparison for API keys to prevent
    /// timing attacks that could leak credential information.
    public static func == (lhs: AnthropicAuthentication.AuthType, rhs: AnthropicAuthentication.AuthType) -> Bool {
        switch (lhs, rhs) {
        case (.apiKey(let lhsKey), .apiKey(let rhsKey)):
            return lhsKey.constantTimeCompare(to: rhsKey)
        case (.auto, .auto):
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension AnthropicAuthentication: CustomDebugStringConvertible {
    /// A debug description with redacted credentials.
    ///
    /// API keys are replaced with `***` to prevent accidental
    /// exposure in logs.
    public var debugDescription: String {
        switch type {
        case .apiKey:
            return "AnthropicAuthentication.apiKey(***)"
        case .auto:
            return "AnthropicAuthentication.auto"
        }
    }
}

// MARK: - CustomStringConvertible

extension AnthropicAuthentication: CustomStringConvertible {
    public var description: String {
        debugDescription
    }
}
