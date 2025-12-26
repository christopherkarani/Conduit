// StreamingResult.swift
// SwiftAI
//
// Typed streaming result for Generable types.

import Foundation

// MARK: - StreamingResult

/// A streaming result that yields partial values of a Generable type.
///
/// `StreamingResult` wraps an async sequence of partial values, enabling
/// progressive UI updates as structured data arrives from the language model.
///
/// ## Usage
///
/// ```swift
/// @Generable
/// struct Recipe {
///     let title: String
///     let ingredients: [String]
/// }
///
/// let stream = provider.stream("Generate a recipe", returning: Recipe.self)
///
/// for try await partial in stream {
///     if let title = partial.title {
///         titleLabel.text = title
///     }
///     if let ingredients = partial.ingredients {
///         updateIngredientsList(ingredients)
///     }
/// }
/// ```
///
/// ## Collecting Final Result
///
/// Use `collect()` to wait for the complete result:
///
/// ```swift
/// let recipe = try await stream.collect()
/// ```
public struct StreamingResult<T: Generable>: AsyncSequence, Sendable {
    public typealias Element = T.Partial

    private let stream: AsyncThrowingStream<T.Partial, Error>

    /// Creates a streaming result from an async throwing stream.
    public init(_ stream: AsyncThrowingStream<T.Partial, Error>) {
        self.stream = stream
    }

    // MARK: - AsyncSequence

    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: AsyncThrowingStream<T.Partial, Error>.AsyncIterator

        public mutating func next() async throws -> T.Partial? {
            try await iterator.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: stream.makeAsyncIterator())
    }

    // MARK: - Convenience Methods

    /// Collects all partial values and returns the final complete result.
    ///
    /// - Returns: The complete Generable value
    /// - Throws: If streaming fails or the final result cannot be constructed
    public func collect() async throws -> T {
        var lastPartial: T.Partial?

        for try await partial in stream {
            lastPartial = partial
        }

        guard let final = lastPartial else {
            throw StreamingError.noContent
        }

        // Convert final partial to complete type
        let content = final.generableContent
        return try T(from: content)
    }

    /// Iterates over partial values, calling the handler for each.
    ///
    /// - Parameter handler: Closure called with each partial value
    /// - Returns: The final complete result
    /// - Throws: If streaming fails or the final result cannot be constructed
    @discardableResult
    public func forEach(_ handler: @Sendable (T.Partial) -> Void) async throws -> T {
        var lastPartial: T.Partial?

        for try await partial in stream {
            handler(partial)
            lastPartial = partial
        }

        guard let final = lastPartial else {
            throw StreamingError.noContent
        }

        let content = final.generableContent
        return try T(from: content)
    }
}

// MARK: - StreamingError

/// Errors that can occur during structured streaming.
public enum StreamingError: Error, Sendable, LocalizedError {
    /// The stream completed without producing any content.
    case noContent

    /// Failed to parse the streamed JSON.
    case parseFailed(String)

    /// The partial result could not be converted to the target type.
    case conversionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .noContent:
            return "Stream completed without producing content"
        case .parseFailed(let json):
            return "Failed to parse streamed JSON: \(json.prefix(100))..."
        case .conversionFailed(let error):
            return "Failed to convert partial to target type: \(error.localizedDescription)"
        }
    }
}
