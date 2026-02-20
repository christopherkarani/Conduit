// OpenAIAPIVariantTests.swift
// Conduit Tests
//
// Tests for OpenAI API variant routing and guarded behavior.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Generable
private struct ResponsesWeatherArgs {
    let city: String
}

@Suite("OpenAI API Variant Tests")
struct OpenAIAPIVariantTests {

    @Test("Default configuration uses chatCompletions variant")
    func defaultConfigurationVariant() {
        #expect(OpenAIConfiguration.default.apiVariant == .chatCompletions)
    }

    @Test("Configuration decodes legacy payload without apiVariant as chatCompletions")
    func configurationDecodesLegacyPayload() throws {
        let encoded = try JSONEncoder().encode(OpenAIConfiguration.default)
        var payload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        payload.removeValue(forKey: "apiVariant")

        let legacy = try JSONSerialization.data(withJSONObject: payload)
        let decoded = try JSONDecoder().decode(OpenAIConfiguration.self, from: legacy)

        #expect(decoded.apiVariant == .chatCompletions)
    }

    @Test("Endpoint selects chat completions or responses URL by variant")
    func endpointSelectsURLByVariant() {
        let endpoint = OpenAIEndpoint.openAI
        #expect(endpoint.textGenerationURL(for: .chatCompletions).absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(endpoint.textGenerationURL(for: .responses).absoluteString == "https://api.openai.com/v1/responses")
    }

    @Test("Request body uses responses input shape when variant is responses")
    func requestBodyUsesResponsesShape() throws {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test"))
        let body = provider.buildRequestBody(
            messages: [.user("Hello from user")],
            model: .gpt4o,
            config: .default,
            stream: false,
            variant: .responses
        )

        #expect(body["messages"] == nil)
        #expect(body["model"] as? String == "gpt-4o")

        let input = try #require(body["input"] as? [[String: Any]])
        let first = try #require(input.first)
        #expect(first["role"] as? String == "user")

        let content = try #require(first["content"] as? [[String: Any]])
        let firstContent = try #require(content.first)
        #expect(firstContent["type"] as? String == "input_text")
        #expect(firstContent["text"] as? String == "Hello from user")
    }

    @Test("Responses request serializes tools and function_call_output entries")
    func responsesRequestSerializesToolsAndToolOutputs() throws {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test"))
        let tool = Transcript.ToolDefinition(
            name: "get_weather",
            description: "Get weather",
            parameters: ResponsesWeatherArgs.generationSchema
        )

        let call = try Transcript.ToolCall(
            id: "call_weather",
            toolName: "get_weather",
            argumentsJSON: #"{"city":"SF"}"#
        )
        let assistant = Message.assistant(toolCalls: [call])
        let toolOutput = Message.toolOutput(call: call, content: "72F and sunny")

        let body = provider.buildRequestBody(
            messages: [.user("What is the weather?"), assistant, toolOutput],
            model: .gpt4o,
            config: .default.tools([tool]).toolChoice(.required).parallelToolCalls(false).maxToolCalls(2),
            stream: false,
            variant: .responses
        )

        let tools = try #require(body["tools"] as? [[String: Any]])
        let firstTool = try #require(tools.first)
        #expect(firstTool["name"] as? String == "get_weather")
        #expect(body["max_tool_calls"] as? Int == 2)

        let input = try #require(body["input"] as? [[String: Any]])
        let hasFunctionCallOutput = input.contains { ($0["type"] as? String) == "function_call_output" && ($0["call_id"] as? String) == "call_weather" }
        #expect(hasFunctionCallOutput)
    }

    @Test("Responses parser extracts output_text and usage")
    func responsesParserExtractsTextAndUsage() async throws {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test").apiVariant(.responses))

        let payload: [String: Any] = [
            "id": "resp_123",
            "output": [
                [
                    "type": "message",
                    "role": "assistant",
                    "content": [
                        [
                            "type": "output_text",
                            "text": "Hello from responses"
                        ]
                    ]
                ]
            ],
            "finish_reason": "stop",
            "usage": [
                "input_tokens": 12,
                "output_tokens": 4
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try await provider.parseGenerationResponse(data: data, variant: .responses)

        #expect(result.text == "Hello from responses")
        #expect(result.finishReason == .stop)
        #expect(result.usage?.promptTokens == 12)
        #expect(result.usage?.completionTokens == 4)
    }

    @Test("Responses parser extracts function_call output as tool call")
    func responsesParserExtractsToolCall() async throws {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test").apiVariant(.responses))

        let payload: [String: Any] = [
            "id": "resp_456",
            "output": [
                [
                    "type": "function_call",
                    "id": "fc_1",
                    "call_id": "call_1",
                    "name": "get_weather",
                    "arguments": #"{"city":"SF"}"#
                ]
            ],
            "finish_reason": "tool_calls",
            "usage": [
                "input_tokens": 11,
                "output_tokens": 7
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try await provider.parseGenerationResponse(data: data, variant: .responses)

        #expect(result.finishReason == .toolCalls)
        #expect(result.toolCalls.count == 1)
        #expect(result.toolCalls.first?.id == "call_1")
        #expect(result.toolCalls.first?.toolName == "get_weather")
    }

    @Test("Responses SSE event decoding handles output text and completion")
    func responsesSSEEventDecoding() {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test").apiVariant(.responses))

        let textEvent = provider.decodeResponsesEventData(
            #"{"type":"response.output_text.delta","delta":"Hello"}"#
        )
        #expect(textEvent?.kind == .outputTextDelta)
        #expect(textEvent?.textDelta == "Hello")

        let completionEvent = provider.decodeResponsesEventData(
            #"{"type":"response.completed","response":{"finish_reason":"stop","usage":{"input_tokens":3,"output_tokens":2}}}"#
        )
        #expect(completionEvent?.kind == .completed)
        #expect(completionEvent?.finishReason == .stop)
        #expect(completionEvent?.usage?.promptTokens == 3)
        #expect(completionEvent?.usage?.completionTokens == 2)
    }

    @Test("Responses SSE decoding ignores empty tool call ids")
    func responsesSSEDecodingSkipsEmptyToolCallIDs() {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test").apiVariant(.responses))

        let createdEvent = provider.decodeResponsesEventData(
            #"{"type":"response.tool_call.created","tool_call":{"call_id":"","name":"lookup","arguments":"{}"}}"#
        )
        #expect(createdEvent?.kind == .toolCallCreated)
        #expect(createdEvent?.toolCallID == "")
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
