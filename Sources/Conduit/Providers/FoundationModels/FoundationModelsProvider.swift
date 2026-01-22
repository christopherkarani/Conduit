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
        let prompt = buildPrompt(from: messages)
        let options = makeGenerationOptions(from: config)

        do {
            let response = try await session.respond(to: prompt, options: options)
            let duration = Date().timeIntervalSince(startTime)

            return GenerationResult(
                text: response.content,
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
                    let options = makeGenerationOptions(from: config)
                    let stream = session.streamResponse(to: prompt, options: options)

                    var previous = ""
                    for try await snapshot in stream {
                        let current = snapshot.content
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
                    let prompt = buildPrompt(from: messages)
                    let options = makeGenerationOptions(from: config)
                    let stream = session.streamResponse(to: prompt, options: options)

                    var previous = ""
                    for try await snapshot in stream {
                        let current = snapshot.content
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

    private nonisolated func buildPrompt(from messages: [Message]) -> String {
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

        return lines.joined(separator: "\n")
    }

    private nonisolated func makeGenerationOptions(from config: GenerateConfig) -> FoundationModels.GenerationOptions {
        var options = FoundationModels.GenerationOptions()

        if config.temperature >= 0 {
            options.temperature = Double(config.temperature)
        }
        if let maxTokens = config.maxTokens {
            options.maximumResponseTokens = maxTokens
        }

        if config.topP > 0, config.topP <= 1 {
            options.sampling = .random(probabilityThreshold: Double(config.topP))
        } else if let topK = config.topK, topK > 0 {
            options.sampling = .random(top: topK)
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
