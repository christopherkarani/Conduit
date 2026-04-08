// FoundationModelsProvider.swift
// Conduit

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// On-device provider backed by Apple Foundation Models (iOS 26+, macOS 26+, visionOS 26+).
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public actor FoundationModelsProvider: AIProvider, TextGenerator {

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    private var configuration: FMConfiguration
    private var session: LanguageModelSession?

    /// Creates a Foundation Models provider with the given configuration.
    public init(configuration: FMConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Availability

    public var isAvailable: Bool {
        get async {
            DeviceCapabilities.current().supportsFoundationModels
        }
    }

    public var availabilityStatus: ProviderAvailability {
        get async {
            if DeviceCapabilities.current().supportsFoundationModels {
                return .available
            }
            return .unavailable(.osVersionNotMet(required: "iOS 26 / macOS 26 / visionOS 26"))
        }
    }

    // MARK: - TextGenerator

    public func generate(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> String {
        let result = try await generate(
            messages: [.user(prompt)],
            model: model,
            config: config
        )
        return result.text
    }

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        try validateModel(model)
        guard !messages.isEmpty else {
            throw AIError.invalidInput("Messages cannot be empty")
        }

        let startTime = Date()
        let session = makeSession()
        let prompt = buildPrompt(from: messages, responseFormat: config.responseFormat)
        let options = makeGenerationOptions(from: config)

        do {
            let response = try await session.respond(to: prompt, options: options)
            let duration = Date().timeIntervalSince(startTime)
            let text = stripCodeFences(response.content, for: config.responseFormat)

            return GenerationResult(
                text: text,
                tokenCount: 0,
                generationTime: duration,
                tokensPerSecond: 0,
                finishReason: .stop,
                usage: UsageStats(promptTokens: 0, completionTokens: 0)
            )
        } catch {
            throw mapFoundationModelsError(error)
        }
    }

    nonisolated public func stream(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try validateModel(model)
                    let session = await makeSession()
                    let effectivePrompt = buildPrompt(
                        from: [.user(prompt)],
                        responseFormat: config.responseFormat
                    )
                    let options = makeGenerationOptions(from: config)
                    let stream = session.streamResponse(to: effectivePrompt, options: options)

                    var previous = ""
                    for try await snapshot in stream {
                        let current = stripCodeFences(snapshot.content, for: config.responseFormat)
                        let delta = current.hasPrefix(previous)
                            ? String(current.dropFirst(previous.count))
                            : current
                        previous = current

                        if !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapFoundationModelsError(error))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    nonisolated public func streamWithMetadata(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try validateModel(model)
                    guard !messages.isEmpty else {
                        throw AIError.invalidInput("Messages cannot be empty")
                    }

                    let session = await makeSession()
                    let prompt = buildPrompt(from: messages, responseFormat: config.responseFormat)
                    let options = makeGenerationOptions(from: config)
                    let stream = session.streamResponse(to: prompt, options: options)

                    var previous = ""
                    for try await snapshot in stream {
                        let current = stripCodeFences(snapshot.content, for: config.responseFormat)
                        let delta = current.hasPrefix(previous)
                            ? String(current.dropFirst(previous.count))
                            : current
                        previous = current

                        if !delta.isEmpty {
                            continuation.yield(GenerationChunk(
                                text: delta,
                                tokenCount: 0,
                                tokenId: nil,
                                logprob: nil,
                                topLogprobs: nil,
                                tokensPerSecond: nil,
                                isComplete: false,
                                finishReason: nil,
                                timestamp: Date()
                            ))
                        }
                    }

                    continuation.yield(GenerationChunk(
                        text: "",
                        tokenCount: 0,
                        tokenId: nil,
                        logprob: nil,
                        topLogprobs: nil,
                        tokensPerSecond: nil,
                        isComplete: true,
                        finishReason: .stop,
                        timestamp: Date(),
                        usage: UsageStats(promptTokens: 0, completionTokens: 0)
                    ))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapFoundationModelsError(error))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    nonisolated public func stream(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        streamWithMetadata(messages: messages, model: model, config: config)
    }

    public func cancelGeneration() async {
        // FoundationModels doesn't expose per-request cancellation yet.
    }

    // MARK: - Private Helpers

    private nonisolated func validateModel(_ model: ModelIdentifier) throws {
        guard case .foundationModels = model else {
            throw AIError.invalidInput("FoundationModelsProvider only supports .foundationModels")
        }
    }

    private func makeSession() -> LanguageModelSession {
        if let session {
            return session
        }

        let session: LanguageModelSession
        if let instructions = configuration.instructions {
            session = LanguageModelSession(model: .default, tools: [], instructions: {
                instructions
            })
        } else {
            session = LanguageModelSession(model: .default, tools: [])
        }

        if configuration.prewarmOnInit {
            session.prewarm(promptPrefix: nil)
        }

        self.session = session
        return session
    }

    private nonisolated func buildPrompt(from messages: [Message], responseFormat: ResponseFormat? = nil) -> String {
        var lines: [String] = []
        lines.reserveCapacity(messages.count)

        for message in messages {
            let text = message.content.textValue
            guard !text.isEmpty else { continue }

            switch message.role {
            case .system:
                lines.append("System: \(text)")
            case .user:
                lines.append("User: \(text)")
            case .assistant:
                lines.append("Assistant: \(text)")
            case .tool:
                let toolName = message.metadata?.custom?["tool_name"]
                let prefix = toolName.map { "Tool(\($0))" } ?? "Tool"
                lines.append("\(prefix): \(text)")
            }
        }

        if let instruction = responseFormat?.promptInstruction {
            lines.append("\n\(instruction)")
        }

        return lines.joined(separator: "\n")
    }

    /// Strips markdown code fences from model output when a JSON response format is requested.
    ///
    /// On-device Foundation Models sometimes wrap JSON in triple-backtick fences
    /// (e.g. ````json ... ````) despite explicit prompt instructions not to.
    /// This normaliser ensures callers always receive clean JSON.
    ///
    /// The trailing fence is only stripped when the opening fence was successfully
    /// removed, preventing asymmetric stripping from producing malformed output.
    nonisolated func stripCodeFences(_ text: String, for format: ResponseFormat?) -> String {
        guard let format else { return text }
        if case .text = format { return text }

        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip leading ```json or ``` fence (requires a newline after the fence marker)
        var didStripOpening = false
        if result.hasPrefix("```") {
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
                didStripOpening = true
            }
        }

        // Only strip trailing ``` when the opening fence was also stripped,
        // avoiding asymmetric removal that would leave malformed content.
        if didStripOpening, result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func makeGenerationOptions(from config: GenerateConfig) -> FoundationModels.GenerationOptions {
        var options = FoundationModels.GenerationOptions()

        if config.temperature >= 0 {
            options.temperature = Double(config.temperature)
        }
        if let maxTokens = config.maxTokens {
            options.maximumResponseTokens = maxTokens
        }

        if let topK = config.topK, topK > 0 {
            options.sampling = .random(top: topK, seed: config.seed)
        } else if config.topP > 0, config.topP <= 1 {
            options.sampling = .random(probabilityThreshold: Double(config.topP), seed: config.seed)
        } else if config.temperature == 0 {
            options.sampling = .greedy
        }

        return options
    }

    private nonisolated func mapFoundationModelsError(_ error: Error) -> AIError {
        if let fmError = error as? LanguageModelSession.GenerationError {
            switch fmError {
            case .rateLimited:
                return .rateLimited(retryAfter: nil)
            case .refusal:
                return .contentFiltered(reason: fmError.localizedDescription)
            case .unsupportedLanguageOrLocale:
                return .unsupportedLanguage(fmError.localizedDescription)
            case .concurrentRequests:
                return .providerUnavailable(reason: .unknown("Concurrent requests are not supported"))
            default:
                return .generationFailed(underlying: SendableError(fmError))
            }
        }

        return .generationFailed(underlying: SendableError(error))
    }
}

// MARK: - Native Structured Generation

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
extension FoundationModelsProvider {

    /// Generates a structured response using Apple's native constrained decoding.
    ///
    /// When the target type conforms to **both** Conduit's ``Generable`` and Apple's
    /// `FoundationModels.Generable`, this override leverages the on-device model's
    /// token-level constrained generation via `respond(to:generating:)`.
    /// This produces more reliable structured output than prompt injection alone.
    ///
    /// Swift overload resolution automatically selects this method over the default
    /// `TextGenerator` extension when the type satisfies both constraints.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Type must conform to both Conduit.Generable and FoundationModels.Generable
    /// @Conduit.Generable
    /// @FoundationModels.Generable
    /// struct Recipe {
    ///     let title: String
    ///     let ingredients: [String]
    /// }
    ///
    /// let provider = FoundationModelsProvider()
    /// let recipe = try await provider.generate(
    ///     "Create a cookie recipe",
    ///     returning: Recipe.self,
    ///     model: .foundationModels
    /// )
    /// ```
    public func generate<T: Generable & FoundationModels.Generable>(
        _ prompt: String,
        returning type: T.Type,
        model: ModelIdentifier,
        config: GenerateConfig = .default
    ) async throws -> T {
        try validateModel(model)
        return try await respondStructured(to: prompt, generating: type, config: config)
    }

    /// Generates a structured response from messages using Apple's native constrained decoding.
    public func generate<T: Generable & FoundationModels.Generable>(
        messages: [Message],
        returning type: T.Type,
        model: ModelIdentifier,
        config: GenerateConfig = .default
    ) async throws -> T {
        try validateModel(model)
        guard !messages.isEmpty else {
            throw AIError.invalidInput("Messages cannot be empty")
        }
        // Native Generable conformance provides schema constraints;
        // responseFormat instructions are intentionally omitted here.
        let prompt = buildPrompt(from: messages)
        return try await respondStructured(to: prompt, generating: type, config: config)
    }

    private func respondStructured<T: FoundationModels.Generable>(
        to prompt: String,
        generating type: T.Type,
        config: GenerateConfig
    ) async throws -> T {
        let session = makeSession()
        let options = makeGenerationOptions(from: config)
        do {
            let response = try await session.respond(to: prompt, generating: T.self, options: options)
            return response.content
        } catch {
            throw mapFoundationModelsError(error)
        }
    }
}

#else

/// Fallback stub for platforms without FoundationModels.
public actor FoundationModelsProvider: AIProvider, TextGenerator {

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier

    public init(configuration: FMConfiguration = .default) {}

    public var isAvailable: Bool { get async { false } }

    public var availabilityStatus: ProviderAvailability {
        get async {
            .unavailable(.osVersionNotMet(required: "iOS 26 / macOS 26 / visionOS 26"))
        }
    }

    public func generate(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> String {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }

    public func generate(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }

    public func stream(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public func streamWithMetadata(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public func stream(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public func cancelGeneration() async {}
}

#endif
