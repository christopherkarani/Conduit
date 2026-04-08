// FoundationModelsProviderTests.swift
// ConduitTests

import Foundation
import Testing
@testable import ConduitAdvanced

#if canImport(FoundationModels)
import FoundationModels

private let foundationModelsPromptWeatherTool = Transcript.ToolDefinition(
    name: "getWeather",
    description: "Get weather for a location.",
    parameters: GenerationSchema(
        type: String.self,
        description: "Arguments for getWeather.",
        properties: [
            .init(name: "location", description: "The location to look up.", type: String.self),
        ]
    )
)

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
}

@Suite("Foundation Models Tool Prompting")
struct FoundationModelsToolPromptingTests {
    @Test("tool prompt uses concrete tool names and nonce")
    func toolPromptUsesConcreteToolNames() {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }

        let context = FoundationModelsToolCallingContext(nonce: "nonce-123")
        let prompt = FoundationModelsToolPromptBuilder.buildPrompt(
            basePrompt: "User: search for docs",
            tools: [foundationModelsPromptWeatherTool],
            toolChoice: .auto,
            context: context,
            responseFormat: nil
        )

        #expect(prompt.contains("\"tool\":\"getWeather\""))
        #expect(prompt.contains("\"nonce\":\"nonce-123\""))
        #expect(!prompt.contains("\"tool\":\"tool_name\""))
        #expect(!prompt.contains("param1"))
    }

    @Test("parser recovers wrapped JSON tool envelope")
    func parserRecoversWrappedEnvelope() {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }

        let context = FoundationModelsToolCallingContext(nonce: "nonce-123")
        let response = """
        I will use a tool.
        ```json
        {"conduit_tool_call":{"arguments":{"location":"San Francisco"},"nonce":"nonce-123","tool":"getWeather"}}
        ```
        """

        let parsed = FoundationModelsToolParser.parseToolCalls(
            from: response,
            availableTools: [foundationModelsPromptWeatherTool],
            context: context
        )

        #expect(parsed?.count == 1)
        #expect(parsed?.first?.toolName == "getWeather")
        #expect(parsed?.first?.arguments.jsonString.contains("San Francisco") == true)
    }

    @Test("stripCodeFences removes json fences for structured responses")
    func stripCodeFencesRemovesJSONFences() {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }

        let provider = FoundationModelsProvider()
        let stripped = provider.stripCodeFences("```json\n{\"ok\":true}\n```", for: .jsonObject)
        #expect(stripped == "{\"ok\":true}")
    }
}
#endif
