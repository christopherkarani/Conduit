// AnthropicProvider+Helpers.swift
// SwiftAI
//
// Helper methods for AnthropicProvider request/response handling.

import Foundation

// MARK: - Request Building

extension AnthropicProvider {

    /// Builds request body for Anthropic Messages API.
    ///
    /// This method transforms SwiftAI's unified Message format into Anthropic's
    /// API-specific request structure. It handles the critical distinction that
    /// Anthropic requires system messages to be sent in a separate `system` field
    /// rather than in the messages array.
    ///
    /// ## Message Role Handling
    ///
    /// - **System messages**: Extracted from the messages array and sent in the
    ///   `system` field. Only the first system message is used; subsequent system
    ///   messages are ignored.
    /// - **User/Assistant messages**: Converted to API format and included in
    ///   the `messages` array.
    /// - **Tool messages**: Currently filtered out (tool support is planned for
    ///   a future phase).
    ///
    /// ## Usage
    /// ```swift
    /// let messages = [
    ///     .system("You are a helpful assistant."),
    ///     .user("Hello!"),
    ///     .assistant("Hi there!")
    /// ]
    /// let request = buildRequestBody(
    ///     messages: messages,
    ///     model: .claudeSonnet45,
    ///     config: .default,
    ///     stream: false
    /// )
    /// // request.system = "You are a helpful assistant."
    /// // request.messages = [user: "Hello!", assistant: "Hi there!"]
    /// ```
    ///
    /// ## Content Extraction
    ///
    /// The method extracts text from Message.Content using the `textValue` property,
    /// which handles both simple `.text` content and multimodal `.parts` content
    /// by concatenating all text parts.
    ///
    /// - Parameters:
    ///   - messages: Array of SwiftAI Message objects. Must contain at least one
    ///     user or assistant message after filtering system messages.
    ///   - model: The Anthropic model identifier to use.
    ///   - config: Generation configuration with sampling parameters.
    ///   - stream: Whether this request is for streaming (sets `stream: true` in body).
    ///
    /// - Returns: An `AnthropicMessagesRequest` ready to be JSON-encoded and sent
    ///   to the `/v1/messages` endpoint.
    ///
    /// - Note: If the messages array contains only system messages, the returned
    ///   request will have an empty `messages` array, which will cause the API to
    ///   return a validation error.
    internal func buildRequestBody(
        messages: [Message],
        model: AnthropicModelID,
        config: GenerateConfig,
        stream: Bool = false
    ) -> AnthropicMessagesRequest {
        // Extract system message (first system role message)
        let systemPrompt = messages.first(where: { $0.role == .system })?.content.textValue

        // Filter out system messages, convert to API format
        let apiMessages = messages.compactMap { msg -> AnthropicMessagesRequest.MessageContent? in
            switch msg.role {
            case .user, .assistant:
                // Check if message has multimodal content (images)
                switch msg.content {
                case .text(let text):
                    // Simple text-only message
                    return AnthropicMessagesRequest.MessageContent(
                        role: msg.role.rawValue,
                        content: .text(text)
                    )

                case .parts(let parts):
                    // Multimodal message with text and/or images
                    var apiParts: [AnthropicMessagesRequest.MessageContent.ContentPart] = []

                    for part in parts {
                        switch part {
                        case .text(let text):
                            // Text part
                            apiParts.append(AnthropicMessagesRequest.MessageContent.ContentPart(
                                type: "text",
                                text: text,
                                source: nil
                            ))

                        case .image(let imageContent):
                            // Image part
                            let source = AnthropicMessagesRequest.MessageContent.ContentPart.ImageSource(
                                type: "base64",
                                mediaType: imageContent.mimeType,
                                data: imageContent.base64Data
                            )
                            apiParts.append(AnthropicMessagesRequest.MessageContent.ContentPart(
                                type: "image",
                                text: nil,
                                source: source
                            ))
                        }
                    }

                    return AnthropicMessagesRequest.MessageContent(
                        role: msg.role.rawValue,
                        content: .multipart(apiParts)
                    )
                }

            case .system, .tool:
                // System messages go in separate field
                // Tool messages not yet supported
                return nil
            }
        }

        // Add extended thinking if configured
        var thinkingRequest: AnthropicMessagesRequest.ThinkingRequest? = nil
        if let thinkingConfig = configuration.thinkingConfig, thinkingConfig.enabled {
            thinkingRequest = AnthropicMessagesRequest.ThinkingRequest(
                type: "enabled",
                budget_tokens: thinkingConfig.budgetTokens
            )
        }

        return AnthropicMessagesRequest(
            model: model.rawValue,
            messages: apiMessages,
            maxTokens: config.maxTokens ?? 1024,
            system: systemPrompt,
            temperature: config.temperature > 0 ? Double(config.temperature) : nil,
            topP: config.topP > 0 && config.topP < 1 ? Double(config.topP) : nil,
            topK: config.topK,
            stream: stream ? true : nil,
            thinking: thinkingRequest
        )
    }
}

// MARK: - HTTP Execution

extension AnthropicProvider {

    /// Executes HTTP request to Anthropic Messages API.
    ///
    /// This method handles the full HTTP request lifecycle: building the URL request,
    /// setting headers, encoding the body, executing the request, and validating
    /// the response.
    ///
    /// ## Request Flow
    ///
    /// 1. **URL Construction**: Appends `/v1/messages` to the base URL
    /// 2. **Headers**: Adds authentication, API version, and content type via
    ///    `configuration.buildHeaders()`
    /// 3. **Body Encoding**: JSON-encodes the request body
    /// 4. **Execution**: Performs async HTTP request
    /// 5. **Validation**: Checks HTTP status code
    /// 6. **Error Handling**: Decodes error responses and maps to AIError
    /// 7. **Success**: Decodes and returns the response
    ///
    /// ## HTTP Status Codes
    ///
    /// - **200-299**: Success - response decoded and returned
    /// - **401**: Authentication error - mapped to `.authenticationFailed`
    /// - **429**: Rate limit - mapped to `.rateLimited`
    /// - **500-599**: Server error - mapped to `.serverError`
    /// - **Other**: Attempts to decode error response, falls back to generic error
    ///
    /// ## Usage
    /// ```swift
    /// let request = buildRequestBody(messages: messages, model: .claudeSonnet45, config: .default)
    /// let response = try await executeRequest(request)
    /// print(response.content.first?.text ?? "")
    /// ```
    ///
    /// - Parameter request: The Anthropic API request to execute.
    ///
    /// - Returns: The decoded `AnthropicMessagesResponse` containing the generated
    ///   message, usage statistics, and stop reason.
    ///
    /// - Throws: `AIError` variants:
    ///   - `.networkError`: Network connectivity issues (URLError)
    ///   - `.authenticationFailed`: Invalid or missing API key (HTTP 401)
    ///   - `.rateLimited`: Rate limit exceeded (HTTP 429)
    ///   - `.serverError`: Anthropic API error (HTTP 4xx/5xx)
    ///   - `.generationFailed`: Encoding/decoding failures
    internal func executeRequest(
        _ request: AnthropicMessagesRequest
    ) async throws -> AnthropicMessagesResponse {
        let url = configuration.baseURL.appendingPathComponent("/v1/messages")
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

        // Execute request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw AIError.networkError(urlError)
        } catch {
            throw AIError.networkError(URLError(.unknown))
        }

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        // Check status code
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to decode error response
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                throw mapAnthropicError(errorResponse, statusCode: httpResponse.statusCode)
            }
            // Fallback to generic error if we can't decode the error response
            throw AIError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        // Decode success response
        do {
            return try decoder.decode(AnthropicMessagesResponse.self, from: data)
        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }
    }
}

// MARK: - Error Mapping

extension AnthropicProvider {

    /// Maps Anthropic API errors to SwiftAI's unified AIError enum.
    ///
    /// Anthropic's API returns structured error responses with a `type` field
    /// that indicates the category of error. This method translates those
    /// error types into SwiftAI's standardized error cases for consistent
    /// error handling across all providers.
    ///
    /// ## Error Type Mappings
    ///
    /// - `invalid_request_error`: Malformed request, invalid parameters
    ///   → `.invalidInput`
    /// - `authentication_error`: Invalid or missing API key
    ///   → `.authenticationFailed`
    /// - `permission_error`: API key lacks required permissions
    ///   → `.authenticationFailed`
    /// - `not_found_error`: Model or resource doesn't exist
    ///   → `.invalidInput`
    /// - `rate_limit_error`: Too many requests
    ///   → `.rateLimited(retryAfter: nil)`
    /// - `timeout_error`: Request took too long
    ///   → `.timeout`
    /// - `api_error`: Internal Anthropic server error
    ///   → `.serverError`
    /// - `overloaded_error`: Anthropic's servers are overloaded
    ///   → `.serverError`
    /// - Unknown types: Future-proofing for new error types
    ///   → `.generationFailed`
    ///
    /// ## Usage
    /// ```swift
    /// let errorResponse = try decoder.decode(AnthropicErrorResponse.self, from: data)
    /// throw mapAnthropicError(errorResponse, statusCode: 429)
    /// // Throws: AIError.rateLimited(retryAfter: nil)
    /// ```
    ///
    /// ## Future Enhancements
    ///
    /// - Extract `Retry-After` header for rate limit errors
    /// - Parse additional error metadata from response
    /// - Handle per-error-type recovery suggestions
    ///
    /// - Parameters:
    ///   - error: The decoded Anthropic error response.
    ///   - statusCode: The HTTP status code from the response.
    ///
    /// - Returns: A SwiftAI `AIError` that represents the Anthropic error.
    internal func mapAnthropicError(
        _ error: AnthropicErrorResponse,
        statusCode: Int
    ) -> AIError {
        switch error.error.type {
        case "invalid_request_error":
            return .invalidInput(error.error.message)

        case "authentication_error":
            return .authenticationFailed(error.error.message)

        case "permission_error":
            return .authenticationFailed(error.error.message)

        case "not_found_error":
            // Model or resource not found
            return .invalidInput(error.error.message)

        case "rate_limit_error":
            // TODO: Extract retry-after from headers if available (future enhancement)
            return .rateLimited(retryAfter: nil)

        case "timeout_error":
            return .timeout(configuration.timeout)

        case "api_error", "overloaded_error":
            // Server-side errors
            return .serverError(statusCode: statusCode, message: error.error.message)

        default:
            // Unknown error type (future-proof for new Anthropic errors)
            let underlyingError = NSError(
                domain: "com.anthropic.api",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: error.error.message]
            )
            return .generationFailed(underlying: SendableError(underlyingError))
        }
    }
}

// MARK: - Response Conversion

extension AnthropicProvider {

    /// Converts Anthropic API response to GenerationResult.
    ///
    /// This method transforms Anthropic's response format into SwiftAI's
    /// unified `GenerationResult` structure, extracting text content,
    /// calculating performance metrics, and mapping metadata fields.
    ///
    /// ## Content Extraction
    ///
    /// Anthropic responses contain a `content` array with multiple content blocks.
    /// This method:
    /// 1. Separates thinking blocks from text blocks
    /// 2. Filters for text blocks (ignores thinking, tool_use, and other block types)
    /// 3. Concatenates all text blocks into a single string
    /// 4. Returns empty string if no text blocks are present
    ///
    /// ## Extended Thinking
    ///
    /// When extended thinking is enabled, the response may contain both:
    /// - **Thinking blocks** (type="thinking"): Internal reasoning process
    /// - **Text blocks** (type="text"): Final response to the user
    ///
    /// The thinking content is extracted but not included in the final text.
    /// It represents Claude's internal reasoning and is billed separately.
    ///
    /// ## Performance Metrics
    ///
    /// - **generationTime**: Calculated as `Date.now - startTime`
    /// - **tokensPerSecond**: `outputTokens / generationTime` (or 0 if time is 0)
    /// - **tokenCount**: Uses Anthropic's `usage.outputTokens`
    ///
    /// ## Usage Statistics
    ///
    /// Maps Anthropic's usage fields to SwiftAI's `UsageStats`:
    /// - `usage.inputTokens` → `promptTokens`
    /// - `usage.outputTokens` → `completionTokens`
    ///
    /// ## Finish Reason Mapping
    ///
    /// Delegates to `mapStopReason()` to convert Anthropic's `stop_reason`
    /// to SwiftAI's `FinishReason` enum.
    ///
    /// ## Usage
    /// ```swift
    /// let startTime = Date()
    /// let response = try await executeRequest(request)
    /// let result = convertToGenerationResult(response, startTime: startTime)
    /// print(result.text)
    /// print("Speed: \(result.tokensPerSecond) tok/s")
    /// ```
    ///
    /// - Parameters:
    ///   - response: The Anthropic API response to convert.
    ///   - startTime: The timestamp when generation started (for performance metrics).
    ///
    /// - Returns: A `GenerationResult` containing the generated text and metadata.
    ///
    /// - Note: The `logprobs` field is always `nil` because Anthropic's API does
    ///   not provide log probabilities for generated tokens.
    internal func convertToGenerationResult(
        _ response: AnthropicMessagesResponse,
        startTime: Date
    ) -> GenerationResult {
        // Separate thinking blocks from text blocks
        // Note: Thinking blocks contain internal reasoning and are not shown to the user
        _ = response.content
            .filter { $0.type == "thinking" }
            .compactMap { $0.text }
            .joined(separator: "\n")

        let responseText = response.content
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined()

        // Return only the response text
        // Thinking is internal reasoning and not shown to the user
        // Future enhancement: could expose thinking via metadata
        let text = responseText

        // Calculate performance metrics
        let duration = Date().timeIntervalSince(startTime)
        let tokensPerSecond = duration > 0 ? Double(response.usage.outputTokens) / duration : 0

        return GenerationResult(
            text: text,
            tokenCount: response.usage.outputTokens,
            generationTime: duration,
            tokensPerSecond: tokensPerSecond,
            finishReason: mapStopReason(response.stopReason),
            logprobs: nil,  // Anthropic doesn't provide logprobs
            usage: UsageStats(
                promptTokens: response.usage.inputTokens,
                completionTokens: response.usage.outputTokens
            )
        )
    }

    /// Maps Anthropic stop_reason to SwiftAI's FinishReason.
    ///
    /// Anthropic uses string-based stop reasons to indicate why generation
    /// terminated. This method converts those strings to SwiftAI's typed
    /// `FinishReason` enum.
    ///
    /// ## Mappings
    ///
    /// - `"end_turn"`: Natural completion → `.stop`
    /// - `"max_tokens"`: Hit token limit → `.maxTokens`
    /// - `"stop_sequence"`: Hit a stop sequence → `.stopSequence`
    /// - `nil` or unknown: Default → `.stop`
    ///
    /// ## Usage
    /// ```swift
    /// let reason = mapStopReason("max_tokens")
    /// // Returns: FinishReason.maxTokens
    /// ```
    ///
    /// - Parameter reason: The Anthropic stop_reason string from the API response.
    ///
    /// - Returns: The corresponding `FinishReason` enum case.
    ///
    /// - Note: Anthropic's `"max_tokens"` maps to SwiftAI's `.maxTokens`.
    private func mapStopReason(_ reason: String?) -> FinishReason {
        switch reason {
        case "end_turn":
            return .stop
        case "max_tokens":
            return .maxTokens
        case "stop_sequence":
            return .stopSequence
        default:
            return .stop
        }
    }
}
