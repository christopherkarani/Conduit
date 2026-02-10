// AnthropicProvider+Streaming.swift
// Conduit
//
// Streaming implementation for AnthropicProvider with Server-Sent Events (SSE) parsing.

#if CONDUIT_TRAIT_ANTHROPIC
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Logging

/// Maximum allowed size for accumulated tool call arguments (100KB).
/// Prevents memory exhaustion from malicious or malformed responses.
private let maxToolArgumentsSize = 100_000

/// Logger for Anthropic streaming diagnostics.
private let logger = ConduitLoggers.streaming

// MARK: - Streaming Implementation

extension AnthropicProvider {

    /// Streams generation with full metadata (tokens, performance metrics).
    ///
    /// Returns AsyncThrowingStream of GenerationChunk for token-by-token streaming.
    /// This is the metadata-rich version used by stream(messages:model:config:).
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// let messages = [Message.user("Explain async/await")]
    ///
    /// let stream = provider.streamWithMetadata(
    ///     messages: messages,
    ///     model: .claudeSonnet45,
    ///     config: .default
    /// )
    ///
    /// for try await chunk in stream {
    ///     if !chunk.text.isEmpty {
    ///         print(chunk.text, terminator: "")
    ///     }
    ///
    ///     if chunk.isComplete {
    ///         print("\n\nFinished: \(chunk.finishReason ?? .stop)")
    ///         if let tps = chunk.tokensPerSecond {
    ///             print("Speed: \(tps) tokens/sec")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## Chunk Structure
    ///
    /// Each `GenerationChunk` contains:
    /// - `text`: Text fragment (may be empty for metadata-only chunks)
    /// - `finishReason`: Present in final chunk, indicates why generation stopped
    /// - `tokensPerSecond`: Performance metric updated with each chunk
    /// - `isComplete`: Whether this is the final chunk
    ///
    /// ## Cancellation
    ///
    /// The stream supports cancellation via Swift's structured concurrency:
    /// ```swift
    /// let task = Task {
    ///     for try await chunk in provider.streamWithMetadata(...) {
    ///         print(chunk.text)
    ///     }
    /// }
    /// task.cancel() // Stops streaming
    /// ```
    ///
    /// ## Error Handling
    ///
    /// The stream throws `AIError` variants:
    /// - `.authenticationFailed`: Invalid or missing API key
    /// - `.rateLimited`: Rate limit exceeded
    /// - `.serverError`: Anthropic API error
    /// - `.networkError`: Network connectivity issues
    ///
    /// - Parameters:
    ///   - messages: The conversation history. Must contain at least one message.
    ///   - model: The Claude model to use (e.g., `.claudeOpus45`).
    ///   - config: Configuration parameters (temperature, max tokens, etc.).
    ///
    /// - Returns: An `AsyncThrowingStream` that emits `GenerationChunk` objects.
    ///
    /// - Note: This method is marked `nonisolated` because it returns the
    ///   stream synchronously. The actual generation happens asynchronously
    ///   when the stream is iterated.
    nonisolated public func streamWithMetadata(
        messages: [Message],
        model: AnthropicModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performStreamingGeneration(
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

    /// Streams generation chunks for the given messages (AIProvider conformance).
    ///
    /// This is the core streaming method required by the `AIProvider` protocol.
    /// It delegates to `streamWithMetadata` to provide the full streaming implementation.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// let messages = [Message.user("Hello")]
    ///
    /// let stream = provider.stream(
    ///     messages: messages,
    ///     model: .claudeSonnet45,
    ///     config: .default
    /// )
    ///
    /// for try await chunk in stream {
    ///     print(chunk.text, terminator: "")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - messages: The conversation history. Must contain at least one message.
    ///   - model: The Claude model to use (e.g., `.claudeOpus45`).
    ///   - config: Configuration parameters (temperature, max tokens, etc.).
    ///
    /// - Returns: An `AsyncThrowingStream` that emits `GenerationChunk` objects.
    ///
    /// - Note: This method is marked `nonisolated` because it returns the
    ///   stream synchronously. The actual generation happens asynchronously
    ///   when the stream is iterated.
    nonisolated public func stream(
        messages: [Message],
        model: AnthropicModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        streamWithMetadata(messages: messages, model: model, config: config)
    }

    /// Streams text-only generation (TextGenerator conformance).
    ///
    /// This method provides string-only streaming for the `TextGenerator` protocol.
    /// It wraps the prompt in a user message and streams the text without metadata.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = AnthropicProvider(apiKey: "sk-ant-...")
    /// let stream = provider.stream(
    ///     "Write a poem about Swift",
    ///     model: .claudeSonnet45,
    ///     config: .default
    /// )
    ///
    /// var fullText = ""
    /// for try await token in stream {
    ///     print(token, terminator: "")
    ///     fullText += token
    /// }
    /// print("\n\nComplete: \(fullText)")
    /// ```
    ///
    /// ## Stream Behavior
    ///
    /// - Emits text fragments as they become available
    /// - Filters out empty text chunks
    /// - Completes when generation finishes
    /// - Throws if an error occurs during generation
    ///
    /// - Parameters:
    ///   - prompt: The input text to generate a response for.
    ///   - model: The Claude model to use (e.g., `.claudeOpus45`).
    ///   - config: Configuration parameters (temperature, max tokens, etc.).
    ///
    /// - Returns: An `AsyncThrowingStream` that emits text fragments.
    ///
    /// - Note: This method is marked `nonisolated` because it returns the
    ///   stream synchronously. The actual generation happens asynchronously
    ///   when the stream is iterated.
    nonisolated public func stream(
        _ prompt: String,
        model: AnthropicModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        let messages = [Message.user(prompt)]

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in streamWithMetadata(messages: messages, model: model, config: config) {
                        // Check for task cancellation at the start of each iteration
                        try Task.checkCancellation()

                        if !chunk.text.isEmpty {
                            continuation.yield(chunk.text)
                        }
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
}

// MARK: - Core Streaming Logic

extension AnthropicProvider {

    /// Internal streaming implementation with SSE parsing.
    ///
    /// This method handles the complete lifecycle of a streaming request:
    /// 1. Build request body with stream=true
    /// 2. Create URLRequest with authentication headers
    /// 3. Execute streaming HTTP request with session.bytes(for:)
    /// 4. Parse Server-Sent Events line by line
    /// 5. Decode JSON events into AnthropicStreamEvent enum
    /// 6. Process events and yield GenerationChunk objects
    /// 7. Send final completion chunk
    ///
    /// ## SSE Format
    ///
    /// Anthropic's streaming API uses Server-Sent Events:
    /// ```
    /// data: {"type":"message_start",...}
    /// data: {"type":"content_block_start",...}
    /// data: {"type":"content_block_delta","delta":{"text":"Hello"}}
    /// data: {"type":"content_block_stop"}
    /// data: {"type":"message_stop"}
    /// ```
    ///
    /// ## Event Flow
    ///
    /// 1. `message_start`: Message metadata (skipped)
    /// 2. `content_block_start`: Content block begins (skipped)
    /// 3. `content_block_delta`: Text chunks (yields GenerationChunk)
    /// 4. `content_block_stop`: Content block ends (skipped)
    /// 5. `message_stop`: Message complete (final chunk)
    ///
    /// ## Performance Tracking
    ///
    /// - Tracks total tokens generated
    /// - Calculates tokens per second from start time
    /// - Updates performance metrics with each chunk
    ///
    /// ## Error Handling
    ///
    /// - HTTP errors mapped to AIError variants
    /// - JSON parsing errors gracefully skipped
    /// - Network errors bubble up to caller
    ///
    /// - Parameters:
    ///   - messages: The conversation history.
    ///   - model: The Claude model to use.
    ///   - config: Configuration parameters.
    ///   - continuation: The stream continuation to yield chunks to.
    ///
    /// - Throws: `AIError` if the request fails or response is invalid.
    internal func performStreamingGeneration(
        messages: [Message],
        model: AnthropicModelID,
        config: GenerateConfig,
        continuation: AsyncThrowingStream<GenerationChunk, Error>.Continuation
    ) async throws {
        // Validate input
        guard !messages.isEmpty else {
            throw AIError.invalidInput("Messages array cannot be empty")
        }

        // Build request with stream=true
        let request = buildRequestBody(messages: messages, model: model, config: config, stream: true)

        // Build URLRequest
        let url = configuration.baseURL.appending(path: "v1/messages")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        // Add headers (authentication, API version, content-type)
        for (name, value) in configuration.buildHeaders() {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        // Encode request body
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }

        // Execute streaming request (cross-platform)
        let bytes: URLSessionAsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.asyncBytes(for: urlRequest)
        } catch let urlError as URLError {
            throw AIError.networkError(urlError)
        } catch {
            throw AIError.networkError(URLError(.unknown))
        }

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Issue 12.9: Collect and decode error body for better diagnostics
            var errorData = Data()
            errorData.reserveCapacity(10_000)  // Pre-allocate for expected error size
            for try await byte in bytes {
                try Task.checkCancellation()
                errorData.append(byte)
                if errorData.count > 10_000 { break } // Limit collection
            }

            // Try to decode structured error response
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: errorData) {
                throw mapAnthropicError(errorResponse, statusCode: httpResponse.statusCode)
            }

            // Fallback with raw error text
            throw AIError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: errorData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            )
        }

        // Parse SSE events line by line
        var totalTokens = 0
        let startTime = Date()

        // Tool call accumulation state
        // Maps content block index to (id, name, jsonBuffer)
        var activeToolCalls: [Int: (id: String, name: String, jsonBuffer: String)] = [:]
        var completedToolCalls: [Transcript.ToolCall] = []

        var sseParser = ServerSentEventParser()

        sse: for try await line in bytes.lines {
            // Check for task cancellation at the start of each iteration
            try Task.checkCancellation()

            for event in sseParser.ingestLine(line) {
                let jsonString = event.data

                // Skip [DONE] marker
                if jsonString == "[DONE]" { break sse }

                guard let eventData = jsonString.data(using: .utf8) else { continue }

                // Issue 12.11: Parse event with error logging for diagnostics
                do {
                    if let event = try parseStreamEvent(from: eventData) {
                        if let chunk = try processStreamEvent(
                            event,
                            startTime: startTime,
                            totalTokens: &totalTokens,
                            activeToolCalls: &activeToolCalls,
                            completedToolCalls: &completedToolCalls
                        ) {
                            continuation.yield(chunk)
                        }
                    }
                } catch let error as AIError {
                    // Stream error events throw AIError - propagate to consumer
                    throw error
                } catch {
                    // Issue 12.11: Log parsing errors for diagnostics
                    logger.debug(
                        "Failed to parse stream event",
                        metadata: ["error": .string("\(error)")]
                    )
                    // Continue processing - don't fail the stream for single event parse errors
                }
            }
        }

        // Send final completion chunk
        continuation.yield(GenerationChunk.completion(finishReason: .stop))
        continuation.finish()
    }

    /// Parses SSE event JSON into AnthropicStreamEvent enum.
    ///
    /// This method determines the event type from the JSON and decodes
    /// the appropriate event structure.
    ///
    /// ## Event Types
    ///
    /// - `message_start`: Initial message metadata
    /// - `content_block_start`: Content block begins
    /// - `content_block_delta`: Text chunk (the important one!)
    /// - `content_block_stop`: Content block ends
    /// - `message_stop`: Message complete
    ///
    /// ## JSON Structure
    ///
    /// All events have a `type` field:
    /// ```json
    /// {
    ///   "type": "content_block_delta",
    ///   "index": 0,
    ///   "delta": {
    ///     "type": "text_delta",
    ///     "text": "Hello"
    ///   }
    /// }
    /// ```
    ///
    /// ## Error Handling
    ///
    /// - Returns `nil` if JSON parsing fails (gracefully skips event)
    /// - Returns `nil` for unknown event types (future-proof)
    /// - Returns appropriate enum case for recognized types
    ///
    /// - Parameter data: The JSON data from the SSE event.
    ///
    /// - Returns: The parsed `AnthropicStreamEvent` or `nil` if parsing fails.
    ///
    /// - Throws: JSONDecoder errors if the JSON structure is invalid.
    internal func parseStreamEvent(from data: Data) throws -> AnthropicStreamEvent? {
        // Decode to determine event type
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        switch type {
        case "message_start":
            let event = try decoder.decode(AnthropicStreamEvent.MessageStart.self, from: data)
            return .messageStart(event)

        case "content_block_start":
            let event = try decoder.decode(AnthropicStreamEvent.ContentBlockStart.self, from: data)
            return .contentBlockStart(event)

        case "content_block_delta":
            let event = try decoder.decode(AnthropicStreamEvent.ContentBlockDelta.self, from: data)
            return .contentBlockDelta(event)

        case "content_block_stop":
            let event = try decoder.decode(AnthropicStreamEvent.ContentBlockStop.self, from: data)
            return .contentBlockStop(event)

        case "message_stop":
            return .messageStop

        case "message_delta":
            let event = try decoder.decode(AnthropicStreamEvent.MessageDelta.self, from: data)
            return .messageDelta(event)

        case "error":
            let event = try decoder.decode(AnthropicStreamEvent.StreamError.self, from: data)
            return .error(event)

        case "ping":
            return .ping

        default:
            // Unknown event type - skip (future-proof)
            return nil
        }
    }

    /// Processes stream event and yields GenerationChunk if applicable.
    ///
    /// **CRITICAL**: Only `content_block_delta` and `message_delta` events
    /// produce chunks - all others are metadata.
    ///
    /// ## Event Processing
    ///
    /// - `messageStart`: Metadata only, returns `nil`
    /// - `contentBlockStart`: Initializes tool call state for tool_use blocks, returns `nil`
    /// - `contentBlockDelta`: **Contains text or tool JSON**, returns `GenerationChunk` for text
    /// - `contentBlockStop`: Finalizes tool calls, returns `nil`
    /// - `messageDelta`: **Contains usage stats**, returns final `GenerationChunk` with tool calls
    /// - `messageStop`: Metadata only, returns `nil`
    /// - `error`: **Throws AIError** to propagate to stream consumer
    /// - `ping`: Keep-alive heartbeat, returns `nil`
    ///
    /// ## Tool Call Handling
    ///
    /// Tool calls are accumulated during streaming:
    /// 1. `contentBlockStart` with type="tool_use" initializes a new tool call
    /// 2. `contentBlockDelta` with type="input_json_delta" accumulates JSON fragments
    /// 3. `contentBlockStop` finalizes the tool call and adds it to completedToolCalls
    /// 4. `messageDelta` returns the final chunk with all completed tool calls
    ///
    /// ## Performance Metrics
    ///
    /// Each chunk includes:
    /// - Token count (incremented)
    /// - Tokens per second (calculated from start time)
    /// - Timestamp
    ///
    /// ## Usage
    /// ```swift
    /// if let chunk = try processStreamEvent(
    ///     event,
    ///     startTime: startTime,
    ///     totalTokens: &totalTokens,
    ///     activeToolCalls: &activeToolCalls,
    ///     completedToolCalls: &completedToolCalls
    /// ) {
    ///     continuation.yield(chunk)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - event: The parsed stream event.
    ///   - startTime: When generation started (for performance metrics).
    ///   - totalTokens: Running total of tokens (incremented for text deltas).
    ///   - activeToolCalls: Currently accumulating tool calls (by content block index).
    ///   - completedToolCalls: Finalized tool calls ready to be returned.
    ///
    /// - Returns: A `GenerationChunk` if this event contains text or completes generation, `nil` otherwise.
    ///
    /// - Throws: `AIError.serverError` if an error event is received.
    internal func processStreamEvent(
        _ event: AnthropicStreamEvent,
        startTime: Date,
        totalTokens: inout Int,
        activeToolCalls: inout [Int: (id: String, name: String, jsonBuffer: String)],
        completedToolCalls: inout [Transcript.ToolCall]
    ) throws -> GenerationChunk? {
        switch event {
        case .contentBlockStart(let start):
            // Initialize tool call state for tool_use blocks
            if start.contentBlock.type == "tool_use",
               let id = start.contentBlock.id,
               let name = start.contentBlock.name {
                // Validate index is within reasonable bounds (0...100)
                guard (0...100).contains(start.index) else {
                    logger.warning(
                        "Skipping tool call '\(name)' with invalid index \(start.index) (must be 0...100)"
                    )
                    return nil
                }
                activeToolCalls[start.index] = (id: id, name: name, jsonBuffer: "")
            }
            return nil

        case .contentBlockDelta(let delta):
            // Handle text deltas
            if delta.delta.type == "text_delta", let text = delta.delta.text {
                // NOTE: Token count is approximate during streaming. Each content_block_delta
                // is counted as 1 token, but may contain multiple tokens. Accurate counts
                // are available in the final message_delta event via UsageStats.
                totalTokens += 1
                let duration = Date().timeIntervalSince(startTime)
                let tokensPerSecond = duration > 0 ? Double(totalTokens) / duration : 0

                return GenerationChunk(
                    text: text,
                    tokenCount: 1,
                    tokenId: nil,
                    logprob: nil,
                    topLogprobs: nil,
                    tokensPerSecond: tokensPerSecond,
                    isComplete: false,
                    finishReason: nil,
                    timestamp: Date()
                )
            }

            // Handle tool input JSON deltas
            if delta.delta.type == "input_json_delta", let partialJson = delta.delta.partialJson {
                if var toolData = activeToolCalls[delta.index] {
                    // Pre-allocate capacity on first append to avoid O(n²) string concatenation
                    if toolData.jsonBuffer.isEmpty {
                        toolData.jsonBuffer.reserveCapacity(min(4096, maxToolArgumentsSize))
                    }

                    // Check buffer size limit to prevent memory exhaustion
                    let newSize = toolData.jsonBuffer.count + partialJson.count
                    if newSize > maxToolArgumentsSize {
                        logger.warning(
                            "Tool call '\(toolData.name)' arguments exceeded \(maxToolArgumentsSize) bytes, truncating"
                        )
                        // Truncate to limit - this will likely result in invalid JSON,
                        // which will be caught during finalization
                        let remaining = max(0, maxToolArgumentsSize - toolData.jsonBuffer.count)
                        toolData.jsonBuffer += String(partialJson.prefix(remaining))
                    } else {
                        toolData.jsonBuffer += partialJson
                    }
                    activeToolCalls[delta.index] = toolData
                }
                // Optionally could yield a PartialToolCall chunk here for progress tracking
            }

            return nil

        case .contentBlockStop(let stop):
            // Finalize tool call if we have one at this index
            if let toolData = activeToolCalls.removeValue(forKey: stop.index) {
                // Only create tool call if we have accumulated JSON
                let jsonBuffer = toolData.jsonBuffer.isEmpty ? "{}" : toolData.jsonBuffer
                do {
                    let toolCall = try Transcript.ToolCall(
                        id: toolData.id,
                        toolName: toolData.name,
                        argumentsJSON: jsonBuffer
                    )
                    completedToolCalls.append(toolCall)
                    logger.debug("Parsed tool call '\(toolData.name)' with id '\(toolData.id)'")
                } catch {
                    // Try to repair incomplete JSON before giving up
                    let repairedJson = JsonRepair.repair(jsonBuffer)
                    if repairedJson != jsonBuffer {
                        logger.debug("Attempting JSON repair for '\(toolData.name)'")
                        do {
                            let toolCall = try Transcript.ToolCall(
                                id: toolData.id,
                                toolName: toolData.name,
                                argumentsJSON: repairedJson
                            )
                            completedToolCalls.append(toolCall)
                            logger.info("Recovered tool call '\(toolData.name)' via JSON repair")
                        } catch {
                            logger.warning(
                                "Failed to parse tool call '\(toolData.name)' even after repair: \(error.localizedDescription)"
                            )
                            logger.debug("Original JSON: \(jsonBuffer.prefix(500))")
                            logger.debug("Repaired JSON: \(repairedJson.prefix(500))")
                        }
                    } else {
                        logger.warning(
                            "Failed to parse tool call '\(toolData.name)': \(error.localizedDescription)"
                        )
                        logger.debug("Malformed JSON buffer: \(jsonBuffer.prefix(500))")
                    }
                }
            }
            return nil

        case .messageDelta(let delta):
            // Final event with usage statistics, stop reason, and completed tool calls
            return GenerationChunk(
                text: "",
                tokenCount: 0,
                tokenId: nil,
                logprob: nil,
                topLogprobs: nil,
                tokensPerSecond: nil,
                isComplete: true,
                finishReason: mapStreamStopReason(delta.delta.stopReason),
                timestamp: Date(),
                usage: UsageStats(
                    promptTokens: delta.usage.inputTokens,
                    completionTokens: delta.usage.outputTokens
                ),
                completedToolCalls: completedToolCalls.isEmpty ? nil : completedToolCalls
            )

        case .error(let streamError):
            // Throw as AIError to propagate to stream consumer
            throw AIError.serverError(
                statusCode: 0,
                message: "[\(streamError.error.type)] \(streamError.error.message)"
            )

        case .ping:
            // Keep-alive heartbeat - ignore
            return nil

        default:
            // message_start, message_stop are metadata only
            return nil
        }
    }

    // MARK: - Private Helpers

    /// Maps Anthropic's stop reason string to a FinishReason enum.
    ///
    /// ## Mapping
    ///
    /// | Anthropic String | FinishReason |
    /// |-----------------|--------------|
    /// | `"end_turn"` | `.stop` |
    /// | `"max_tokens"` | `.maxTokens` |
    /// | `"stop_sequence"` | `.stopSequence` |
    /// | `"tool_use"` | `.toolCall` |
    /// | `"pause_turn"` | `.pauseTurn` |
    /// | `"refusal"` | `.contentFilter` |
    /// | `nil` or unknown | `.stop` |
    ///
    /// - Parameter reason: The Anthropic stop_reason string from the API response.
    ///
    /// - Returns: The corresponding `FinishReason` enum case.
    private func mapStreamStopReason(_ reason: String?) -> FinishReason {
        switch reason {
        case "end_turn":
            return .stop
        case "max_tokens":
            return .maxTokens
        case "stop_sequence":
            return .stopSequence
        case "tool_use":
            return .toolCall
        case "pause_turn":
            return .pauseTurn
        case "refusal":
            return .contentFilter
        case "model_context_window_exceeded":
            return .modelContextWindowExceeded
        default:
            return .stop
        }
    }
}

#endif // CONDUIT_TRAIT_ANTHROPIC
