import Foundation
import Testing
@testable import Conduit

#if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models)
@Generable
private struct CoreMLWeatherArgs {
    let city: String
}
#endif

@Suite("CoreML Provider")
struct CoreMLProviderTests {

    @Test("Provider availability is coherent")
    func providerAvailabilityIsCoherent() async {
        let provider = CoreMLProvider()
        let isAvailable = await provider.isAvailable
        let status = await provider.availabilityStatus

        #expect(status.isAvailable == isAvailable)
        if isAvailable {
            #expect(status.unavailableReason == nil)
        } else {
            #expect(status.unavailableReason != nil)
        }
    }

    @Test("Generate rejects non-CoreML model identifiers")
    func generateRejectsNonCoreMLModelIdentifier() async {
        let provider = CoreMLProvider()

        do {
            _ = try await provider.generate(
                messages: [.user("Hello")],
                model: .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit"),
                config: .default
            )
            Issue.record("Expected generation to fail")
        } catch let error as AIError {
            #if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models)
            if case .invalidInput(let message) = error {
                #expect(message.contains("only supports .coreml()"))
            } else {
                Issue.record("Expected invalidInput, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                #expect(true)
            } else {
                Issue.record("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Generate rejects non-mlmodelc paths")
    func generateRejectsNonCompiledModelPath() async {
        let provider = CoreMLProvider()

        do {
            _ = try await provider.generate(
                messages: [.user("Hello")],
                model: .coreml("/tmp/model.mlmodel"),
                config: .default
            )
            Issue.record("Expected generation to fail")
        } catch let error as AIError {
            #if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models)
            if case .invalidInput(let message) = error {
                #expect(message.contains(".mlmodelc"))
            } else {
                Issue.record("Expected invalidInput for non-compiled model, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                #expect(true)
            } else {
                Issue.record("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Generate fails with modelNotFound when mlmodelc path does not exist")
    func generateMissingCompiledModelPathFails() async {
        let provider = CoreMLProvider()
        let missingPath = "/tmp/conduit-coreml-missing-\(UUID().uuidString).mlmodelc"

        do {
            _ = try await provider.generate(
                messages: [.user("Hello")],
                model: .coreml(missingPath),
                config: .default
            )
            Issue.record("Expected generation to fail")
        } catch let error as AIError {
            #if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models)
            if case .modelNotFound(let model) = error {
                #expect(model == .coreml(missingPath))
            } else {
                Issue.record("Expected modelNotFound, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                #expect(true)
            } else {
                Issue.record("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Stream fails with modelNotFound when mlmodelc path does not exist")
    func streamMissingCompiledModelPathFails() async {
        let provider = CoreMLProvider()
        let missingPath = "/tmp/conduit-coreml-missing-\(UUID().uuidString).mlmodelc"
        let stream = provider.stream(
            "Hello",
            model: .coreml(missingPath),
            config: .default
        )

        do {
            for try await _ in stream {}
            Issue.record("Expected stream to fail")
        } catch let error as AIError {
            #if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models)
            if case .modelNotFound(let model) = error {
                #expect(model == .coreml(missingPath))
            } else {
                Issue.record("Expected modelNotFound, got \(error)")
            }
            #else
            if case .providerUnavailable(reason: .deviceNotSupported) = error {
                #expect(true)
            } else {
                Issue.record("Expected providerUnavailable(.deviceNotSupported), got \(error)")
            }
            #endif
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }
}

#if CONDUIT_TRAIT_COREML && canImport(CoreML)
@Suite("CoreML Configuration")
struct CoreMLConfigurationTests {

    @Test("Default CoreML configuration values")
    func defaultValues() {
        let config = CoreMLConfiguration.default

        #expect(config.computeUnits == .all)
        #expect(config.defaultMaxTokens == 512)
        #expect(config.promptFormatting == .rolePrefixedText)
        #expect(config.toolSpecificationStrategy == .openAIFunction)
        #expect(config.chatTemplate == nil)
        #expect(config.additionalTemplateContext == nil)
    }

    @Test("CoreML configuration codable round trip")
    func codableRoundTrip() throws {
        let original = CoreMLConfiguration(
            computeUnits: .cpuAndGPU,
            defaultMaxTokens: 256,
            promptFormatting: .tokenizerChatTemplate,
            toolSpecificationStrategy: .none,
            chatTemplate: "{% for message in messages %}{{ message['content'] }}{% endfor %}",
            additionalTemplateContext: ["safety_mode": .string("strict")]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CoreMLConfiguration.self, from: data)

        #expect(decoded == original)
    }

    @Test("CoreML configuration clamps defaultMaxTokens and normalizes template context")
    func clampingAndNormalization() {
        let config = CoreMLConfiguration(
            defaultMaxTokens: 0,
            chatTemplate: "   ",
            additionalTemplateContext: [:]
        )

        #expect(config.defaultMaxTokens == 1)
        #expect(config.chatTemplate == nil)
        #expect(config.additionalTemplateContext == nil)
    }
}
#endif

#if CONDUIT_TRAIT_COREML && canImport(CoreML) && canImport(Tokenizers) && canImport(Generation) && canImport(Models)
@Suite("CoreML Prompt Formatting")
struct CoreMLPromptFormattingTests {
    @Test("Default chat-template message conversion maps roles and tool metadata")
    func defaultChatTemplateMessageConversion() async throws {
        let provider = CoreMLProvider(
            configuration: .init(promptFormatting: .tokenizerChatTemplate)
        )

        let toolCall = try Transcript.ToolCall(
            id: "call_weather",
            toolName: "get_weather",
            argumentsJSON: #"{"city":"Paris"}"#
        )

        let messages: [Message] = [
            .system("You are helpful."),
            .user("How is the weather?"),
            .assistant("", toolCalls: [toolCall]),
            Message(
                role: .tool,
                content: .text("Sunny, 20C"),
                metadata: MessageMetadata(custom: ["tool_name": "get_weather"])
            )
        ]

        let converted = try await provider.makeChatTemplateMessages(from: messages)
        #expect(converted.count == 4)
        #expect(converted[0]["role"] == .string("system"))
        #expect(converted[1]["content"] == .string("How is the weather?"))
        #expect(converted[2]["tool_calls"] != nil)
        #expect(converted[3]["name"] == .string("get_weather"))
    }

    @Test("Chat-template message conversion rejects image content")
    func chatTemplateMessageConversionRejectsImageContent() async {
        let provider = CoreMLProvider(
            configuration: .init(promptFormatting: .tokenizerChatTemplate)
        )

        let imageMessage = Message(
            role: .user,
            content: .parts([.image(.init(base64Data: "ZmFrZQ==", mimeType: "image/png"))])
        )

        await #expect(throws: AIError.self) {
            _ = try await provider.makeChatTemplateMessages(from: [imageMessage])
        }
    }

    @Test("Default tool specification conversion emits OpenAI-function format")
    func defaultToolSpecificationConversion() async {
        let provider = CoreMLProvider()
        let weatherTool = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get weather by city name",
            parameters: CoreMLWeatherArgs.generationSchema
        )

        let specs = await provider.makeToolSpecifications(from: [weatherTool])
        #expect(specs.count == 1)
        #expect(specs[0]["type"] == .string("function"))

        guard case .object(let functionObject) = specs[0]["function"] else {
            Issue.record("Expected function object in tool specification")
            return
        }
        #expect(functionObject["name"] == .string("get_weather"))
        #expect(functionObject["description"] == .string("Get weather by city name"))
        #expect(functionObject["parameters"] != nil)
    }

    @Test("Tool specification strategy none emits no tool specifications")
    func toolSpecificationStrategyNoneEmitsNoToolSpecs() async {
        let provider = CoreMLProvider(
            configuration: .init(toolSpecificationStrategy: .none)
        )
        let weatherTool = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get weather by city name",
            parameters: CoreMLWeatherArgs.generationSchema
        )

        let specs = await provider.makeToolSpecifications(from: [weatherTool])
        #expect(specs.isEmpty)
    }
}
#endif
