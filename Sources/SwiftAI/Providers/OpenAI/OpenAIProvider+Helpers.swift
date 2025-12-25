// OpenAIProvider+Helpers.swift
// SwiftAI
//
// Helper methods for OpenAIProvider.

import Foundation

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

        // Convert messages
        body["messages"] = messages.map { message -> [String: Any] in
            [
                "role": message.role.rawValue,
                "content": message.content.textValue
            ]
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
                    // Ensure the result fits in UInt64
                    guard nanoseconds <= Double(UInt64.max) else {
                        try await Task.sleep(nanoseconds: UInt64.max)
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
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.generationFailed(underlying: SendableError(NSError(
                domain: "OpenAIProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]
            )))
        }

        let finishReasonStr = firstChoice["finish_reason"] as? String
        let finishReason = finishReasonStr.flatMap { FinishReason(rawValue: $0) } ?? .stop

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

        // Calculate token count and performance metrics
        let tokenCount = usage?.completionTokens ?? 0

        return GenerationResult(
            text: content,
            tokenCount: tokenCount,
            generationTime: 0, // Not available in non-streaming mode
            tokensPerSecond: 0,
            finishReason: finishReason,
            usage: usage
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
