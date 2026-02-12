// StructuredOutputGenerationTests.swift
// ConduitTests

import Testing
@testable import Conduit

@Generable
private struct StreamingProfile {
    let name: String
    let age: Int
}

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
        private let streamedChunks: [String]

        init(promptResponse: String = "", messagesResponse: String = "", streamedChunks: [String] = []) {
            self.promptResponse = promptResponse
            self.messagesResponse = messagesResponse
            self.streamedChunks = streamedChunks
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
                for chunk in streamedChunks {
                    continuation.yield(chunk)
                }
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

    @Test("Structured streaming recovers fragmented malformed JSON")
    func structuredStreamingRecoversMalformedFragments() async throws {
        let generator = FakeTextGenerator(streamedChunks: [
            #"{"name":"Alice""#,
            #","age":30,"#
        ])

        let stream = generator.stream(
            "Return JSON",
            returning: StreamingProfile.self,
            model: .test
        )

        var lastSnapshot: StreamingResult<StreamingProfile>.Snapshot?
        for try await snapshot in stream {
            lastSnapshot = snapshot
        }

        let final = try #require(lastSnapshot)
        #expect((try? final.rawContent.value(String.self, forProperty: "name")) == "Alice")
        #expect((try? final.rawContent.value(Int.self, forProperty: "age")) == 30)
    }

    @Test("Structured streaming emits deterministic final upgraded snapshot")
    func structuredStreamingEmitsFinalUpgradedSnapshot() async throws {
        let generator = FakeTextGenerator(streamedChunks: [
            #"{"name":"Alice""#,
            #","age":30,"#
        ])

        let stream = generator.stream(
            "Return JSON",
            returning: StreamingProfile.self,
            model: .test
        )

        var snapshots: [StreamingResult<StreamingProfile>.Snapshot] = []
        for try await snapshot in stream {
            snapshots.append(snapshot)
        }

        #expect(snapshots.count >= 2)
        let first = try #require(snapshots.first)
        let last = try #require(snapshots.last)
        #expect((try? first.rawContent.value(String.self, forProperty: "name")) == "Alice")
        #expect((try? first.rawContent.value(Int.self, forProperty: "age")) == nil)
        #expect((try? last.rawContent.value(Int.self, forProperty: "age")) == 30)
    }
}
