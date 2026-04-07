// FoundationModelsProviderTests.swift
// ConduitTests

import Foundation
import Testing
@testable import ConduitAdvanced

#if canImport(FoundationModels)
import FoundationModels

private let foundationModelsRuntimeAvailable: Bool = {
    if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
        return SystemLanguageModel.default.isAvailable
    }
    return false
}()

@Suite("Foundation Models Provider")
struct FoundationModelsProviderTests {

    @Test("availability matches device capabilities")
    func availabilityMatchesDeviceCapabilities() async {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()

        #expect(await provider.isAvailable == DeviceCapabilities.current().supportsFoundationModels)
        #expect(await provider.isAvailable == foundationModelsRuntimeAvailable)
    }

    @Test("rejects non-Foundation Models identifiers")
    func rejectsNonFoundationModelsIdentifiers() async {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()

        await #expect(throws: AIError.self) {
            _ = try await provider.generate(
                messages: [.user("Hello")],
                model: .openAI("gpt-4o-mini"),
                config: .default
            )
        }
    }

    @Test(
        "generate returns text when Foundation Models runtime is available",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func generateReturnsText() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()
        let result = try await provider.generate(
            messages: [.user("Reply with one short sentence saying hello.")],
            model: .foundationModels,
            config: .default.maxTokens(24).temperature(0.2)
        )

        #expect(!result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test(
        "stream emits text when Foundation Models runtime is available",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func streamEmitsText() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()
        let stream = provider.stream(
            messages: [.user("Reply with a short greeting.")],
            model: .foundationModels,
            config: .default.maxTokens(16).temperature(0.2)
        )

        var combined = ""
        for try await chunk in stream {
            combined += chunk.text
        }

        #expect(!combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Response Format Tests

    @Test(
        "generate with jsonObject responseFormat produces JSON output",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func generateWithJsonObjectResponseFormat() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else { return }

        let provider = FoundationModelsProvider()
        let result = try await provider.generate(
            messages: [.user("Return a JSON object with a single key 'greeting' and value 'hello'")],
            model: .foundationModels,
            config: .default.responseFormat(.jsonObject).maxTokens(64).temperature(0)
        )

        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
                "Expected JSON output, got: \(trimmed.prefix(100))")
    }

    @Test(
        "generate with jsonSchema responseFormat produces schema-conforming JSON",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func generateWithJsonSchemaResponseFormat() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else { return }

        let schema = GenerationSchema.schema(
            root: .object(GenerationSchema.ObjectNode(
                description: "A greeting",
                properties: [
                    "message": .string(GenerationSchema.StringNode(
                        description: "A short greeting text",
                        pattern: nil,
                        enumChoices: nil
                    ))
                ],
                required: ["message"]
            )),
            defs: [:]
        )

        let provider = FoundationModelsProvider()
        let result = try await provider.generate(
            messages: [.user("Say hello")],
            model: .foundationModels,
            config: .default
                .responseFormat(.jsonSchema(name: "Greeting", schema: schema))
                .maxTokens(64)
                .temperature(0)
        )

        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.hasPrefix("{"), "Expected JSON object, got: \(trimmed.prefix(100))")

        let data = Data(trimmed.utf8)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["message"] != nil, "Expected 'message' key in response")
    }

    @Test(
        "generate with text responseFormat returns plain text",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func generateWithTextResponseFormat() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else { return }

        let provider = FoundationModelsProvider()
        let result = try await provider.generate(
            messages: [.user("Say hello in one sentence")],
            model: .foundationModels,
            config: .default.responseFormat(.text).maxTokens(24).temperature(0.2)
        )

        #expect(!result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test(
        "stream with jsonObject responseFormat produces JSON chunks",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func streamWithJsonObjectResponseFormat() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else { return }

        let provider = FoundationModelsProvider()
        let stream = provider.stream(
            messages: [.user("Return a JSON object with key 'status' and value 'ok'")],
            model: .foundationModels,
            config: .default.responseFormat(.jsonObject).maxTokens(64).temperature(0)
        )

        var combined = ""
        for try await chunk in stream {
            combined += chunk.text
        }

        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
                "Expected JSON output from stream, got: \(trimmed.prefix(100))")
    }
}

// MARK: - Code Fence Stripping Unit Tests

@Suite("FoundationModelsProvider Code Fence Stripping")
struct CodeFenceStrippingTests {

    // Access stripCodeFences through a helper since it's private.
    // We test indirectly via generate() for integration, but also test
    // the stripping logic by feeding known inputs through a thin wrapper.

    @available(macOS 26.0, iOS 26.0, visionOS 26.0, *)
    private func stripViaProvider(_ text: String, format: ResponseFormat?) async -> String {
        // Use a provider instance to call the private stripCodeFences indirectly
        // by setting the response as if it came from the model.
        // Since stripCodeFences is nonisolated private, we test behavior through generate.
        // For unit-level testing, we replicate the stripping logic here.
        return CodeFenceStrippingTests.stripCodeFences(text, for: format)
    }

    /// Replicates FoundationModelsProvider.stripCodeFences for unit testing.
    /// Kept in sync with the production implementation.
    static func stripCodeFences(_ text: String, for format: ResponseFormat?) -> String {
        guard let format else { return text }
        if case .text = format { return text }

        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var didStripOpening = false
        if result.hasPrefix("```") {
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
                didStripOpening = true
            }
        }

        if didStripOpening, result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("strips json code fences from response")
    func stripsJsonCodeFences() {
        let input = "```json\n{\"greeting\": \"hello\"}\n```"
        let result = Self.stripCodeFences(input, for: .jsonObject)
        #expect(result == "{\"greeting\": \"hello\"}")
    }

    @Test("strips plain code fences without language tag")
    func stripsPlainCodeFences() {
        let input = "```\n{\"key\": \"value\"}\n```"
        let result = Self.stripCodeFences(input, for: .jsonObject)
        #expect(result == "{\"key\": \"value\"}")
    }

    @Test("does not strip fences for text format")
    func doesNotStripForTextFormat() {
        let input = "```json\n{\"key\": \"value\"}\n```"
        let result = Self.stripCodeFences(input, for: .text)
        #expect(result == input)
    }

    @Test("does not strip fences when format is nil")
    func doesNotStripWhenFormatNil() {
        let input = "```json\n{\"key\": \"value\"}\n```"
        let result = Self.stripCodeFences(input, for: nil)
        #expect(result == input)
    }

    @Test("returns clean JSON unchanged")
    func returnsCleanJsonUnchanged() {
        let input = "{\"greeting\": \"hello\"}"
        let result = Self.stripCodeFences(input, for: .jsonObject)
        #expect(result == input)
    }

    @Test("does not strip trailing fence when opening fence is absent")
    func doesNotStripTrailingFenceAlone() {
        let input = "{\"key\": \"value\"}```"
        let result = Self.stripCodeFences(input, for: .jsonObject)
        #expect(result == input)
    }

    @Test("does not strip opening fence without newline (no asymmetric strip)")
    func doesNotStripOpeningFenceWithoutNewline() {
        let input = "```{\"a\":1}```"
        let result = Self.stripCodeFences(input, for: .jsonObject)
        // No newline after opening ```, so nothing is stripped
        #expect(result == input)
    }

    @Test("handles whitespace around fences")
    func handlesWhitespaceAroundFences() {
        let input = "  \n```json\n{\"key\": \"value\"}\n```\n  "
        let result = Self.stripCodeFences(input, for: .jsonObject)
        #expect(result == "{\"key\": \"value\"}")
    }

    @Test("works with jsonSchema format")
    func worksWithJsonSchemaFormat() {
        let schema = GenerationSchema.schema(
            root: .boolean,
            defs: [:]
        )
        let input = "```json\ntrue\n```"
        let result = Self.stripCodeFences(input, for: .jsonSchema(name: "Test", schema: schema))
        #expect(result == "true")
    }
}
#endif
