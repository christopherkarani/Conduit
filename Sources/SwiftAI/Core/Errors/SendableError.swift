// SendableError.swift
// SwiftAI

import Foundation

/// A Sendable wrapper for capturing error information across concurrency boundaries.
///
/// Swift 6.2's strict concurrency requires all types crossing actor boundaries to be
/// Sendable. Since `Error` is not inherently Sendable, this wrapper captures the
/// essential error information (descriptions) as Sendable String values.
///
/// ## Overview
///
/// The `SendableError` type solves a common problem in Swift 6.2: when you catch an
/// error in one concurrency domain and need to throw it (or store it) in another,
/// the compiler requires the error type to be `Sendable`. Many Foundation and third-party
/// error types don't conform to `Sendable`, so this wrapper extracts their descriptions
/// into `Sendable` strings.
///
/// ## Usage
///
/// ### Wrapping Caught Errors
/// ```swift
/// actor NetworkManager {
///     func fetchData() async throws -> Data {
///         do {
///             return try await URLSession.shared.data(from: url).0
///         } catch {
///             // URLError is not Sendable, wrap it
///             throw AIError.networkFailed(underlying: SendableError(error))
///         }
///     }
/// }
/// ```
///
/// ### Creating Custom Sendable Errors
/// ```swift
/// let error = SendableError(
///     localizedDescription: "Model file corrupted",
///     debugDescription: "SHA256 mismatch: expected abc123, got def456"
/// )
/// throw AIError.modelLoadFailed(underlying: error)
/// ```
///
/// ### Extracting Information
/// ```swift
/// if case .generationFailed(let underlying) = error {
///     print(underlying.localizedDescription)  // User-facing message
///     logger.debug("\(underlying.debugDescription)")  // Debug details
/// }
/// ```
///
/// ## Design Notes
///
/// This type is deliberately simple, capturing only string descriptions. It does not
/// attempt to preserve the original error type or its structured data, as that would
/// require the original error to be `Sendable`. For detailed error handling, consider
/// catching and handling specific error types before they cross concurrency boundaries.
///
/// - Note: This type conforms to `Equatable` and `Hashable` based on its descriptions,
///   not the identity of the underlying error.
public struct SendableError: Error, Sendable, CustomStringConvertible {
    /// The localized description of the original error.
    ///
    /// This is the user-facing error message suitable for display in UI.
    public let localizedDescription: String

    /// A debug-friendly description of the original error.
    ///
    /// This typically contains more technical details useful for logging and debugging.
    public let debugDescription: String

    /// Creates a SendableError from any Error.
    ///
    /// This initializer extracts the `localizedDescription` and a debug representation
    /// from the provided error. The debug representation uses Swift's `String(describing:)`
    /// to capture as much information as possible.
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try FileManager.default.removeItem(at: url)
    /// } catch {
    ///     let sendableError = SendableError(error)
    ///     // Can now pass sendableError across actor boundaries
    /// }
    /// ```
    ///
    /// - Parameter error: The error to wrap. Can be any type conforming to `Error`.
    public init(_ error: Error) {
        self.localizedDescription = error.localizedDescription
        self.debugDescription = String(describing: error)
    }

    /// Creates a SendableError with explicit descriptions.
    ///
    /// Use this initializer when you want to create a custom error message without
    /// wrapping an existing error.
    ///
    /// ## Example
    /// ```swift
    /// let error = SendableError(
    ///     localizedDescription: "Failed to download model",
    ///     debugDescription: "HTTP 404: Model 'llama-3.2-1B' not found at https://example.com/models"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - localizedDescription: The user-facing error description.
    ///   - debugDescription: The debug description. Defaults to `localizedDescription` if not provided.
    public init(localizedDescription: String, debugDescription: String? = nil) {
        self.localizedDescription = localizedDescription
        self.debugDescription = debugDescription ?? localizedDescription
    }

    /// A string representation of the error.
    ///
    /// Returns the `localizedDescription` for general display purposes.
    public var description: String {
        localizedDescription
    }
}

// MARK: - Equatable

extension SendableError: Equatable {
    /// Compares two SendableError instances for equality.
    ///
    /// Two `SendableError` instances are equal if both their `localizedDescription`
    /// and `debugDescription` strings are equal.
    ///
    /// - Note: This compares the captured descriptions, not the identity or type
    ///   of the original underlying error.
    public static func == (lhs: SendableError, rhs: SendableError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription &&
        lhs.debugDescription == rhs.debugDescription
    }
}

// MARK: - Hashable

extension SendableError: Hashable {
    /// Hashes the essential components of the error.
    ///
    /// The hash value is computed from both `localizedDescription` and `debugDescription`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(localizedDescription)
        hasher.combine(debugDescription)
    }
}
