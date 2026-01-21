// URLSessionAsyncBytes.swift
// Conduit
//
// Cross-platform async byte streaming for URLSession.
// On Apple platforms, uses native URLSession.bytes(for:).
// On Linux, provides a polyfill using URLSessionDataTask with delegate.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Cross-Platform Byte Streaming

#if canImport(FoundationNetworking)

/// A cross-platform async sequence of bytes for streaming HTTP responses on Linux.
///
/// This type provides Linux compatibility for `URLSession.bytes(for:)` which is
/// only available on Apple platforms. It uses a delegate-based approach to
/// stream bytes as they arrive from the server.
///
/// ## Usage
///
/// ```swift
/// let (stream, response) = try await session.asyncBytes(for: request)
/// for try await byte in stream {
///     // Process byte
/// }
/// // Or iterate lines:
/// for try await line in stream.lines {
///     // Process line
/// }
/// ```
public struct URLSessionAsyncBytes: AsyncSequence, Sendable {
    public typealias Element = UInt8

    private let stream: AsyncThrowingStream<UInt8, Error>

    init(stream: AsyncThrowingStream<UInt8, Error>) {
        self.stream = stream
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: stream.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: AsyncThrowingStream<UInt8, Error>.AsyncIterator

        public mutating func next() async throws -> UInt8? {
            try await iterator.next()
        }
    }

    /// An async sequence of lines from the byte stream.
    ///
    /// Lines are delimited by `\n`, `\r`, or `\r\n`. The delimiter is not included
    /// in the returned strings.
    public var lines: AsyncLineSequence {
        AsyncLineSequence(bytes: self)
    }
}

/// An async sequence that yields lines from a byte stream.
public struct AsyncLineSequence: AsyncSequence, Sendable {
    public typealias Element = String

    /// Maximum buffer size in bytes (10 MB) to prevent unbounded memory growth.
    /// If a line exceeds this size, an error will be thrown.
    public static let maxBufferSize = 10 * 1024 * 1024

    private let bytes: URLSessionAsyncBytes

    init(bytes: URLSessionAsyncBytes) {
        self.bytes = bytes
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bytesIterator: bytes.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var bytesIterator: URLSessionAsyncBytes.AsyncIterator
        var buffer: [UInt8] = []
        var finished = false

        public mutating func next() async throws -> String? {
            if finished { return nil }

            while true {
                // Check if we have a complete line in the buffer
                if let newlineIndex = buffer.firstIndex(where: { $0 == UInt8(ascii: "\n") || $0 == UInt8(ascii: "\r") }) {
                    let delimiter = buffer[newlineIndex]
                    let lineBytes = Array(buffer[..<newlineIndex])
                    var removeCount = newlineIndex + 1
                    if delimiter == UInt8(ascii: "\r"),
                       removeCount < buffer.count,
                       buffer[removeCount] == UInt8(ascii: "\n") {
                        removeCount += 1
                    }
                    buffer.removeFirst(removeCount)
                    return String(decoding: lineBytes, as: UTF8.self)
                }

                // Check buffer size limit before reading more bytes
                if buffer.count >= AsyncLineSequence.maxBufferSize {
                    throw URLError(.dataLengthExceedsMaximum)
                }

                // Read more bytes
                guard let byte = try await bytesIterator.next() else {
                    // End of stream - return remaining buffer if non-empty
                    finished = true
                    if buffer.isEmpty {
                        return nil
                    }
                    // Handle trailing \r
                    if buffer.last == UInt8(ascii: "\r") {
                        buffer.removeLast()
                    }
                    let remaining = String(decoding: buffer, as: UTF8.self)
                    buffer.removeAll()
                    return remaining.isEmpty ? nil : remaining
                }

                buffer.append(byte)
            }
        }
    }
}

/// Delegate for streaming HTTP response data on Linux.
///
/// This class buffers incoming data and feeds it to an AsyncThrowingStream
/// for consumption by async/await code.
final class StreamingDataDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<UInt8, Error>.Continuation
    private let responseContinuation: CheckedContinuation<URLResponse, Error>
    private var hasReceivedResponse = false
    private let lock = NSLock()

    init(
        continuation: AsyncThrowingStream<UInt8, Error>.Continuation,
        responseContinuation: CheckedContinuation<URLResponse, Error>
    ) {
        self.continuation = continuation
        self.responseContinuation = responseContinuation
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        lock.lock()
        if !hasReceivedResponse {
            hasReceivedResponse = true
            lock.unlock()
            responseContinuation.resume(returning: response)
        } else {
            lock.unlock()
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        for byte in data {
            continuation.yield(byte)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let hadResponse = hasReceivedResponse
        if !hadResponse {
            hasReceivedResponse = true
            lock.unlock()

            // Resume continuation outside the lock to avoid potential deadlock
            if let error = error {
                responseContinuation.resume(throwing: error)
                continuation.finish(throwing: error)
            } else {
                // Edge case: completed without receiving response
                responseContinuation.resume(throwing: URLError(.badServerResponse))
                continuation.finish()
            }
        } else {
            lock.unlock()

            // Response was already received, just finish the stream
            if let error = error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}

extension URLSession {
    /// Streams bytes from a URL request asynchronously (Linux polyfill).
    ///
    /// This method provides Linux compatibility for the Apple-only
    /// `URLSession.bytes(for:)` API. It uses a delegate-based approach
    /// to stream response data as it arrives.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: A tuple containing an async byte stream and the URL response.
    /// - Throws: `URLError` if the request fails.
    ///
    /// - Note: On Linux, this creates a new session with default configuration
    ///   because `URLSession.configuration` is not safely reusable with
    ///   FoundationNetworking's libcurl backend.
    public func asyncBytes(for request: URLRequest) async throws -> (URLSessionAsyncBytes, URLResponse) {
        // Validate URL before passing to libcurl to prevent CURLE_BAD_FUNCTION_ARGUMENT (error 43)
        guard let url = request.url else {
            throw URLError(.badURL, userInfo: [
                NSLocalizedDescriptionKey: "URLRequest has nil URL"
            ])
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw URLError(.unsupportedURL, userInfo: [
                NSLocalizedDescriptionKey: "URL scheme must be http or https, got: \(url.scheme ?? "nil")"
            ])
        }

        guard url.host != nil else {
            throw URLError(.badURL, userInfo: [
                NSLocalizedDescriptionKey: "URL must have a host component"
            ])
        }

        // Create a dedicated session with delegate for streaming
        var streamContinuation: AsyncThrowingStream<UInt8, Error>.Continuation!

        let byteStream = AsyncThrowingStream<UInt8, Error> { continuation in
            streamContinuation = continuation
        }

        let response: URLResponse = try await withCheckedThrowingContinuation { responseContinuation in
            let delegate = StreamingDataDelegate(
                continuation: streamContinuation,
                responseContinuation: responseContinuation
            )

            // Use fresh default configuration instead of self.configuration
            // to avoid libcurl errors on Linux where session configuration
            // may not be safely accessible after creation.
            let streamingSession = URLSession(
                configuration: .default,
                delegate: delegate,
                delegateQueue: nil
            )

            let task = streamingSession.dataTask(with: request)

            streamContinuation.onTermination = { @Sendable _ in
                task.cancel()
                streamingSession.invalidateAndCancel()
            }

            task.resume()
        }

        return (URLSessionAsyncBytes(stream: byteStream), response)
    }
}

#else

// MARK: - Apple Platforms Wrapper

/// Wrapper around native URLSession.AsyncBytes for API consistency.
///
/// On Apple platforms, this provides the same interface as the Linux polyfill
/// while delegating to the native implementation.
public struct URLSessionAsyncBytes: AsyncSequence, Sendable {
    public typealias Element = UInt8

    private let nativeBytes: URLSession.AsyncBytes

    init(nativeBytes: URLSession.AsyncBytes) {
        self.nativeBytes = nativeBytes
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(nativeIterator: nativeBytes.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var nativeIterator: URLSession.AsyncBytes.AsyncIterator

        public mutating func next() async throws -> UInt8? {
            try await nativeIterator.next()
        }
    }

    /// An async sequence of lines from the byte stream.
    public var lines: AsyncLineSequence {
        AsyncLineSequence(bytes: self)
    }
}

/// An async sequence that yields lines from a byte stream (Apple platforms).
///
/// This implementation mirrors the Linux polyfill for API consistency,
/// parsing lines from raw bytes rather than wrapping the native `.lines`.
public struct AsyncLineSequence: AsyncSequence, Sendable {
    public typealias Element = String

    /// Maximum buffer size in bytes (10 MB) to prevent unbounded memory growth.
    /// If a line exceeds this size, an error will be thrown.
    public static let maxBufferSize = 10 * 1024 * 1024

    private let bytes: URLSessionAsyncBytes

    init(bytes: URLSessionAsyncBytes) {
        self.bytes = bytes
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bytesIterator: bytes.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var bytesIterator: URLSessionAsyncBytes.AsyncIterator
        var buffer: [UInt8] = []
        var finished = false

        public mutating func next() async throws -> String? {
            if finished { return nil }

            while true {
                // Check if we have a complete line in the buffer
                if let newlineIndex = buffer.firstIndex(where: { $0 == UInt8(ascii: "\n") || $0 == UInt8(ascii: "\r") }) {
                    let delimiter = buffer[newlineIndex]
                    let lineBytes = Array(buffer[..<newlineIndex])
                    var removeCount = newlineIndex + 1
                    if delimiter == UInt8(ascii: "\r"),
                       removeCount < buffer.count,
                       buffer[removeCount] == UInt8(ascii: "\n") {
                        removeCount += 1
                    }
                    buffer.removeFirst(removeCount)
                    return String(decoding: lineBytes, as: UTF8.self)
                }

                // Check buffer size limit before reading more bytes
                if buffer.count >= AsyncLineSequence.maxBufferSize {
                    throw URLError(.dataLengthExceedsMaximum)
                }

                // Read more bytes
                guard let byte = try await bytesIterator.next() else {
                    // End of stream - return remaining buffer if non-empty
                    finished = true
                    if buffer.isEmpty {
                        return nil
                    }
                    // Handle trailing \r
                    if buffer.last == UInt8(ascii: "\r") {
                        buffer.removeLast()
                    }
                    let remaining = String(decoding: buffer, as: UTF8.self)
                    buffer.removeAll()
                    return remaining.isEmpty ? nil : remaining
                }

                buffer.append(byte)
            }
        }
    }
}

extension URLSession {
    /// Streams bytes from a URL request asynchronously.
    ///
    /// On Apple platforms, this wraps the native `URLSession.bytes(for:)`
    /// API for API consistency with the Linux polyfill.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: A tuple containing the async byte stream and the URL response.
    /// - Throws: `URLError` if the request fails.
    public func asyncBytes(for request: URLRequest) async throws -> (URLSessionAsyncBytes, URLResponse) {
        // Validate URL for consistency with Linux implementation
        guard let url = request.url else {
            throw URLError(.badURL, userInfo: [
                NSLocalizedDescriptionKey: "URLRequest has nil URL"
            ])
        }

        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw URLError(.unsupportedURL, userInfo: [
                NSLocalizedDescriptionKey: "URL scheme must be http or https, got: \(url.scheme ?? "nil")"
            ])
        }

        guard url.host != nil else {
            throw URLError(.badURL, userInfo: [
                NSLocalizedDescriptionKey: "URL must have a host component"
            ])
        }

        let (nativeBytes, response) = try await self.bytes(for: request)
        return (URLSessionAsyncBytes(nativeBytes: nativeBytes), response)
    }
}

#endif
