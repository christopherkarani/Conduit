// OpenAIProviderRequestBuildingTests.swift
// Conduit Tests
//
// Tests for OpenAI/OpenRouter request building details (tools + reasoning).

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Generable
private struct RootResolvedAddress {
    let city: String
    let country: String
}

@Generable
private struct RootResolvedArgs {
    let location: RootResolvedAddress
}

@Suite("OpenAI Provider Request Building Tests")
struct OpenAIProviderRequestBuildingTests {

    @Test("Tool output messages include tool_call_id for OpenAI/OpenRouter")
    func toolOutputMessagesIncludeToolCallID() async throws {
        let provider = OpenAIProvider(configuration: .openRouter(apiKey: "or-test"))

        let call = try Transcript.ToolCall(id: "call_1", toolName: "get_weather", argumentsJSON: #"{"city":"SF"}"#)
        let toolMessage = Message.toolOutput(call: call, content: "72F and sunny")

        let body = provider.buildRequestBody(
            messages: [toolMessage],
            model: .openRouter("anthropic/claude-3-opus"),
            config: .default,
            stream: false
        )

        let messages = try #require(body["messages"] as? [[String: Any]])
        let first = try #require(messages.first)

        #expect(first["role"] as? String == "tool")
        #expect(first["tool_call_id"] as? String == "call_1")
        #expect(first["content"] as? String == "72F and sunny")
    }

    @Test("Assistant tool calls are serialized in request history")
    func assistantToolCallsSerialized() async throws {
        let provider = OpenAIProvider(configuration: .openRouter(apiKey: "or-test"))

        let call = try Transcript.ToolCall(
            id: "call_2",
            toolName: "lookup_stock",
            argumentsJSON: #"{"ticker":"ACME"}"#
        )
        let assistantMessage = Message.assistant(toolCalls: [call])

        let body = provider.buildRequestBody(
            messages: [assistantMessage],
            model: .openRouter("openai/gpt-4o"),
            config: .default,
            stream: false
        )

        let messages = try #require(body["messages"] as? [[String: Any]])
        let first = try #require(messages.first)

        #expect(first["role"] as? String == "assistant")

        let toolCalls = try #require(first["tool_calls"] as? [[String: Any]])
        let toolCall = try #require(toolCalls.first)
        let function = try #require(toolCall["function"] as? [String: Any])

        #expect(toolCall["id"] as? String == "call_2")
        #expect(toolCall["type"] as? String == "function")
        #expect(function["name"] as? String == "lookup_stock")
        #expect(function["arguments"] as? String == #"{"ticker":"ACME"}"#)
    }

    @Test("Non-stream finish_reason tool_calls maps to FinishReason.toolCalls")
    func finishReasonToolCallsMapsCorrectly() async throws {
        let provider = OpenAIProvider(configuration: .openRouter(apiKey: "or-test"))

        let response: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "content": NSNull(),
                        "tool_calls": []
                    ],
                    "finish_reason": "tool_calls"
                ]
            ],
            "usage": [
                "prompt_tokens": 1,
                "completion_tokens": 1
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: response)
        let result = try await provider.parseGenerationResponse(data: data)

        #expect(result.finishReason == .toolCalls)
    }

    @Test("Non-stream reasoning text parsed from message")
    func reasoningTextParsed() async throws {
        let provider = OpenAIProvider(configuration: .openRouter(apiKey: "or-test"))

        let response: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "content": "Answer",
                        "reasoning": "Because of X"
                    ],
                    "finish_reason": "stop"
                ]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: response)
        let result = try await provider.parseGenerationResponse(data: data)

        #expect(result.reasoningDetails.count == 1)
        #expect(result.reasoningDetails.first?.content == "Because of X")
    }

    @Test("OpenRouter reasoning enables include_reasoning unless exclude=true")
    func openRouterIncludeReasoningFlag() async throws {
        let provider = OpenAIProvider(configuration: .openRouter(apiKey: "or-test"))

        let body = provider.buildRequestBody(
            messages: [.user("Hi")],
            model: .openRouter("anthropic/claude-3-opus"),
            config: .default.reasoning(.high),
            stream: false
        )

        #expect(body["include_reasoning"] as? Bool == true)

        if let reasoning = body["reasoning"] as? [String: Any] {
            #expect(reasoning["effort"] as? String == "high")
        } else {
            Issue.record("Expected reasoning object in request body")
        }

        let excludedBody = provider.buildRequestBody(
            messages: [.user("Hi")],
            model: .openRouter("anthropic/claude-3-opus"),
            config: .default.reasoning(ReasoningConfig(effort: .high, exclude: true)),
            stream: false
        )

        #expect(excludedBody["include_reasoning"] as? Bool == nil)
    }

    @Test("OpenRouter provider routing uses slugs and latency sort")
    func openRouterProviderRoutingUsesSlugs() async throws {
        let routing = OpenRouterRoutingConfig(
            providers: [.anthropic, .openai],
            fallbacks: false,
            routeByLatency: true,
            dataCollection: .deny
        )
        let provider = OpenAIProvider(configuration: .openRouter(apiKey: "or-test").openRouter(routing))

        let body = provider.buildRequestBody(
            messages: [.user("Hi")],
            model: .openRouter("anthropic/claude-3-opus"),
            config: .default,
            stream: false
        )

        let providerObj = try #require(body["provider"] as? [String: Any])
        #expect(providerObj["order"] as? [String] == ["anthropic", "openai"])
        #expect(providerObj["allow_fallbacks"] as? Bool == false)
        #expect(providerObj["sort"] as? String == "latency")
        #expect(providerObj["data_collection"] as? String == "deny")
    }

    @Test("Tool parameters resolve root refs before OpenAI serialization")
    func toolParametersResolveRootRefs() async throws {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test"))
        let tool = Transcript.ToolDefinition(
            name: "locate",
            description: "Locate a city",
            parameters: RootResolvedArgs.generationSchema
        )

        let body = provider.buildRequestBody(
            messages: [.user("Find me a location")],
            model: .gpt4o,
            config: .default.tools([tool]).toolChoice(.required),
            stream: false
        )

        let tools = try #require(body["tools"] as? [[String: Any]])
        let firstTool = try #require(tools.first)
        let function = try #require(firstTool["function"] as? [String: Any])
        let parameters = try #require(function["parameters"] as? [String: Any])

        #expect(parameters["type"] as? String == "object")
    }

    @Test("OpenAI request includes max_tool_calls when configured")
    func requestIncludesMaxToolCalls() async throws {
        let provider = OpenAIProvider(configuration: .openAI(apiKey: "sk-test"))
        let tool = Transcript.ToolDefinition(
            name: "locate",
            description: "Locate a city",
            parameters: RootResolvedArgs.generationSchema
        )

        let config = GenerateConfig.default
            .tools([tool])
            .toolChoice(.required)
            .parallelToolCalls(true)
            .maxToolCalls(2)

        let body = provider.buildRequestBody(
            messages: [.user("Find me a location")],
            model: .gpt4o,
            config: config,
            stream: false
        )

        #expect(body["max_tool_calls"] as? Int == 2)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
