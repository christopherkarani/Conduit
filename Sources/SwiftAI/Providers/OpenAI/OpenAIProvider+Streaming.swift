// OpenAIProvider+Streaming.swift
// SwiftAI
//
// Streaming text generation functionality for OpenAIProvider.

import Foundation

// MARK: - Streaming Methods

extension OpenAIProvider {

    /// Streams text generation token by token.
    nonisolated public func stream(
        _ prompt: String,
        model: OpenAIModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        let messages = [Message.user(prompt)]
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in self.streamWithMetadata(messages: messages, model: model, config: config) {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Streams text generation with full metadata.
    nonisolated public func streamWithMetadata(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStreamingGeneration(
                        messages: messages,
                        model: model,
                        config: config,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Streams generation from a conversation.
    ///
    /// This method conforms to the `AIProvider` protocol.
    /// For simple string prompts, use `stream(_:model:config:)` instead.
    nonisolated public func stream(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        streamWithMetadata(messages: messages, model: model, config: config)
    }

    // MARK: - Internal Streaming Implementation

    /// Performs a streaming generation request.
    internal func performStreamingGeneration(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig,
        continuation: AsyncThrowingStream<GenerationChunk, Error>.Continuation
    ) async throws {
        let url = configuration.endpoint.chatCompletionsURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add headers
        for (name, value) in configuration.buildHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
        }

        // Build request body with streaming
        let body = buildRequestBody(messages: messages, model: model, config: config, stream: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute streaming request
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            // Try to read error body with size limit to prevent DoS
            let maxErrorSize = 10_000 // 10KB should be enough for error messages
            var errorData = Data()
            errorData.reserveCapacity(maxErrorSize)

            for try await byte in bytes {
                // Enforce size limit
                guard errorData.count < maxErrorSize else {
                    let message = String(data: errorData, encoding: .utf8)
                    throw AIError.serverError(
                        statusCode: httpResponse.statusCode,
                        message: (message ?? "") + " (error message truncated)"
                    )
                }
                errorData.append(byte)
            }

            let message = String(data: errorData, encoding: .utf8)
            throw AIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // Parse SSE stream with proper UTF-8 handling
        var chunkIndex = 0
        var buffer = ""
        var byteBuffer = Data()

        // Buffer size limits to prevent DoS
        let maxBufferSize = 50_000 // 50KB reasonable for a single SSE line
        let maxByteBufferSize = 4 // UTF-8 sequences are max 4 bytes

        for try await byte in bytes {
            try Task.checkCancellation()

            // Accumulate bytes for UTF-8 decoding
            byteBuffer.append(byte)

            // Try to decode accumulated bytes as UTF-8
            if let decodedString = String(data: byteBuffer, encoding: .utf8) {
                // Successfully decoded - append to buffer and clear byte buffer
                buffer.append(decodedString)
                byteBuffer.removeAll(keepingCapacity: true)

                // Enforce buffer size limit to prevent DoS
                guard buffer.count < maxBufferSize else {
                    throw AIError.generationFailed(underlying: SendableError(NSError(
                        domain: "OpenAIProvider",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Stream buffer overflow - line exceeds \(maxBufferSize) characters"]
                    )))
                }
            } else if byteBuffer.count > maxByteBufferSize {
                // We have more than 4 bytes and still can't decode - invalid UTF-8
                throw AIError.generationFailed(underlying: SendableError(NSError(
                    domain: "OpenAIProvider",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 sequence in streaming response"]
                )))
            }
            // Otherwise, continue accumulating bytes (incomplete multi-byte sequence)

            // Process complete lines
            while let lineEnd = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<lineEnd])
                buffer = String(buffer[buffer.index(after: lineEnd)...])

                if line.hasPrefix("data: ") {
                    let jsonStr = String(line.dropFirst(6))

                    if jsonStr == "[DONE]" {
                        continuation.finish()
                        return
                    }

                    if let jsonData = jsonStr.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let delta = firstChoice["delta"] as? [String: Any] {

                        let content = delta["content"] as? String
                        let finishReasonStr = firstChoice["finish_reason"] as? String
                        let finishReason = finishReasonStr.flatMap { FinishReason(rawValue: $0) }

                        // Only yield if there's content or if it's a final chunk with finish reason
                        if let content = content, !content.isEmpty {
                            let chunk = GenerationChunk(
                                text: content,
                                isComplete: finishReason != nil,
                                finishReason: finishReason
                            )
                            continuation.yield(chunk)
                            chunkIndex += 1
                        } else if let finishReason = finishReason {
                            // Yield completion chunk
                            let chunk = GenerationChunk.completion(finishReason: finishReason)
                            continuation.yield(chunk)
                        }
                    }
                }
            }
        }

        continuation.finish()
    }
}
