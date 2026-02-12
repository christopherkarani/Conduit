// TextGenerator+StructuredStreaming.swift
// Conduit
//
// Extension for streaming structured Generable responses.

import Foundation

// MARK: - TextGenerator Structured Streaming

extension TextGenerator {

    /// Streams a structured response, yielding partial values as they arrive.
    ///
    /// This method enables progressive UI updates during generation by parsing
    /// incomplete JSON and yielding typed partial values.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Generable
    /// struct Analysis {
    ///     let summary: String
    ///     let score: Int
    /// }
    ///
    /// let stream = provider.stream(
    ///     "Analyze this text",
    ///     returning: Analysis.self,
    ///     model: .claude4Sonnet
    /// )
    ///
    /// for try await partial in stream {
    ///     if let summary = partial.summary {
    ///         summaryLabel.text = summary
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model
    ///   - type: The Generable type to parse responses into
    ///   - model: The model to use for generation
    ///   - config: Configuration options for the request
    /// - Returns: A StreamingResult that yields partial values
    public func stream<T: Generable>(
        _ prompt: String,
        returning type: T.Type,
        model: ModelID,
        config: GenerateConfig = GenerateConfig()
    ) -> StreamingResult<T> {
        // Create the underlying string stream
        let stringStream = stream(prompt, model: model, config: config)

        // Transform to structured streaming
        let structuredStream = AsyncThrowingStream<StreamingResult<T>.Snapshot, Error> { continuation in
            let task = Task {
                var accumulated = ""
                accumulated.reserveCapacity(4096)
                var lastParsedContent: GeneratedContent?
                let partialDecoder = PartialJSONDecoder()

                // Maximum buffer size limit (1MB)
                let maxAccumulatedSize = 1_000_000

                do {
                    for try await chunk in stringStream {
                        // Check for cancellation to improve responsiveness
                        try Task.checkCancellation()

                        // Check buffer size limit BEFORE appending to prevent exceeding limit
                        guard accumulated.count + chunk.count <= maxAccumulatedSize else {
                            throw StreamingError.parseFailed("Response would exceed maximum size of 1MB")
                        }
                        accumulated += chunk

                        // Only attempt parse when chunk likely changes JSON parseability.
                        let shouldAttemptParse = chunk.rangeOfCharacter(
                            from: CharacterSet(charactersIn: "{}[]\":,0123456789tfn-")
                        ) != nil
                        guard shouldAttemptParse else { continue }

                        // Try strict parse first, then partial decode/repair fallback.
                        if let content = Self.parseStreamingContent(
                            from: accumulated,
                            partialDecoder: partialDecoder
                        ) {
                            do {
                                let partial = try T.PartiallyGenerated(content)
                                // Only yield if meaningfully different from last
                                if lastParsedContent != content {
                                    lastParsedContent = content
                                    continuation.yield(.init(content: partial, rawContent: content))
                                }
                            } catch {
                                // Parsing to Partial failed, continue accumulating
                            }
                        }
                    }

                    // Final parse attempt with complete content
                    if let content = Self.parseStreamingContent(
                        from: accumulated,
                        partialDecoder: partialDecoder
                    ) {
                        do {
                            let partial = try T.PartiallyGenerated(content)
                            if lastParsedContent != content {
                                continuation.yield(.init(content: partial, rawContent: content))
                            }
                        } catch {
                            continuation.finish(throwing: StreamingError.conversionFailed(error))
                            return
                        }
                    } else if lastParsedContent == nil && !accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        continuation.finish(throwing: StreamingError.parseFailed("Unable to parse streamed JSON"))
                        return
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

        return StreamingResult(structuredStream)
    }

    /// Parses streaming JSON with strict, partial, and repair fallbacks.
    private static func parseStreamingContent(
        from json: String,
        partialDecoder: PartialJSONDecoder
    ) -> GeneratedContent? {
        // Prefer strict JSON parse to avoid unnecessary repair/completion artifacts.
        if let strict = parseStrictStreamingJSON(json) {
            return strict
        }

        // Try partial decoding into a dynamic JSON value for incomplete fragments.
        if let data = json.data(using: .utf8),
           let decoded = try? partialDecoder.decode(AnyCodable.self, from: data),
           let content = try? GeneratedContent.fromJSONValue(decoded.value.anyValue) {
            return content
        }

        // Fall back to JSON repair for malformed fragments (trailing commas, cut strings).
        return JsonRepair.tryParse(json)
    }

    /// Strict JSON parse helper used before fallback paths.
    private static func parseStrictStreamingJSON(_ json: String) -> GeneratedContent? {
        guard let data = json.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let content = try? GeneratedContent.fromJSONValue(value) else {
            return nil
        }
        return content
    }

    /// Streams a structured response with messages context.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - type: The Generable type to parse responses into
    ///   - model: The model to use for generation
    ///   - config: Configuration options for the request
    /// - Returns: A StreamingResult that yields partial values
    public func stream<T: Generable>(
        messages: [Message],
        returning type: T.Type,
        model: ModelID,
        config: GenerateConfig = GenerateConfig()
    ) -> StreamingResult<T> {
        // Validate messages array is non-empty
        guard !messages.isEmpty else {
            let errorStream = AsyncThrowingStream<StreamingResult<T>.Snapshot, Error> { continuation in
                continuation.finish(throwing: StreamingError.parseFailed("Messages array cannot be empty"))
            }
            return StreamingResult(errorStream)
        }

        // Build prompt from messages for structured output
        let prompt = messages.map { message in
            switch message.role {
            case .user:
                return "User: \(message.content.textValue)"
            case .assistant:
                return "Assistant: \(message.content.textValue)"
            case .system:
                return "System: \(message.content.textValue)"
            case .tool:
                return "Tool: \(message.content.textValue)"
            }
        }.joined(separator: "\n")

        // Add schema instruction
        let schemaJSON = T.generationSchema.toJSONString()
        let structuredPrompt = """
        \(prompt)

        Respond with valid JSON matching this schema:
        \(schemaJSON)
        """

        return stream(structuredPrompt, returning: type, model: model, config: config)
    }
}
