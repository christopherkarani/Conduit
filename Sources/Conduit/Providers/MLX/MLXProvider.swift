// MLXProvider.swift
// Conduit

#if CONDUIT_TRAIT_MLX
import Foundation

// MARK: - Linux Compatibility
// NOTE: MLX requires Metal GPU and Apple Silicon. Not available on Linux.
#if canImport(MLX)

@preconcurrency import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXLLM
// Note: Tokenizer protocol is re-exported through MLXLMCommon

// MARK: - MLXProvider

/// Local inference provider using MLX on Apple Silicon.
///
/// `MLXProvider` runs language models entirely on-device using Apple's MLX framework.
/// It provides high-performance inference with complete privacy and offline capability.
///
/// ## Apple Silicon Required
///
/// MLX requires Apple Silicon (M1 or later). On Intel Macs or other platforms,
/// this provider will be unavailable.
///
/// ## Usage
///
/// ### Basic Generation
/// ```swift
/// let provider = MLXProvider()
/// let response = try await provider.generate(
///     "What is Swift?",
///     model: .llama3_2_1b,
///     config: .default
/// )
/// print(response)
/// ```
///
/// ### Streaming
/// ```swift
/// let stream = provider.stream(
///     "Write a poem",
///     model: .llama3_2_1b,
///     config: .default
/// )
/// for try await text in stream {
///     print(text, terminator: "")
/// }
/// ```
///
/// ### Token Counting
/// ```swift
/// let count = try await provider.countTokens(in: "Hello", for: .llama3_2_1b)
/// print("Tokens: \(count.count)")
/// ```
///
/// ## Protocol Conformances
/// - `AIProvider`: Core generation and streaming
/// - `TextGenerator`: Text-specific conveniences
/// - `TokenCounter`: Token counting and encoding
///
/// ## Thread Safety
/// As an actor, `MLXProvider` is thread-safe and serializes all operations.
public actor MLXProvider: AIProvider, TextGenerator, TokenCounter {

    // MARK: - Associated Types

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    // MARK: - Properties

    /// Configuration for MLX inference.
    public let configuration: MLXConfiguration

    /// Model loader for managing loaded models.
    private let modelLoader: MLXModelLoader

    /// Flag for cancellation support.
    private var isCancelled: Bool = false

    /// Tracks whether runtime configuration has been applied.
    private var didApplyRuntimeConfiguration: Bool = false

    /// Bounded runtime diagnostics for capability/fallback telemetry.
    private var runtimeDiagnosticsEvents: [ProviderRuntimeDiagnosticsEvent] = []
    private let runtimeDiagnosticsLimit = 512

    // MARK: - Initialization

    /// Creates an MLX provider with the specified configuration.
    ///
    /// - Parameter configuration: MLX configuration settings. Defaults to `.default`.
    ///
    /// ## Example
    /// ```swift
    /// // Use default configuration
    /// let provider = MLXProvider()
    ///
    /// // Use memory-efficient configuration
    /// let provider = MLXProvider(configuration: .memoryEfficient)
    ///
    /// // Custom configuration
    /// let provider = MLXProvider(
    ///     configuration: .default.memoryLimit(.gigabytes(8))
    /// )
    /// ```
    public init(configuration: MLXConfiguration = .default) {
        self.configuration = configuration
        self.modelLoader = MLXModelLoader(configuration: configuration)
    }

    // MARK: - AIProvider: Availability

    /// Whether MLX is available on this device.
    ///
    /// Returns `true` only on Apple Silicon (arm64) devices.
    public var isAvailable: Bool {
        get async {
            #if arch(arm64)
            return true
            #else
            return false
            #endif
        }
    }

    /// Detailed availability status for MLX.
    ///
    /// Checks device architecture and system requirements.
    public var availabilityStatus: ProviderAvailability {
        get async {
            #if arch(arm64)
            return .available
            #else
            return .unavailable(.deviceNotSupported)
            #endif
        }
    }

    // MARK: - AIProvider: Generation

    /// Generates a complete response for the given messages.
    ///
    /// Performs non-streaming text generation and waits for the entire response
    /// before returning.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.mlx()` model.
    ///   - config: Generation configuration controlling sampling and limits.
    /// - Returns: Complete generation result with metadata.
    /// - Throws: `AIError` if generation fails.
    public func generate(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        #if arch(arm64)
        // Validate model type
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Reset cancellation flag
        isCancelled = false

        // Perform generation
        return try await performGeneration(messages: messages, model: model, config: config)
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Streams generation tokens as they are produced.
    ///
    /// Returns an async stream that yields chunks incrementally during generation.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.mlx()` model.
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
            let task = Task {
                await self.performStreamingGeneration(
                    messages: messages,
                    model: model,
                    config: config,
                    continuation: continuation
                )
            }

            continuation.onTermination = { @Sendable termination in
                task.cancel()
                Task {
                    await self.cancelGeneration()
                }

                // Ensure continuation is finished when stream is cancelled
                // This prevents resource leaks when cancellation happens
                // before the streaming loop begins
                if case .cancelled = termination {
                    let finalChunk = GenerationChunk.completion(finishReason: .cancelled)
                    continuation.yield(finalChunk)
                    continuation.finish()
                }
            }
        }
    }

    /// Cancels any in-flight generation request.
    ///
    /// Sets the cancellation flag to stop generation at the next opportunity.
    public func cancelGeneration() async {
        isCancelled = true
    }

    // MARK: - Model Capabilities

    /// Returns the capabilities of the currently loaded model.
    ///
    /// This method queries the cached capabilities of a loaded model without
    /// triggering a load operation. If the model is not loaded, it returns `nil`.
    ///
    /// To detect capabilities without loading a model, use `VLMDetector.shared.detectCapabilities()`.
    ///
    /// - Parameter model: The model identifier to query.
    /// - Returns: The model's capabilities if loaded, `nil` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// let provider = MLXProvider()
    /// let model = ModelIdentifier.mlx("mlx-community/llava-1.5-7b-4bit")
    ///
    /// // After loading via generate() or stream()
    /// if let capabilities = await provider.getModelCapabilities(model) {
    ///     if capabilities.supportsVision {
    ///         print("VLM architecture: \(capabilities.architectureType?.rawValue ?? "unknown")")
    ///     }
    /// }
    /// ```
    public func getModelCapabilities(_ model: ModelID) async -> ModelCapabilities? {
        return await modelLoader.getCapabilities(model)
    }

    /// Detects the capabilities of a model without loading it.
    ///
    /// This method uses VLMDetector to analyze the model and determine its
    /// capabilities through metadata, config inspection, or name heuristics.
    /// This is useful for capability checking before loading a model.
    ///
    /// - Parameter model: The model identifier to detect.
    /// - Returns: The detected model capabilities.
    ///
    /// ## Example
    /// ```swift
    /// let provider = MLXProvider()
    /// let model = ModelIdentifier.mlx("mlx-community/pixtral-12b-4bit")
    ///
    /// // Detect before loading
    /// let capabilities = await provider.detectCapabilities(model)
    /// if capabilities.supportsVision {
    ///     print("This model supports vision inputs")
    ///     // Prepare image inputs...
    /// }
    ///
    /// // Then generate
    /// let result = try await provider.generate(messages, model: model, config: .default)
    /// ```
    public func detectCapabilities(_ model: ModelID) async -> ModelCapabilities {
        return await VLMDetector.shared.detectCapabilities(model)
    }

    // MARK: - Runtime Feature Capabilities

    /// Returns runtime feature capabilities for the given model.
    ///
    /// These capabilities represent provider/runtime-owned features (post-v1).
    public func runtimeCapabilities(for model: ModelID) async -> ProviderRuntimeCapabilities {
        let quantization = ProviderRuntimeFeatureCapability(
            isSupported: true,
            supportedBits: [4, 8]
        )

        // MLX high-level ChatSession does not currently expose deterministic low-level
        // controls required for these runtime features.
        let unsupportedReason = "not_exposed_by_mlx_chatsession_runtime"

        return ProviderRuntimeCapabilities(
            kvQuantization: quantization,
            attentionSinks: ProviderRuntimeFeatureCapability(
                isSupported: false,
                reasonUnavailable: unsupportedReason
            ),
            kvSwap: ProviderRuntimeFeatureCapability(
                isSupported: false,
                reasonUnavailable: unsupportedReason
            ),
            incrementalPrefill: ProviderRuntimeFeatureCapability(
                isSupported: false,
                reasonUnavailable: unsupportedReason
            ),
            speculativeScheduling: ProviderRuntimeFeatureCapability(
                isSupported: false,
                supportsVerifierRollback: false,
                reasonUnavailable: unsupportedReason
            )
        )
    }

    /// Snapshot current runtime diagnostics.
    public func runtimeDiagnosticsSnapshot() -> [ProviderRuntimeDiagnosticsEvent] {
        runtimeDiagnosticsEvents
    }

    /// Clears buffered runtime diagnostics.
    public func clearRuntimeDiagnostics() {
        runtimeDiagnosticsEvents.removeAll(keepingCapacity: false)
    }

    // MARK: - Cache Management

    /// Returns statistics about the model cache.
    ///
    /// Provides insights into memory usage, cached models, and current active model.
    ///
    /// - Returns: Cache statistics structure.
    ///
    /// ## Example
    /// ```swift
    /// let provider = MLXProvider()
    /// let stats = await provider.cacheStats()
    /// print("Cached models: \(stats.cachedModelCount)")
    /// print("Memory usage: \(stats.totalMemoryUsage)")
    /// if let current = stats.currentModelId {
    ///     print("Current model: \(current)")
    /// }
    /// ```
    public func cacheStats() async -> CacheStats {
        return await MLXModelCache.shared.cacheStats()
    }

    /// Evicts a specific model from the cache.
    ///
    /// Removes the model from memory, freeing up resources. The model
    /// files remain on disk and can be reloaded when needed.
    ///
    /// - Parameter model: The model identifier to evict.
    ///
    /// ## Example
    /// ```swift
    /// let provider = MLXProvider()
    /// let model = ModelIdentifier.mlx("mlx-community/llama-3.2-1B-4bit")
    ///
    /// // After using the model
    /// await provider.evictModel(model)
    /// ```
    public func evictModel(_ model: ModelID) async {
        guard case .mlx(let modelId) = model else { return }
        await MLXModelCache.shared.remove(modelId)
    }

    /// Clears all cached models from memory.
    ///
    /// Removes all loaded models from the cache, freeing memory.
    /// Model files remain on disk and can be reloaded when needed.
    ///
    /// ## Example
    /// ```swift
    /// let provider = MLXProvider()
    ///
    /// // Clear all cached models to free memory
    /// await provider.clearCache()
    /// ```
    public func clearCache() async {
        await MLXModelCache.shared.removeAll()
    }

    // MARK: - Model Warmup

    /// Warms up the model for optimal first-token latency.
    ///
    /// Performs a minimal generation to trigger critical one-time operations:
    /// - **Model Loading**: Downloads and loads model weights if not cached
    /// - **Metal Shader Compilation**: JIT-compiles GPU kernels (first-call overhead)
    /// - **Attention Cache Initialization**: Allocates KV cache buffers
    /// - **Unified Memory Setup**: Initializes memory pools for Metal operations
    ///
    /// This is especially important for MLX because Metal shaders are compiled
    /// just-in-time on first use, which can add 1-3 seconds of latency. After
    /// warmup, subsequent generation calls will have much lower first-token latency.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider()
    /// let model = ModelIdentifier.llama3_2_1b
    ///
    /// // Warm up before first user request
    /// try await provider.warmUp(model: model)
    ///
    /// // Now first-token latency is optimized
    /// let response = try await provider.generate("Hello", model: model, config: .default)
    /// ```
    ///
    /// ## Performance Impact
    /// - **Without warmup**: First generation ~2-4 seconds (includes shader compilation)
    /// - **With warmup**: First generation ~100-300ms (shaders already compiled)
    /// - **Warmup duration**: Typically 1-2 seconds
    ///
    /// - Parameters:
    ///   - model: The model to warm up. Must be a `.mlx()` model.
    ///   - prefillChars: Number of characters in warmup prompt. Controls attention cache size. Default: 50.
    ///   - maxTokens: Maximum tokens to generate during warmup. Default: 5.
    ///   - keepLoaded: Whether to keep model loaded after warmup. Default: true.
    ///
    /// - Throws: `AIError` if warmup fails (e.g., model download fails, out of memory).
    ///
    /// ## Example: Application Startup
    /// ```swift
    /// // During app launch
    /// Task {
    ///     let provider = MLXProvider()
    ///     try? await provider.warmUp(model: .llama3_2_1b)
    /// }
    ///
    /// // Later, when user makes first request
    /// let response = try await provider.generate(...) // Fast!
    /// ```
    ///
    /// - Note: If the model is already loaded and warm, this operation completes quickly
    ///   as a no-op. It's safe to call multiple times.
    public func warmUp(
        model: ModelID,
        prefillChars: Int = 50,
        maxTokens: Int = 5,
        keepLoaded: Bool = true
    ) async throws {
        #if arch(arm64)
        // Validate model type
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Create warmup prompt with specified length
        // Use repeating pattern that's representative of real text
        let basePattern = "The quick brown fox. "
        let repeatCount = max(1, prefillChars / basePattern.count)
        let prefillText = String(repeating: basePattern, count: repeatCount).prefix(prefillChars)

        // Create minimal config for warmup
        // Temperature 0 ensures deterministic, fast generation
        let warmupConfig = GenerateConfig(
            maxTokens: maxTokens,
            temperature: 0.0,
            topP: 1.0
        )

        // Perform minimal generation to trigger all initialization
        _ = try await generate(String(prefillText), model: model, config: warmupConfig)

        // Optionally unload model if not keeping it loaded
        if !keepLoaded {
            await evictModel(model)
        }
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    // MARK: - TextGenerator

    /// Generates text from a simple string prompt.
    ///
    /// Convenience method that wraps the prompt in a user message.
    ///
    /// - Parameters:
    ///   - prompt: Input text to generate a response for.
    ///   - model: Model identifier. Must be a `.mlx()` model.
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
    ///   - model: Model identifier. Must be a `.mlx()` model.
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
            let task = Task {
                do {
                    for try await chunk in chunkStream {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                Task { await self.cancelGeneration() }
            }
        }
    }

    /// Streams generation with full chunk metadata.
    ///
    /// - Parameters:
    ///   - messages: Conversation history to process.
    ///   - model: Model identifier. Must be a `.mlx()` model.
    ///   - config: Generation configuration.
    /// - Returns: Async throwing stream of generation chunks.
    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        stream(messages: messages, model: model, config: config)
    }

    // MARK: - TokenCounter

    /// Counts tokens in the given text.
    ///
    /// - Parameters:
    ///   - text: Text to count tokens in.
    ///   - model: Model whose tokenizer to use.
    /// - Returns: Token count information.
    /// - Throws: `AIError` if tokenization fails.
    public func countTokens(
        in text: String,
        for model: ModelID
    ) async throws -> TokenCount {
        #if arch(arm64)
        await applyRuntimeConfigurationIfNeeded()

        // Validate model type
        guard case .mlx(let modelId) = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Encode text using model loader
        let tokens = try await modelLoader.encode(text: text, for: model)

        return TokenCount(
            count: tokens.count,
            text: text,
            tokenizer: modelId,
            tokenIds: tokens
        )
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Counts tokens in a message array, including chat template overhead.
    ///
    /// - Parameters:
    ///   - messages: Messages to count tokens in.
    ///   - model: Model whose tokenizer and chat template to use.
    /// - Returns: Token count information including special tokens.
    /// - Throws: `AIError` if tokenization fails.
    public func countTokens(
        in messages: [Message],
        for model: ModelID
    ) async throws -> TokenCount {
        #if arch(arm64)
        await applyRuntimeConfigurationIfNeeded()

        // Validate model type
        guard case .mlx(let modelId) = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Calculate prompt tokens (text content)
        // Note: This doesn't include chat template overhead.
        // For accurate counts with chat template, you'd need model-specific logic.
        var totalTokens = 0
        for message in messages {
            let text = message.content.textValue
            let tokens = try await modelLoader.encode(text: text, for: model)
            totalTokens += tokens.count
        }

        // Estimate special token overhead per message (role markers, etc.)
        // This is approximate - actual overhead varies by model
        let estimatedSpecialTokens = messages.count * 4

        return TokenCount(
            count: totalTokens + estimatedSpecialTokens,
            text: "",
            tokenizer: modelId,
            promptTokens: totalTokens,
            specialTokens: estimatedSpecialTokens
        )
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Encodes text to token IDs.
    ///
    /// - Parameters:
    ///   - text: Text to encode.
    ///   - model: Model whose tokenizer to use.
    /// - Returns: Array of token IDs.
    /// - Throws: `AIError` if encoding fails.
    public func encode(
        _ text: String,
        for model: ModelID
    ) async throws -> [Int] {
        #if arch(arm64)
        // Validate model type
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Encode text using model loader
        return try await modelLoader.encode(text: text, for: model)
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }

    /// Decodes token IDs back to text.
    ///
    /// - Parameters:
    ///   - tokens: Token IDs to decode.
    ///   - model: Model whose tokenizer to use.
    ///   - skipSpecialTokens: Whether to skip special tokens in output.
    /// - Returns: Decoded text string.
    /// - Throws: `AIError` if decoding fails.
    public func decode(
        _ tokens: [Int],
        for model: ModelID,
        skipSpecialTokens: Bool
    ) async throws -> String {
        #if arch(arm64)
        // Validate model type
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        // Decode tokens using model loader
        // Note: skipSpecialTokens is not directly supported by mlx-swift-lm
        // The tokenizer.decode() handles this automatically in most cases
        return try await modelLoader.decode(tokens: tokens, for: model)
        #else
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
        #endif
    }
}

// MARK: - Private Implementation

extension MLXProvider {

    /// Performs non-streaming generation using ChatSession.
    ///
    /// Uses the high-level ChatSession API from mlx-swift-lm for
    /// simpler and more reliable generation.
    private func performGeneration(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        guard case .mlx = model else {
            throw AIError.invalidInput("MLXProvider only supports .mlx() models")
        }

        await applyRuntimeConfigurationIfNeeded()

        // Load model container
        let container = try await modelLoader.loadModel(identifier: model)

        // Track timing
        let startTime = Date()

        // Create generation parameters
        let runtimeConfiguration = await resolveRuntimeConfiguration(
            model: model,
            generateConfig: config
        )
        let params = createGenerateParameters(
            from: config,
            mlxConfiguration: runtimeConfiguration
        )

        // Create chat session with the container and parameters
        let session = MLXLMCommon.ChatSession(container, generateParameters: params)

        // Build prompt from messages
        let prompt = buildPrompt(from: messages)

        // Generate response
        var generatedText = ""
        var tokenCount = 0

        // Use streaming internally to track token count
        for try await chunk in session.streamResponse(to: prompt) {
            // Check cancellation
            try Task.checkCancellation()
            if isCancelled {
                return GenerationResult(
                    text: generatedText,
                    tokenCount: tokenCount,
                    generationTime: Date().timeIntervalSince(startTime),
                    tokensPerSecond: 0,
                    finishReason: .cancelled
                )
            }

            generatedText += chunk
            tokenCount += 1
        }

        // Calculate metrics
        let duration = Date().timeIntervalSince(startTime)
        let tokensPerSecond = duration > 0 ? Double(tokenCount) / duration : 0

        return GenerationResult(
            text: generatedText,
            tokenCount: tokenCount,
            generationTime: duration,
            tokensPerSecond: tokensPerSecond,
            finishReason: .stop
        )
    }

    /// Performs streaming generation using ChatSession.
    ///
    /// Uses the high-level ChatSession API from mlx-swift-lm for
    /// simpler and more reliable streaming.
    private func performStreamingGeneration(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig,
        continuation: AsyncThrowingStream<GenerationChunk, Error>.Continuation
    ) async {
        do {
            guard case .mlx = model else {
                continuation.finish(throwing: AIError.invalidInput("MLXProvider only supports .mlx() models"))
                return
            }

            // Reset cancellation flag
            isCancelled = false

            await applyRuntimeConfigurationIfNeeded()

            // Load model container
            let container = try await modelLoader.loadModel(identifier: model)

            // Create generation parameters
            let runtimeConfiguration = await resolveRuntimeConfiguration(
                model: model,
                generateConfig: config
            )
            let params = createGenerateParameters(
                from: config,
                mlxConfiguration: runtimeConfiguration
            )

            // Create chat session with the container and parameters
            let session = MLXLMCommon.ChatSession(container, generateParameters: params)

            // Build prompt from messages
            let prompt = buildPrompt(from: messages)

            // Track timing
            let startTime = Date()
            var totalTokens = 0

            // Stream response
            for try await chunk in session.streamResponse(to: prompt) {
                // Check cancellation using Task.checkCancellation()
                try Task.checkCancellation()
                if isCancelled {
                    let finalChunk = GenerationChunk.completion(finishReason: .cancelled)
                    continuation.yield(finalChunk)
                    continuation.finish()
                    return
                }

                totalTokens += 1

                // Calculate current throughput
                let elapsed = Date().timeIntervalSince(startTime)
                let tokensPerSecond = elapsed > 0 ? Double(totalTokens) / elapsed : 0

                // Yield chunk
                let generationChunk = GenerationChunk(
                    text: chunk,
                    tokenCount: 1,
                    tokensPerSecond: tokensPerSecond,
                    isComplete: false
                )
                continuation.yield(generationChunk)
            }

            // Send completion chunk
            let finalChunk = GenerationChunk.completion(finishReason: .stop)
            continuation.yield(finalChunk)
            continuation.finish()

        } catch is CancellationError {
            let finalChunk = GenerationChunk.completion(finishReason: .cancelled)
            continuation.yield(finalChunk)
            continuation.finish()
        } catch {
            continuation.finish(throwing: AIError.generationFailed(underlying: SendableError(error)))
        }
    }

    /// Builds a simple prompt string from messages.
    ///
    /// ChatSession handles conversation context internally, so we pass the
    /// last user message. For multi-turn conversations, system prompts are
    /// included as context.
    private func buildPrompt(from messages: [Message]) -> String {
        // Find the system message if present
        let systemMessage = messages.first { $0.role == .system }

        // Get the last user message
        let lastUserMessage = messages.last { $0.role == .user }

        // Build the prompt
        var prompt = ""

        if let system = systemMessage {
            prompt += "System: \(system.content.textValue)\n\n"
        }

        // Include recent conversation context (excluding system which is already handled)
        let recentMessages = messages.suffix(6).filter { $0.role != .system }
        for message in recentMessages {
            let rolePrefix: String
            switch message.role {
            case .user: rolePrefix = "User"
            case .assistant: rolePrefix = "Assistant"
            case .system: continue // Filtered out above, but compiler needs this
            case .tool: rolePrefix = "Tool"
            }
            prompt += "\(rolePrefix): \(message.content.textValue)\n"
        }

        // If we only have a single user message, just return its content
        if messages.count == 1, let only = messages.first, only.role == .user {
            return only.content.textValue
        }

        return prompt.isEmpty ? (lastUserMessage?.content.textValue ?? "") : prompt
    }

    /// Converts Conduit GenerateConfig to mlx-swift-lm GenerateParameters.
    private func createGenerateParameters(
        from config: GenerateConfig,
        mlxConfiguration: MLXConfiguration
    ) -> GenerateParameters {
        MLXGenerateParametersBuilder().make(
            mlxConfiguration: mlxConfiguration,
            generateConfig: config
        )
    }

    private func resolveRuntimeConfiguration(
        model: ModelIdentifier,
        generateConfig: GenerateConfig
    ) async -> MLXConfiguration {
        var effectiveRuntimeFeatures = generateConfig.runtimeFeatures ?? .init()
        let capabilities = await runtimeCapabilities(for: model)
        let policy = configuration.runtimePolicy.applying(overrides: generateConfig.runtimePolicyOverride)
        let modelID = model.rawValue

        var effectiveConfiguration = configuration.applying(runtimeFeatures: effectiveRuntimeFeatures)

        if effectiveConfiguration.useQuantizedKVCache {
            let feature: ProviderRuntimeFeature = .kvQuantization
            let requestedBits = max(4, min(8, effectiveConfiguration.kvQuantizationBits))

            guard policy.isEnabled(feature: feature) else {
                effectiveConfiguration.useQuantizedKVCache = false
                effectiveRuntimeFeatures.kvQuantization.enabled = false
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .capabilityDenied,
                    modelID: modelID,
                    reason: "policyDisabled",
                    details: ["requested_bits": String(requestedBits)]
                )
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .fallbackUsed,
                    modelID: modelID,
                    reason: "fallbackToUnquantizedKV",
                    details: [:]
                )
                return effectiveConfiguration
            }

            guard policy.isModelAllowed(feature: feature, modelID: modelID) else {
                effectiveConfiguration.useQuantizedKVCache = false
                effectiveRuntimeFeatures.kvQuantization.enabled = false
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .capabilityDenied,
                    modelID: modelID,
                    reason: "modelNotAllowlisted",
                    details: ["requested_bits": String(requestedBits)]
                )
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .fallbackUsed,
                    modelID: modelID,
                    reason: "fallbackToUnquantizedKV",
                    details: [:]
                )
                return effectiveConfiguration
            }

            guard capabilities.kvQuantization.isSupported else {
                effectiveConfiguration.useQuantizedKVCache = false
                effectiveRuntimeFeatures.kvQuantization.enabled = false
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .capabilityDenied,
                    modelID: modelID,
                    reason: capabilities.kvQuantization.reasonUnavailable ?? "runtimeUnsupported",
                    details: ["requested_bits": String(requestedBits)]
                )
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .fallbackUsed,
                    modelID: modelID,
                    reason: "fallbackToUnquantizedKV",
                    details: [:]
                )
                return effectiveConfiguration
            }

            if !capabilities.kvQuantization.supportedBits.contains(requestedBits) {
                effectiveConfiguration.useQuantizedKVCache = false
                effectiveRuntimeFeatures.kvQuantization.enabled = false
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .capabilityDenied,
                    modelID: modelID,
                    reason: "unsupportedBitDepth",
                    details: [
                        "requested_bits": String(requestedBits),
                        "supported_bits": capabilities.kvQuantization.supportedBits.map(String.init).joined(separator: ","),
                    ]
                )
                recordRuntimeDiagnostic(
                    feature: feature,
                    kind: .fallbackUsed,
                    modelID: modelID,
                    reason: "fallbackToUnquantizedKV",
                    details: [:]
                )
                return effectiveConfiguration
            }

            recordRuntimeDiagnostic(
                feature: feature,
                kind: .capabilitySelected,
                modelID: modelID,
                reason: nil,
                details: [
                    "effective_bits": String(requestedBits),
                    "source": generateConfig.runtimeFeatures == nil ? "providerConfiguration" : "runtimeOverride",
                ]
            )
        }

        evaluateUnsupportedFeature(
            .attentionSinks,
            enabled: effectiveRuntimeFeatures.attentionSinks.enabled == true,
            capability: capabilities.attentionSinks,
            modelID: modelID,
            policy: policy
        )
        evaluateUnsupportedFeature(
            .kvSwap,
            enabled: effectiveRuntimeFeatures.kvSwap.enabled == true,
            capability: capabilities.kvSwap,
            modelID: modelID,
            policy: policy
        )
        evaluateUnsupportedFeature(
            .incrementalPrefill,
            enabled: effectiveRuntimeFeatures.incrementalPrefill.enabled == true,
            capability: capabilities.incrementalPrefill,
            modelID: modelID,
            policy: policy
        )
        evaluateUnsupportedFeature(
            .speculativeScheduling,
            enabled: effectiveRuntimeFeatures.speculativeScheduling.enabled == true,
            capability: capabilities.speculativeScheduling,
            modelID: modelID,
            policy: policy
        )

        return effectiveConfiguration
    }

    private func evaluateUnsupportedFeature(
        _ feature: ProviderRuntimeFeature,
        enabled: Bool,
        capability: ProviderRuntimeFeatureCapability,
        modelID: String,
        policy: ProviderRuntimePolicy
    ) {
        guard enabled else { return }

        if !policy.isEnabled(feature: feature) {
            recordRuntimeDiagnostic(
                feature: feature,
                kind: .capabilityDenied,
                modelID: modelID,
                reason: "policyDisabled",
                details: [:]
            )
            recordRuntimeDiagnostic(
                feature: feature,
                kind: .fallbackUsed,
                modelID: modelID,
                reason: "fallbackToBaseline",
                details: [:]
            )
            return
        }

        if !policy.isModelAllowed(feature: feature, modelID: modelID) {
            recordRuntimeDiagnostic(
                feature: feature,
                kind: .capabilityDenied,
                modelID: modelID,
                reason: "modelNotAllowlisted",
                details: [:]
            )
            recordRuntimeDiagnostic(
                feature: feature,
                kind: .fallbackUsed,
                modelID: modelID,
                reason: "fallbackToBaseline",
                details: [:]
            )
            return
        }

        if !capability.isSupported {
            recordRuntimeDiagnostic(
                feature: feature,
                kind: .capabilityDenied,
                modelID: modelID,
                reason: capability.reasonUnavailable ?? "runtimeUnsupported",
                details: [:]
            )
            recordRuntimeDiagnostic(
                feature: feature,
                kind: .fallbackUsed,
                modelID: modelID,
                reason: "fallbackToBaseline",
                details: [:]
            )
        } else {
            recordRuntimeDiagnostic(
                feature: feature,
                kind: .capabilitySelected,
                modelID: modelID,
                reason: nil,
                details: [:]
            )
        }
    }

    private func recordRuntimeDiagnostic(
        feature: ProviderRuntimeFeature,
        kind: ProviderRuntimeDiagnosticsEventKind,
        modelID: String,
        reason: String?,
        details: [String: String]
    ) {
        runtimeDiagnosticsEvents.append(
            ProviderRuntimeDiagnosticsEvent(
                feature: feature,
                kind: kind,
                modelID: modelID,
                reason: reason,
                details: details
            )
        )

        if runtimeDiagnosticsEvents.count > runtimeDiagnosticsLimit {
            runtimeDiagnosticsEvents.removeFirst(runtimeDiagnosticsEvents.count - runtimeDiagnosticsLimit)
        }
    }

    // Test hook: deterministic validation of runtime gating without model execution.
    internal func _testing_resolveRuntimeConfiguration(
        model: ModelIdentifier,
        generateConfig: GenerateConfig
    ) async -> MLXConfiguration {
        await resolveRuntimeConfiguration(model: model, generateConfig: generateConfig)
    }

    // MARK: - Runtime Configuration

    private func applyRuntimeConfigurationIfNeeded() async {
        guard !didApplyRuntimeConfiguration else { return }
        await MLXModelCache.shared.apply(configuration: configuration.cacheConfiguration())

        #if arch(arm64)
        let resolvedLimit = MLXRuntimeMemoryLimit.resolved(from: configuration)
        MLX.GPU.set(memoryLimit: resolvedLimit)
        #endif

        didApplyRuntimeConfiguration = true
    }
}

#endif // canImport(MLX)

#endif // CONDUIT_TRAIT_MLX
