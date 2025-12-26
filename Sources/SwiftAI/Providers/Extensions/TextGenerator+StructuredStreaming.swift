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
                var lastParsedPartial: T.Partial?

                do {
                    for try await chunk in stringStream {
                        accumulated += chunk

                        // Try to parse the accumulated JSON
                        if let content = JsonRepair.tryParse(accumulated) {
                            do {
                                let partial = try T.Partial(from: content)
                                // Only yield if different from last
                                lastParsedPartial = partial
                                continuation.yield(partial)
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
