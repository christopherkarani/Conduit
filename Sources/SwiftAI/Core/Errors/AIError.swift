// AIError.swift
// SwiftAI

import Foundation

/// Errors that can occur during AI operations.
///
/// `AIError` is the primary error type used throughout SwiftAI. All provider
/// implementations throw `AIError` instances, allowing consistent error handling
/// regardless of which provider is being used.
///
/// ## Error Categories
/// - **Provider Errors**: Issues with provider availability or configuration
/// - **Generation Errors**: Problems during text generation
/// - **Network Errors**: Network-related failures (cloud providers)
/// - **Resource Errors**: Memory, storage, or download issues
/// - **Input Errors**: Invalid inputs or unsupported formats
///
/// ## Usage
/// ```swift
/// do {
///     let response = try await provider.generate("Hello", model: .llama3_2_1B)
/// } catch let error as AIError {
///     print(error.errorDescription ?? "Unknown error")
///     if error.isRetryable {
///         // Retry the operation
///     }
/// }
/// ```
public enum AIError: Error, Sendable, LocalizedError, CustomStringConvertible {

    // MARK: - Provider Errors

    /// The requested provider is not available.
    ///
    /// This occurs when:
    /// - The device doesn't support the provider (e.g., non-Apple Silicon for MLX)
    /// - Required OS version is not met
    /// - Apple Intelligence is disabled
    /// - Network is unavailable for cloud providers
    case providerUnavailable(reason: UnavailabilityReason)

    /// The specified model was not found.
    ///
    /// The model identifier doesn't match any known model.
    case modelNotFound(ModelIdentifier)

    /// The model is not downloaded/cached locally.
    ///
    /// For local providers, the model must be downloaded before use.
    case modelNotCached(ModelIdentifier)

    /// Authentication failed.
    ///
    /// API key is invalid, expired, or missing.
    case authenticationFailed(String)

    // MARK: - Generation Errors

    /// Generation failed with an underlying error.
    ///
    /// Wraps provider-specific errors that occur during inference.
    case generationFailed(underlying: SendableError)

    /// Input exceeded the model's token limit.
    ///
    /// - Parameters:
    ///   - count: Actual token count of the input
    ///   - limit: Maximum allowed tokens
    case tokenLimitExceeded(count: Int, limit: Int)

    /// Content was filtered by safety systems.
    ///
    /// The model or provider filtered the output due to content policy.
    case contentFiltered(reason: String?)

    /// Operation was cancelled by the user.
    case cancelled

    /// Operation timed out.
    ///
    /// - Parameter duration: The timeout duration in seconds
    case timeout(TimeInterval)

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

    // MARK: - Resource Errors

    /// Insufficient memory to load or run the model.
    ///
    /// - Parameters:
    ///   - required: Memory required by the model
    ///   - available: Memory currently available
    case insufficientMemory(required: ByteCount, available: ByteCount)

    /// Model download failed.
    ///
    /// Wraps the underlying error that caused the download to fail.
    case downloadFailed(underlying: SendableError)

    /// File operation failed.
    ///
    /// Wraps file system errors (permissions, disk full, etc.).
    case fileError(underlying: SendableError)

    // MARK: - Input Errors

    /// Invalid input was provided.
    ///
    /// The input doesn't meet requirements (empty, malformed, etc.).
    case invalidInput(String)

    /// Unsupported audio format for transcription.
    ///
    /// - Parameter format: The unsupported format that was provided
    case unsupportedAudioFormat(String)

    /// Unsupported language.
    ///
    /// The language is not supported by the model.
    case unsupportedLanguage(String)

    // MARK: - LocalizedError

    /// A localized description of the error.
    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let reason):
            return "Provider unavailable: \(reason.description)"

        case .modelNotFound(let model):
            return "Model not found: \(model.rawValue)"

        case .modelNotCached(let model):
            return "Model not cached: \(model.rawValue)"

        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"

        case .generationFailed(let error):
            return "Generation failed: \(error.localizedDescription)"

        case .tokenLimitExceeded(let count, let limit):
            return "Token limit exceeded: \(count) tokens (limit: \(limit))"

        case .contentFiltered(let reason):
            if let reason = reason {
                return "Content filtered: \(reason)"
            }
            return "Content filtered by safety systems"

        case .cancelled:
            return "Operation cancelled"

        case .timeout(let duration):
            return "Operation timed out after \(Int(duration)) seconds"

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

        case .insufficientMemory(let required, let available):
            return "Insufficient memory: requires \(required.formatted), available \(available.formatted)"

        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"

        case .fileError(let error):
            return "File error: \(error.localizedDescription)"

        case .invalidInput(let message):
            return "Invalid input: \(message)"

        case .unsupportedAudioFormat(let format):
            return "Unsupported audio format: \(format)"

        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language)"
        }
    }

    /// A localized suggestion for recovering from the error.
    public var recoverySuggestion: String? {
        switch self {
        case .providerUnavailable(let reason):
            return recoverySuggestionForUnavailability(reason)

        case .modelNotFound:
            return "Check the model identifier and try again. Use ModelIdentifier static properties for known models."

        case .modelNotCached:
            return "Download the model using ModelManager.shared.download() before using it."

        case .authenticationFailed:
            return "Verify your API key is correct and has not expired."

        case .generationFailed:
            return "Try again or use a different model. If the problem persists, check your input."

        case .tokenLimitExceeded(_, let limit):
            return "Reduce your input to fit within \(limit) tokens. Consider summarizing or chunking long content."

        case .contentFiltered:
            return "Modify your prompt to comply with content guidelines."

        case .cancelled:
            return nil

        case .timeout:
            return "Try again or increase the timeout duration. Consider using a faster model for long operations."

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

        case .insufficientMemory:
            return "Close other applications to free memory, or try a smaller model."

        case .downloadFailed:
            return "Check your internet connection and available storage space, then try again."

        case .fileError:
            return "Check file permissions and available disk space."

        case .invalidInput:
            return "Check the input format and try again."

        case .unsupportedAudioFormat(let format):
            return "Convert your audio to a supported format (WAV, MP3, M4A, FLAC). Received: \(format)"

        case .unsupportedLanguage:
            return "Use a supported language or enable auto-detection."
        }
    }

    private func recoverySuggestionForUnavailability(_ reason: UnavailabilityReason) -> String? {
        switch reason {
        case .deviceNotSupported:
            return "This feature requires Apple Silicon. Use a cloud provider instead."

        case .osVersionNotMet(let required):
            return "Update to \(required) or later to use this feature."

        case .appleIntelligenceDisabled:
            return "Enable Apple Intelligence in Settings > Apple Intelligence & Siri."

        case .modelDownloading:
            return "Wait for the download to complete."

        case .modelNotDownloaded:
            return "Download the model using ModelManager before using it."

        case .noNetwork:
            return "Connect to the internet to use this cloud provider."

        case .apiKeyMissing:
            return "Configure your API key before using this provider."

        case .insufficientMemory(let required, let available):
            return "Free up \(ByteCount(required.bytes - available.bytes).formatted) of memory or use a smaller model."

        case .unknown:
            return nil
        }
    }

    // MARK: - Retryability

    /// Whether this error may succeed if retried.
    ///
    /// Returns `true` for transient errors like network issues or rate limits.
    /// Returns `false` for permanent errors like invalid input or unsupported features.
    public var isRetryable: Bool {
        switch self {
        case .providerUnavailable(let reason):
            switch reason {
            case .modelDownloading, .noNetwork:
                return true
            default:
                return false
            }

        case .networkError:
            return true

        case .serverError(let statusCode, _):
            // 5xx errors are server-side and may be transient
            return statusCode >= 500

        case .rateLimited:
            return true

        case .timeout:
            return true

        case .generationFailed:
            return true

        case .downloadFailed:
            return true

        default:
            return false
        }
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        errorDescription ?? "Unknown AI error"
    }
}

// MARK: - Convenience Initializers

extension AIError {

    /// Creates a generation failed error from any Error.
    ///
    /// - Parameter error: The underlying error.
    /// - Returns: An `AIError.generationFailed` case.
    public static func generation(_ error: Error) -> AIError {
        .generationFailed(underlying: SendableError(error))
    }

    /// Creates a download failed error from any Error.
    ///
    /// - Parameter error: The underlying error.
    /// - Returns: An `AIError.downloadFailed` case.
    public static func download(_ error: Error) -> AIError {
        .downloadFailed(underlying: SendableError(error))
    }

    /// Creates a file error from any Error.
    ///
    /// - Parameter error: The underlying error.
    /// - Returns: An `AIError.fileError` case.
    public static func file(_ error: Error) -> AIError {
        .fileError(underlying: SendableError(error))
    }
}

// MARK: - Error Categorization

extension AIError {

    /// The category of this error.
    public var category: ErrorCategory {
        switch self {
        case .providerUnavailable, .modelNotFound, .modelNotCached, .authenticationFailed:
            return .provider
        case .generationFailed, .tokenLimitExceeded, .contentFiltered, .cancelled, .timeout:
            return .generation
        case .networkError, .serverError, .rateLimited:
            return .network
        case .insufficientMemory, .downloadFailed, .fileError:
            return .resource
        case .invalidInput, .unsupportedAudioFormat, .unsupportedLanguage:
            return .input
        }
    }

    /// Error category for grouping related errors.
    public enum ErrorCategory: String, Sendable, CaseIterable {
        case provider
        case generation
        case network
        case resource
        case input

        public var displayName: String {
            switch self {
            case .provider: return "Provider Error"
            case .generation: return "Generation Error"
            case .network: return "Network Error"
            case .resource: return "Resource Error"
            case .input: return "Input Error"
            }
        }
    }
}
