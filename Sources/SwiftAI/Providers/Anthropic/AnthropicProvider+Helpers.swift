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

        // Build metadata if userId is provided
        let metadata: AnthropicMessagesRequest.Metadata? = config.userId.map {
            AnthropicMessagesRequest.Metadata(userId: $0)
        }

        // Convert tools if provided and toolChoice is not .none
        let (toolDefinitions, toolChoiceRequest) = convertToolsConfig(config)

        return AnthropicMessagesRequest(
            model: model.rawValue,
            messages: apiMessages,
            maxTokens: config.maxTokens ?? 1024,
            system: systemPrompt,
            temperature: config.temperature >= 0 ? Double(config.temperature) : nil,
            topP: (config.topP > 0 && config.topP <= 1) ? Double(config.topP) : nil,
            topK: config.topK,
            stream: stream ? true : nil,
            thinking: thinkingRequest,
            stopSequences: config.stopSequences.isEmpty ? nil : config.stopSequences,
            metadata: metadata,
            serviceTier: config.serviceTier?.rawValue,
            tools: toolDefinitions,
            toolChoice: toolChoiceRequest
        )
    }

    /// Converts SwiftAI tool configuration to Anthropic's API format.
    ///
    /// - Parameter config: The generation configuration with tools.
    /// - Returns: Tuple of tool definitions and tool choice for API request.
    ///   Returns (nil, nil) if toolChoice is .none or no tools are provided.
    private func convertToolsConfig(
        _ config: GenerateConfig
    ) -> ([AnthropicMessagesRequest.ToolDefinitionRequest]?, AnthropicMessagesRequest.ToolChoiceRequest?) {
        // If toolChoice is .none, omit tools entirely
        if case .none = config.toolChoice {
            return (nil, nil)
        }

        // If no tools, nothing to convert
        guard !config.tools.isEmpty else {
            return (nil, nil)
        }

        // Convert tool definitions
        let tools = config.tools.map { tool -> AnthropicMessagesRequest.ToolDefinitionRequest in
            let schemaDict = tool.parameters.toJSONSchema()
            let inputSchema = convertToInputSchema(schemaDict)

            return AnthropicMessagesRequest.ToolDefinitionRequest(
                name: tool.name,
                description: tool.description,
                inputSchema: inputSchema
            )
        }

        // Convert tool choice
        let toolChoice: AnthropicMessagesRequest.ToolChoiceRequest
        switch config.toolChoice {
        case .auto:
            toolChoice = AnthropicMessagesRequest.ToolChoiceRequest(type: "auto", name: nil)
        case .required:
            toolChoice = AnthropicMessagesRequest.ToolChoiceRequest(type: "any", name: nil)
        case .tool(let name):
            toolChoice = AnthropicMessagesRequest.ToolChoiceRequest(type: "tool", name: name)
        case .none:
            // Already handled above, but needed for exhaustive switch
            return (nil, nil)
        }

        return (tools, toolChoice)
    }

    /// Converts a JSON Schema dictionary to Anthropic's InputSchema type.
    private func convertToInputSchema(
        _ dict: [String: Any]
    ) -> AnthropicMessagesRequest.ToolDefinitionRequest.InputSchema {
        let properties = (dict["properties"] as? [String: [String: Any]]) ?? [:]
        let required = dict["required"] as? [String]
        let additionalProperties = dict["additionalProperties"] as? Bool

        let convertedProperties = properties.mapValues { propDict -> AnthropicMessagesRequest.ToolDefinitionRequest.PropertySchema in
            convertToPropertySchema(propDict)
        }

        return AnthropicMessagesRequest.ToolDefinitionRequest.InputSchema(
            type: "object",
            properties: convertedProperties,
            required: required,
            additionalProperties: additionalProperties
        )
    }

    /// Converts a property dictionary to PropertySchema.
    private func convertToPropertySchema(
        _ dict: [String: Any]
    ) -> AnthropicMessagesRequest.ToolDefinitionRequest.PropertySchema {
        // Handle type (can be string or array for nullable)
        let schemaType: AnthropicMessagesRequest.ToolDefinitionRequest.SchemaType
        if let typeString = dict["type"] as? String {
            schemaType = .single(typeString)
        } else if let typeArray = dict["type"] as? [String] {
            schemaType = .multiple(typeArray)
        } else {
            schemaType = .single("string") // Default fallback
        }

        // Handle items for arrays
        var items: AnthropicMessagesRequest.ToolDefinitionRequest.ItemSchema? = nil
        if let itemsDict = dict["items"] as? [String: Any] {
            let itemType: AnthropicMessagesRequest.ToolDefinitionRequest.SchemaType
            if let t = itemsDict["type"] as? String {
                itemType = .single(t)
            } else if let t = itemsDict["type"] as? [String] {
                itemType = .multiple(t)
            } else {
                itemType = .single("string")
            }
            items = AnthropicMessagesRequest.ToolDefinitionRequest.ItemSchema(
                type: itemType,
                description: itemsDict["description"] as? String
            )
        }

        // Handle nested properties for objects
        var nestedProperties: [String: AnthropicMessagesRequest.ToolDefinitionRequest.PropertySchema]? = nil
        if let propsDict = dict["properties"] as? [String: [String: Any]] {
            nestedProperties = propsDict.mapValues { convertToPropertySchema($0) }
        }

        return AnthropicMessagesRequest.ToolDefinitionRequest.PropertySchema(
            type: schemaType,
            description: dict["description"] as? String,
            items: items,
            properties: nestedProperties,
            required: dict["required"] as? [String],
            additionalProperties: dict["additionalProperties"] as? Bool,
            enumValues: dict["enum"] as? [String],
            minimum: dict["minimum"] as? Int,
            maximum: dict["maximum"] as? Int,
            minLength: dict["minLength"] as? Int,
            maxLength: dict["maxLength"] as? Int,
            pattern: dict["pattern"] as? String,
            const: dict["const"] as? String
        )
    }
}

// MARK: - HTTP Execution

extension AnthropicProvider {

    /// Executes HTTP request to Anthropic Messages API with retry logic.
    ///
    /// This method handles the full HTTP request lifecycle: building the URL request,
    /// setting headers, encoding the body, executing the request with automatic retries,
    /// and validating the response.
    ///
    /// ## Request Flow
    ///
    /// 1. **URL Construction**: Appends `/v1/messages` to the base URL
    /// 2. **Headers**: Adds authentication, API version, and content type via
    ///    `configuration.buildHeaders()`
    /// 3. **Body Encoding**: JSON-encodes the request body
    /// 4. **Execution**: Performs async HTTP request with retry logic
    /// 5. **Validation**: Checks HTTP status code
    /// 6. **Error Handling**: Decodes error responses and maps to AIError
    /// 7. **Success**: Decodes and returns the response with rate limit info
    ///
    /// ## Retry Logic
    ///
    /// The method implements exponential backoff retry for transient errors:
    /// - **Network errors (URLError)**: Retried with exponential backoff
    /// - **429 Rate limit**: Retried after Retry-After header duration (or backoff)
    /// - **500+ Server errors**: Retried with exponential backoff
    /// - **400-499 Client errors (except 429)**: Fail immediately, no retry
    ///
    /// Backoff formula: `2^attempt` seconds (1s, 2s, 4s, 8s...)
    /// Maximum attempts: `configuration.maxRetries + 1` (initial + retries)
    ///
    /// ## HTTP Status Codes
    ///
    /// - **200-299**: Success - response decoded and returned
    /// - **401**: Authentication error - mapped to `.authenticationFailed` (no retry)
    /// - **429**: Rate limit - mapped to `.rateLimited` (retried)
    /// - **500-599**: Server error - mapped to `.serverError` (retried)
    /// - **Other 4xx**: Client error (no retry)
    ///
    /// ## Usage
    /// ```swift
    /// let request = buildRequestBody(messages: messages, model: .claudeSonnet45, config: .default)
    /// let (response, rateLimitInfo) = try await executeRequest(request)
    /// print(response.content.first?.text ?? "")
    /// print("Remaining requests: \(rateLimitInfo?.remainingRequests ?? 0)")
    /// ```
    ///
    /// - Parameter request: The Anthropic API request to execute.
    ///
    /// - Returns: A tuple containing the decoded `AnthropicMessagesResponse` and
    ///   optional `RateLimitInfo` extracted from response headers.
    ///
    /// - Throws: `AIError` variants:
    ///   - `.networkError`: Network connectivity issues (URLError)
    ///   - `.authenticationFailed`: Invalid or missing API key (HTTP 401)
    ///   - `.rateLimited`: Rate limit exceeded after all retries (HTTP 429)
    ///   - `.serverError`: Anthropic API error after all retries (HTTP 4xx/5xx)
    ///   - `.generationFailed`: Encoding/decoding failures or all retries exhausted
    internal func executeRequest(
        _ request: AnthropicMessagesRequest
    ) async throws -> (AnthropicMessagesResponse, RateLimitInfo?) {
        // Encode request body once (reused across retries)
        let requestBody: Data
        do {
            requestBody = try encoder.encode(request)
        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }

        var lastError: Error?

        for attempt in 0...configuration.maxRetries {
            do {
                // Build URLRequest for each attempt
                let url = configuration.baseURL.appending(path: "v1/messages")
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"

                // Add headers (authentication, API version, content-type)
                for (name, value) in configuration.buildHeaders() {
                    urlRequest.setValue(value, forHTTPHeaderField: name)
                }

                urlRequest.httpBody = requestBody

                // Execute request
                let (data, response) = try await session.data(for: urlRequest)

                // Validate HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIError.networkError(URLError(.badServerResponse))
                }

                // Extract rate limit info from headers
                let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                    if let key = pair.key as? String, let value = pair.value as? String {
                        result[key] = value
                    }
                }
                let rateLimitInfo = RateLimitInfo(headers: headers)

                // Success case
                if (200...299).contains(httpResponse.statusCode) {
                    let decoded = try decoder.decode(AnthropicMessagesResponse.self, from: data)
                    return (decoded, rateLimitInfo)
                }

                // Determine if this error is retryable
                let statusCode = httpResponse.statusCode
                let isRetryable = statusCode == 429 || statusCode >= 500

                if isRetryable && attempt < configuration.maxRetries {
                    // Calculate wait time
                    let waitTime: TimeInterval
                    if statusCode == 429, let retryAfter = rateLimitInfo.retryAfter {
                        // Use Retry-After header for rate limits
                        waitTime = retryAfter
                    } else {
                        // Exponential backoff: 1s, 2s, 4s, 8s...
                        waitTime = pow(2.0, Double(attempt))
                    }

                    try await Task.sleep(for: .seconds(waitTime))
                    continue
                }

                // Non-retryable error or retries exhausted - throw appropriate error
                if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                    throw mapAnthropicError(errorResponse, statusCode: statusCode)
                }

                throw AIError.serverError(
                    statusCode: statusCode,
                    message: String(data: data, encoding: .utf8) ?? "Unknown error"
                )

            } catch let urlError as URLError {
                // Network errors are retryable
                lastError = AIError.networkError(urlError)

                if attempt < configuration.maxRetries {
                    let waitTime = pow(2.0, Double(attempt))
                    try await Task.sleep(for: .seconds(waitTime))
                    continue
                }

                throw AIError.networkError(urlError)

            } catch let aiError as AIError {
                // Check if this AIError is retryable
                if aiError.isRetryable && attempt < configuration.maxRetries {
                    lastError = aiError
                    let waitTime = pow(2.0, Double(attempt))
                    try await Task.sleep(for: .seconds(waitTime))
                    continue
                }

                throw aiError

            } catch {
                // Unknown errors - rethrow immediately
                throw error
            }
        }

        // All retries exhausted - throw last error or generic failure
        if let lastError = lastError {
            throw lastError
        }

        throw AIError.generationFailed(
            underlying: SendableError(
                NSError(domain: "AnthropicProvider", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "All retry attempts exhausted"
                ])
            )
        )
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
    /// - `billing_error`: Payment required (HTTP 402)
    ///   → `.billingError`
    /// - `request_too_large`: Request exceeds 32MB limit (HTTP 413)
    ///   → `.invalidInput`
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

        case "billing_error":
            return .billingError(error.error.message)

        case "request_too_large":
            return .invalidInput("Request exceeds 32MB size limit. \(error.error.message)")

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
    /// ## Rate Limit Information
    ///
    /// When provided, the `rateLimitInfo` parameter is included in the result,
    /// allowing callers to monitor API usage and implement request pacing.
    ///
    /// ## Finish Reason Mapping
    ///
    /// Delegates to `mapStopReason()` to convert Anthropic's `stop_reason`
    /// to SwiftAI's `FinishReason` enum.
    ///
    /// ## Usage
    /// ```swift
    /// let startTime = Date()
    /// let (response, rateLimitInfo) = try await executeRequest(request)
    /// let result = convertToGenerationResult(response, startTime: startTime, rateLimitInfo: rateLimitInfo)
    /// print(result.text)
    /// print("Speed: \(result.tokensPerSecond) tok/s")
    /// print("Remaining requests: \(result.rateLimitInfo?.remainingRequests ?? 0)")
    /// ```
    ///
    /// - Parameters:
    ///   - response: The Anthropic API response to convert.
    ///   - startTime: The timestamp when generation started (for performance metrics).
    ///   - rateLimitInfo: Optional rate limit information extracted from HTTP response headers.
    ///
    /// - Returns: A `GenerationResult` containing the generated text, metadata, and rate limit info.
    ///
    /// - Note: The `logprobs` field is always `nil` because Anthropic's API does
    ///   not provide log probabilities for generated tokens.
    internal func convertToGenerationResult(
        _ response: AnthropicMessagesResponse,
        startTime: Date,
        rateLimitInfo: RateLimitInfo? = nil
    ) throws -> GenerationResult {
        // Extract text blocks for the final response
        // Note: Thinking blocks (type="thinking") contain internal reasoning
        // and are filtered out, as they are not part of the user-facing response
        let responseText = response.content
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined()

        // Issue 12.8: Validate non-empty response
        // Allow empty text if stop_reason is "tool_use" since tool calls may not have text content
        guard !responseText.isEmpty || response.stopReason == "tool_use" else {
            throw AIError.generationFailed(underlying: SendableError(
                NSError(domain: "com.anthropic.api", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "API returned empty content"])
            ))
        }

        // Future enhancement: thinking blocks could be exposed via GenerationResult metadata
        // Example: response.content.filter { $0.type == "thinking" }.compactMap { $0.text }
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
            ),
            rateLimitInfo: rateLimitInfo
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
    /// - `"tool_use"`: Tool call requested → `.toolCall`
    /// - `"pause_turn"`: Long-running turn paused → `.pauseTurn`
    /// - `"refusal"`: Content refused → `.contentFilter`
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
