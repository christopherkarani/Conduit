// OpenAIToolParsingTests.swift
// Conduit Tests
//
// Tests for OpenAI tool call response parsing.
// TDD Red Phase: These tests should fail until implementation is complete.

import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("OpenAI Tool Parsing Tests")
struct OpenAIToolParsingTests {

    // MARK: - Response Parsing Tests

    @Suite("Response Parsing")
    struct ResponseParsingTests {

        @Test("Parse response with single tool call")
        func parseSingleToolCall() async throws {
            let json = """
            {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_abc123",
                            "type": "function",
                            "function": {
                                "name": "get_weather",
                                "arguments": "{\\"city\\": \\"San Francisco\\", \\"units\\": \\"celsius\\"}"
                            }
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {
                    "prompt_tokens": 100,
                    "completion_tokens": 50,
                    "total_tokens": 150
                }
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.hasToolCalls)
            #expect(result.toolCalls.count == 1)
            #expect(result.toolCalls[0].id == "call_abc123")
            #expect(result.toolCalls[0].toolName == "get_weather")
            #expect(result.finishReason == .toolCalls)
        }

        @Test("Parse response with multiple tool calls")
        func parseMultipleToolCalls() async throws {
            let json = """
            {
                "id": "chatcmpl-456",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [
                            {
                                "id": "call_1",
                                "type": "function",
                                "function": {
                                    "name": "get_weather",
                                    "arguments": "{\\"city\\": \\"NYC\\"}"
                                }
                            },
                            {
                                "id": "call_2",
                                "type": "function",
                                "function": {
                                    "name": "get_stock_price",
                                    "arguments": "{\\"symbol\\": \\"AAPL\\"}"
                                }
                            }
                        ]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {
                    "prompt_tokens": 100,
                    "completion_tokens": 80,
                    "total_tokens": 180
                }
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.hasToolCalls)
            #expect(result.toolCalls.count == 2)
            #expect(result.toolCalls[0].id == "call_1")
            #expect(result.toolCalls[0].toolName == "get_weather")
            #expect(result.toolCalls[1].id == "call_2")
            #expect(result.toolCalls[1].toolName == "get_stock_price")
        }

        @Test("Parse response with text and no tool calls")
        func parseTextOnlyResponse() async throws {
            let json = """
            {
                "id": "chatcmpl-789",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "Hello! How can I help you today?"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 50,
                    "completion_tokens": 10,
                    "total_tokens": 60
                }
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(!result.hasToolCalls)
            #expect(result.toolCalls.isEmpty)
            #expect(result.text == "Hello! How can I help you today?")
            #expect(result.finishReason == .stop)
        }

        @Test("Parse response with content and tool calls together")
        func parseContentWithToolCalls() async throws {
            let json = """
            {
                "id": "chatcmpl-mixed",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "I'll check that for you.",
                        "tool_calls": [{
                            "id": "call_mixed",
                            "type": "function",
                            "function": {
                                "name": "search",
                                "arguments": "{\\"query\\": \\"test\\"}"
                            }
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {
                    "prompt_tokens": 50,
                    "completion_tokens": 30,
                    "total_tokens": 80
                }
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            // Both text and tool calls should be present
            #expect(result.text == "I'll check that for you.")
            #expect(result.hasToolCalls)
            #expect(result.toolCalls[0].toolName == "search")
        }
    }

    // MARK: - Finish Reason Mapping Tests

    @Suite("Finish Reason Mapping")
    struct FinishReasonMappingTests {

        @Test("finish_reason tool_calls maps to FinishReason.toolCall")
        func toolCallsFinishReason() async throws {
            let json = """
            {
                "id": "chatcmpl-finish",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_x",
                            "type": "function",
                            "function": {"name": "test", "arguments": "{}"}
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.finishReason == .toolCalls)
        }

        @Test("finish_reason stop maps to FinishReason.stop")
        func stopFinishReason() async throws {
            let json = """
            {
                "id": "chatcmpl-stop",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "Done."},
                    "finish_reason": "stop"
                }],
                "usage": {"prompt_tokens": 10, "completion_tokens": 1, "total_tokens": 11}
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.finishReason == .stop)
        }

        @Test("finish_reason length maps to FinishReason.maxTokens")
        func lengthFinishReason() async throws {
            let json = """
            {
                "id": "chatcmpl-length",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "Truncated text..."},
                    "finish_reason": "length"
                }],
                "usage": {"prompt_tokens": 10, "completion_tokens": 100, "total_tokens": 110}
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.finishReason == .maxTokens)
        }

        @Test("finish_reason content_filter maps to FinishReason.contentFilter")
        func contentFilterFinishReason() async throws {
            let json = """
            {
                "id": "chatcmpl-filter",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": ""},
                    "finish_reason": "content_filter"
                }],
                "usage": {"prompt_tokens": 10, "completion_tokens": 0, "total_tokens": 10}
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.finishReason == .contentFilter)
        }
    }

    // MARK: - Tool Arguments Tests

    @Suite("Tool Arguments")
    struct ToolArgumentsTests {

        @Test("Tool arguments JSON string is parseable")
        func toolArgumentsJSONParseable() async throws {
            let json = """
            {
                "id": "chatcmpl-args",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_args",
                            "type": "function",
                            "function": {
                                "name": "create_user",
                                "arguments": "{\\"name\\": \\"John\\", \\"age\\": 30, \\"active\\": true}"
                            }
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {"prompt_tokens": 50, "completion_tokens": 20, "total_tokens": 70}
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.toolCalls.count == 1)

            let toolCall = result.toolCalls[0]
            let argsData = try toolCall.argumentsData()

            // Should be valid JSON
            let argsDict = try JSONSerialization.jsonObject(with: argsData) as? [String: Any]
            #expect(argsDict?["name"] as? String == "John")
            #expect(argsDict?["age"] as? Int == 30)
            #expect(argsDict?["active"] as? Bool == true)
        }

        @Test("Tool with empty arguments works")
        func emptyArguments() async throws {
            let json = """
            {
                "id": "chatcmpl-empty",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_empty",
                            "type": "function",
                            "function": {
                                "name": "get_current_time",
                                "arguments": "{}"
                            }
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {"prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30}
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.toolCalls.count == 1)
            #expect(result.toolCalls[0].toolName == "get_current_time")

            let argsData = try result.toolCalls[0].argumentsData()
            let argsDict = try JSONSerialization.jsonObject(with: argsData) as? [String: Any]
            #expect(argsDict?.isEmpty == true)
        }

        @Test("Tool arguments string representation")
        func argumentsStringRepresentation() async throws {
            let json = """
            {
                "id": "chatcmpl-str",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_str",
                            "type": "function",
                            "function": {
                                "name": "echo",
                                "arguments": "{\\"message\\": \\"Hello World\\"}"
                            }
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {"prompt_tokens": 15, "completion_tokens": 8, "total_tokens": 23}
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            let argsString = result.toolCalls[0].argumentsString
            #expect(argsString.contains("Hello World"))
        }
    }

    // MARK: - Usage Statistics Tests

    @Suite("Usage Statistics")
    struct UsageStatisticsTests {

        @Test("Usage stats are captured with tool calls")
        func usageStatsWithToolCalls() async throws {
            let json = """
            {
                "id": "chatcmpl-usage",
                "object": "chat.completion",
                "created": 1699000000,
                "model": "gpt-4",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_usage",
                            "type": "function",
                            "function": {"name": "test", "arguments": "{}"}
                        }]
                    },
                    "finish_reason": "tool_calls"
                }],
                "usage": {
                    "prompt_tokens": 150,
                    "completion_tokens": 75,
                    "total_tokens": 225
                }
            }
            """

            let provider = OpenAIProvider(apiKey: "sk-test")
            let data = json.data(using: .utf8)!
            let result = try await provider.parseGenerationResponse(data: data)

            #expect(result.usage?.promptTokens == 150)
            #expect(result.usage?.completionTokens == 75)
        }
    }
}
