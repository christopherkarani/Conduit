// OpenAIProvider.swift
// SwiftAI
//
// OpenAI-compatible provider actor for text generation, embeddings, and more.

import Foundation

// MARK: - OpenAIProvider

/// A provider for OpenAI-compatible APIs.
///
/// `OpenAIProvider` provides unified access to multiple OpenAI-compatible backends:
/// - **OpenAI**: Official OpenAI API (GPT-4, DALL-E, Whisper)
/// - **OpenRouter**: Aggregator with access to multiple providers
/// - **Ollama**: Local inference server
/// - **Azure OpenAI**: Microsoft's enterprise OpenAI service
/// - **Custom**: Any OpenAI-compatible endpoint
///
/// ## Progressive Disclosure
///
/// ### Level 1: Simple
/// ```swift
/// let provider = OpenAIProvider(apiKey: "sk-...")
/// let response = try await provider.generate("Hello", model: .gpt4o)
/// ```
///
/// ### Level 2: Standard
/// ```swift
/// let provider = OpenAIProvider(endpoint: .openRouter, apiKey: "or-...")
/// let response = try await provider.generate(
///     messages: [.user("Hello")],
///     model: .openRouter("anthropic/claude-3-opus")
/// )
/// ```
///
/// ### Level 3: Expert
/// ```swift
/// let config = OpenAIConfiguration(
///     endpoint: .openRouter,
///     authentication: .bearer("or-..."),
///     timeout: 120,
///     openRouterConfig: OpenRouterRoutingConfig(
///         providers: [.anthropic],
///         fallbacks: true
///     )
/// )
/// let provider = OpenAIProvider(configuration: config)
/// ```
///
/// ## Thread Safety
///
/// `OpenAIProvider` is an actor, ensuring thread-safe access to all methods.
/// It can be safely shared across concurrent tasks.
///
/// ## Protocol Conformances
///
/// - `AIProvider`: Core provider protocol
/// - `TextGenerator`: Text generation capabilities
/// - `EmbeddingGenerator`: Embedding generation
/// - `TokenCounter`: Token counting (estimated)
///
/// ## Cancellation
///
/// All async methods support Swift's structured concurrency cancellation.
/// Use `cancelGeneration()` for explicit cancellation control.
public actor OpenAIProvider: AIProvider, TextGenerator, EmbeddingGenerator, TokenCounter, ImageGenerator {

    // MARK: - Type Aliases

    /// The response type for non-streaming generation.
    public typealias Response = GenerationResult

    /// The chunk type for streaming generation.
    public typealias StreamChunk = GenerationChunk

    /// The model identifier type for this provider.
    public typealias ModelID = OpenAIModelID

    // MARK: - Properties

    /// The configuration for this provider.
    public let configuration: OpenAIConfiguration

    /// The URLSession used for HTTP requests.
    private let session: URLSession

    /// Active generation task for cancellation.
    private var activeTask: Task<Void, Never>?

    /// JSON encoder for request bodies.
    private let encoder: JSONEncoder

    /// JSON decoder for response bodies.
    private let decoder: JSONDecoder

    /// Active image generation task for cancellation.
    private var activeImageTask: Task<GeneratedImage, Error>?

    // MARK: - Initialization

    /// Creates a provider with a full configuration.
    ///
    /// - Parameter configuration: The provider configuration.
    public init(configuration: OpenAIConfiguration) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.session = URLSession(configuration: sessionConfig)

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Creates a provider for OpenAI with an API key.
    ///
    /// This is the simplest way to create an OpenAI provider.
    ///
    /// ```swift
    /// let provider = OpenAIProvider(apiKey: "sk-...")
    /// ```
    ///
    /// - Parameter apiKey: Your OpenAI API key.
    public init(apiKey: String) {
        self.init(configuration: .openAI(apiKey: apiKey))
    }

    /// Creates a provider for a specific endpoint with an API key.
    ///
    /// ```swift
    /// let provider = OpenAIProvider(endpoint: .openRouter, apiKey: "or-...")
    /// ```
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint to use.
    ///   - apiKey: The API key (optional for Ollama).
    public init(endpoint: OpenAIEndpoint, apiKey: String? = nil) {
        let auth = OpenAIAuthentication.for(endpoint: endpoint, apiKey: apiKey)
        self.init(configuration: OpenAIConfiguration(endpoint: endpoint, authentication: auth))
    }

    // MARK: - AIProvider Protocol

    /// Whether this provider is currently available.
    public var isAvailable: Bool {
        get async {
            // Check authentication
            guard configuration.hasValidAuthentication else {
                return false
            }

            // For Ollama, check server health
            if case .ollama = configuration.endpoint {
                if let ollamaConfig = configuration.ollamaConfig, ollamaConfig.healthCheck {
                    return await checkOllamaHealth()
                }
            }

            return true
        }
    }

    /// Detailed availability status.
    public var availabilityStatus: ProviderAvailability {
        get async {
            // Check authentication
            guard configuration.hasValidAuthentication else {
                return .unavailable(.apiKeyMissing)
            }

            // For Ollama, check server health
            if case .ollama = configuration.endpoint {
                if let ollamaConfig = configuration.ollamaConfig, ollamaConfig.healthCheck {
                    let healthy = await checkOllamaHealth()
                    if !healthy {
                        return .unavailable(.noNetwork)
                    }
                }
            }

            return .available
        }
    }

    /// Cancels any in-flight generation.
    public func cancelGeneration() async {
        activeTask?.cancel()
        activeTask = nil
        // Also cancel image generation
        activeImageTask?.cancel()
        activeImageTask = nil
    }

    // MARK: - TextGenerator Protocol

    /// Generates text from a simple string prompt.
    public func generate(
        _ prompt: String,
        model: OpenAIModelID,
        config: GenerateConfig
    ) async throws -> String {
        let messages = [Message.user(prompt)]
        let result = try await generate(messages: messages, model: model, config: config)
        return result.text
    }

    /// Generates text from a conversation.
    public func generate(
        messages: [Message],
        model: OpenAIModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        try await performGeneration(messages: messages, model: model, config: config, stream: false)
    }

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

    // MARK: - EmbeddingGenerator Protocol

    /// Generates an embedding for the given text.
    public func embed(
        _ text: String,
        model: OpenAIModelID
    ) async throws -> EmbeddingResult {
        let url = configuration.endpoint.embeddingsURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add headers
        for (name, value) in configuration.buildHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
        }

        // Build request body
        let body: [String: Any] = [
            "model": model.rawValue,
            "input": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.serverError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Double] else {
            throw AIError.generationFailed(underlying: SendableError(NSError(
                domain: "OpenAIProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid embedding response"]
            )))
        }

        let floatEmbedding = embedding.map { Float($0) }
        return EmbeddingResult(
            vector: floatEmbedding,
            text: text,
            model: model.rawValue
        )
    }

    /// Generates embeddings for multiple texts.
    ///
    /// This method uses concurrent processing with structured concurrency
    /// to generate embeddings in parallel while preserving the original order.
    ///
    /// - Parameters:
    ///   - texts: Array of text strings to generate embeddings for.
    ///   - model: The model to use for generating embeddings.
    /// - Returns: Array of `EmbeddingResult` in the same order as input texts.
    /// - Throws: `AIError` if any embedding generation fails.
    public func embedBatch(
        _ texts: [String],
        model: OpenAIModelID
    ) async throws -> [EmbeddingResult] {
        // Process embeddings concurrently while preserving order
        try await withThrowingTaskGroup(of: (Int, EmbeddingResult).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let result = try await self.embed(text, model: model)
                    return (index, result)
                }
            }

            var results = [(Int, EmbeddingResult)]()
            results.reserveCapacity(texts.count)

            for try await indexedResult in group {
                results.append(indexedResult)
            }

            // Sort by original index to preserve order
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - TokenCounter Protocol

    /// Counts tokens in text (estimated).
    ///
    /// - Important: This method uses a rough estimate of approximately 4 characters per token,
    ///   which may be inaccurate for:
    ///   - Non-English text (typically uses more tokens)
    ///   - Code or technical content (variable token density)
    ///   - Text with many special characters or unicode
    ///   - Structured data formats (JSON, XML, etc.)
    ///
    /// For accurate token counting, consider:
    /// - Using OpenAI's `tiktoken` library for client-side counting
    /// - Calling the token counting API endpoint directly
    /// - Testing with your specific content and model to calibrate estimates
    ///
    /// - Parameters:
    ///   - text: The text to count tokens for.
    ///   - model: The model identifier (used for future model-specific counting).
    /// - Returns: An estimated token count.
    /// - Note: Estimates assume English prose. Actual counts may vary by ±50% or more.
    public func countTokens(
        in text: String,
        for model: OpenAIModelID
    ) async throws -> TokenCount {
        // Use a simple estimation: ~4 characters per token
        let estimatedTokens = max(1, text.count / 4)
        return TokenCount(count: estimatedTokens, isEstimate: true)
    }

    /// Counts tokens in messages (estimated).
    ///
    /// - Important: This method uses a rough estimate of approximately 4 characters per token,
    ///   plus 4 tokens of overhead per message, which may be inaccurate for:
    ///   - Non-English text (typically uses more tokens)
    ///   - Code or technical content (variable token density)
    ///   - Text with many special characters or unicode
    ///   - Structured data formats (JSON, XML, etc.)
    ///
    /// For accurate token counting, consider:
    /// - Using OpenAI's `tiktoken` library for client-side counting
    /// - Calling the token counting API endpoint directly
    /// - Testing with your specific content and model to calibrate estimates
    ///
    /// - Parameters:
    ///   - messages: The messages to count tokens for.
    ///   - model: The model identifier (used for future model-specific counting).
    /// - Returns: An estimated total token count including message overhead.
    /// - Note: Estimates assume English prose and include per-message formatting overhead.
    ///   Actual counts may vary by ±50% or more depending on content characteristics.
    public func countTokens(
        in messages: [Message],
        for model: OpenAIModelID
    ) async throws -> TokenCount {
        // Estimate tokens for each message plus overhead
        var totalTokens = 0
        for message in messages {
            let textTokens = max(1, message.content.textValue.count / 4)
            totalTokens += textTokens + 4  // 4 tokens overhead per message
        }
        return TokenCount(count: totalTokens, isEstimate: true)
    }

    /// Encodes text to tokens (not supported - throws error).
    public func encode(_ text: String, for model: OpenAIModelID) async throws -> [Int] {
        throw AIError.providerUnavailable(reason: .unknown("Token encoding not supported for OpenAI provider"))
    }

    /// Decodes tokens to text (not supported - throws error).
    public func decode(_ tokens: [Int], for model: OpenAIModelID, skipSpecialTokens: Bool) async throws -> String {
        throw AIError.providerUnavailable(reason: .unknown("Token decoding not supported for OpenAI provider"))
    }

    // MARK: - Capabilities

    /// The capabilities available for this provider.
    public var capabilities: OpenAICapabilities {
        get async {
            configuration.endpoint.defaultCapabilities
        }
    }

    // MARK: - ImageGenerator Protocol

    /// Generates an image from a text prompt using DALL-E.
    ///
    /// Uses DALL-E 3 by default unless DALL-E 2-only sizes are specified.
    /// Always uses base64 response format for reliable data (URLs expire in 60 min).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = OpenAIProvider(apiKey: "sk-...")
    /// let image = try await provider.generateImage(
    ///     prompt: "A cat wearing a top hat",
    ///     config: .dalleHD
    /// )
    /// try image.save(to: documentsURL.appending(path: "cat.png"))
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: Text description of desired image (max 4000 chars for DALL-E 3).
    ///   - negativePrompt: Not supported by DALL-E (ignored).
    ///   - config: Image generation configuration.
    ///   - onProgress: Not supported by DALL-E (ignored).
    /// - Returns: Generated image with metadata including revised prompt.
    /// - Throws: `AIError.invalidInput` if prompt is empty.
    /// - Throws: `AIError.providerUnavailable` if endpoint is not OpenAI.
    /// - Throws: `AIError.contentFiltered` if prompt violates content policy.
    public func generateImage(
        prompt: String,
        negativePrompt: String? = nil,
        config: ImageGenerationConfig = .default,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)? = nil
    ) async throws -> GeneratedImage {
        // 1. Check cancellation
        try Task.checkCancellation()

        // 2. Validate prompt
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AIError.invalidInput("Prompt cannot be empty")
        }

        // 3. Validate endpoint supports image generation
        guard configuration.endpoint == .openAI else {
            throw AIError.providerUnavailable(reason: .unknown(
                "Image generation is only supported with OpenAI endpoint"
            ))
        }

        // 4. Determine model based on size compatibility
        let model: String
        if let size = config.dalleSize, !size.supportedByDallE3 {
            model = "dall-e-2"
        } else {
            model = "dall-e-3"
        }

        // 5. Validate prompt length based on selected model
        // DALL-E 3: 4000 character limit
        // DALL-E 2: 1000 character limit
        // Note: Using character count as a proxy since actual token limits are:
        // DALL-E 3: ~1000 tokens, DALL-E 2: ~400 tokens
        // Character limits are more conservative and easier to validate
        let maxPromptLength = model == "dall-e-3" ? 4000 : 1000
        if trimmedPrompt.count > maxPromptLength {
            throw AIError.invalidInput(
                "Prompt exceeds maximum length of \(maxPromptLength) characters for \(model). " +
                "Current length: \(trimmedPrompt.count) characters."
            )
        }

        // 6. Determine size
        let size: String
        if let dalleSize = config.dalleSize {
            size = dalleSize.rawValue
        } else if let width = config.width, let height = config.height {
            size = mapToDALLESize(width: width, height: height, model: model)
        } else {
            size = "1024x1024"
        }

        // 7. Build request
        let url = configuration.endpoint.imagesGenerationsURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        for (name, value) in configuration.buildHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
        }

        // 8. Build request body
        var body: [String: Any] = [
            "model": model,
            "prompt": trimmedPrompt,
            "n": 1,
            "size": size,
            "response_format": "b64_json"
        ]

        // Add DALL-E 3 specific options
        if model == "dall-e-3" {
            if let quality = config.dalleQuality {
                body["quality"] = quality.rawValue
            }
            if let style = config.dalleStyle {
                body["style"] = style.rawValue
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 9. Execute request
        try Task.checkCancellation()

        let (data, response) = try await session.data(for: request)

        // 9. Check HTTP status
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            // Check for rate limiting
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) }
                throw AIError.rateLimited(retryAfter: retryAfter)
            }

            // Try to parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                if message.contains("content policy") || message.contains("safety") {
                    throw AIError.contentFiltered(reason: message)
                }
                throw AIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
            throw AIError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        // 10. Check cancellation after response
        try Task.checkCancellation()

        // 11. Parse response
        return try parseImageResponse(data: data, model: model)
    }

    // MARK: - Private Methods

    /// Performs a non-streaming generation request.
    private func performGeneration(
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

    /// Performs a streaming generation request.
    private func performStreamingGeneration(
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

        // Execute streaming request
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            // Try to read error body with size limit to prevent DoS
            let maxErrorSize = 10_000 // 10KB should be enough for error messages
            var errorData = Data()
            errorData.reserveCapacity(min(1024, maxErrorSize))

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

        // Parse SSE stream
        var chunkIndex = 0
        var buffer = ""

        for try await byte in bytes {
            try Task.checkCancellation()

            // Validate UTF-8 byte before creating UnicodeScalar
            guard let scalar = UnicodeScalar(byte) else {
                throw AIError.generationFailed(underlying: SendableError(NSError(
                    domain: "OpenAIProvider",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 byte (\(byte)) in streaming response"]
                )))
            }
            buffer.append(Character(scalar))

            // Process complete lines
            while let lineEnd = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<lineEnd])
                buffer = String(buffer[buffer.index(after: lineEnd)...])

                if line.hasPrefix("data: ") {
                    let jsonStr = String(line.dropFirst(6))

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

                        // Only yield if there's content or if it's a final chunk with finish reason
                        if let content = content, !content.isEmpty {
                            let chunk = GenerationChunk(
                                text: content,
                                isComplete: finishReason != nil,
                                finishReason: finishReason
                            )
                            continuation.yield(chunk)
                            chunkIndex += 1
                        } else if let finishReason = finishReason {
                            // Yield completion chunk
                            let chunk = GenerationChunk.completion(finishReason: finishReason)
                            continuation.yield(chunk)
                        }
                    }
                }
            }
        }

        continuation.finish()
    }

    /// Builds the request body for chat completions.
    private func buildRequestBody(
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
    private func executeWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
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
    private func parseGenerationResponse(data: Data) throws -> GenerationResult {
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
    private func checkOllamaHealth() async -> Bool {
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

    /// Maps arbitrary dimensions to the nearest supported DALL-E size.
    private func mapToDALLESize(width: Int, height: Int, model: String) -> String {
        if model == "dall-e-2" {
            // DALL-E 2: 256, 512, or 1024 square only
            let maxDim = max(width, height)
            if maxDim <= 256 { return "256x256" }
            if maxDim <= 512 { return "512x512" }
            return "1024x1024"
        } else {
            // DALL-E 3: 1024x1024, 1792x1024, 1024x1792
            let aspectRatio = Float(width) / Float(height)
            if aspectRatio > 1.5 {
                return "1792x1024" // Landscape
            } else if aspectRatio < 0.67 {
                return "1024x1792" // Portrait
            }
            return "1024x1024" // Square
        }
    }

    /// Parses DALL-E image generation response.
    private func parseImageResponse(data: Data, model: String) throws -> GeneratedImage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.generationFailed(underlying: SendableError(
                NSError(domain: "OpenAIProvider", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
            ))
        }

        guard let dataArray = json["data"] as? [[String: Any]],
              let firstImage = dataArray.first,
              let b64Json = firstImage["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64Json) else {
            throw AIError.generationFailed(underlying: SendableError(
                NSError(domain: "OpenAIProvider", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid image data in response"])
            ))
        }

        // Extract metadata
        let revisedPrompt = firstImage["revised_prompt"] as? String
        let created = json["created"] as? TimeInterval

        let metadata = ImageGenerationMetadata(
            revisedPrompt: revisedPrompt,
            createdAt: created.map { Date(timeIntervalSince1970: $0) },
            model: model
        )

        return GeneratedImage(data: imageData, format: .png, metadata: metadata)
    }
}
