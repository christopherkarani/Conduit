// GenerationStream.swift
// SwiftAI

import Foundation

/// A stream of generated content chunks.
///
/// `GenerationStream` wraps `AsyncThrowingStream` and provides
/// additional conveniences for working with streamed generation.
///
/// ## Usage
/// ```swift
/// let stream = provider.stream(messages: messages, model: .llama3_2_1B, config: .default)
///
/// // Simple text iteration
/// for try await text in stream.text {
///     print(text, terminator: "")
/// }
///
/// // Full chunk iteration with metadata
/// for try await chunk in stream {
///     print("Token: \(chunk.text), Tokens/sec: \(chunk.tokensPerSecond ?? 0)")
/// }
///
/// // Collect all text
/// let fullText = try await stream.collect()
/// ```
public struct GenerationStream: AsyncSequence, Sendable {
    public typealias Element = GenerationChunk

    /// The underlying async throwing stream.
    private let stream: AsyncThrowingStream<GenerationChunk, Error>

    /// The time when this stream was created.
    private let startTime: Date

    // MARK: - Initialization

    /// Creates a generation stream from an async throwing stream.
    ///
    /// - Parameter stream: The underlying stream of generation chunks.
    public init(_ stream: AsyncThrowingStream<GenerationChunk, Error>) {
        self.stream = stream
        self.startTime = Date()
    }

    // MARK: - AsyncSequence Conformance

    /// Creates an async iterator for this stream.
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream.makeAsyncIterator())
    }

    /// The async iterator for GenerationStream.
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<GenerationChunk, Error>.AsyncIterator

        init(_ iterator: AsyncThrowingStream<GenerationChunk, Error>.AsyncIterator) {
            self.iterator = iterator
        }

        /// Returns the next chunk in the stream.
        public mutating func next() async throws -> GenerationChunk? {
            try await iterator.next()
        }
    }

    // MARK: - Convenience Properties

    /// A stream that yields only the text content of each chunk.
    ///
    /// Use this when you only care about the text and not the metadata.
    ///
    /// ```swift
    /// for try await text in stream.text {
    ///     print(text, terminator: "")
    /// }
    /// ```
    public var text: AsyncThrowingMapSequence<GenerationStream, String> {
        self.map { $0.text }
    }

    // MARK: - Collection Methods

    /// Collects all chunks and returns the complete text.
    ///
    /// Waits for the stream to complete and concatenates all chunk text.
    ///
    /// - Returns: The complete generated text.
    /// - Throws: Any error from the underlying stream.
    public func collect() async throws -> String {
        var result = ""
        for try await chunk in self {
            result += chunk.text
        }
        return result
    }

    /// Collects all chunks and returns the final generation result.
    ///
    /// Gathers complete text, token counts, and timing information.
    ///
    /// - Returns: A `GenerationResult` with complete metrics.
    /// - Throws: Any error from the underlying stream.
    public func collectWithMetadata() async throws -> GenerationResult {
        var text = ""
        var totalTokens = 0
        var firstChunkTime: Date?
        var lastChunkTime: Date?
        var lastFinishReason: FinishReason?

        for try await chunk in self {
            if firstChunkTime == nil {
                firstChunkTime = Date()
            }
            lastChunkTime = Date()
            text += chunk.text
            totalTokens += chunk.tokenCount
            if chunk.finishReason != nil {
                lastFinishReason = chunk.finishReason
            }
        }

        let duration = lastChunkTime?.timeIntervalSince(firstChunkTime ?? startTime) ?? 0

        return GenerationResult(
            text: text,
            tokenCount: totalTokens,
            generationTime: duration,
            tokensPerSecond: duration > 0 ? Double(totalTokens) / duration : 0,
            finishReason: lastFinishReason ?? .stop
        )
    }

    /// Returns the first chunk along with the time-to-first-token latency.
    ///
    /// Useful for measuring model responsiveness.
    ///
    /// - Returns: A tuple of the first chunk and latency in seconds,
    ///            or `nil` if the stream is empty.
    /// - Throws: Any error from the underlying stream.
    public func timeToFirstToken() async throws -> (chunk: GenerationChunk, latency: TimeInterval)? {
        for try await chunk in self {
            let latency = Date().timeIntervalSince(startTime)
            return (chunk, latency)
        }
        return nil
    }

    // MARK: - Factory Methods

    /// Creates a GenerationStream from a simple string stream.
    ///
    /// Converts each string into a `GenerationChunk` with default metadata.
    /// Useful when adapting simpler streaming APIs.
    ///
    /// - Parameter stringStream: An async stream of strings.
    /// - Returns: A GenerationStream wrapping the string stream.
    public static func from(_ stringStream: AsyncThrowingStream<String, Error>) -> GenerationStream {
        let chunkStream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            Task {
                do {
                    for try await text in stringStream {
                        let chunk = GenerationChunk(text: text)
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        return GenerationStream(chunkStream)
    }
}
