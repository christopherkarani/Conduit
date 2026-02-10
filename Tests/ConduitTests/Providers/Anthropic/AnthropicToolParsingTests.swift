// AnthropicToolParsingTests.swift
// Conduit Tests
//
// Tests for Anthropic tool call response parsing.
// TDD Red Phase: These tests should fail until implementation is complete.

#if CONDUIT_TRAIT_ANTHROPIC
import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("Anthropic Tool Parsing Tests")
struct AnthropicToolParsingTests {

    // MARK: - ContentBlock Parsing Tests

    @Suite("ContentBlock Decoding")
    struct ContentBlockDecodingTests {

        @Test("Decode text content block")
        func decodeTextContentBlock() throws {
            let json = """
            {
                "type": "text",
                "text": "I'll check the weather for you."
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }

            let block = try JSONDecoder().decode(
                AnthropicMessagesResponse.ContentBlock.self,
                from: data
            )

            #expect(block.type == "text")
            #expect(block.text == "I'll check the weather for you.")
        }

        @Test("Decode tool_use content block")
        func decodeToolUseContentBlock() throws {
            let json = """
            {
                "type": "tool_use",
                "id": "toolu_01ABC123",
                "name": "get_weather",
                "input": {"city": "San Francisco", "units": "celsius"}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }

            let block = try JSONDecoder().decode(
                AnthropicMessagesResponse.ContentBlock.self,
                from: data
            )

            #expect(block.type == "tool_use")
            #expect(block.id == "toolu_01ABC123")
            #expect(block.name == "get_weather")
            #expect(block.input != nil)
        }

        @Test("Decode tool_use with complex nested input")
        func decodeToolUseWithComplexInput() throws {
            let json = """
            {
                "type": "tool_use",
                "id": "toolu_01XYZ789",
                "name": "search_database",
                "input": {
                    "query": "swift programming",
                    "filters": {
                        "language": "en",
                        "year": 2024
                    },
                    "limit": 10,
                    "include_metadata": true
                }
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }

            let block = try JSONDecoder().decode(
                AnthropicMessagesResponse.ContentBlock.self,
                from: data
            )

            #expect(block.type == "tool_use")
            #expect(block.id == "toolu_01XYZ789")
            #expect(block.name == "search_database")
            #expect(block.input != nil)
        }

        @Test("Decode tool_use with empty input")
        func decodeToolUseWithEmptyInput() throws {
            let json = """
            {
                "type": "tool_use",
                "id": "toolu_01EMPTY",
                "name": "get_current_time",
                "input": {}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }

            let block = try JSONDecoder().decode(
                AnthropicMessagesResponse.ContentBlock.self,
                from: data
            )

            #expect(block.type == "tool_use")
            #expect(block.id == "toolu_01EMPTY")
            #expect(block.name == "get_current_time")
            #expect(block.input != nil)
        }
    }

    // MARK: - Full Response Parsing Tests

    @Suite("Full Response Parsing")
    struct FullResponseParsingTests {

        @Test("Parse response with single tool_use block")
        func parseSingleToolUseBlock() throws {
            let json = """
            {
                "id": "msg_123",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "I'll get the weather."},
                    {"type": "tool_use", "id": "toolu_01", "name": "get_weather", "input": {"city": "SF"}}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 100, "output_tokens": 50}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }

            let response = try JSONDecoder().decode(
                AnthropicMessagesResponse.self,
                from: data
            )

            #expect(response.content.count == 2)
            #expect(response.stopReason == "tool_use")

            // First block should be text
            let textBlock = response.content[0]
            #expect(textBlock.type == "text")
            #expect(textBlock.text == "I'll get the weather.")

            // Second block should be tool_use
            let toolBlock = response.content[1]
            #expect(toolBlock.type == "tool_use")
            #expect(toolBlock.id == "toolu_01")
            #expect(toolBlock.name == "get_weather")
        }

        @Test("Parse response with multiple tool_use blocks")
        func parseMultipleToolUseBlocks() throws {
            let json = """
            {
                "id": "msg_456",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "tool_use", "id": "toolu_01", "name": "get_weather", "input": {"city": "SF"}},
                    {"type": "tool_use", "id": "toolu_02", "name": "get_time", "input": {"timezone": "PST"}}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 100, "output_tokens": 80}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }

            let response = try JSONDecoder().decode(
                AnthropicMessagesResponse.self,
                from: data
            )

            #expect(response.content.count == 2)
            #expect(response.stopReason == "tool_use")

            #expect(response.content[0].type == "tool_use")
            #expect(response.content[0].id == "toolu_01")
            #expect(response.content[0].name == "get_weather")

            #expect(response.content[1].type == "tool_use")
            #expect(response.content[1].id == "toolu_02")
            #expect(response.content[1].name == "get_time")
        }

        @Test("Parse text-only response has no tool_use")
        func parseTextOnlyResponse() throws {
            let json = """
            {
                "id": "msg_789",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "Hello! How can I help you today?"}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 50, "output_tokens": 10}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }

            let response = try JSONDecoder().decode(
                AnthropicMessagesResponse.self,
                from: data
            )

            #expect(response.content.count == 1)
            #expect(response.content[0].type == "text")
            #expect(response.stopReason == "end_turn")

            // No tool_use blocks
            let toolBlocks = response.content.filter { $0.type == "tool_use" }
            #expect(toolBlocks.isEmpty)
        }
    }

    // MARK: - GenerationResult Conversion Tests

    @Suite("GenerationResult Conversion")
    struct GenerationResultConversionTests {

        @Test("convertToGenerationResult extracts tool calls")
        func extractToolCalls() async throws {
            // Create a mock provider
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            // Create a mock response with tool_use
            let json = """
            {
                "id": "msg_tool",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "Let me check that."},
                    {"type": "tool_use", "id": "toolu_abc", "name": "calculator", "input": {"expression": "2+2"}}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 100, "output_tokens": 30}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            // Convert to GenerationResult
            let startTime = Date()
            let result = try await provider.convertToGenerationResult(response, startTime: startTime)

            // Verify tool calls are extracted
            #expect(result.hasToolCalls)
            #expect(result.toolCalls.count == 1)
            #expect(result.toolCalls[0].id == "toolu_abc")
            #expect(result.toolCalls[0].toolName == "calculator")
            #expect(result.finishReason == .toolCall)
        }

        @Test("convertToGenerationResult extracts multiple tool calls")
        func extractMultipleToolCalls() async throws {
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            let json = """
            {
                "id": "msg_multi",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "tool_use", "id": "toolu_1", "name": "weather", "input": {"city": "NYC"}},
                    {"type": "tool_use", "id": "toolu_2", "name": "stock", "input": {"symbol": "AAPL"}}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 100, "output_tokens": 50}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            let result = try await provider.convertToGenerationResult(response, startTime: Date())

            #expect(result.hasToolCalls)
            #expect(result.toolCalls.count == 2)
            #expect(result.toolCalls[0].toolName == "weather")
            #expect(result.toolCalls[1].toolName == "stock")
        }

        @Test("convertToGenerationResult preserves text with tool calls")
        func preserveTextWithToolCalls() async throws {
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            let json = """
            {
                "id": "msg_mixed",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "I'll help you with that calculation."},
                    {"type": "tool_use", "id": "toolu_calc", "name": "calculator", "input": {"a": 5, "b": 3}}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 100, "output_tokens": 40}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            let result = try await provider.convertToGenerationResult(response, startTime: Date())

            // Text should be preserved
            #expect(result.text == "I'll help you with that calculation.")

            // Tool calls should also be present
            #expect(result.hasToolCalls)
            #expect(result.toolCalls[0].toolName == "calculator")
        }

        @Test("convertToGenerationResult handles no tool calls")
        func handleNoToolCalls() async throws {
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            let json = """
            {
                "id": "msg_text",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "Just a simple response."}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 50, "output_tokens": 10}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            let result = try await provider.convertToGenerationResult(response, startTime: Date())

            #expect(!result.hasToolCalls)
            #expect(result.toolCalls.isEmpty)
            #expect(result.finishReason == .stop)
        }
    }

    // MARK: - Stop Reason Mapping Tests

    @Suite("Stop Reason Mapping")
    struct StopReasonMappingTests {

        @Test("tool_use stop reason maps to FinishReason.toolCall")
        func toolUseStopReasonMapsToToolCall() async throws {
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            let json = """
            {
                "id": "msg_stop",
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "tool_use", "id": "toolu_x", "name": "test", "input": {}}
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 10, "output_tokens": 5}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            let result = try await provider.convertToGenerationResult(response, startTime: Date())

            #expect(result.finishReason == .toolCall)
        }

        @Test("end_turn stop reason maps to FinishReason.stop")
        func endTurnStopReasonMapsToStop() async throws {
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            let json = """
            {
                "id": "msg_end",
                "type": "message",
                "role": "assistant",
                "content": [{"type": "text", "text": "Done."}],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 10, "output_tokens": 1}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            let result = try await provider.convertToGenerationResult(response, startTime: Date())

            #expect(result.finishReason == .stop)
        }
    }

    // MARK: - Tool Arguments Parsing Tests

    @Suite("Tool Arguments Parsing")
    struct ToolArgumentsParsingTests {

        @Test("Tool arguments are properly serialized to Data")
        func toolArgumentsSerializedToData() async throws {
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            let json = """
            {
                "id": "msg_args",
                "type": "message",
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "toolu_args",
                        "name": "search",
                        "input": {
                            "query": "swift programming",
                            "limit": 5,
                            "include_snippets": true
                        }
                    }
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 50, "output_tokens": 20}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            let result = try await provider.convertToGenerationResult(response, startTime: Date())

            #expect(result.toolCalls.count == 1)

            let toolCall = result.toolCalls[0]
            let argsData = try toolCall.argumentsData()

            // Should be valid JSON data
            let argsDict = try JSONSerialization.jsonObject(with: argsData) as? [String: Any]
            #expect(argsDict?["query"] as? String == "swift programming")
            #expect(argsDict?["limit"] as? Int == 5)
            #expect(argsDict?["include_snippets"] as? Bool == true)
        }

        @Test("Tool arguments string representation works")
        func toolArgumentsStringRepresentation() async throws {
            let provider = AnthropicProvider(apiKey: "sk-ant-test")

            let json = """
            {
                "id": "msg_str",
                "type": "message",
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "toolu_str",
                        "name": "echo",
                        "input": {"message": "Hello World"}
                    }
                ],
                "model": "claude-sonnet-4-5-20250929",
                "stop_reason": "tool_use",
                "usage": {"input_tokens": 20, "output_tokens": 10}
            }
            """
            guard let data = json.data(using: .utf8) else {
                Issue.record("Failed to convert test JSON to Data")
                return
            }
            let response = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)

            let result = try await provider.convertToGenerationResult(response, startTime: Date())

            let toolCall = result.toolCalls[0]
            let argsString = toolCall.argumentsString

            #expect(argsString.contains("Hello World"))
        }
    }
}

#endif // CONDUIT_TRAIT_ANTHROPIC
