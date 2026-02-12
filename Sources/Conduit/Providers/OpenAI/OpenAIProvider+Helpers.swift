// OpenAIProvider+Helpers.swift
// Conduit
//
// Helper methods for OpenAIProvider.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
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
        let apiVariant = configuration.apiVariant

        let url = configuration.endpoint.textGenerationURL(for: apiVariant)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add headers
        for (name, value) in configuration.buildHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
        }

        // Build request body
        let body = buildRequestBody(
            messages: messages,
            model: model,
            config: config,
            stream: stream,
            variant: apiVariant
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request with retry
        let (data, _) = try await executeWithRetry(request: request)

        // Parse response
        return try parseGenerationResponse(data: data, variant: apiVariant)
    }

    /// Builds the request body for chat completions.
    nonisolated func buildRequestBody(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig,
        stream: Bool,
        variant: OpenAIAPIVariant = .chatCompletions
    ) -> [String: Any] {
        if variant == .responses {
            return buildResponsesRequestBody(messages: messages, model: model, config: config, stream: stream)
        }

        // Warn about potential model/endpoint mismatch for OpenRouter
        if case .openRouter = configuration.endpoint,
           !model.rawValue.contains("/") {
            logger.warning(
                "Model '\(model.rawValue)' may not work correctly with OpenRouter. Consider using .openRouter(\"provider/\(model.rawValue)\") format (e.g., .openRouter(\"openai/\(model.rawValue)\"))."
            )
        }

        var body: [String: Any] = [
            "model": model.rawValue,
            "stream": stream
        ]

        // Convert messages with full content support (text, images, audio)
        body["messages"] = messages.map { message -> [String: Any] in
            var messageDict: [String: Any] = ["role": message.role.rawValue]
            messageDict["content"] = serializeMessageContent(message.content)

            if message.role == .assistant,
               let toolCalls = message.metadata?.toolCalls,
               !toolCalls.isEmpty {
                messageDict["tool_calls"] = serializeToolCalls(toolCalls)

                if message.content.isEmpty {
                    messageDict["content"] = NSNull()
                }
            }

            // Tool messages must include the tool call ID (OpenAI/OpenRouter spec).
            // Conduit stores this in MessageMetadata.custom via Message.toolOutput(...).
            if message.role == .tool {
                let toolCallId = message.metadata?.custom?["tool_call_id"]
                if let toolCallId {
                    messageDict["tool_call_id"] = toolCallId
                } else {
                    logger.warning("Tool message is missing tool_call_id in metadata; request may be rejected by OpenAI/OpenRouter")
                }

                // Optional, but useful for some providers/debugging.
                if let toolName = message.metadata?.custom?["tool_name"] {
                    messageDict["name"] = toolName
                }
            }

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

            // Add max_tool_calls if explicitly set
            if let maxToolCalls = config.maxToolCalls {
                body["max_tool_calls"] = maxToolCalls
            }
        }

        // Add response format if configured
        if let responseFormat = config.responseFormat {
            body["response_format"] = serializeResponseFormat(responseFormat)
        }

        // Add reasoning configuration if set
        if let reasoning = config.reasoning {
            body["reasoning"] = serializeReasoningConfig(reasoning)

            // OpenRouter often requires an explicit flag to include reasoning output.
            // If exclude=true, the user explicitly does not want reasoning in responses.
            if case .openRouter = configuration.endpoint, reasoning.exclude != true {
                body["include_reasoning"] = true
            }
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

    /// Builds a request body for OpenAI Responses API.
    ///
    /// Note: full response parsing/execution is intentionally guarded elsewhere for now.
    private nonisolated func buildResponsesRequestBody(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig,
        stream: Bool
    ) -> [String: Any] {
        let serializedInput = serializeResponsesInput(messages)
        var body: [String: Any] = [
            "model": model.rawValue,
            "input": serializedInput.input
        ]

        if let instructions = serializedInput.instructions, !instructions.isEmpty {
            body["instructions"] = instructions
        }

        if stream {
            body["stream"] = true
        }

        if let maxTokens = config.maxTokens {
            body["max_output_tokens"] = maxTokens
        }
        body["temperature"] = config.temperature
        body["top_p"] = config.topP

        if !config.stopSequences.isEmpty {
            body["stop"] = config.stopSequences
        }

        if !config.tools.isEmpty && config.toolChoice != .none {
            body["tools"] = serializeResponsesToolDefinitions(config.tools)

            switch config.toolChoice {
            case .auto:
                break
            case .required:
                body["tool_choice"] = "required"
            case .none:
                break
            case .tool(let name):
                body["tool_choice"] = [
                    "type": "function",
                    "name": name
                ]
            }

            if let parallel = config.parallelToolCalls {
                body["parallel_tool_calls"] = parallel
            }

            if let maxToolCalls = config.maxToolCalls {
                body["max_tool_calls"] = maxToolCalls
            }
        }

        if let reasoning = config.reasoning {
            body["reasoning"] = serializeReasoningConfig(reasoning)
        }

        return body
    }

    // MARK: - Content Serialization

    /// Serializes message content to OpenAI/OpenRouter format.
    private nonisolated func serializeMessageContent(_ content: Message.Content) -> Any {
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
    private nonisolated func serializeContentPart(_ part: Message.ContentPart) -> [String: Any]? {
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

    private nonisolated func serializeSchema(_ schema: GenerationSchema) -> [String: Any] {
        let resolved = schema.withResolvedRoot() ?? schema
        return resolved.toJSONSchema()
    }

    private struct ResponsesSerializedInput {
        let instructions: String?
        let input: [[String: Any]]
    }

    /// Serializes messages into a Responses API compatible input format.
    private nonisolated func serializeResponsesInput(_ messages: [Message]) -> ResponsesSerializedInput {
        var instructions: [String] = []
        var input: [[String: Any]] = []
        input.reserveCapacity(messages.count)

        for message in messages {
            switch message.role {
            case .system:
                let text = message.content.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    instructions.append(text)
                }

            case .tool:
                if let toolCallID = message.metadata?.custom?["tool_call_id"] {
                    input.append([
                        "type": "function_call_output",
                        "call_id": toolCallID,
                        "output": message.content.textValue
                    ])
                } else {
                    input.append([
                        "type": "message",
                        "role": "tool",
                        "content": serializeResponsesContent(message.content)
                    ])
                }

            case .assistant:
                if let toolCalls = message.metadata?.toolCalls, !toolCalls.isEmpty {
                    for call in toolCalls {
                        input.append([
                            "type": "function_call",
                            "id": call.id,
                            "call_id": call.id,
                            "name": call.toolName,
                            "arguments": call.argumentsString
                        ])
                    }
                }

                if !message.content.isEmpty {
                    input.append([
                        "type": "message",
                        "role": "assistant",
                        "content": serializeResponsesContent(message.content)
                    ])
                }

            case .user:
                input.append([
                    "type": "message",
                    "role": "user",
                    "content": serializeResponsesContent(message.content)
                ])
            }
        }

        let joinedInstructions = instructions.isEmpty ? nil : instructions.joined(separator: "\n\n")
        return ResponsesSerializedInput(instructions: joinedInstructions, input: input)
    }

    private nonisolated func serializeResponsesContent(_ content: Message.Content) -> [[String: Any]] {
        switch content {
        case .text(let text):
            return [["type": "input_text", "text": text]]
        case .parts(let parts):
            return parts.compactMap { part in
                switch part {
                case .text(let text):
                    return ["type": "input_text", "text": text]
                case .image(let image):
                    let dataURL = "data:\(image.mimeType);base64,\(image.base64Data)"
                    return ["type": "input_image", "image_url": dataURL]
                case .audio(let audio):
                    return [
                        "type": "input_audio",
                        "input_audio": [
                            "data": audio.base64Data,
                            "format": audio.format.rawValue
                        ]
                    ]
                }
            }
        }
    }

    private nonisolated func serializeResponsesToolDefinitions(
        _ tools: [Transcript.ToolDefinition]
    ) -> [[String: Any]] {
        tools.map { tool in
            [
                "type": "function",
                "name": tool.name,
                "description": tool.description,
                "parameters": serializeSchema(tool.parameters)
            ]
        }
    }

    nonisolated func unsupportedResponsesVariantError(operation: String) -> AIError {
        .providerUnavailable(reason: .unknown(
            "OpenAI API variant 'responses' is not fully supported for \(operation). Use '.chatCompletions'."
        ))
    }

    /// Serializes response format configuration.
    private nonisolated func serializeResponseFormat(_ format: ResponseFormat) -> [String: Any] {
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

    /// Serializes tool calls for OpenAI/OpenRouter assistant messages.
    private nonisolated func serializeToolCalls(_ toolCalls: [Transcript.ToolCall]) -> [[String: Any]] {
        toolCalls.map { call in
            [
                "id": call.id,
                "type": "function",
                "function": [
                    "name": call.toolName,
                    "arguments": call.argumentsString
                ]
            ]
        }
    }

    /// Serializes reasoning configuration.
    private nonisolated func serializeReasoningConfig(_ config: ReasoningConfig) -> [String: Any] {
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
    internal func parseGenerationResponse(
        data: Data,
        variant: OpenAIAPIVariant = .chatCompletions
    ) throws -> GenerationResult {
        switch variant {
        case .chatCompletions:
            return try parseChatCompletionsGenerationResponse(data: data)
        case .responses:
            return try parseResponsesGenerationResponse(data: data)
        }
    }

    private func parseChatCompletionsGenerationResponse(data: Data) throws -> GenerationResult {
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
        // - "tool_calls" -> .toolCalls
        // - "content_filter" -> .contentFilter
        // - "stop" -> .stop
        let finishReason = mapFinishReason(firstChoice["finish_reason"] as? String) ?? .stop

        // Parse tool calls if present
        var toolCalls: [Transcript.ToolCall] = []
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
                    let toolCall = try Transcript.ToolCall(
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
        let usage = parseUsageStats(json["usage"] as? [String: Any])

        // Parse reasoning details if present
        let reasoningDetails = parseReasoningDetails(json: json, message: message, choice: firstChoice)

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

    private func parseResponsesGenerationResponse(data: Data) throws -> GenerationResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary data>"
            throw AIError.generationFailed(underlying: SendableError(NSError(
                domain: "OpenAIProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid responses payload. Preview: \(preview)"]
            )))
        }

        let output = json["output"] as? [[String: Any]] ?? []
        let toolCalls = parseResponsesToolCalls(output: output)
        let outputText = json["output_text"] as? String
        let extractedText = extractResponsesText(output: output)
        let text = outputText ?? extractedText ?? ""
        let usage = parseUsageStats(json["usage"] as? [String: Any])

        let finishReason: FinishReason
        if let mapped = mapFinishReason(json["finish_reason"] as? String) {
            finishReason = mapped
        } else if !toolCalls.isEmpty {
            finishReason = .toolCalls
        } else {
            finishReason = .stop
        }

        let reasoningDetails = parseResponsesReasoningDetails(json: json, output: output)
        let tokenCount = usage?.completionTokens ?? 0

        return GenerationResult(
            text: text,
            tokenCount: tokenCount,
            generationTime: 0,
            tokensPerSecond: 0,
            finishReason: finishReason,
            usage: usage,
            toolCalls: toolCalls,
            reasoningDetails: reasoningDetails
        )
    }

    private func parseResponsesToolCalls(output: [[String: Any]]) -> [Transcript.ToolCall] {
        var toolCalls: [Transcript.ToolCall] = []

        for block in output {
            guard let type = block["type"] as? String else { continue }

            if type == "function_call",
               let name = block["name"] as? String {
                let id = (block["call_id"] as? String)
                    ?? (block["id"] as? String)
                    ?? UUID().uuidString
                let arguments = block["arguments"] as? String ?? "{}"

                if let toolCall = try? Transcript.ToolCall(id: id, toolName: name, argumentsJSON: arguments) {
                    toolCalls.append(toolCall)
                }
                continue
            }

            if type == "message",
               let content = block["content"] as? [[String: Any]] {
                for item in content {
                    guard let contentType = item["type"] as? String else { continue }
                    guard contentType == "tool_call" || contentType == "tool_use" || contentType == "function_call" else {
                        continue
                    }

                    let id = (item["call_id"] as? String)
                        ?? (item["id"] as? String)
                        ?? UUID().uuidString
                    guard let name = item["name"] as? String else { continue }

                    let argumentsString: String = {
                        if let stringArgs = item["arguments"] as? String {
                            return stringArgs
                        }
                        if let inputJSON = item["input_json"] as? [String: Any],
                           let data = try? JSONSerialization.data(withJSONObject: inputJSON),
                           let jsonString = String(data: data, encoding: .utf8) {
                            return jsonString
                        }
                        return "{}"
                    }()

                    if let toolCall = try? Transcript.ToolCall(id: id, toolName: name, argumentsJSON: argumentsString) {
                        toolCalls.append(toolCall)
                    }
                }
            }
        }

        return toolCalls
    }

    private func extractResponsesText(output: [[String: Any]]) -> String? {
        var parts: [String] = []
        for block in output {
            guard let type = block["type"] as? String, type == "message",
                  let content = block["content"] as? [[String: Any]]
            else { continue }

            for item in content {
                guard let contentType = item["type"] as? String, contentType == "output_text",
                      let text = item["text"] as? String else { continue }
                parts.append(text)
            }
        }
        return parts.isEmpty ? nil : parts.joined()
    }

    private func parseResponsesReasoningDetails(
        json: [String: Any],
        output: [[String: Any]]
    ) -> [ReasoningDetail] {
        var details: [ReasoningDetail] = []
        var index = 0

        if let reasoningText = json["reasoning"] as? String, !reasoningText.isEmpty {
            details.append(ReasoningDetail(
                id: "rd_\(index)",
                type: "reasoning.text",
                format: "unknown",
                index: index,
                content: reasoningText
            ))
            index += 1
        }

        for block in output {
            guard let type = block["type"] as? String, type == "message",
                  let content = block["content"] as? [[String: Any]]
            else { continue }

            for item in content {
                guard let contentType = item["type"] as? String else { continue }
                guard contentType == "reasoning" || contentType == "reasoning_text" else { continue }

                let contentText = (item["text"] as? String) ?? (item["content"] as? String)
                details.append(ReasoningDetail(
                    id: item["id"] as? String ?? "rd_\(index)",
                    type: "reasoning.text",
                    format: "unknown",
                    index: index,
                    content: contentText
                ))
                index += 1
            }
        }

        return details
    }

    private func parseUsageStats(_ usageJson: [String: Any]?) -> UsageStats? {
        guard let usageJson else { return nil }

        let promptTokens = (usageJson["prompt_tokens"] as? Int)
            ?? (usageJson["input_tokens"] as? Int)
            ?? 0
        let completionTokens = (usageJson["completion_tokens"] as? Int)
            ?? (usageJson["output_tokens"] as? Int)
            ?? 0

        return UsageStats(promptTokens: promptTokens, completionTokens: completionTokens)
    }

    private func mapFinishReason(_ finishReason: String?) -> FinishReason? {
        switch finishReason {
        case "stop":
            return .stop
        case "length", "max_output_tokens":
            return .maxTokens
        case "tool_calls":
            return .toolCalls
        case "tool_call":
            return .toolCall
        case "content_filter":
            return .contentFilter
        case "cancelled", "canceled":
            return .cancelled
        default:
            return nil
        }
    }

    private func parseReasoningDetails(
        json: [String: Any],
        message: [String: Any],
        choice: [String: Any]
    ) -> [ReasoningDetail] {
        // OpenRouter / OpenAI-compatible variants seen in the wild:
        // - Top-level: { "reasoning_details": [ ... ] }
        // - Choice-level: { "choices": [{ "reasoning_details": [ ... ] }] }
        // - Message-level: { "choices": [{ "message": { "reasoning_details": [ ... ] } }] }
        // - Message-level shorthand: { "choices": [{ "message": { "reasoning": "..." } }] }
        let reasoningArray =
            (message["reasoning_details"] as? [[String: Any]])
            ?? (choice["reasoning_details"] as? [[String: Any]])
            ?? (json["reasoning_details"] as? [[String: Any]])

        if let reasoningArray {
            return reasoningArray.enumerated().map { index, rd in
                ReasoningDetail(
                    id: rd["id"] as? String ?? "rd_\(index)",
                    type: rd["type"] as? String ?? "reasoning.text",
                    format: rd["format"] as? String ?? "unknown",
                    index: index,
                    content: rd["content"] as? String
                )
            }
        }

        if let reasoningText = message["reasoning"] as? String, !reasoningText.isEmpty {
            return [
                ReasoningDetail(
                    id: "rd_0",
                    type: "reasoning.text",
                    format: "unknown",
                    index: 0,
                    content: reasoningText
                )
            ]
        }

        return []
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

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
