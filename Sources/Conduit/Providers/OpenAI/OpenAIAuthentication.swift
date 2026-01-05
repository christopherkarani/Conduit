// OpenAIAuthentication.swift
// Conduit
//
// Authentication types for OpenAI-compatible providers.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - OpenAIAuthentication

/// Authentication configuration for OpenAI-compatible APIs.
///
/// Different OpenAI-compatible backends use different authentication schemes:
/// - **OpenAI/OpenRouter**: Bearer token in Authorization header
/// - **Azure**: API key in a custom header
/// - **Ollama**: No authentication (local server)
///
/// ## Usage
///
/// ### Bearer Token (OpenAI, OpenRouter)
/// ```swift
/// let auth = OpenAIAuthentication.bearer("sk-...")
/// ```
///
/// ### API Key Header (Azure)
/// ```swift
/// let auth = OpenAIAuthentication.apiKey("azure-key", headerName: "api-key")
/// ```
///
/// ### No Authentication (Ollama)
/// ```swift
/// let auth = OpenAIAuthentication.none
/// ```
///
/// ### Environment Variable
/// ```swift
/// let auth = OpenAIAuthentication.environment("OPENAI_API_KEY")
/// ```
///
/// ### Auto-Detection
/// ```swift
/// let auth = OpenAIAuthentication.auto
/// // Checks: OPENAI_API_KEY, OPENROUTER_API_KEY, etc.
/// ```
///
/// ## Security
///
/// Authentication values are automatically redacted in debug output
/// to prevent accidental exposure in logs.
public enum OpenAIAuthentication: Sendable {

    // MARK: - Cases

    /// No authentication required.
    ///
    /// Use this for local servers like Ollama that don't require authentication.
    case none

    /// Bearer token authentication.
    ///
    /// The token is sent in the `Authorization` header as:
    /// `Authorization: Bearer {token}`
    ///
    /// This is the standard authentication for OpenAI and OpenRouter.
    ///
    /// - Parameter token: The API key or access token.
    case bearer(String)

    /// API key in a custom header.
    ///
    /// The key is sent in a custom header:
    /// `{headerName}: {key}`
    ///
    /// This is used by Azure OpenAI Service.
    ///
    /// - Parameters:
    ///   - key: The API key value.
    ///   - headerName: The header name. Default: `"api-key"`
    case apiKey(String, headerName: String = "api-key")

    /// Load API key from an environment variable.
    ///
    /// The key is resolved at runtime from the specified environment variable.
    ///
    /// - Parameter variableName: The environment variable name.
    case environment(String)

    /// Auto-detect authentication from common environment variables.
    ///
    /// Checks the following environment variables in order:
    /// 1. `OPENAI_API_KEY`
    /// 2. `OPENROUTER_API_KEY`
    /// 3. `AZURE_OPENAI_API_KEY`
    ///
    /// Falls back to `.none` if no variables are set.
    case auto

    // MARK: - Resolution

    /// Resolves the authentication to an API key string.
    ///
    /// - Returns: The API key, or `nil` if no authentication is configured.
    public func resolve() -> String? {
        switch self {
        case .none:
            return nil

        case .bearer(let token):
            return token

        case .apiKey(let key, _):
            return key

        case .environment(let variableName):
            return ProcessInfo.processInfo.environment[variableName]

        case .auto:
            let variables = [
                "OPENAI_API_KEY",
                "OPENROUTER_API_KEY",
                "AZURE_OPENAI_API_KEY"
            ]
            for variable in variables {
                if let value = ProcessInfo.processInfo.environment[variable],
                   !value.isEmpty {
                    return value
                }
            }
            return nil
        }
    }

    /// Whether this authentication is configured with a valid key.
    ///
    /// For `.environment` and `.auto`, this checks if the environment
    /// variable is set and non-empty.
    public var isConfigured: Bool {
        switch self {
        case .none:
            return true  // None is intentionally "configured"
        case .bearer(let token):
            return !token.isEmpty
        case .apiKey(let key, _):
            return !key.isEmpty
        case .environment, .auto:
            return resolve() != nil
        }
    }

    /// The header name for this authentication type.
    ///
    /// - Returns: The header name, or `nil` for `.none`.
    public var headerName: String? {
        switch self {
        case .none:
            return nil
        case .bearer:
            return "Authorization"
        case .apiKey(_, let name):
            return name
        case .environment, .auto:
            // Environment-based auth uses Bearer by default
            return "Authorization"
        }
    }

    /// The header value for this authentication type.
    ///
    /// - Returns: The full header value (e.g., "Bearer sk-..."), or `nil` if not configured.
    public var headerValue: String? {
        switch self {
        case .none:
            return nil

        case .bearer(let token):
            return "Bearer \(token)"

        case .apiKey(let key, _):
            return key

        case .environment(let variableName):
            guard let key = ProcessInfo.processInfo.environment[variableName] else {
                return nil
            }
            return "Bearer \(key)"

        case .auto:
            guard let key = resolve() else {
                return nil
            }
            return "Bearer \(key)"
        }
    }

    /// Applies this authentication to a URL request.
    ///
    /// - Parameter request: The request to modify.
    /// - Returns: The request with authentication headers added.
    public func apply(to request: inout URLRequest) {
        guard let name = headerName, let value = headerValue else {
            return
        }
        request.setValue(value, forHTTPHeaderField: name)
    }
}

// MARK: - Hashable

extension OpenAIAuthentication: Hashable {
    /// Hashes the authentication type without exposing sensitive credentials.
    ///
    /// **Security**: Only the discriminator (case type) and non-sensitive values
    /// are hashed. API keys and tokens are NOT included in the hash to prevent
    /// exposure through hash collision analysis or debug output.
    ///
    /// This means two `.bearer("key1")` and `.bearer("key2")` will hash identically,
    /// which is acceptable since Hashable is primarily used for dictionary keys
    /// and the equality check (==) will still distinguish them correctly.
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .none:
            hasher.combine(0)
        case .bearer:
            // Only hash the case discriminator, NOT the token
            hasher.combine(1)
        case .apiKey(_, let headerName):
            // Only hash the case discriminator and header name, NOT the key
            hasher.combine(2)
            hasher.combine(headerName)
        case .environment(let variableName):
            // Variable name is not sensitive
            hasher.combine(3)
            hasher.combine(variableName)
        case .auto:
            hasher.combine(4)
        }
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

extension OpenAIAuthentication: Equatable {
    /// Compares two authentication instances for equality.
    ///
    /// **Security**: Uses constant-time comparison for API keys and tokens
    /// to prevent timing attacks that could leak credential information.
    /// Non-sensitive fields like header names and environment variable names
    /// use standard comparison.
    public static func == (lhs: OpenAIAuthentication, rhs: OpenAIAuthentication) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.bearer(let lhsToken), .bearer(let rhsToken)):
            return lhsToken.constantTimeCompare(to: rhsToken)
        case (.apiKey(let lhsKey, let lhsHeader), .apiKey(let rhsKey, let rhsHeader)):
            // Constant-time for the key, regular comparison for header name (not sensitive)
            return lhsKey.constantTimeCompare(to: rhsKey) && lhsHeader == rhsHeader
        case (.environment(let lhsVariable), .environment(let rhsVariable)):
            // Environment variable names are not sensitive
            return lhsVariable == rhsVariable
        case (.auto, .auto):
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension OpenAIAuthentication: CustomDebugStringConvertible {
    /// A debug description with redacted credentials.
    ///
    /// API keys and tokens are replaced with `***` to prevent
    /// accidental exposure in logs.
    public var debugDescription: String {
        switch self {
        case .none:
            return "OpenAIAuthentication.none"
        case .bearer:
            return "OpenAIAuthentication.bearer(***)"
        case .apiKey(_, let headerName):
            return "OpenAIAuthentication.apiKey(***, headerName: \"\(headerName)\")"
        case .environment(let variableName):
            return "OpenAIAuthentication.environment(\"\(variableName)\")"
        case .auto:
            return "OpenAIAuthentication.auto"
        }
    }
}

// MARK: - CustomStringConvertible

extension OpenAIAuthentication: CustomStringConvertible {
    public var description: String {
        debugDescription
    }
}

// MARK: - Convenience Initializers

extension OpenAIAuthentication {

    /// Creates a bearer authentication from an API key string.
    ///
    /// This is equivalent to `.bearer(apiKey)`.
    ///
    /// - Parameter apiKey: The API key.
    /// - Returns: A bearer authentication.
    public static func from(apiKey: String) -> OpenAIAuthentication {
        .bearer(apiKey)
    }

    /// Creates authentication appropriate for the given endpoint.
    ///
    /// - Parameters:
    ///   - endpoint: The OpenAI endpoint.
    ///   - apiKey: The API key (optional for Ollama).
    /// - Returns: The appropriate authentication for the endpoint.
    public static func `for`(
        endpoint: OpenAIEndpoint,
        apiKey: String? = nil
    ) -> OpenAIAuthentication {
        switch endpoint {
        case .ollama:
            return .none

        case .azure:
            guard let key = apiKey else {
                return .environment("AZURE_OPENAI_API_KEY")
            }
            return .apiKey(key, headerName: "api-key")

        case .openAI:
            guard let key = apiKey else {
                return .environment("OPENAI_API_KEY")
            }
            return .bearer(key)

        case .openRouter:
            guard let key = apiKey else {
                return .environment("OPENROUTER_API_KEY")
            }
            return .bearer(key)

        case .custom:
            guard let key = apiKey else {
                return .auto
            }
            return .bearer(key)
        }
    }
}
