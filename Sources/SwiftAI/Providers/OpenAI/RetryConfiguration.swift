// RetryConfiguration.swift
// SwiftAI
//
// Retry and resilience configuration for OpenAI-compatible providers.

import Foundation

// MARK: - RetryConfiguration

/// Configuration for retry behavior in OpenAI-compatible providers.
///
/// Controls how failed requests are retried, including delay strategies,
/// maximum attempts, and which errors are retryable.
///
/// ## Usage
///
/// ### Default Configuration
/// ```swift
/// let config = RetryConfiguration.default
/// // 3 retries, exponential backoff, 1s base delay
/// ```
///
/// ### Aggressive Retry
/// ```swift
/// let config = RetryConfiguration.aggressive
/// // 5 retries, shorter delays
/// ```
///
/// ### Custom Configuration
/// ```swift
/// let config = RetryConfiguration(
///     maxRetries: 5,
///     baseDelay: 2.0,
///     maxDelay: 60.0,
///     strategy: .exponentialWithJitter()
/// )
/// ```
///
/// ### Fluent API
/// ```swift
/// let config = RetryConfiguration.default
///     .maxRetries(5)
///     .baseDelay(0.5)
///     .strategy(.fixed(delay: 1.0))
/// ```
///
/// ## Retry Strategies
///
/// - **immediate**: No delay between retries
/// - **fixed**: Constant delay between retries
/// - **exponentialBackoff**: Delay doubles each retry
/// - **exponentialWithJitter**: Exponential with randomization to prevent thundering herd
public struct RetryConfiguration: Sendable, Hashable {

    // MARK: - Properties

    /// Maximum number of retry attempts.
    ///
    /// Set to 0 to disable retries entirely.
    /// Default: 3
    public var maxRetries: Int

    /// Base delay before first retry (in seconds).
    ///
    /// Used as the starting point for backoff calculations.
    /// Default: 1.0
    public var baseDelay: TimeInterval

    /// Maximum delay between retries (in seconds).
    ///
    /// Caps the delay to prevent excessively long waits.
    /// Default: 30.0
    public var maxDelay: TimeInterval

    /// The retry delay strategy.
    ///
    /// Determines how delay increases between retries.
    /// Default: `.exponentialBackoff()`
    public var strategy: RetryStrategy

    /// HTTP status codes that should trigger a retry.
    ///
    /// Default: 408, 429, 500, 502, 503, 504
    public var retryableStatusCodes: Set<Int>

    /// Error types that should trigger a retry.
    ///
    /// Default: timeout, connectionLost, serverError, rateLimited
    public var retryableErrors: Set<RetryableErrorType>

    // MARK: - Initialization

    /// Creates a retry configuration with custom settings.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum retry attempts. Default: 3
    ///   - baseDelay: Base delay in seconds. Default: 1.0
    ///   - maxDelay: Maximum delay cap in seconds. Default: 30.0
    ///   - strategy: Retry delay strategy. Default: `.exponentialBackoff()`
    ///   - retryableStatusCodes: HTTP codes to retry. Default: 408, 429, 500, 502, 503, 504
    ///   - retryableErrors: Error types to retry. Default: timeout, connectionLost, serverError, rateLimited
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        strategy: RetryStrategy = .exponentialBackoff(),
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        retryableErrors: Set<RetryableErrorType> = [.timeout, .connectionLost, .serverError, .rateLimited]
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.strategy = strategy
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableErrors = retryableErrors
    }

    // MARK: - Static Presets

    /// Default retry configuration.
    ///
    /// Balanced settings for typical API usage.
    ///
    /// ## Configuration
    /// - maxRetries: 3
    /// - baseDelay: 1.0s
    /// - maxDelay: 30.0s
    /// - strategy: exponentialBackoff
    public static let `default` = RetryConfiguration()

    /// Aggressive retry configuration.
    ///
    /// More attempts with shorter delays for critical operations.
    ///
    /// ## Configuration
    /// - maxRetries: 5
    /// - baseDelay: 0.5s
    /// - maxDelay: 15.0s
    /// - strategy: exponentialWithJitter
    public static let aggressive = RetryConfiguration(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 15.0,
        strategy: .exponentialWithJitter()
    )

    /// Conservative retry configuration.
    ///
    /// Fewer attempts with longer delays to reduce load.
    ///
    /// ## Configuration
    /// - maxRetries: 2
    /// - baseDelay: 2.0s
    /// - maxDelay: 60.0s
    /// - strategy: exponentialBackoff
    public static let conservative = RetryConfiguration(
        maxRetries: 2,
        baseDelay: 2.0,
        maxDelay: 60.0,
        strategy: .exponentialBackoff()
    )

    /// No retry configuration.
    ///
    /// Disables all retries.
    public static let none = RetryConfiguration(maxRetries: 0)

    // MARK: - Delay Calculation

    /// Calculates the delay for a given retry attempt.
    ///
    /// - Parameter attempt: The retry attempt number (0-indexed).
    /// - Returns: The delay in seconds before this retry.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }

        let rawDelay = strategy.delay(forAttempt: attempt, baseDelay: baseDelay)
        return min(rawDelay, maxDelay)
    }

    /// Determines if a status code should trigger a retry.
    ///
    /// - Parameter statusCode: The HTTP status code.
    /// - Returns: `true` if the request should be retried.
    public func shouldRetry(statusCode: Int) -> Bool {
        retryableStatusCodes.contains(statusCode)
    }

    /// Determines if an error type should trigger a retry.
    ///
    /// - Parameter errorType: The error type.
    /// - Returns: `true` if the request should be retried.
    public func shouldRetry(errorType: RetryableErrorType) -> Bool {
        retryableErrors.contains(errorType)
    }
}

// MARK: - RetryStrategy

/// Strategy for calculating retry delays.
public enum RetryStrategy: Sendable, Hashable {

    /// No delay between retries.
    ///
    /// Use sparingly to avoid overwhelming the server.
    case immediate

    /// Fixed delay between retries.
    ///
    /// - Parameter delay: The constant delay in seconds.
    case fixed(delay: TimeInterval)

    /// Exponential backoff.
    ///
    /// Delay doubles with each retry: base, base*2, base*4, etc.
    ///
    /// - Parameter multiplier: The backoff multiplier. Default: 2.0
    case exponentialBackoff(multiplier: Double = 2.0)

    /// Exponential backoff with jitter.
    ///
    /// Adds randomization to prevent thundering herd problem.
    ///
    /// - Parameters:
    ///   - multiplier: The backoff multiplier. Default: 2.0
    ///   - jitterFactor: Random factor (0-1) applied to delay. Default: 0.1
    case exponentialWithJitter(multiplier: Double = 2.0, jitterFactor: Double = 0.1)

    /// Calculates the delay for a given attempt.
    ///
    /// - Parameters:
    ///   - attempt: The retry attempt number (1-indexed for delay).
    ///   - baseDelay: The base delay in seconds.
    /// - Returns: The calculated delay in seconds.
    public func delay(forAttempt attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        switch self {
        case .immediate:
            return 0

        case .fixed(let delay):
            return delay

        case .exponentialBackoff(let multiplier):
            return baseDelay * pow(multiplier, Double(attempt - 1))

        case .exponentialWithJitter(let multiplier, let jitterFactor):
            let baseExp = baseDelay * pow(multiplier, Double(attempt - 1))
            let jitter = baseExp * jitterFactor * Double.random(in: -1...1)
            return max(0, baseExp + jitter)
        }
    }
}

// MARK: - RetryableErrorType

/// Types of errors that can be retried.
public enum RetryableErrorType: String, Sendable, Hashable, CaseIterable {

    /// Request timed out.
    case timeout

    /// Connection was lost or reset.
    case connectionLost

    /// Server returned a 5xx error.
    case serverError

    /// Rate limit was exceeded.
    case rateLimited

    /// DNS resolution failed.
    case dnsFailure

    /// SSL/TLS handshake failed.
    case sslError

    /// Determines if a URLError should be retried.
    ///
    /// - Parameter urlError: The URLError to check.
    /// - Returns: The matching retryable error type, if any.
    public static func from(_ urlError: URLError) -> RetryableErrorType? {
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .networkConnectionLost, .notConnectedToInternet:
            return .connectionLost
        case .dnsLookupFailed, .cannotFindHost:
            return .dnsFailure
        case .secureConnectionFailed, .serverCertificateHasBadDate,
             .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid, .clientCertificateRejected:
            return .sslError
        default:
            return nil
        }
    }
}

// MARK: - Fluent API

extension RetryConfiguration {

    /// Returns a copy with the specified maximum retries.
    ///
    /// - Parameter count: Maximum retry attempts.
    /// - Returns: A new configuration with the updated value.
    public func maxRetries(_ count: Int) -> RetryConfiguration {
        var copy = self
        copy.maxRetries = max(0, count)
        return copy
    }

    /// Returns a copy with the specified base delay.
    ///
    /// - Parameter delay: Base delay in seconds.
    /// - Returns: A new configuration with the updated value.
    public func baseDelay(_ delay: TimeInterval) -> RetryConfiguration {
        var copy = self
        copy.baseDelay = max(0, delay)
        return copy
    }

    /// Returns a copy with the specified maximum delay.
    ///
    /// - Parameter delay: Maximum delay in seconds.
    /// - Returns: A new configuration with the updated value.
    public func maxDelay(_ delay: TimeInterval) -> RetryConfiguration {
        var copy = self
        copy.maxDelay = max(copy.baseDelay, delay)
        return copy
    }

    /// Returns a copy with the specified retry strategy.
    ///
    /// - Parameter strategy: The retry delay strategy.
    /// - Returns: A new configuration with the updated strategy.
    public func strategy(_ strategy: RetryStrategy) -> RetryConfiguration {
        var copy = self
        copy.strategy = strategy
        return copy
    }

    /// Returns a copy with the specified retryable status codes.
    ///
    /// - Parameter codes: HTTP status codes that should trigger a retry.
    /// - Returns: A new configuration with the updated codes.
    public func retryableStatusCodes(_ codes: Set<Int>) -> RetryConfiguration {
        var copy = self
        copy.retryableStatusCodes = codes
        return copy
    }

    /// Returns a copy with the specified retryable error types.
    ///
    /// - Parameter errors: Error types that should trigger a retry.
    /// - Returns: A new configuration with the updated error types.
    public func retryableErrors(_ errors: Set<RetryableErrorType>) -> RetryConfiguration {
        var copy = self
        copy.retryableErrors = errors
        return copy
    }

    /// Returns a copy with retries disabled.
    ///
    /// - Returns: A new configuration with maxRetries set to 0.
    public func disabled() -> RetryConfiguration {
        var copy = self
        copy.maxRetries = 0
        return copy
    }
}

// MARK: - Codable

extension RetryConfiguration: Codable {}
extension RetryStrategy: Codable {}
extension RetryableErrorType: Codable {}
