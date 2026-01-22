// StructuredOutputGenerationTests.swift
// ConduitTests

import Testing
@testable import Conduit

@Suite("StructuredOutputGeneration")
struct StructuredOutputGenerationTests {

    enum TestModelID: String, ModelIdentifying {
        case test = "test-model"

        var displayName: String { rawValue }
        var provider: ProviderType { .mlx }
        var description: String { rawValue }
    }

    final class FakeTextGenerator: TextGenerator {
        typealias ModelID = TestModelID

        private actor Storage {
            var lastPrompt: String?
            var lastMessages: [Message]?

            func record(prompt: String) {
                lastPrompt = prompt
            }

            func record(messages: [Message]) {
                lastMessages = messages
            }
        }

        private let storage = Storage()

        private let promptResponse: String
        private let messagesResponse: String

        init(promptResponse: String = "", messagesResponse: String = "") {
            self.promptResponse = promptResponse
            self.messagesResponse = messagesResponse
        }

        func generate(
            _ prompt: String,
            model: ModelID,
            config: GenerateConfig
        ) async throws -> String {
            await storage.record(prompt: prompt)
            return promptResponse
        }

        func generate(
            messages: [Message],
            model: ModelID,
            config: GenerateConfig
        ) async throws -> GenerationResult {
            await storage.record(messages: messages)
            return .text(messagesResponse)
        }

        func recordedPrompt() async -> String? {
            await storage.lastPrompt
        }

        func recordedMessages() async -> [Message]? {
            await storage.lastMessages
        }

        func stream(
            _ prompt: String,
            model: ModelID,
            config: GenerateConfig
        ) -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }

        func streamWithMetadata(
            messages: [Message],
            model: ModelID,
            config: GenerateConfig
        ) -> AsyncThrowingStream<GenerationChunk, Error> {
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        }
    }

    @Test("Parses valid JSON array from prompt")
    func parsesValidJSONArrayFromPrompt() async throws {
        let generator = FakeTextGenerator(promptResponse: #"["a", "b"]"#)

        let output = try await generator.generate(
            "Return two strings",
            returning: [String].self,
            model: .test
        )

        #expect(output == ["a", "b"])

        let prompt = await generator.recordedPrompt()
        #expect(prompt?.contains("Respond with valid JSON matching this schema:") == true)
        #expect(prompt?.contains([String].generationSchema.toJSONString()) == true)
    }

    @Test("Repairs missing closing bracket")
    func repairsMissingClosingBracket() async throws {
        let generator = FakeTextGenerator(promptResponse: #"["a", "b""#)

        let output = try await generator.generate(
            "Return two strings",
            returning: [String].self,
            model: .test
        )

        #expect(output == ["a", "b"])
    }

    @Test("Parses JSON array from messages")
    func parsesJSONArrayFromMessages() async throws {
        let generator = FakeTextGenerator(messagesResponse: #"["x"]"#)

        let output = try await generator.generate(
            messages: [.user("Hello")],
            returning: [String].self,
            model: .test
        )

        #expect(output == ["x"])

        let messages = await generator.recordedMessages()
        let lastText = messages?.last?.content.textValue
        #expect(lastText?.contains("Respond with valid JSON matching this schema:") == true)
        #expect(lastText?.contains([String].generationSchema.toJSONString()) == true)
    }
}
