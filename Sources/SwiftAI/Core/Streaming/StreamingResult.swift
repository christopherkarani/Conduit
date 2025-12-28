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

    /// Iterates over partial values, calling the handler for each, then returns the final result.
    ///
    /// This method combines observation and collection in a single operation. The handler
    /// is called for each partial value as it arrives, and the final complete result is
    /// returned after the stream completes.
    ///
    /// - Note: The method name `reduce` reflects that it reduces the stream to a single
    ///   final value while allowing observation of intermediate states. This follows
    ///   Swift conventions where `forEach` returns `Void`.
    ///
    /// ## Usage
    /// ```swift
    /// let recipe = try await stream.reduce { partial in
    ///     if let title = partial.title {
    ///         print("Title so far: \(title)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter handler: Closure called with each partial value as it arrives
    /// - Returns: The final complete result after the stream completes
    /// - Throws: `StreamingError.noContent` if the stream is empty,
    ///           or other errors if streaming or conversion fails
    @discardableResult
    public func reduce(_ handler: @Sendable (T.Partial) -> Void) async throws -> T {
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

    /// Collects all partial values and returns the final result, or nil if empty.
    ///
    /// Unlike `collect()`, this method returns `nil` instead of throwing when
    /// the stream completes without producing any content.
    ///
    /// ## Usage
    /// ```swift
    /// if let recipe = try await stream.collectOrNil() {
    ///     print("Got recipe: \(recipe)")
    /// } else {
    ///     print("Stream was empty")
    /// }
    /// ```
    ///
    /// - Returns: The complete result, or `nil` if the stream was empty
    /// - Throws: If streaming fails or the result cannot be constructed
    public func collectOrNil() async throws -> T? {
        var lastPartial: T.Partial?

        for try await partial in stream {
            lastPartial = partial
        }

        guard let final = lastPartial else {
            return nil
        }

        let content = final.generableContent
        return try T(from: content)
    }

    // MARK: - Main Actor Helpers

    /// Iterates over partial values on the main actor for safe UI updates.
    ///
    /// This method is designed for SwiftUI and UIKit scenarios where you need
    /// to update UI elements from streaming results. Each partial value is
    /// delivered on the main actor, eliminating the need for manual isolation.
    ///
    /// ## Usage
    /// ```swift
    /// let recipe = try await stream.reduceOnMain { partial in
    ///     if let title = partial.title {
    ///         titleLabel.text = title  // Safe - on main actor
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter handler: Closure called on the main actor with each partial value
    /// - Returns: The final complete result after the stream completes
    /// - Throws: `StreamingError.noContent` if the stream is empty
    @MainActor
    @discardableResult
    public func reduceOnMain(_ handler: @MainActor (T.Partial) -> Void) async throws -> T {
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
