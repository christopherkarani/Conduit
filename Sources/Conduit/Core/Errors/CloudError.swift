// CloudError.swift
// Conduit

import Foundation

/// Errors specific to cloud API providers.
///
/// These errors relate to network connectivity, server responses,
/// authentication, and billing with cloud services.
public enum CloudError: Error, Sendable, LocalizedError, CustomStringConvertible {

    // MARK: - Network Errors

    /// Network request failed.
    ///
    /// Wraps `URLError` for network-related failures.
    case networkError(URLError)

    /// Server returned an error response.
    ///
    /// - Parameters:
    ///   - statusCode: HTTP status code
    ///   - message: Optional error message from the server
    case serverError(statusCode: Int, message: String?)

    /// Rate limit exceeded.
    ///
    /// - Parameter retryAfter: Seconds to wait before retrying (if known)
    case rateLimited(retryAfter: TimeInterval?)

    // MARK: - Authentication & Billing

    /// Authentication failed.
    ///
    /// API key is invalid, expired, or missing.
    case authenticationFailed(String)

    /// Payment or billing issue with the API.
    ///
    /// The account has billing issues such as insufficient credits,
    /// expired payment method, or unpaid invoices (HTTP 402).
    case billingError(String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .networkError(let urlError):
            return "Network error: \(urlError.localizedDescription)"

        case .serverError(let statusCode, let message):
            if let message = message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error: HTTP \(statusCode)"

        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(Int(seconds)) seconds"
            }
            return "Rate limited. Please try again later"

        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"

        case .billingError(let message):
            return "Billing error: \(message). Please check your payment method."
        }
    }

    /// A localized suggestion for recovering from the error.
    public var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."

        case .serverError(let statusCode, _):
            if statusCode >= 500 {
                return "The server is experiencing issues. Try again later."
            }
            return "Check your request parameters and try again."

        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Wait \(Int(seconds)) seconds before making another request."
            }
            return "Wait a moment before making more requests."

        case .authenticationFailed:
            return "Verify your API key is correct and has not expired."

        case .billingError:
            return "Update your payment method or add credits to your account."
        }
    }

    // MARK: - Retryability

    /// Whether this error may succeed if retried.
    public var isRetryable: Bool {
        switch self {
        case .networkError:
            return true

        case .serverError(let statusCode, _):
            return statusCode >= 500

        case .rateLimited:
            return true

        case .authenticationFailed, .billingError:
            return false
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        errorDescription ?? "Unknown cloud error"
    }
}
