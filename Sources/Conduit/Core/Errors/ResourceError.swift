// ResourceError.swift
// Conduit

import Foundation

public enum ResourceError: Error, Sendable, LocalizedError, CustomStringConvertible {

    case insufficientMemory(required: ByteCount, available: ByteCount)

    case downloadFailed(underlying: SendableError)

    case fileError(underlying: SendableError)

    case insufficientDiskSpace(required: ByteCount, available: ByteCount)

    case checksumMismatch(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .insufficientMemory(let required, let available):
            return "Insufficient memory: requires \(required.formatted), available \(available.formatted)"

        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"

        case .fileError(let error):
            return "File error: \(error.localizedDescription)"

        case .insufficientDiskSpace(let required, let available):
            return "Insufficient disk space: requires \(required.formatted), available \(available.formatted)"

        case .checksumMismatch(let expected, let actual):
            return "Checksum verification failed: expected \(expected.prefix(16))..., got \(actual.prefix(16))..."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .insufficientMemory:
            return "Close other applications to free memory, or try a smaller model."

        case .downloadFailed:
            return "Check your internet connection and available storage space, then try again."

        case .fileError:
            return "Check file permissions and available disk space."

        case .insufficientDiskSpace(let required, _):
            return "Free up at least \(required.formatted) of disk space and try again."

        case .checksumMismatch:
            return "The downloaded file may be corrupted. Delete the model and try downloading again."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .downloadFailed:
            return true
        default:
            return false
        }
    }

    public var description: String {
        errorDescription ?? "Unknown resource error"
    }
}
