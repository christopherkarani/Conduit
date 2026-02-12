// CoreMLProvider.swift
// Conduit

import Foundation

#if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models)
import CoreML
import Tokenizers
@preconcurrency import Generation
@preconcurrency import Models

/// Native Core ML provider backed by `swift-transformers`.
///
/// Use `.coreml("/path/to/model.mlmodelc")` model identifiers with this provider.
public actor CoreMLProvider: AIProvider, TextGenerator {

    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier
    public typealias ChatTemplateMessagesHandler = @Sendable ([Message]) throws -> [CoreMLConfiguration.ChatTemplateMessage]
    public typealias ToolSpecificationHandler = @Sendable ([Transcript.ToolDefinition]) -> [CoreMLConfiguration.ToolSpecification]

    /// Runtime configuration for Core ML inference.
    public let configuration: CoreMLConfiguration
    private let chatTemplateMessagesHandler: ChatTemplateMessagesHandler?
    private let toolSpecificationHandler: ToolSpecificationHandler?

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private struct Runtime {
        let model: Models.LanguageModel
        let tokenizer: any Tokenizer
    }

    private let minimumSupportedVersion = "iOS 18 / macOS 15 / tvOS 18 / watchOS 11 / visionOS 2"

    public init(
        configuration: CoreMLConfiguration = .default,
        chatTemplateMessagesHandler: ChatTemplateMessagesHandler? = nil,
        toolSpecificationHandler: ToolSpecificationHandler? = nil
    ) {
        self.configuration = configuration
        self.chatTemplateMessagesHandler = chatTemplateMessagesHandler
        self.toolSpecificationHandler = toolSpecificationHandler
    }

    // MARK: - Availability

    public var isAvailable: Bool {
        get async {
            if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
                return true
            }
            return false
        }
    }

    public var availabilityStatus: ProviderAvailability {
        get async {
            if await isAvailable {
                return .available
            }
            return .unavailable(.osVersionNotMet(required: minimumSupportedVersion))
        }
    }

    // MARK: - Generation

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
        guard !messages.isEmpty else {
            throw AIError.invalidInput("Messages cannot be empty")
        }

        let modelURL = try resolveCompiledModelURL(from: model)

        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            do {
                return try await generateOnSupportedOS(messages: messages, modelURL: modelURL, config: config)
            } catch {
                throw mapError(error)
            }
        }

        throw AIError.providerUnavailable(reason: .osVersionNotMet(required: minimumSupportedVersion))
    }

    public nonisolated func stream(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        let chunkStream = stream(messages: [.user(prompt)], model: model, config: config)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in chunkStream where !chunk.text.isEmpty {
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

    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        stream(messages: messages, model: model, config: config)
    }

    public nonisolated func stream(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let result = try await self.generate(messages: messages, model: model, config: config)

                    if !result.text.isEmpty {
                        continuation.yield(
                            GenerationChunk(
                                text: result.text,
                                tokenCount: result.tokenCount,
                                tokensPerSecond: result.tokensPerSecond,
                                isComplete: false
                            )
                        )
                    }

                    continuation.yield(
                        GenerationChunk(
                            text: "",
                            tokenCount: 0,
                            isComplete: true,
                            finishReason: result.finishReason,
                            usage: result.usage
                        )
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

    public func cancelGeneration() async {
        // swift-transformers does not expose per-request cancellation hooks.
    }
}

// MARK: - Private Helpers

extension CoreMLProvider {
    private nonisolated func resolveCompiledModelURL(from model: ModelIdentifier) throws -> URL {
        guard case .coreml(let path) = model else {
            throw AIError.invalidInput("CoreMLProvider only supports .coreml() models")
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw AIError.invalidInput("Model path cannot be empty")
        }

        let modelURL = URL(fileURLWithPath: trimmedPath)
        guard modelURL.pathExtension.lowercased() == "mlmodelc" else {
            throw AIError.invalidInput("CoreMLProvider requires a compiled .mlmodelc model path")
        }

        var isDirectory: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory)
        guard fileExists else {
            throw AIError.modelNotFound(.coreml(trimmedPath))
        }
        guard isDirectory.boolValue else {
            throw AIError.invalidInput("CoreML .mlmodelc path must reference a directory")
        }

        return modelURL
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private func generateOnSupportedOS(
        messages: [Message],
        modelURL: URL,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        let startTime = Date()
        let runtime = try await loadRuntime(modelURL: modelURL)
        let promptTokens = try encodeInputTokens(
            messages: messages,
            config: config,
            tokenizer: runtime.tokenizer
        )

        await runtime.model.resetState()

        let outputTokenIDs = await runtime.model.generate(
            config: makeGenerationConfig(from: config),
            tokens: promptTokens,
            model: runtime.model.callAsFunction
        )

        let promptTextPrefix = runtime.tokenizer.decode(tokens: promptTokens)
        let fullText = runtime.tokenizer.decode(tokens: outputTokenIDs)
        let outputText: String
        if fullText.hasPrefix(promptTextPrefix) {
            let startIndex = fullText.index(fullText.startIndex, offsetBy: promptTextPrefix.count)
            outputText = String(fullText[startIndex...])
        } else {
            outputText = fullText
        }

        let completionTokens = runtime.tokenizer.encode(text: outputText).count
        let generationTime = Date().timeIntervalSince(startTime)
        let tokensPerSecond = generationTime > 0 ? Double(completionTokens) / generationTime : 0

        return GenerationResult(
            text: outputText,
            tokenCount: completionTokens,
            generationTime: generationTime,
            tokensPerSecond: tokensPerSecond,
            finishReason: .stop,
            usage: UsageStats(promptTokens: promptTokens.count, completionTokens: completionTokens)
        )
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private func loadRuntime(modelURL: URL) async throws -> Runtime {
        do {
            let model = try Models.LanguageModel.loadCompiled(
                url: modelURL,
                computeUnits: configuration.computeUnits.mlComputeUnits
            )
            let tokenizer = try await model.tokenizer

            return Runtime(model: model, tokenizer: tokenizer)
        } catch {
            throw AIError.generation(error)
        }
    }

    private func encodeInputTokens(
        messages: [Message],
        config: GenerateConfig,
        tokenizer: any Tokenizer
    ) throws -> [Int] {
        switch configuration.promptFormatting {
        case .rolePrefixedText:
            let prompt = buildPrompt(from: messages)
            return tokenizer.encode(text: prompt)

        case .tokenizerChatTemplate:
            let templateMessages = try makeChatTemplateMessages(from: messages)
                .map(toTokenizerMessage(from:))

            let toolSpecs: [ToolSpec]? = {
                let specs = makeToolSpecifications(from: config.tools)
                guard !specs.isEmpty else { return nil }
                return specs.map(toTokenizerToolSpec(from:))
            }()

            let additionalContext = configuration.additionalTemplateContext?.mapValues(sendableValue(from:))

            if let chatTemplate = configuration.chatTemplate {
                return try tokenizer.applyChatTemplate(
                    messages: templateMessages,
                    chatTemplate: .literal(chatTemplate),
                    addGenerationPrompt: true,
                    truncation: false,
                    maxLength: nil,
                    tools: toolSpecs,
                    additionalContext: additionalContext
                )
            }

            return try tokenizer.applyChatTemplate(
                messages: templateMessages,
                chatTemplate: nil,
                addGenerationPrompt: true,
                truncation: false,
                maxLength: nil,
                tools: toolSpecs,
                additionalContext: additionalContext
            )
        }
    }

    func makeChatTemplateMessages(
        from messages: [Message]
    ) throws -> [CoreMLConfiguration.ChatTemplateMessage] {
        if let chatTemplateMessagesHandler {
            return try chatTemplateMessagesHandler(messages)
        }

        var converted: [CoreMLConfiguration.ChatTemplateMessage] = []
        converted.reserveCapacity(messages.count)

        for message in messages {
            try validateMessageContentForChatTemplate(message)

            var payload: CoreMLConfiguration.ChatTemplateMessage = [
                "role": .string(message.role.rawValue),
                "content": .string(message.content.textValue)
            ]

            if message.role == .tool, let toolName = message.metadata?.custom?["tool_name"] {
                payload["name"] = .string(toolName)
            }

            if message.role == .assistant,
               let toolCalls = message.metadata?.toolCalls,
               !toolCalls.isEmpty {
                let callPayload: [JSONValue] = toolCalls.map { toolCall in
                    .object([
                        "id": .string(toolCall.id),
                        "type": .string("function"),
                        "function": .object([
                            "name": .string(toolCall.toolName),
                            "arguments": .string(toolCall.argumentsString)
                        ])
                    ])
                }
                payload["tool_calls"] = .array(callPayload)
            }

            converted.append(payload)
        }

        return converted
    }

    func makeToolSpecifications(
        from toolDefinitions: [Transcript.ToolDefinition]
    ) -> [CoreMLConfiguration.ToolSpecification] {
        if let toolSpecificationHandler {
            return toolSpecificationHandler(toolDefinitions)
        }

        guard configuration.toolSpecificationStrategy == .openAIFunction else {
            return []
        }

        return toolDefinitions.map { tool in
            let resolvedSchema = tool.parameters.withResolvedRoot() ?? tool.parameters
            let parameters: JSONValue = (try? JSONValue(resolvedSchema))
                ?? .object(["type": .string("object"), "properties": .object([:]), "required": .array([])])

            return [
                "type": .string("function"),
                "function": .object([
                    "name": .string(tool.name),
                    "description": .string(tool.description),
                    "parameters": parameters
                ])
            ]
        }
    }

    private nonisolated func validateMessageContentForChatTemplate(_ message: Message) throws {
        switch message.content {
        case .text:
            return
        case .parts(let parts):
            for part in parts {
                switch part {
                case .text:
                    continue
                case .image:
                    throw AIError.invalidInput("CoreMLProvider tokenizer chat templates do not support image message parts")
                case .audio:
                    throw AIError.invalidInput("CoreMLProvider tokenizer chat templates do not support audio message parts")
                }
            }
        }
    }

    private nonisolated func toTokenizerMessage(
        from message: CoreMLConfiguration.ChatTemplateMessage
    ) -> Tokenizers.Message {
        message.mapValues(sendableValue(from:))
    }

    private nonisolated func toTokenizerToolSpec(
        from specification: CoreMLConfiguration.ToolSpecification
    ) -> ToolSpec {
        specification.mapValues(sendableValue(from:))
    }

    private nonisolated func sendableValue(from value: JSONValue) -> any Sendable {
        switch value {
        case .null:
            return value
        case .bool(let bool):
            return bool
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .string(let string):
            return string
        case .array(let values):
            return values.map(sendableValue(from:))
        case .object(let object):
            return object.mapValues(sendableValue(from:))
        }
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

        lines.append("Assistant:")
        return lines.joined(separator: "\n")
    }

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private nonisolated func makeGenerationConfig(from config: GenerateConfig) -> GenerationConfig {
        var generationConfig = GenerationConfig(maxNewTokens: config.maxTokens ?? configuration.defaultMaxTokens)
        generationConfig.temperature = config.temperature

        if let topK = config.topK, topK > 0 {
            generationConfig.doSample = true
            generationConfig.topK = topK
        } else if config.topP > 0, config.topP <= 1 {
            generationConfig.doSample = true
            generationConfig.topP = config.topP
        } else if config.temperature <= 0 {
            generationConfig.doSample = false
        }

        return generationConfig
    }

    private nonisolated func mapError(_ error: Error) -> AIError {
        if let aiError = error as? AIError {
            return aiError
        }
        if let tokenizerError = error as? Tokenizers.TokenizerError {
            switch tokenizerError {
            case .missingChatTemplate:
                return .invalidInput(
                    "Tokenizer has no chat template. Provide CoreMLConfiguration.chatTemplate or use .rolePrefixedText formatting."
                )
            default:
                return .invalidInput("Tokenizer chat-template formatting failed: \(tokenizerError.localizedDescription)")
            }
        }
        return .generation(error)
    }
}

#else

/// Fallback stub when Core ML runtime dependencies are unavailable.
public actor CoreMLProvider: AIProvider, TextGenerator {
    public typealias Response = GenerationResult
    public typealias StreamChunk = GenerationChunk
    public typealias ModelID = ModelIdentifier
    public typealias ChatTemplateMessagesHandler = @Sendable ([Message]) throws -> [CoreMLConfiguration.ChatTemplateMessage]
    public typealias ToolSpecificationHandler = @Sendable ([Transcript.ToolDefinition]) -> [CoreMLConfiguration.ToolSpecification]

    public let configuration: CoreMLConfiguration
    private let chatTemplateMessagesHandler: ChatTemplateMessagesHandler?
    private let toolSpecificationHandler: ToolSpecificationHandler?

    public init(
        configuration: CoreMLConfiguration = .default,
        chatTemplateMessagesHandler: ChatTemplateMessagesHandler? = nil,
        toolSpecificationHandler: ToolSpecificationHandler? = nil
    ) {
        self.configuration = configuration
        self.chatTemplateMessagesHandler = chatTemplateMessagesHandler
        self.toolSpecificationHandler = toolSpecificationHandler
    }

    public var isAvailable: Bool {
        get async { false }
    }

    public var availabilityStatus: ProviderAvailability {
        get async { .unavailable(.deviceNotSupported) }
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

    public nonisolated func stream(
        _ prompt: String,
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public nonisolated func streamWithMetadata(
        messages: [Message],
        model: ModelIdentifier,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: AIError.providerUnavailable(reason: .deviceNotSupported))
        }
    }

    public nonisolated func stream(
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
