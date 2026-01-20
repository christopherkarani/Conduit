// GenerationResultToolCallTests.swift
// Conduit Tests
//
// Tests for GenerationResult tool call support.
// TDD Red Phase: These tests should fail until implementation is complete.

import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("GenerationResult Tool Calls Tests")
struct GenerationResultToolCallTests {

    // MARK: - Basic Properties Tests

    @Suite("Tool Call Properties")
    struct ToolCallPropertiesTests {

        @Test("Empty toolCalls by default")
        func emptyToolCallsByDefault() {
            let result = GenerationResult.text("Hello world")
            #expect(result.toolCalls.isEmpty)
        }

        @Test("hasToolCalls returns false when no tools")
        func hasToolCallsReturnsFalseWhenNoTools() {
            let result = GenerationResult.text("Hello world")
            #expect(!result.hasToolCalls)
        }

        @Test("hasToolCalls returns true when tools present")
        func hasToolCallsReturnsTrueWhenPresent() throws {
            let toolCall = try Transcript.ToolCall(
                id: "call_123",
                toolName: "get_weather",
                argumentsJSON: #"{"city": "San Francisco"}"#
            )

            let result = GenerationResult(
                text: "",
                tokenCount: 10,
                generationTime: 0.5,
                tokensPerSecond: 20.0,
                finishReason: .toolCall,
                toolCalls: [toolCall]
            )

            #expect(result.hasToolCalls)
            #expect(result.toolCalls.count == 1)
        }

        @Test("toolCalls contains correct data")
        func toolCallsContainsCorrectData() throws {
            let toolCall = try Transcript.ToolCall(
                id: "call_abc123",
                toolName: "search_database",
                argumentsJSON: #"{"query": "test", "limit": 10}"#
            )

            let result = GenerationResult(
                text: "I'll search for that.",
                tokenCount: 5,
                generationTime: 0.3,
                tokensPerSecond: 16.7,
                finishReason: .toolCall,
                toolCalls: [toolCall]
            )

            #expect(result.toolCalls[0].id == "call_abc123")
            #expect(result.toolCalls[0].toolName == "search_database")
        }

        @Test("Multiple tool calls supported")
        func multipleToolCallsSupported() throws {
            let toolCall1 = try Transcript.ToolCall(
                id: "call_1",
                toolName: "get_weather",
                argumentsJSON: #"{"city": "SF"}"#
            )
            let toolCall2 = try Transcript.ToolCall(
                id: "call_2",
                toolName: "get_time",
                argumentsJSON: #"{"timezone": "PST"}"#
            )

            let result = GenerationResult(
                text: "",
                tokenCount: 0,
                generationTime: 0.1,
                tokensPerSecond: 0,
                finishReason: .toolCall,
                toolCalls: [toolCall1, toolCall2]
            )

            #expect(result.toolCalls.count == 2)
            #expect(result.toolCalls[0].toolName == "get_weather")
            #expect(result.toolCalls[1].toolName == "get_time")
        }
    }

    // MARK: - Equatable Tests

    @Suite("Equatable")
    struct EquatableTests {

        @Test("Results with same toolCalls are equal")
        func resultsWithSameToolCallsAreEqual() throws {
            let toolCall = try Transcript.ToolCall(
                id: "call_123",
                toolName: "test_tool",
                argumentsJSON: #"{}"#
            )

            let result1 = GenerationResult(
                text: "Test",
                tokenCount: 1,
                generationTime: 0.1,
                tokensPerSecond: 10.0,
                finishReason: .toolCall,
                toolCalls: [toolCall]
            )

            let result2 = GenerationResult(
                text: "Test",
                tokenCount: 1,
                generationTime: 0.1,
                tokensPerSecond: 10.0,
                finishReason: .toolCall,
                toolCalls: [toolCall]
            )

            #expect(result1 == result2)
        }

        @Test("Results with different toolCalls are not equal")
        func resultsWithDifferentToolCallsAreNotEqual() throws {
            let toolCall1 = try Transcript.ToolCall(
                id: "call_1",
                toolName: "tool_a",
                argumentsJSON: #"{}"#
            )
            let toolCall2 = try Transcript.ToolCall(
                id: "call_2",
                toolName: "tool_b",
                argumentsJSON: #"{}"#
            )

            let result1 = GenerationResult(
                text: "Test",
                tokenCount: 1,
                generationTime: 0.1,
                tokensPerSecond: 10.0,
                finishReason: .toolCall,
                toolCalls: [toolCall1]
            )

            let result2 = GenerationResult(
                text: "Test",
                tokenCount: 1,
                generationTime: 0.1,
                tokensPerSecond: 10.0,
                finishReason: .toolCall,
                toolCalls: [toolCall2]
            )

            #expect(result1 != result2)
        }

    }

    // MARK: - Factory Method Tests

    @Suite("Factory Methods")
    struct FactoryMethodTests {

        @Test("text() factory has empty toolCalls")
        func textFactoryHasEmptyToolCalls() {
            let result = GenerationResult.text("Simple response")
            #expect(result.toolCalls.isEmpty)
            #expect(!result.hasToolCalls)
        }
    }

    // MARK: - Finish Reason Tests

    @Suite("Finish Reason Integration")
    struct FinishReasonTests {

        @Test("toolCall finish reason with tool calls")
        func toolCallFinishReasonWithToolCalls() throws {
            let toolCall = try Transcript.ToolCall(
                id: "call_123",
                toolName: "test_tool",
                argumentsJSON: #"{}"#
            )

            let result = GenerationResult(
                text: "",
                tokenCount: 0,
                generationTime: 0.1,
                tokensPerSecond: 0,
                finishReason: .toolCall,
                toolCalls: [toolCall]
            )

            #expect(result.finishReason == .toolCall)
            #expect(result.hasToolCalls)
        }

        @Test("stop finish reason can have empty toolCalls")
        func stopFinishReasonCanHaveEmptyToolCalls() {
            let result = GenerationResult(
                text: "Regular response",
                tokenCount: 5,
                generationTime: 0.2,
                tokensPerSecond: 25.0,
                finishReason: .stop,
                toolCalls: []
            )

            #expect(result.finishReason == .stop)
            #expect(!result.hasToolCalls)
        }
    }

    // MARK: - Backward Compatibility Tests

    @Suite("Backward Compatibility")
    struct BackwardCompatibilityTests {

        @Test("Existing initializer still works")
        func existingInitializerStillWorks() {
            // This tests that code NOT passing toolCalls still compiles and works
            let result = GenerationResult(
                text: "Hello",
                tokenCount: 1,
                generationTime: 0.1,
                tokensPerSecond: 10.0,
                finishReason: .stop
            )

            #expect(result.text == "Hello")
            #expect(result.toolCalls.isEmpty)
        }

        @Test("Existing code patterns work unchanged")
        func existingCodePatternsWorkUnchanged() {
            // Simulate existing usage pattern
            let result = GenerationResult.text("Response")

            // Old patterns should work
            #expect(!result.text.isEmpty)
            #expect(result.finishReason == .stop)

            // New patterns also work
            #expect(!result.hasToolCalls)
        }
    }
}
