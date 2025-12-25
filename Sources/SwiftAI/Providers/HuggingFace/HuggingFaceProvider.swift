// HuggingFaceProvider.swift
// SwiftAI

import Foundation

// MARK: - HuggingFaceProvider

/// Cloud-based inference provider using HuggingFace Inference API.
///
/// `HuggingFaceProvider` enables access to hundreds of models hosted on HuggingFace's
/// infrastructure, from small specialized models to large frontier LLMs. All inference
/// happens in the cloud, requiring network connectivity and a HuggingFace API token.
///
/// ## Features
///
/// - **Massive Model Access**: Access models too large to run locally
/// - **No Local Resources**: Zero memory footprint on your device
/// - **Instant Availability**: No downloads, models are instantly available
/// - **Auto-scaling**: HuggingFace handles all infrastructure scaling
///
/// ## Requirements
///
/// - Active internet connection
/// - HuggingFace account and API token
/// - Set `HF_TOKEN` environment variable or provide token explicitly
///
/// ## Usage
///
/// ### Basic Setup
/// ```swift
/// // Using environment variable (recommended)
/// let provider = HuggingFaceProvider()
///
/// // Explicit token
/// let provider = HuggingFaceProvider(token: "hf_...")
///
/// // Custom configuration
/// let config = HFConfiguration.default
///     .timeout(120)
///     .maxRetries(5)
/// let provider = HuggingFaceProvider(configuration: config)
/// ```
///
/// ### Text Generation
/// ```swift
/// let provider = HuggingFaceProvider()
/// let response = try await provider.generate(
///     "Explain quantum computing",
///     model: .llama3_1_70B,
///     config: .default
/// )
/// print(response)
/// ```
///
/// ### Streaming Generation
/// ```swift
/// let stream = provider.stream(
///     "Write a poem about AI",
///     model: .llama3_1_8B,
///     config: .creative
/// )
///
/// for try await text in stream {
///     print(text, terminator: "")
/// }
/// ```
///
/// ### Embeddings
/// ```swift
/// let embedding = try await provider.embed(
///     "SwiftAI is a unified inference framework",
///     model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
/// )
/// print("Dimensions: \(embedding.dimensions)")
/// ```
///
/// ### Audio Transcription
/// ```swift
/// let result = try await provider.transcribe(
///     audioURL: audioFileURL,
///     model: .whisperLargeV3,
///     config: .detailed
/// )
/// print(result.text)
/// ```
///
/// ## Protocol Conformances
/// - `AIProvider`: Core generation and streaming
/// - `TextGenerator`: Text-specific conveniences
/// - `EmbeddingGenerator`: Vector embeddings
/// - `Transcriber`: Audio transcription
///
/// ## Thread Safety
/// As an actor, `HuggingFaceProvider` is thread-safe and serializes all operations.
public actor HuggingFaceProvider: AIProvider, TextGenerator, EmbeddingGenerator, Transcriber {

    // MARK: - Associated Types

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    // MARK: - Properties

    /// Configuration for HuggingFace API access.
    public let configuration: HFConfiguration

    /// Internal HTTP client for API communication.
    private let client: HFInferenceClient

    /// Flag for cancellation support.
    private var isCancelled: Bool = false

    /// Current image generation task for cancellation support.
    private var currentImageTask: Task<GeneratedImage, Error>?

    /// Default model for image generation.
    /// Can be overridden when calling textToImage() by passing a different model.
    public let defaultImageModel: String

    // MARK: - Initialization

    /// Creates a HuggingFace provider with the specified configuration.
    ///
    /// - Parameters:
    ///   - configuration: HuggingFace configuration settings. Defaults to `.default`.
    ///   - defaultImageModel: Default model for image generation. Defaults to Stable Diffusion 3.
    ///
    /// ## Example
    /// ```swift
    /// // Use default configuration with auto token detection
    /// let provider = HuggingFaceProvider()
    ///
    /// // Use custom configuration
    /// let provider = HuggingFaceProvider(
    ///     configuration: .default.timeout(120).maxRetries(5)
    /// )
    ///
    /// // Use custom image model
    /// let provider = HuggingFaceProvider(
    ///     defaultImageModel: "stabilityai/stable-diffusion-xl-base-1.0"
    /// )
    /// ```
    public init(
        configuration: HFConfiguration = .default,
        defaultImageModel: String = "stabilityai/stable-diffusion-3"
    ) {
        self.configuration = configuration
        self.client = HFInferenceClient(configuration: configuration)
        self.defaultImageModel = defaultImageModel
    }

    /// Creates a HuggingFace provider with an explicit API token.
    ///
    /// Convenience initializer for providing a static token.
    ///
    /// - Parameters:
    ///   - token: HuggingFace API token (starts with "hf_").
    ///   - defaultImageModel: Default model for image generation. Defaults to Stable Diffusion 3.
    ///
    /// ## Example
    /// ```swift
    /// let provider = HuggingFaceProvider(token: "hf_...")
    ///
    /// // With custom image model
    /// let provider = HuggingFaceProvider(
    ///     token: "hf_...",
    ///     defaultImageModel: "stabilityai/stable-diffusion-xl-base-1.0"
    /// )
    /// ```
    ///
    /// - Warning: Do not hardcode tokens in source code. Load from secure storage.
    public init(
        token: String,
        defaultImageModel: String = "stabilityai/stable-diffusion-3"
    ) {
        let config = HFConfiguration.default.token(.static(token))
        self.configuration = config
        self.client = HFInferenceClient(configuration: config)
        self.defaultImageModel = defaultImageModel
    }

    // MARK: - AIProvider: Availability

    /// Whether HuggingFace is available for inference.
    ///
    /// Returns `true` if an API token is configured.
    public var isAvailable: Bool {
        get async {
            configuration.hasToken
        }
    }

    /// Detailed availability status for HuggingFace.
    ///
    /// Checks token configuration and network requirements.
    public var availabilityStatus: ProviderAvailability {
        get async {
            guard configuration.hasToken else {
                return .unavailable(.apiKeyMissing)
            }

            return .available
        }
    }

    // MARK: - AIProvider: Generation

    /// Generates a complete response for the given messages.
    ///
    /// Performs non-streaming text generation via HuggingFace Inference API.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.huggingFace()` model.
    ///   - config: Generation configuration controlling sampling and limits.
    /// - Returns: Complete generation result with metadata.
    /// - Throws: `AIError` if generation fails.
    public func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        // Validate model type
        guard case .huggingFace(let modelId) = model else {
            throw AIError.invalidInput("HuggingFaceProvider only supports .huggingFace() models")
        }

        // Reset cancellation flag
        isCancelled = false

        // Convert messages to HF format
        let hfMessages = messages.map { HFMessage(from: $0) }

        // Track timing
        let startTime = Date()

        // Perform chat completion
        let response = try await client.chatCompletion(
            model: modelId,
            messages: hfMessages,
            config: config
        )

        // Extract result
        guard let choice = response.choices.first else {
            throw AIError.generationFailed(underlying: SendableError(localizedDescription: "No choices in response"))
        }

        guard let message = choice.message else {
            throw AIError.generationFailed(underlying: SendableError(localizedDescription: "No message in choice"))
        }

        // Calculate metrics
        let duration = Date().timeIntervalSince(startTime)
        let tokenCount = response.usage?.completion_tokens ?? 0
        let tokensPerSecond = duration > 0 ? Double(tokenCount) / duration : 0

        // Map finish reason
        let finishReason = mapFinishReason(choice.finish_reason)

        // Convert usage stats
        let usage: UsageStats? = response.usage.map {
            UsageStats(
                promptTokens: $0.prompt_tokens,
                completionTokens: $0.completion_tokens
            )
        }

        return GenerationResult(
            text: message.content,
            tokenCount: tokenCount,
            generationTime: duration,
            tokensPerSecond: tokensPerSecond,
            finishReason: finishReason,
            usage: usage
        )
    }

    /// Streams generation tokens as they are produced.
    ///
    /// Returns an async stream that yields chunks incrementally during generation.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.huggingFace()` model.
    ///   - config: Generation configuration controlling sampling and limits.
    /// - Returns: Async throwing stream of generation chunks.
    ///
    /// ## Note
    /// This method is `nonisolated` because it returns synchronously. The actual
    /// generation work happens asynchronously when the stream is iterated.
    public nonisolated func stream(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performStreamingGeneration(
                    messages: messages,
                    model: model,
                    config: config,
                    continuation: continuation
                )
            }
        }
    }

    /// Cancels any in-flight generation request.
    ///
    /// Cancels both text and image generation tasks. For text generation,
    /// sets the cancellation flag to stop at the next opportunity. For image
    /// generation, cancels the HTTP request.
    ///
    /// ## Behavior
    ///
    /// - For text generation: Sets cancellation flag checked during streaming
    /// - For image generation: Cancels the current HTTP request
    /// - Cleans up task references
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = HuggingFaceProvider()
    ///
    /// let task = Task {
    ///     try await provider.generate("Write a long story...", model: .llama3_1_8B)
    /// }
    ///
    /// // Cancel after 5 seconds
    /// try await Task.sleep(for: .seconds(5))
    /// await provider.cancelGeneration()
    /// ```
    public func cancelGeneration() async {
        // Set cancellation flag for text generation
        isCancelled = true

        // Cancel any ongoing image generation
        currentImageTask?.cancel()
        currentImageTask = nil
    }

    // MARK: - TextGenerator

    /// Generates text from a simple string prompt.
    ///
    /// Convenience method that wraps the prompt in a user message.
    ///
    /// - Parameters:
    ///   - prompt: Input text to generate a response for.
    ///   - model: Model identifier. Must be a `.huggingFace()` model.
    ///   - config: Generation configuration.
    /// - Returns: Generated text as a string.
    /// - Throws: `AIError` if generation fails.
    public func generate(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) async throws -> String {
        let messages = [Message.user(prompt)]
        let result = try await generate(messages: messages, model: model, config: config)
        return result.text
    }

    /// Streams text generation from a simple prompt.
    ///
    /// - Parameters:
    ///   - prompt: Input text to generate a response for.
    ///   - model: Model identifier. Must be a `.huggingFace()` model.
    ///   - config: Generation configuration.
    /// - Returns: Async throwing stream of text strings.
    public nonisolated func stream(
        _ prompt: String,
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        let messages = [Message.user(prompt)]
        let chunkStream = stream(messages: messages, model: model, config: config)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in chunkStream {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Streams generation with full chunk metadata.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.huggingFace()` model.
    ///   - config: Generation configuration.
    /// - Returns: Async throwing stream of generation chunks.
    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        stream(messages: messages, model: model, config: config)
    }

    // MARK: - EmbeddingGenerator

    /// Generates an embedding vector for the given text.
    ///
    /// - Parameters:
    ///   - text: Input text to embed.
    ///   - model: Embedding model identifier. Must be a `.huggingFace()` model.
    /// - Returns: Embedding result with vector and metadata.
    /// - Throws: `AIError` if embedding fails.
    public func embed(
        _ text: String,
        model: ModelID
    ) async throws -> EmbeddingResult {
        // Validate model type
        guard case .huggingFace(let modelId) = model else {
            throw AIError.invalidInput("HuggingFaceProvider only supports .huggingFace() models")
        }

        // Call feature extraction
        let embeddings = try await client.featureExtraction(
            model: modelId,
            inputs: [text]
        )

        // Extract first embedding
        guard let embedding = embeddings.first else {
            throw AIError.generationFailed(underlying: SendableError(localizedDescription: "No embedding returned"))
        }

        return EmbeddingResult(
            vector: embedding,
            text: text,
            model: modelId
        )
    }

    /// Generates embeddings for multiple texts in a batch.
    ///
    /// - Parameters:
    ///   - texts: Array of texts to embed.
    ///   - model: Embedding model identifier. Must be a `.huggingFace()` model.
    /// - Returns: Array of embedding results, one per input text.
    /// - Throws: `AIError` if batch embedding fails.
    public func embedBatch(
        _ texts: [String],
        model: ModelID
    ) async throws -> [EmbeddingResult] {
        // Validate model type
        guard case .huggingFace(let modelId) = model else {
            throw AIError.invalidInput("HuggingFaceProvider only supports .huggingFace() models")
        }

        // Call feature extraction with batch
        let embeddings = try await client.featureExtraction(
            model: modelId,
            inputs: texts
        )

        // Convert to results
        return zip(texts, embeddings).map { text, embedding in
            EmbeddingResult(
                vector: embedding,
                text: text,
                model: modelId
            )
        }
    }

    // MARK: - Transcriber

    /// Transcribes audio from a file URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe.
    ///   - model: Transcription model identifier. Must be a `.huggingFace()` model.
    ///   - config: Transcription configuration.
    /// - Returns: Transcription result with text and segments.
    /// - Throws: `AIError` if transcription fails.
    public func transcribe(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult {
        // Load audio data
        let data = try Data(contentsOf: url)
        return try await transcribe(audioData: data, model: model, config: config)
    }

    /// Transcribes audio from raw data.
    ///
    /// - Parameters:
    ///   - data: Raw audio data.
    ///   - model: Transcription model identifier. Must be a `.huggingFace()` model.
    ///   - config: Transcription configuration.
    /// - Returns: Transcription result with text and segments.
    /// - Throws: `AIError` if transcription fails.
    public func transcribe(
        audioData data: Data,
        model: ModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult {
        // Validate model type
        guard case .huggingFace(let modelId) = model else {
            throw AIError.invalidInput("HuggingFaceProvider only supports .huggingFace() models")
        }

        // Track timing
        let startTime = Date()

        // Perform ASR
        let response = try await client.automaticSpeechRecognition(
            model: modelId,
            audioData: data,
            config: config
        )

        // Calculate duration
        let processingTime = Date().timeIntervalSince(startTime)

        // Convert chunks to segments
        let segments: [TranscriptionSegment] = response.chunks?.enumerated().map { index, chunk in
            let startTime = chunk.timestamp.first ?? 0.0
            let endTime = chunk.timestamp.count > 1 ? chunk.timestamp[1] : startTime

            return TranscriptionSegment(
                id: index,
                startTime: startTime,
                endTime: endTime,
                text: chunk.text
            )
        } ?? []

        // Calculate total audio duration (use last segment end time)
        let audioDuration = segments.last?.endTime ?? 0.0

        return TranscriptionResult(
            text: response.text,
            segments: segments,
            language: config.language,
            duration: audioDuration,
            processingTime: processingTime
        )
    }

    /// Streams transcription results as they become available.
    ///
    /// HuggingFace Inference API does not support streaming transcription.
    /// This method falls back to calling `transcribe()` and yielding all segments.
    ///
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe.
    ///   - model: Transcription model identifier. Must be a `.huggingFace()` model.
    ///   - config: Transcription configuration.
    /// - Returns: Async throwing stream of transcription segments.
    public nonisolated func streamTranscription(
        audioURL url: URL,
        model: ModelID,
        config: TranscriptionConfig
    ) -> AsyncThrowingStream<TranscriptionSegment, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // HF doesn't support streaming transcription, so we fallback
                    // to full transcription and yield all segments
                    let result = try await self.transcribe(
                        audioURL: url,
                        model: model,
                        config: config
                    )

                    // Yield all segments
                    for segment in result.segments {
                        continuation.yield(segment)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Image Generation

    /// Generates an image from a text prompt.
    ///
    /// Uses HuggingFace's text-to-image models like Stable Diffusion to create
    /// images from natural language descriptions.
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image.
    ///   - model: Model identifier. Must be a `.huggingFace()` model. If not provided, uses `defaultImageModel`.
    ///   - negativePrompt: Optional text describing what to avoid in the image.
    ///   - config: Image generation configuration (dimensions, steps, guidance).
    /// - Returns: A `GeneratedImage` with the image data and convenience methods.
    /// - Throws: `AIError` if image generation fails.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let provider = HuggingFaceProvider()
    ///
    /// // Simple generation with default model
    /// let result = try await provider.textToImage(
    ///     "A sunset over mountains, oil painting style"
    /// )
    ///
    /// // With explicit model
    /// let result = try await provider.textToImage(
    ///     "A cat wearing a top hat, digital art",
    ///     model: .huggingFace("stabilityai/stable-diffusion-xl-base-1.0")
    /// )
    ///
    /// // With negative prompt
    /// let result = try await provider.textToImage(
    ///     "A professional portrait photograph",
    ///     negativePrompt: "blurry, low quality, distorted, cartoon",
    ///     config: .highQuality
    /// )
    ///
    /// // Display in SwiftUI
    /// if let image = result.image {
    ///     image.resizable().scaledToFit()
    /// }
    ///
    /// // Save to file
    /// try result.save(to: URL.documentsDirectory.appending(path: "sunset.png"))
    ///
    /// // Save to Photos (iOS only)
    /// try await result.saveToPhotos()
    /// ```
    ///
    /// ## Supported Models
    ///
    /// - `stabilityai/stable-diffusion-3`
    /// - `stabilityai/stable-diffusion-xl-base-1.0`
    /// - `runwayml/stable-diffusion-v1-5`
    /// - Any HuggingFace model supporting the text-to-image pipeline
    ///
    /// ## Configuration Presets
    ///
    /// | Preset | Description |
    /// |--------|-------------|
    /// | `.default` | Model defaults |
    /// | `.highQuality` | 50 steps, guidance 7.5 |
    /// | `.fast` | 20 steps for quick previews |
    /// | `.square1024` | 1024x1024 high resolution |
    public func textToImage(
        _ prompt: String,
        model: ModelID? = nil,
        negativePrompt: String? = nil,
        config: ImageGenerationConfig = .default
    ) async throws -> GeneratedImage {
        // Resolve model ID
        let modelId: String
        if let model = model {
            // Validate model type
            guard case .huggingFace(let id) = model else {
                throw AIError.invalidInput("HuggingFaceProvider only supports .huggingFace() models for text-to-image")
            }
            modelId = id
        } else {
            // Use default image model
            modelId = defaultImageModel
        }

        // Convert to HuggingFace-specific parameters if any are set
        let parameters: HFImageParameters? = (config.hasParameters || negativePrompt != nil)
            ? HFImageParameters(from: config, negativePrompt: negativePrompt)
            : nil

        // Delegate to internal client
        return try await client.textToImage(
            model: modelId,
            prompt: prompt,
            negativePrompt: negativePrompt,
            parameters: parameters
        )
    }
}

// MARK: - Private Implementation

extension HuggingFaceProvider {

    /// Performs streaming generation using HuggingFace's SSE API.
    ///
    /// Uses the client's streaming chat completion endpoint and converts
    /// server-sent events to GenerationChunk instances.
    private func performStreamingGeneration(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig,
        continuation: AsyncThrowingStream<GenerationChunk, Error>.Continuation
    ) async {
        do {
            guard case .huggingFace(let modelId) = model else {
                continuation.finish(throwing: AIError.invalidInput("HuggingFaceProvider only supports .huggingFace() models"))
                return
            }

            // Reset cancellation flag
            isCancelled = false

            // Convert messages to HF format
            let hfMessages = messages.map { HFMessage(from: $0) }

            // Track timing
            let startTime = Date()
            var totalTokens = 0
            var fullText = ""

            // Stream chat completion
            let stream = await client.streamChatCompletion(
                model: modelId,
                messages: hfMessages,
                config: config
            )

            for try await response in stream {
                // Check cancellation
                if Task.isCancelled || isCancelled {
                    let finalChunk = GenerationChunk.completion(finishReason: .cancelled)
                    continuation.yield(finalChunk)
                    continuation.finish()
                    return
                }

                // Extract delta content
                guard let choice = response.choices.first else {
                    continue
                }

                // Handle streaming delta
                if let delta = choice.delta, let content = delta.content {
                    totalTokens += 1
                    fullText += content

                    // Calculate current throughput
                    let elapsed = Date().timeIntervalSince(startTime)
                    let tokensPerSecond = elapsed > 0 ? Double(totalTokens) / elapsed : 0

                    // Yield chunk
                    let chunk = GenerationChunk(
                        text: content,
                        tokenCount: 1,
                        tokensPerSecond: tokensPerSecond,
                        isComplete: false
                    )
                    continuation.yield(chunk)
                }

                // Handle finish reason
                if let finishReasonStr = choice.finish_reason {
                    let finishReason = mapFinishReason(finishReasonStr)
                    let finalChunk = GenerationChunk.completion(finishReason: finishReason)
                    continuation.yield(finalChunk)
                    continuation.finish()
                    return
                }
            }

            // If we reach here without a finish reason, assume stop
            let finalChunk = GenerationChunk.completion(finishReason: .stop)
            continuation.yield(finalChunk)
            continuation.finish()

        } catch {
            continuation.finish(throwing: AIError.generationFailed(underlying: SendableError(error)))
        }
    }

    /// Maps HuggingFace finish reasons to SwiftAI finish reasons.
    ///
    /// - Parameter reason: The HuggingFace finish reason string.
    /// - Returns: The corresponding `FinishReason` case.
    private func mapFinishReason(_ reason: String?) -> FinishReason {
        guard let reason = reason else {
            return .stop
        }

        switch reason.lowercased() {
        case "stop", "eos_token", "end_of_sequence":
            return .stop
        case "length", "max_tokens":
            return .maxTokens
        case "content_filter":
            return .contentFilter
        default:
            return .stop
        }
    }
}

// MARK: - ImageGenerator Conformance

extension HuggingFaceProvider: ImageGenerator {

    /// Generates an image using HuggingFace's cloud API.
    ///
    /// This is a convenience wrapper around `textToImage()` that conforms
    /// to the `ImageGenerator` protocol for unified usage across providers.
    ///
    /// ## Cloud-Based Progress
    ///
    /// Cloud-based image generation happens server-side, so true progress tracking
    /// is not available. The `onProgress` callback will be invoked twice:
    /// - Once at the start (progress: 0%)
    /// - Once upon completion (progress: 100%)
    ///
    /// For real-time progress updates, use a local provider like `MLXImageProvider`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let provider = HuggingFaceProvider()
    ///
    /// // Using ImageGenerator protocol
    /// let image = try await provider.generateImage(
    ///     prompt: "A sunset over mountains",
    ///     config: .highQuality
    /// )
    ///
    /// // With negative prompt
    /// let image = try await provider.generateImage(
    ///     prompt: "A professional portrait",
    ///     negativePrompt: "blurry, low quality",
    ///     config: .square1024
    /// )
    ///
    /// // With synthetic progress tracking
    /// let image = try await provider.generateImage(
    ///     prompt: "A futuristic cityscape",
    ///     config: .highQuality
    /// ) { progress in
    ///     print("Progress: \(progress.percentComplete)%")
    ///     // Will print: "Progress: 0%" then "Progress: 100%"
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image.
    ///   - negativePrompt: Optional text describing what to avoid.
    ///     Supported by most Stable Diffusion models on HuggingFace.
    ///   - config: Image generation configuration.
    ///   - onProgress: Progress callback. Receives synthetic progress updates
    ///     (start and completion only) since cloud generation doesn't support
    ///     step-by-step progress.
    /// - Returns: The generated image.
    /// - Throws: `AIError` if generation fails.
    public func generateImage(
        prompt: String,
        negativePrompt: String?,
        config: ImageGenerationConfig,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)?
    ) async throws -> GeneratedImage {
        // Report initial progress if callback provided
        if let onProgress = onProgress {
            let startProgress = ImageGenerationProgress(
                currentStep: 0,
                totalSteps: config.steps ?? 30
            )
            onProgress(startProgress)
        }

        // Create a cancellable task for image generation
        let task = Task<GeneratedImage, Error> {
            try await textToImage(
                prompt,
                model: nil, // Use default image model
                negativePrompt: negativePrompt,
                config: config
            )
        }

        // Store for cancellation support
        currentImageTask = task

        do {
            // Wait for generation to complete
            let image = try await task.value

            // Clear the task reference
            currentImageTask = nil

            // Report completion progress if callback provided
            if let onProgress = onProgress {
                let completionProgress = ImageGenerationProgress(
                    currentStep: config.steps ?? 30,
                    totalSteps: config.steps ?? 30
                )
                onProgress(completionProgress)
            }

            return image

        } catch {
            // Clear the task reference on error
            currentImageTask = nil
            throw error
        }
    }
}

