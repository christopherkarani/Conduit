// OpenAIProvider+Helpers.swift
// Conduit
//
// Helper methods for OpenAIProvider.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Logging

/// Logger for OpenAI provider diagnostics.
private let logger = ConduitLoggers.openAI

// MARK: - Helper Methods

extension OpenAIProvider {

    /// Performs a non-streaming generation request.
    internal func performGeneration(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig,
        stream: Bool
    ) async throws -> GenerationResult {
        let url = configuration.endpoint.chatCompletionsURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add headers
        for (name, value) in configuration.buildHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
        }

        // Build request body
        let body = buildRequestBody(messages: messages, model: model, config: config, stream: false)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request with retry
        let (data, _) = try await executeWithRetry(request: request)

        // Parse response
        return try parseGenerationResponse(data: data)
    }

    /// Builds the request body for chat completions.
    internal func buildRequestBody(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig,
        stream: Bool
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model.rawValue,
            "stream": stream
        ]

        // Convert messages with full content support (text, images, audio)
        body["messages"] = messages.map { message -> [String: Any] in
            var messageDict: [String: Any] = ["role": message.role.rawValue]
            messageDict["content"] = serializeMessageContent(message.content)
            return messageDict
        }

        // Add generation config
        if let maxTokens = config.maxTokens {
            body["max_tokens"] = maxTokens
        }

        body["temperature"] = config.temperature
        body["top_p"] = config.topP

        if let topK = config.topK {
            body["top_k"] = topK
        }

        if config.frequencyPenalty != 0 {
            body["frequency_penalty"] = config.frequencyPenalty
        }

        if config.presencePenalty != 0 {
            body["presence_penalty"] = config.presencePenalty
        }

        if !config.stopSequences.isEmpty {
            body["stop"] = config.stopSequences
        }

        if let seed = config.seed {
            body["seed"] = seed
        }

        // Add tools if configured (and toolChoice is not .none)
        if !config.tools.isEmpty && config.toolChoice != .none {
            body["tools"] = config.tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": serializeSchema(tool.parameters)
                    ]
                ]
            }

            // Add tool_choice
            switch config.toolChoice {
            case .auto:
                // Omit or set to "auto" - most providers default to auto
                break
            case .required:
                body["tool_choice"] = "required"
            case .none:
                // Already handled above - don't include tools
                break
            case .tool(let name):
                body["tool_choice"] = [
                    "type": "function",
                    "function": ["name": name]
                ]
            }

            // Add parallel_tool_calls if explicitly set
            if let parallel = config.parallelToolCalls {
                body["parallel_tool_calls"] = parallel
            }
        }

        // Add response format if configured
        if let responseFormat = config.responseFormat {
            body["response_format"] = serializeResponseFormat(responseFormat)
        }

        // Add reasoning configuration if set
        if let reasoning = config.reasoning {
            body["reasoning"] = serializeReasoningConfig(reasoning)
        }

        // Add OpenRouter routing if applicable
        if case .openRouter = configuration.endpoint,
           let orConfig = configuration.openRouterConfig,
           let routing = orConfig.providerRouting() {
            body["provider"] = routing
        }

        // Add Ollama options if applicable
        if case .ollama = configuration.endpoint,
           let ollamaConfig = configuration.ollamaConfig {
            if let keepAlive = ollamaConfig.keepAlive {
                body["keep_alive"] = keepAlive
            }
            let options = ollamaConfig.options()
            if !options.isEmpty {
                body["options"] = options
            }
        }

        return body
    }

    // MARK: - Content Serialization

    /// Serializes message content to OpenAI/OpenRouter format.
    private func serializeMessageContent(_ content: Message.Content) -> Any {
        switch content {
        case .text(let text):
            // Simple text content - return as string for efficiency
            return text

        case .parts(let parts):
            // Check if all parts are text-only
            let allText = parts.allSatisfy {
                if case .text = $0 { return true }
                return false
            }

            if allText && parts.count == 1 {
                if case .text(let text) = parts[0] {
                    return text
                }
            }

            // Multimodal content - return as array
            return parts.compactMap { part -> [String: Any]? in
                serializeContentPart(part)
            }
        }
    }

    /// Serializes a single content part to OpenAI/OpenRouter format.
    private func serializeContentPart(_ part: Message.ContentPart) -> [String: Any]? {
        switch part {
        case .text(let text):
            return [
                "type": "text",
                "text": text
            ]

        case .image(let imageContent):
            // OpenAI format: image_url with data URL
            let dataURL = "data:\(imageContent.mimeType);base64,\(imageContent.base64Data)"
            return [
                "type": "image_url",
                "image_url": ["url": dataURL]
            ]

        case .audio(let audioContent):
            // OpenRouter/OpenAI audio format: input_audio
            return [
                "type": "input_audio",
                "input_audio": [
                    "data": audioContent.base64Data,
                    "format": audioContent.format.rawValue
                ]
            ]
        }
    }

    /// Serializes a Schema to JSON Schema format for tool parameters.
    private func serializeSchema(_ schema: Schema) -> [String: Any] {
        var result: [String: Any] = [:]

        switch schema {
        case .string(let constraints):
            result["type"] = "string"
            for constraint in constraints {
                switch constraint {
                case .minLength(let value):
                    result["minLength"] = value
                case .maxLength(let value):
                    result["maxLength"] = value
                case .pattern(let value):
                    result["pattern"] = value
                case .constant(let value):
                    result["const"] = value
                case .anyOf(let values):
                    result["enum"] = values
                }
            }

        case .integer(let constraints):
            result["type"] = "integer"
            for constraint in constraints {
                switch constraint {
                case .range(let lowerBound, let upperBound):
                    if let lower = lowerBound {
                        result["minimum"] = lower
                    }
                    if let upper = upperBound {
                        result["maximum"] = upper
                    }
                }
            }

        case .number(let constraints):
            result["type"] = "number"
            for constraint in constraints {
                switch constraint {
                case .range(let lowerBound, let upperBound):
                    if let lower = lowerBound {
                        result["minimum"] = lower
                    }
                    if let upper = upperBound {
                        result["maximum"] = upper
                    }
                }
            }

        case .boolean(let constraints):
            result["type"] = "boolean"
            // Boolean constraints are typically empty in JSON Schema
            _ = constraints  // Silence unused warning

        case .array(let items, let constraints):
            result["type"] = "array"
            result["items"] = serializeSchema(items)
            for constraint in constraints {
                switch constraint {
                case .count(let lowerBound, let upperBound):
                    if let lower = lowerBound {
                        result["minItems"] = lower
                    }
                    if let upper = upperBound {
                        result["maxItems"] = upper
                    }
                }
            }

        case .object(let name, let description, let properties):
            result["type"] = "object"
            if !name.isEmpty {
                result["title"] = name
            }
            if let description = description {
                result["description"] = description
            }
            if !properties.isEmpty {
                var props: [String: Any] = [:]
                var required: [String] = []
                for (key, property) in properties {
                    var propSchema = serializeSchema(property.schema)
                    if let desc = property.description {
                        propSchema["description"] = desc
                    }
                    props[key] = propSchema
                    // Assume all properties are required by default
                    required.append(key)
                }
                result["properties"] = props
                if !required.isEmpty {
                    result["required"] = required
                }
            }

        case .optional(let wrapped):
            // Optional types become the wrapped type with nullable: true
            result = serializeSchema(wrapped)
            result["nullable"] = true

        case .anyOf(let name, let description, let schemas):
            if !name.isEmpty {
                result["title"] = name
            }
            if let description = description {
                result["description"] = description
            }
            result["anyOf"] = schemas.map { serializeSchema($0) }
        }

        return result
    }

    /// Serializes response format configuration.
    private func serializeResponseFormat(_ format: ResponseFormat) -> [String: Any] {
        switch format {
        case .text:
            return ["type": "text"]
        case .jsonObject:
            return ["type": "json_object"]
        case .jsonSchema(let name, let schema):
            return [
                "type": "json_schema",
                "json_schema": [
                    "name": name,
                    "schema": serializeSchema(schema),
                    "strict": true
                ]
            ]
        }
    }

    /// Serializes reasoning configuration.
    private func serializeReasoningConfig(_ config: ReasoningConfig) -> [String: Any] {
        var result: [String: Any] = [:]

        if let effort = config.effort {
            result["effort"] = effort.rawValue
        }

        if let maxTokens = config.maxTokens {
            result["max_tokens"] = maxTokens
        }

        if let exclude = config.exclude {
            result["exclude"] = exclude
        }

        if let enabled = config.enabled {
            result["enabled"] = enabled
        }

        return result
    }

    /// Executes a request with retry logic.
    internal func executeWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0...configuration.maxRetries {
            do {
                try Task.checkCancellation()

                if attempt > 0 {
                    let delay = configuration.retryConfig.delay(forAttempt: attempt)
                    // Prevent overflow by capping delay at 60 seconds
                    let cappedDelay = min(delay, 60.0)
                    // Use checked multiplication to prevent overflow
                    let nanoseconds = cappedDelay * 1_000_000_000
                    // Ensure the result is valid and fits in UInt64
                    guard nanoseconds.isFinite && nanoseconds >= 0 && nanoseconds <= Double(UInt64.max) else {
                        // Fallback to 60 seconds for invalid values
                        try await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000))
                        continue
                    }
                    try await Task.sleep(nanoseconds: UInt64(nanoseconds))
                }

                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIError.networkError(URLError(.badServerResponse))
                }

                // Check for retryable status codes
                if configuration.retryConfig.shouldRetry(statusCode: httpResponse.statusCode) {
                    lastError = AIError.serverError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
                    continue
                }

                // Check for rate limiting
                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { Double($0) }
                        .map { min($0, 300) }  // Cap at 5 minutes to prevent DoS
                    throw AIError.rateLimited(retryAfter: retryAfter)
                }

                // Check for other errors
                guard httpResponse.statusCode == 200 else {
                    throw AIError.serverError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
                }

                return (data, response)

            } catch let error as URLError {
                if let retryable = RetryableErrorType.from(error),
                   configuration.retryConfig.shouldRetry(errorType: retryable) {
                    lastError = AIError.networkError(error)
                    continue
                }
                throw AIError.networkError(error)

            } catch {
                throw error
            }
        }

        throw lastError ?? AIError.networkError(URLError(.unknown))
    }

    /// Parses a generation response.
    internal func parseGenerationResponse(data: Data) throws -> GenerationResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary data>"
            throw AIError.generationFailed(underlying: SendableError(NSError(
                domain: "OpenAIProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response format. Preview: \(preview)"]
            )))
        }

        // Content may be null when tool calls are present
        let content = message["content"] as? String ?? ""

        // Parse finish reason, mapping OpenAI values to our FinishReason
        // OpenAI uses different names than our enum raw values:
        // - "length" -> .maxTokens
        // - "tool_calls" -> .toolCall
        // - "content_filter" -> .contentFilter
        // - "stop" -> .stop
        let finishReasonStr = firstChoice["finish_reason"] as? String
        let finishReason: FinishReason
        switch finishReasonStr {
        case "stop":
            finishReason = .stop
        case "length":
            finishReason = .maxTokens
        case "tool_calls":
            finishReason = .toolCall
        case "content_filter":
            finishReason = .contentFilter
        default:
            finishReason = .stop
        }

        // Parse tool calls if present
        var toolCalls: [AIToolCall] = []
        if let openAIToolCalls = message["tool_calls"] as? [[String: Any]] {
            for tc in openAIToolCalls {
                guard let id = tc["id"] as? String,
                      let function = tc["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let argumentsString = function["arguments"] as? String else {
                    logger.warning("Skipping tool call with missing required fields (id, function, name, or arguments)")
                    continue
                }

                do {
                    let toolCall = try AIToolCall(
                        id: id,
                        toolName: name,
                        argumentsJSON: argumentsString
                    )
                    toolCalls.append(toolCall)
                    logger.debug("Successfully parsed tool call: \(name) (id: \(id))")
                } catch {
                    logger.warning("Skipping malformed tool call '\(name)': \(error.localizedDescription)")
                    continue
                }
            }
        }

        // Parse usage if present
        var usage: UsageStats?
        if let usageJson = json["usage"] as? [String: Any] {
            let promptTokens = usageJson["prompt_tokens"] as? Int ?? 0
            let completionTokens = usageJson["completion_tokens"] as? Int ?? 0
            usage = UsageStats(
                promptTokens: promptTokens,
                completionTokens: completionTokens
            )
        }

        // Parse reasoning details if present
        var reasoningDetails: [ReasoningDetail] = []
        if let reasoningData = json["reasoning_details"] as? [[String: Any]] {
            for (index, rd) in reasoningData.enumerated() {
                let id = rd["id"] as? String ?? "rd_\(index)"
                let type = rd["type"] as? String ?? "reasoning.text"
                let format = rd["format"] as? String ?? "unknown"
                let content = rd["content"] as? String

                let detail = ReasoningDetail(
                    id: id,
                    type: type,
                    format: format,
                    index: index,
                    content: content
                )
                reasoningDetails.append(detail)
            }
        }

        // Calculate token count and performance metrics
        let tokenCount = usage?.completionTokens ?? 0

        return GenerationResult(
            text: content,
            tokenCount: tokenCount,
            generationTime: 0, // Not available in non-streaming mode
            tokensPerSecond: 0,
            finishReason: finishReason,
            usage: usage,
            toolCalls: toolCalls,
            reasoningDetails: reasoningDetails
        )
    }

    /// Checks if the Ollama server is healthy.
    internal func checkOllamaHealth() async -> Bool {
        guard case .ollama(let host, let port) = configuration.endpoint else {
            return false
        }

        guard let healthURL = URL(string: "http://\(host):\(port)/api/version") else {
            return false
        }
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = configuration.ollamaConfig?.healthCheckTimeout ?? 5.0

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
