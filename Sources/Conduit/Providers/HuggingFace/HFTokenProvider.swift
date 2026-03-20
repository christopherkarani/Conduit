// HFTokenProvider.swift
// Conduit

import Foundation
#if canImport(Security)
import Security
#endif

/// Token provider for HuggingFace authentication.
///
/// `HFTokenProvider` manages authentication tokens for the HuggingFace Inference API.
/// It supports multiple resolution strategies, from automatic environment variable
/// detection to explicit keychain access.
///
/// ## Resolution Order
///
/// When using `.auto`, tokens are resolved in this order:
/// 1. `HF_TOKEN` environment variable
/// 2. `HUGGING_FACE_HUB_TOKEN` environment variable
/// 3. Returns `nil` if neither is set
///
/// ## Usage
///
/// ```swift
/// // Automatic resolution from environment
/// let config = HFConfiguration(tokenProvider: .auto)
///
/// // Explicit token
/// let config = HFConfiguration(tokenProvider: .static("hf_..."))
///
/// // Keychain-based (macOS/iOS)
/// let config = HFConfiguration(
///     tokenProvider: .keychain(
///         service: "com.example.app",
///         account: "huggingface-token"
///     )
/// )
///
/// // No authentication (public models only)
/// let config = HFConfiguration(tokenProvider: .none)
/// ```
///
/// ## Security
///
/// - Tokens are never logged or printed in debug descriptions
/// - Keychain access uses `kSecAttrAccessibleWhenUnlocked` (default)
/// - Static tokens should be loaded from secure storage, not hardcoded
///
/// ## Thread Safety
///
/// `HFTokenProvider` conforms to `Sendable` and is safe to share across actors.
/// Keychain reads are synchronous and thread-safe.
enum HFTokenProvider: Sendable, Hashable {

    /// Automatically resolve token from environment variables.
    ///
    /// Checks `HF_TOKEN` first, then `HUGGING_FACE_HUB_TOKEN`.
    /// This is the recommended approach for local development and CI environments.
    case auto

    /// Use a statically provided token.
    ///
    /// - Parameter token: The HuggingFace API token (starts with "hf_")
    ///
    /// - Warning: Do not hardcode tokens in source code. Load from secure storage
    ///   like Keychain or environment variables.
    case `static`(String)

    /// Load token from macOS/iOS Keychain.
    ///
    /// - Parameters:
    ///   - service: The keychain service identifier
    ///   - account: The keychain account name
    ///
    /// Uses `kSecClassGenericPassword` with the specified service and account.
    case keychain(service: String, account: String)

    /// No authentication token provided.
    ///
    /// Only works with public models that don't require authentication.
    /// Most HuggingFace models require authentication.
    case none

    // MARK: - Token Resolution

    /// Resolves the authentication token based on the provider strategy.
    ///
    /// - Returns: The resolved token, or `nil` if unavailable.
    ///
    /// ## Resolution Behavior
    /// - `.auto`: Checks environment variables in order
    /// - `.static(token)`: Returns the provided token
    /// - `.keychain(service, account)`: Reads from Keychain (returns `nil` if not found)
    /// - `.none`: Returns `nil`
    ///
    /// - Note: This property performs I/O for `.keychain` and is not cached.
    ///   Consider caching the result if called frequently.
    var token: String? {
        switch self {
        case .auto:
            return resolveFromEnvironment()

        case .static(let token):
            return token

        case .keychain(let service, let account):
            return resolveFromKeychain(service: service, account: account)

        case .none:
            return nil
        }
    }

    /// Whether a token is configured and available.
    ///
    /// Returns `true` if token resolution would return a non-empty string.
    /// Use this for quick availability checks without resolving the full token.
    ///
    /// - Returns: `true` if a token is available, `false` otherwise.
    var isConfigured: Bool {
        guard let resolved = token else { return false }
        return !resolved.isEmpty
    }

    // MARK: - Private Resolution Methods

    private func resolveFromEnvironment() -> String? {
        let environment = ProcessInfo.processInfo.environment

        // Check HF_TOKEN first (newer convention)
        if let token = environment["HF_TOKEN"], !token.isEmpty {
            return token
        }

        // Fall back to HUGGING_FACE_HUB_TOKEN (legacy)
        if let token = environment["HUGGING_FACE_HUB_TOKEN"], !token.isEmpty {
            return token
        }

        return nil
    }

    private func resolveFromKeychain(service: String, account: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
        #else
        // Security framework not available on this platform
        return nil
        #endif
    }
}

// MARK: - Hashable Conformance

extension HFTokenProvider {

    func hash(into hasher: inout Hasher) {
        // Only hash token presence, not value, to prevent credential leakage in logs/debug output
        switch self {
        case .auto:
            hasher.combine("auto")
        case .static(let token):
            hasher.combine("static")
            hasher.combine(!token.isEmpty)
        case .keychain(let service, let account):
            hasher.combine("keychain")
            hasher.combine(service)
            hasher.combine(account)
        case .none:
            hasher.combine("none")
        }
    }

    static func == (lhs: HFTokenProvider, rhs: HFTokenProvider) -> Bool {
        switch (lhs, rhs) {
        case (.auto, .auto):
            return true
        case (.static(let lhsToken), .static(let rhsToken)):
            // Use constant-time comparison via Data to prevent timing attacks
            let lhsData = Data(lhsToken.utf8)
            let rhsData = Data(rhsToken.utf8)
            guard lhsData.count == rhsData.count else { return false }
            var result: UInt8 = 0
            for (lhsByte, rhsByte) in zip(lhsData, rhsData) {
                result |= lhsByte ^ rhsByte
            }
            return result == 0
        case (.keychain(let lhsService, let lhsAccount), .keychain(let rhsService, let rhsAccount)):
            return lhsService == rhsService && lhsAccount == rhsAccount
        case (.none, .none):
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension HFTokenProvider: CustomStringConvertible {

    /// A description that does not expose the actual token value.
    var description: String {
        switch self {
        case .auto:
            return "HFTokenProvider.auto"
        case .static:
            return "HFTokenProvider.static(<redacted>)"
        case .keychain(let service, let account):
            return "HFTokenProvider.keychain(service: \"\(service)\", account: \"\(account)\")"
        case .none:
            return "HFTokenProvider.none"
        }
    }
}
