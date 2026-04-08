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
        let tools = effectiveTools(from: config)
        let toolContext = tools.isEmpty ? nil : FoundationModelsToolCallingContext.make()
        let prompt = buildPrompt(
            from: messages,
            tools: tools,
            toolChoice: config.toolChoice,
            toolContext: toolContext,
            responseFormat: config.responseFormat
        )
        let options = makeGenerationOptions(from: config)

        do {
            let response = try await session.respond(to: prompt, options: options)
            let duration = Date().timeIntervalSince(startTime)
            let text = stripCodeFences(response.content, for: config.responseFormat)
            let toolCalls: [Transcript.ToolCall] = if let toolContext, !tools.isEmpty {
                FoundationModelsToolParser.parseToolCalls(
                    from: text,
                    availableTools: tools,
                    context: toolContext
                ) ?? []
            } else {
                []
            }

            return GenerationResult(
                text: toolCalls.isEmpty ? text : "",
                tokenCount: 0,
                generationTime: duration,
                tokensPerSecond: 0,
                finishReason: toolCalls.isEmpty ? .stop : .toolCall,
                usage: UsageStats(promptTokens: 0, completionTokens: 0),
                toolCalls: toolCalls
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
                    let prompt = buildPrompt(
                        from: [.user(prompt)],
                        tools: [],
                        toolChoice: config.toolChoice,
                        toolContext: nil,
                        responseFormat: config.responseFormat
                    )
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
                    let prompt = buildPrompt(
                        from: messages,
                        tools: [],
                        toolChoice: config.toolChoice,
                        toolContext: nil,
                        responseFormat: config.responseFormat
                    )
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

    private nonisolated func buildPrompt(
        from messages: [Message],
        tools: [Transcript.ToolDefinition],
        toolChoice: ToolChoice,
        toolContext: FoundationModelsToolCallingContext?,
        responseFormat: ResponseFormat?
    ) -> String {
        var lines: [String] = []
        lines.reserveCapacity(messages.count)

        for message in messages {
            let text = message.content.textValue
            switch message.role {
            case .system:
                guard !text.isEmpty else { continue }
                lines.append("System: \(text)")
            case .user:
                guard !text.isEmpty else { continue }
                lines.append("User: \(text)")
            case .assistant:
                if let toolCalls = message.metadata?.toolCalls, !toolCalls.isEmpty {
                    lines.append("Assistant requested tool calls:")
                    for toolCall in toolCalls {
                        lines.append("- \(toolCall.toolName)(\(toolCall.argumentsString)) [id=\(toolCall.id)]")
                    }
                }
                if !text.isEmpty {
                    lines.append("Assistant: \(text)")
                }
            case .tool:
                let toolName = message.metadata?.custom?["tool_name"]
                let callID = message.metadata?.custom?["tool_call_id"]
                let prefix = toolName.map { "Tool result (\($0))" } ?? "Tool result"
                if let callID, !callID.isEmpty {
                    lines.append("\(prefix) [id=\(callID)]: \(text)")
                } else {
                    lines.append("\(prefix): \(text)")
                }
            }
        }

        let basePrompt = lines.joined(separator: "\n")
        guard let toolContext, !tools.isEmpty else {
            return FoundationModelsToolPromptBuilder.appendResponseFormatInstruction(
                to: basePrompt,
                responseFormat: responseFormat
            )
        }

        return FoundationModelsToolPromptBuilder.buildPrompt(
            basePrompt: basePrompt,
            tools: tools,
            toolChoice: toolChoice,
            context: toolContext,
            responseFormat: responseFormat
        )
    }

    nonisolated func stripCodeFences(_ text: String, for format: ResponseFormat?) -> String {
        guard let format else { return text }
        if case .text = format { return text }

        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var didStripOpening = false
        if result.hasPrefix("```"), let newlineIndex = result.firstIndex(of: "\n") {
            result = String(result[result.index(after: newlineIndex)...])
            didStripOpening = true
        }

        if didStripOpening, result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func effectiveTools(from config: GenerateConfig) -> [Transcript.ToolDefinition] {
        switch config.toolChoice {
        case .none:
            []
        default:
            config.tools
        }
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
