// OpenAIProvider+Streaming.swift
// Conduit
//
// Streaming text generation functionality for OpenAIProvider.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Logging

/// Maximum allowed size for accumulated tool call arguments (100KB).
/// Prevents memory exhaustion from malicious or malformed responses.
private let maxToolArgumentsSize = 100_000

/// Maximum allowed size for accumulated reasoning text (100KB).
/// Prevents memory exhaustion from malicious or malformed responses.
private let maxReasoningSize = 100_000

private struct ReasoningAccumulator {
    var id: String
    var type: String
    var format: String
    var index: Int
    var content: String
}

/// Logger for OpenAI streaming operations.
private let logger = ConduitLoggers.streaming

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

        // Execute streaming request (cross-platform)
        let (bytes, response) = try await session.asyncBytes(for: request)

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
        var sseParser = ServerSentEventParser()

        // Buffer size limits to prevent DoS
        let maxBufferSize = 50_000 // 50KB reasonable for a single SSE line
        let maxByteBufferSize = 4 // UTF-8 sequences are max 4 bytes

        // Tool call accumulation by index
        // Each entry tracks: id, name, and accumulated arguments buffer
        var toolCallAccumulators: [Int: (id: String, name: String, argumentsBuffer: String)] = [:]
        var completedToolCalls: [Transcript.ToolCall] = []

        // Reasoning accumulation
        var reasoningBuffer = ""
        var reasoningDetailBuffers: [String: ReasoningAccumulator] = [:]

        func buildReasoningDetails() -> [ReasoningDetail] {
            var details = reasoningDetailBuffers.values
                .sorted(by: { $0.index < $1.index })
                .map { acc in
                    ReasoningDetail(
                        id: acc.id,
                        type: acc.type,
                        format: acc.format,
                        index: acc.index,
                        content: acc.content.isEmpty ? nil : acc.content
                    )
                }

            if !reasoningBuffer.isEmpty {
                let nextIndex = (details.map(\.index).max() ?? -1) + 1
                details.append(ReasoningDetail(
                    id: "rd_text",
                    type: "reasoning.text",
                    format: "unknown",
                    index: nextIndex,
                    content: reasoningBuffer
                ))
            }

            return details
        }

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

                for event in sseParser.ingestLine(line) {
                    let jsonStr = event.data

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

                        var hasReasoningUpdate = false
                        var reasoningDetailsForChunk: [ReasoningDetail]? = nil

                        if let reasoningDelta = delta["reasoning"] as? String, !reasoningDelta.isEmpty {
                            let newSize = reasoningBuffer.count + reasoningDelta.count
                            if newSize > maxReasoningSize {
                                logger.warning("Reasoning text exceeded \(maxReasoningSize) bytes, truncating")
                                let remaining = max(0, maxReasoningSize - reasoningBuffer.count)
                                reasoningBuffer += String(reasoningDelta.prefix(remaining))
                            } else {
                                reasoningBuffer += reasoningDelta
                            }
                            hasReasoningUpdate = true
                        }

                        if let reasoningDetailsDelta = delta["reasoning_details"] as? [[String: Any]] {
                            for (fallbackIndex, rd) in reasoningDetailsDelta.enumerated() {
                                let id = rd["id"] as? String ?? "rd_\(fallbackIndex)"
                                let type = rd["type"] as? String ?? "reasoning.text"
                                let format = rd["format"] as? String ?? "unknown"
                                let index = rd["index"] as? Int ?? fallbackIndex
                                let fragment = rd["content"] as? String ?? ""

                                var acc = reasoningDetailBuffers[id] ?? ReasoningAccumulator(
                                    id: id,
                                    type: type,
                                    format: format,
                                    index: index,
                                    content: ""
                                )
                                acc.type = type
                                acc.format = format
                                acc.index = index

                                if !fragment.isEmpty {
                                    let newSize = acc.content.count + fragment.count
                                    if newSize > maxReasoningSize {
                                        logger.warning("Reasoning detail '\(id)' exceeded \(maxReasoningSize) bytes, truncating")
                                        let remaining = max(0, maxReasoningSize - acc.content.count)
                                        acc.content += String(fragment.prefix(remaining))
                                    } else {
                                        acc.content += fragment
                                    }
                                }

                                reasoningDetailBuffers[id] = acc
                                hasReasoningUpdate = true
                            }
                        }

                        if hasReasoningUpdate {
                            let details = buildReasoningDetails()
                            if !details.isEmpty {
                                reasoningDetailsForChunk = details
                            }
                        }

                        // Process tool calls if present in delta
                        var partialToolCall: PartialToolCall?
                        if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                            for tc in toolCalls {
                                guard let index = tc["index"] as? Int else { continue }

                                // Validate index is within reasonable bounds (0...100)
                                guard (0...100).contains(index) else {
                                    let toolName = (tc["function"] as? [String: Any])?["name"] as? String ?? "unknown"
                                    logger.warning(
                                        "Skipping tool call '\(toolName)' with invalid index \(index) (must be 0...100)"
                                    )
                                    continue
                                }

                                // First chunk for this tool call has id, type, and function name
                                if let id = tc["id"] as? String,
                                   let function = tc["function"] as? [String: Any],
                                   let name = function["name"] as? String {
                                    // Initialize accumulator with initial arguments (if any)
                                    let args = function["arguments"] as? String ?? ""
                                    toolCallAccumulators[index] = (id: id, name: name, argumentsBuffer: args)
                                } else if let function = tc["function"] as? [String: Any],
                                          let argsFragment = function["arguments"] as? String {
                                    // Append to existing accumulator with buffer size check
                                    if var acc = toolCallAccumulators[index] {
                                        // Pre-allocate capacity on first append to avoid O(n²) string concatenation
                                        if acc.argumentsBuffer.isEmpty {
                                            acc.argumentsBuffer.reserveCapacity(min(4096, maxToolArgumentsSize))
                                        }

                                        let newSize = acc.argumentsBuffer.count + argsFragment.count
                                        if newSize > maxToolArgumentsSize {
                                            logger.warning(
                                                "Tool call '\(acc.name)' arguments exceeded \(maxToolArgumentsSize) bytes, truncating"
                                            )
                                            let remaining = max(0, maxToolArgumentsSize - acc.argumentsBuffer.count)
                                            acc.argumentsBuffer += String(argsFragment.prefix(remaining))
                                        } else {
                                            acc.argumentsBuffer += argsFragment
                                        }
                                        toolCallAccumulators[index] = acc
                                    }
                                }

                                // Create partial tool call for streaming updates
                                if let acc = toolCallAccumulators[index] {
                                    partialToolCall = PartialToolCall(
                                        id: acc.id,
                                        toolName: acc.name,
                                        index: index,
                                        argumentsFragment: acc.argumentsBuffer
                                    )
                                }
                            }
                        }

                        // Check if we should finalize tool calls
                        let isToolCallsComplete = finishReason == .toolCalls || finishReason == .toolCall

                        if isToolCallsComplete && !toolCallAccumulators.isEmpty {
                            let completedReasoningDetails = buildReasoningDetails()

                            // Finalize all accumulated tool calls
                            for (index, acc) in toolCallAccumulators.sorted(by: { $0.key < $1.key }) {
                                do {
                                    let toolCall = try Transcript.ToolCall(
                                        id: acc.id,
                                        toolName: acc.name,
                                        argumentsJSON: acc.argumentsBuffer
                                    )
                                    completedToolCalls.append(toolCall)
                                    logger.debug("Parsed tool call '\(acc.name)' at index \(index)")
                                } catch {
                                    // Try to repair incomplete JSON before giving up
                                    let repairedJson = JsonRepair.repair(acc.argumentsBuffer)
                                    if repairedJson != acc.argumentsBuffer {
                                        logger.debug("Attempting JSON repair for '\(acc.name)'")
                                        do {
                                            let toolCall = try Transcript.ToolCall(
                                                id: acc.id,
                                                toolName: acc.name,
                                                argumentsJSON: repairedJson
                                            )
                                            completedToolCalls.append(toolCall)
                                            logger.info("Recovered tool call '\(acc.name)' via JSON repair")
                                        } catch {
                                            logger.warning(
                                                "Failed to parse tool call '\(acc.name)' even after repair: \(error.localizedDescription)"
                                            )
                                            logger.debug("Original JSON: \(acc.argumentsBuffer.prefix(500))")
                                            logger.debug("Repaired JSON: \(repairedJson.prefix(500))")
                                        }
                                    } else {
                                        logger.warning(
                                            "Failed to parse tool call '\(acc.name)': \(error.localizedDescription)"
                                        )
                                        logger.debug("Malformed JSON buffer: \(acc.argumentsBuffer.prefix(500))")
                                    }
                                }
                            }

                            // Yield final chunk with completed tool calls
                            let chunk = GenerationChunk(
                                text: content ?? "",
                                tokenCount: content?.isEmpty == false ? 1 : 0,
                                isComplete: true,
                                finishReason: finishReason,
                                completedToolCalls: completedToolCalls.isEmpty ? nil : completedToolCalls,
                                reasoningDetails: completedReasoningDetails.isEmpty ? nil : completedReasoningDetails
                            )
                            continuation.yield(chunk)
                            chunkIndex += 1
                        } else if let content = content, !content.isEmpty {
                            let finalReasoningDetails: [ReasoningDetail]? = {
                                if finishReason != nil {
                                    let details = buildReasoningDetails()
                                    return details.isEmpty ? nil : details
                                }
                                return reasoningDetailsForChunk
                            }()

                            // Yield content chunk (may also include partial tool call)
                            let chunk = GenerationChunk(
                                text: content,
                                isComplete: finishReason != nil,
                                finishReason: finishReason,
                                partialToolCall: partialToolCall,
                                reasoningDetails: finalReasoningDetails
                            )
                            continuation.yield(chunk)
                            chunkIndex += 1
                        } else if partialToolCall != nil {
                            // Yield chunk with only partial tool call update
                            let chunk = GenerationChunk(
                                text: "",
                                tokenCount: 0,
                                isComplete: false,
                                partialToolCall: partialToolCall,
                                reasoningDetails: reasoningDetailsForChunk
                            )
                            continuation.yield(chunk)
                            chunkIndex += 1
                        } else if let reasoningDetailsForChunk {
                            let chunk = GenerationChunk(
                                text: "",
                                tokenCount: 0,
                                isComplete: false,
                                reasoningDetails: reasoningDetailsForChunk
                            )
                            continuation.yield(chunk)
                            chunkIndex += 1
                        } else if let finishReason = finishReason {
                            let completedReasoningDetails = buildReasoningDetails()
                            // Yield completion chunk
                            let chunk = GenerationChunk(
                                text: "",
                                tokenCount: 0,
                                isComplete: true,
                                finishReason: finishReason,
                                reasoningDetails: completedReasoningDetails.isEmpty ? nil : completedReasoningDetails
                            )
                            continuation.yield(chunk)
                        }
                    }
                }
            }
        }

        continuation.finish()
    }
}
