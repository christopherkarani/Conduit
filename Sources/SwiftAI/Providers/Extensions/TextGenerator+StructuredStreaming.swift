// TextGenerator+StructuredStreaming.swift
// SwiftAI
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
        let structuredStream = AsyncThrowingStream<T.Partial, Error> { continuation in
            Task {
                var accumulated = ""
                accumulated.reserveCapacity(4096)
                var lastParsedPartial: T.Partial?
                var lastParsedContent: StructuredContent?

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

                        // Only attempt parse when we see potential JSON structure closures
                        let shouldAttemptParse = chunk.contains("}") || chunk.contains("]") || chunk.contains("\"")
                        guard shouldAttemptParse else { continue }

                        // Try to parse the accumulated JSON
                        if let content = JsonRepair.tryParse(accumulated) {
                            do {
                                let partial = try T.Partial(from: content)
                                // Only yield if meaningfully different from last
                                let currentContent = partial.generableContent
                                if lastParsedContent != currentContent {
                                    lastParsedContent = currentContent
                                    lastParsedPartial = partial
                                    continuation.yield(partial)
                                }
                            } catch {
                                // Parsing to Partial failed, continue accumulating
                            }
                        }
                    }

                    // Final parse attempt with complete content
                    if let content = JsonRepair.tryParse(accumulated) {
                        do {
                            let partial = try T.Partial(from: content)
                            if lastParsedPartial == nil {
                                continuation.yield(partial)
                            }
                        } catch {
                            continuation.finish(throwing: StreamingError.conversionFailed(error))
                            return
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        return StreamingResult(structuredStream)
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
            let errorStream = AsyncThrowingStream<T.Partial, Error> { continuation in
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
        let schemaJSON = T.schema.description
        let structuredPrompt = """
        \(prompt)

        Respond with valid JSON matching this schema:
        \(schemaJSON)
        """

        return stream(structuredPrompt, returning: type, model: model, config: config)
    }
}
