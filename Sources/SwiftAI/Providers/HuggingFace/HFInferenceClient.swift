// HFInferenceClient.swift
// SwiftAI

import Foundation

// MARK: - Request DTOs

/// Request payload for HuggingFace chat completion API.
internal struct HFChatCompletionRequest: Codable, Sendable {
    let model: String
    let messages: [HFMessage]
    let max_tokens: Int?
    let temperature: Float?
    let top_p: Float?
    let stream: Bool
    let stop: [String]?
    let frequency_penalty: Float?
    let presence_penalty: Float?
    let seed: Int?

    init(
        model: String,
        messages: [HFMessage],
        config: GenerateConfig,
        stream: Bool
    ) {
        self.model = model
        self.messages = messages
        self.max_tokens = config.maxTokens
        self.temperature = config.temperature
        self.top_p = config.topP
        self.stream = stream
        self.stop = config.stopSequences.isEmpty ? nil : config.stopSequences
        self.frequency_penalty = config.frequencyPenalty != 0.0 ? config.frequencyPenalty : nil
        self.presence_penalty = config.presencePenalty != 0.0 ? config.presencePenalty : nil
        self.seed = config.seed.map { Int($0) }
    }
}

/// A single message in a chat conversation for HuggingFace API.
internal struct HFMessage: Codable, Sendable {
    let role: String
    let content: String

    init(role: String, content: String) {
        self.role = role
        self.content = content
    }

    init(from message: Message) {
        self.role = message.role.rawValue
        self.content = message.content.textValue
    }
}

/// Request payload for feature extraction (embeddings).
internal struct HFFeatureExtractionRequest: Codable, Sendable {
    let inputs: [String]
    let options: HFFeatureOptions?

    init(inputs: [String], waitForModel: Bool = true) {
        self.inputs = inputs
        self.options = HFFeatureOptions(wait_for_model: waitForModel, use_cache: true)
    }
}

/// Options for feature extraction requests.
internal struct HFFeatureOptions: Codable, Sendable {
    let wait_for_model: Bool?
    let use_cache: Bool?
}

/// Request payload for text-to-image generation.
internal struct HFTextToImageRequest: Codable, Sendable {
    let inputs: String
    let parameters: HFImageParameters?

    init(prompt: String, parameters: HFImageParameters? = nil) {
        self.inputs = prompt
        self.parameters = parameters
    }
}

/// Parameters for image generation.
internal struct HFImageParameters: Codable, Sendable {
    let width: Int?
    let height: Int?
    let num_inference_steps: Int?
    let guidance_scale: Float?
    let negative_prompt: String?

    init(
        width: Int? = nil,
        height: Int? = nil,
        steps: Int? = nil,
        guidanceScale: Float? = nil,
        negativePrompt: String? = nil
    ) {
        self.width = width
        self.height = height
        self.num_inference_steps = steps
        self.guidance_scale = guidanceScale
        self.negative_prompt = negativePrompt
    }

    /// Creates HuggingFace-specific parameters from the public config.
    ///
    /// - Parameters:
    ///   - config: The public image generation configuration.
    ///   - negativePrompt: Optional negative prompt text.
    init(from config: ImageGenerationConfig, negativePrompt: String? = nil) {
        self.init(
            width: config.width,
            height: config.height,
            steps: config.steps,
            guidanceScale: config.guidanceScale,
            negativePrompt: negativePrompt
        )
    }
}

// MARK: - Response DTOs

/// Response from HuggingFace chat completion API.
internal struct HFChatCompletionResponse: Codable, Sendable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [HFChoice]
    let usage: HFUsage?
}

/// A single choice in a chat completion response.
internal struct HFChoice: Codable, Sendable {
    let index: Int
    let message: HFResponseMessage?
    let delta: HFDelta?
    let finish_reason: String?
}

/// A message in a chat completion response.
internal struct HFResponseMessage: Codable, Sendable {
    let role: String
    let content: String
}

/// A delta update in a streaming chat completion.
internal struct HFDelta: Codable, Sendable {
    let role: String?
    let content: String?
}

/// Token usage statistics from the API.
internal struct HFUsage: Codable, Sendable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

/// Response from automatic speech recognition API.
internal struct HFASRResponse: Codable, Sendable {
    let text: String
    let chunks: [HFTranscriptionChunk]?
}

/// A timestamped chunk of transcribed audio.
internal struct HFTranscriptionChunk: Codable, Sendable {
    let text: String
    let timestamp: [Double]  // [start, end]
}

/// Error response from HuggingFace API.
internal struct HFErrorResponse: Codable, Sendable {
    let error: String?
    let error_type: String?
    let estimated_time: Double?
}

// MARK: - SSE Event

/// A server-sent event from the streaming API.
internal struct SSEEvent: Sendable {
    let type: String?
    let data: String

    /// Whether this is the final event marker.
    var isDone: Bool {
        data == "[DONE]"
    }
}

// MARK: - SSE Stream Parser

/// Parses server-sent events from a byte stream.
internal actor SSEStreamParser {
    private var buffer: String = ""

    /// Parses incoming data and returns complete events.
    ///
    /// - Parameter data: Raw bytes from the network stream.
    /// - Returns: Array of complete SSE events found in the data.
    func parse(_ data: Data) -> [SSEEvent] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        buffer += text

        var events: [SSEEvent] = []
        let lines = buffer.components(separatedBy: "\n")

        // Keep the last incomplete line in the buffer
        buffer = lines.last ?? ""

        var currentEvent: (type: String?, data: String?) = (nil, nil)

        for line in lines.dropLast() {
            if line.isEmpty {
                // Empty line marks the end of an event
                if let data = currentEvent.data {
                    events.append(SSEEvent(type: currentEvent.type, data: data))
                }
                currentEvent = (nil, nil)
            } else if line.hasPrefix("data: ") {
                currentEvent.data = String(line.dropFirst(6))
            } else if line.hasPrefix("event: ") {
                currentEvent.type = String(line.dropFirst(7))
            }
            // Ignore other SSE fields (id:, retry:, etc.)
        }

        return events
    }

    /// Resets the internal buffer.
    func reset() {
        buffer = ""
    }
}

// MARK: - HFInferenceClient

/// Internal HTTP client for HuggingFace Inference API.
///
/// Handles all network communication, SSE streaming, error mapping,
/// and retry logic for the HuggingFace provider.
internal actor HFInferenceClient {

    private let configuration: HFConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Creates a new HuggingFace inference client.
    ///
    /// - Parameter configuration: Configuration for the API client.
    init(configuration: HFConfiguration) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.session = URLSession(configuration: sessionConfig)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Chat Completion (Non-Streaming)

    /// Performs a non-streaming chat completion request.
    ///
    /// - Parameters:
    ///   - model: The HuggingFace model identifier.
    ///   - messages: Array of messages in the conversation.
    ///   - config: Generation configuration parameters.
    /// - Returns: The chat completion response.
    /// - Throws: `AIError` if the request fails.
    func chatCompletion(
        model: String,
        messages: [HFMessage],
        config: GenerateConfig
    ) async throws -> HFChatCompletionResponse {
        let request = HFChatCompletionRequest(
            model: model,
            messages: messages,
            config: config,
            stream: false
        )

        let url = configuration.baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(model)
            .appendingPathComponent("v1/chat/completions")

        return try await performRequest(
            url: url,
            method: "POST",
            body: request,
            responseType: HFChatCompletionResponse.self
        )
    }

    // MARK: - Chat Completion (Streaming)

    /// Performs a streaming chat completion request.
    ///
    /// - Parameters:
    ///   - model: The HuggingFace model identifier.
    ///   - messages: Array of messages in the conversation.
    ///   - config: Generation configuration parameters.
    /// - Returns: An async stream of chat completion chunks.
    func streamChatCompletion(
        model: String,
        messages: [HFMessage],
        config: GenerateConfig
    ) -> AsyncThrowingStream<HFChatCompletionResponse, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = HFChatCompletionRequest(
                        model: model,
                        messages: messages,
                        config: config,
                        stream: true
                    )

                    let url = configuration.baseURL
                        .appendingPathComponent("models")
                        .appendingPathComponent(model)
                        .appendingPathComponent("v1/chat/completions")

                    try await streamRequest(
                        url: url,
                        body: request,
                        continuation: continuation
                    )

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

    // MARK: - Feature Extraction (Embeddings)

    /// Performs feature extraction (embeddings) request.
    ///
    /// - Parameters:
    ///   - model: The HuggingFace model identifier.
    ///   - inputs: Array of text inputs to embed.
    /// - Returns: Array of embedding vectors (one per input).
    /// - Throws: `AIError` if the request fails.
    func featureExtraction(
        model: String,
        inputs: [String]
    ) async throws -> [[Float]] {
        let request = HFFeatureExtractionRequest(inputs: inputs)

        let url = configuration.baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(model)

        return try await performRequest(
            url: url,
            method: "POST",
            body: request,
            responseType: [[Float]].self
        )
    }

    // MARK: - Automatic Speech Recognition

    /// Performs automatic speech recognition (transcription).
    ///
    /// - Parameters:
    ///   - model: The HuggingFace model identifier.
    ///   - audioData: Raw audio data (MP3, WAV, etc.).
    ///   - config: Transcription configuration.
    /// - Returns: The transcription result.
    /// - Throws: `AIError` if the request fails.
    func automaticSpeechRecognition(
        model: String,
        audioData: Data,
        config: TranscriptionConfig
    ) async throws -> HFASRResponse {
        let url = configuration.baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(model)

        var urlRequest = try createURLRequest(url: url, method: "POST")
        urlRequest.setValue("audio/mpeg", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = audioData

        return try await performRequestWithRetry(urlRequest, responseType: HFASRResponse.self)
    }

    // MARK: - Text-to-Image Generation

    /// Generates an image from a text prompt.
    ///
    /// - Parameters:
    ///   - model: The HuggingFace model identifier (e.g., "stabilityai/stable-diffusion-3").
    ///   - prompt: The text prompt describing the desired image.
    ///   - negativePrompt: Optional text describing what to avoid in the image.
    ///   - parameters: Optional image generation parameters.
    /// - Returns: A `GeneratedImage` with the image data and convenience methods.
    /// - Throws: `AIError` if the request fails.
    ///
    /// ## Usage
    /// ```swift
    /// let result = try await client.textToImage(
    ///     model: "stabilityai/stable-diffusion-3",
    ///     prompt: "A cat wearing a top hat",
    ///     negativePrompt: "blurry, low quality"
    /// )
    ///
    /// // Use in SwiftUI
    /// result.image
    ///
    /// // Save to file
    /// try result.save(to: fileURL)
    ///
    /// // Access raw data
    /// result.data
    /// ```
    func textToImage(
        model: String,
        prompt: String,
        negativePrompt: String? = nil,
        parameters: HFImageParameters? = nil
    ) async throws -> GeneratedImage {
        // Merge negative prompt into parameters if provided
        let finalParameters: HFImageParameters?
        if let negativePrompt = negativePrompt {
            if let params = parameters {
                // Merge negative prompt with existing parameters
                finalParameters = HFImageParameters(
                    width: params.width,
                    height: params.height,
                    steps: params.num_inference_steps,
                    guidanceScale: params.guidance_scale,
                    negativePrompt: negativePrompt
                )
            } else {
                // Create parameters with just negative prompt
                finalParameters = HFImageParameters(negativePrompt: negativePrompt)
            }
        } else {
            finalParameters = parameters
        }

        let request = HFTextToImageRequest(prompt: prompt, parameters: finalParameters)

        let url = configuration.baseURL
            .appendingPathComponent("models")
            .appendingPathComponent(model)

        var urlRequest = try createURLRequest(url: url, method: "POST")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("image/png", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try encoder.encode(request)

        let data = try await performImageRequestWithRetry(urlRequest)
        return GeneratedImage(data: data, format: .png)
    }

    /// Performs an image request with automatic retry logic.
    private func performImageRequestWithRetry(_ request: URLRequest) async throws -> Data {
        var lastError: Error?

        for attempt in 0...configuration.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIError.networkError(URLError(.badServerResponse))
                }

                if httpResponse.statusCode >= 400 {
                    try handleHTTPError(statusCode: httpResponse.statusCode, data: data, response: httpResponse)
                }

                return data

            } catch let error as AIError {
                lastError = error

                guard error.isRetryable && attempt < configuration.maxRetries else {
                    throw error
                }

                let delay = configuration.retryBaseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            } catch {
                throw AIError.generation(error)
            }
        }

        throw lastError ?? AIError.generationFailed(underlying: SendableError(URLError(.unknown)))
    }

    // MARK: - Request Execution

    /// Performs a generic HTTP request with JSON encoding/decoding.
    private func performRequest<Request: Encodable, Response: Decodable>(
        url: URL,
        method: String,
        body: Request,
        responseType: Response.Type
    ) async throws -> Response {
        var urlRequest = try createURLRequest(url: url, method: method)
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(body)

        return try await performRequestWithRetry(urlRequest, responseType: responseType)
    }

    /// Performs a request with automatic retry logic.
    private func performRequestWithRetry<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        var lastError: Error?

        for attempt in 0...configuration.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIError.networkError(URLError(.badServerResponse))
                }

                // Check for errors
                if httpResponse.statusCode >= 400 {
                    try handleHTTPError(statusCode: httpResponse.statusCode, data: data, response: httpResponse)
                }

                // Decode successful response
                return try decoder.decode(Response.self, from: data)

            } catch let error as AIError {
                lastError = error

                // Only retry if the error is retryable and we haven't exhausted retries
                guard error.isRetryable && attempt < configuration.maxRetries else {
                    throw error
                }

                // Calculate exponential backoff delay
                let delay = configuration.retryBaseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            } catch {
                throw AIError.generation(error)
            }
        }

        throw lastError ?? AIError.generationFailed(underlying: SendableError(URLError(.unknown)))
    }

    // MARK: - Streaming Request

    /// Performs a streaming SSE request.
    private func streamRequest<Request: Encodable>(
        url: URL,
        body: Request,
        continuation: AsyncThrowingStream<HFChatCompletionResponse, Error>.Continuation
    ) async throws {
        var urlRequest = try createURLRequest(url: url, method: "POST")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try encoder.encode(body)

        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode >= 400 {
            // Read all data for error response
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            try handleHTTPError(statusCode: httpResponse.statusCode, data: errorData, response: httpResponse)
        }

        let parser = SSEStreamParser()

        for try await line in bytes.lines {
            let events = await parser.parse(Data((line + "\n").utf8))

            for event in events {
                if event.isDone {
                    return
                }

                // Parse the JSON data
                if let data = event.data.data(using: .utf8) {
                    do {
                        let chunk = try decoder.decode(HFChatCompletionResponse.self, from: data)
                        continuation.yield(chunk)
                    } catch {
                        // Skip malformed chunks
                        continue
                    }
                }
            }
        }
    }

    // MARK: - Error Handling

    /// Maps HTTP errors to AIError cases.
    private func handleHTTPError(statusCode: Int, data: Data, response: HTTPURLResponse) throws {
        // Try to decode error response
        let errorMessage: String?
        let estimatedTime: Double?

        if let errorResponse = try? decoder.decode(HFErrorResponse.self, from: data) {
            errorMessage = errorResponse.error
            estimatedTime = errorResponse.estimated_time
        } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            errorMessage = text
            estimatedTime = nil
        } else {
            errorMessage = nil
            estimatedTime = nil
        }

        switch statusCode {
        case 401:
            throw AIError.authenticationFailed("Invalid or missing API token")

        case 429:
            // Parse Retry-After header if present
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw AIError.rateLimited(retryAfter: retryAfter)

        case 503:
            // Model loading or server unavailable
            if estimatedTime != nil {
                throw AIError.providerUnavailable(reason: .modelDownloading(progress: 0.0))
            } else {
                throw AIError.serverError(statusCode: statusCode, message: errorMessage)
            }

        case 400..<500:
            // Client errors (invalid input, not found, etc.)
            throw AIError.serverError(statusCode: statusCode, message: errorMessage)

        case 500..<600:
            // Server errors (retryable)
            throw AIError.serverError(statusCode: statusCode, message: errorMessage)

        default:
            throw AIError.serverError(statusCode: statusCode, message: errorMessage)
        }
    }

    // MARK: - URL Request Creation

    /// Creates a base URL request with authentication headers.
    private func createURLRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method

        // Add authentication if available
        let token = try resolveToken()
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("SwiftAI/1.0", forHTTPHeaderField: "User-Agent")

        return request
    }

    /// Resolves the API token from the configuration.
    private func resolveToken() throws -> String {
        guard let token = configuration.tokenProvider.token, !token.isEmpty else {
            throw AIError.authenticationFailed("No HuggingFace API token configured. Set HF_TOKEN environment variable or provide a token explicitly.")
        }

        return token
    }
}
