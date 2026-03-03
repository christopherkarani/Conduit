// ToolMessageTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("ToolMessage Tests")
struct ToolMessageTests {

    // MARK: - Transcript.ToolCall Helpers

    @Test("ToolCall argumentsString returns JSON")
    func toolCallArgumentsString() {
        let content = GeneratedContent(kind: .structure(
            properties: ["location": GeneratedContent(kind: .string("San Francisco"))],
            orderedKeys: ["location"]
        ))
        let call = Transcript.ToolCall(
            id: "call-1",
            toolName: "get_weather",
            arguments: content
        )

        let argsString = call.argumentsString
        #expect(argsString.contains("San Francisco"))
    }

    @Test("ToolCall argumentsData returns valid data")
    func toolCallArgumentsData() throws {
        let content = GeneratedContent(kind: .structure(
            properties: ["query": GeneratedContent(kind: .string("test"))],
            orderedKeys: ["query"]
        ))
        let call = Transcript.ToolCall(
            id: "call-1",
            toolName: "search",
            arguments: content
        )

        let data = try call.argumentsData()
        #expect(!data.isEmpty)
    }

    // MARK: - Transcript.ToolOutput Helpers

    @Test("ToolOutput text extracts text segments")
    func toolOutputText() {
        let output = Transcript.ToolOutput(
            id: "call-1",
            toolName: "search",
            segments: [
                .text(Transcript.TextSegment(content: "Result 1")),
                .text(Transcript.TextSegment(content: "Result 2"))
            ]
        )

        let text = output.text
        #expect(text.contains("Result 1"))
        #expect(text.contains("Result 2"))
    }

    @Test("ToolOutput init from call preserves id and name")
    func toolOutputFromCall() {
        let call = Transcript.ToolCall(
            id: "call-42",
            toolName: "calculator",
            arguments: GeneratedContent(kind: .null)
        )

        let output = Transcript.ToolOutput(
            call: call,
            segments: [.text(Transcript.TextSegment(content: "42"))]
        )

        #expect(output.id == "call-42")
        #expect(output.toolName == "calculator")
        #expect(output.text == "42")
    }

    // MARK: - Message.toolOutput

    @Test("Message.toolOutput creates tool role message")
    func messageToolOutput() {
        let output = Transcript.ToolOutput(
            id: "call-1",
            toolName: "weather",
            segments: [.text(Transcript.TextSegment(content: "Sunny, 72°F"))]
        )

        let message = Message.toolOutput(output)

        #expect(message.role == .tool)
        #expect(message.content.textValue == "Sunny, 72°F")
        #expect(message.metadata?.custom?["tool_call_id"] == "call-1")
        #expect(message.metadata?.custom?["tool_name"] == "weather")
    }

    @Test("Message.toolOutput from call and content")
    func messageToolOutputFromCallAndContent() {
        let call = Transcript.ToolCall(
            id: "call-1",
            toolName: "search",
            arguments: GeneratedContent(kind: .null)
        )

        let message = Message.toolOutput(call: call, content: "Found 5 results")

        #expect(message.role == .tool)
        #expect(message.content.textValue == "Found 5 results")
    }

    // MARK: - Collection Extension

    @Test("call(named:) finds tool call by name")
    func callNamed() {
        let calls = [
            Transcript.ToolCall(id: "1", toolName: "weather", arguments: GeneratedContent(kind: .null)),
            Transcript.ToolCall(id: "2", toolName: "search", arguments: GeneratedContent(kind: .null)),
            Transcript.ToolCall(id: "3", toolName: "calculator", arguments: GeneratedContent(kind: .null))
        ]

        let found = calls.call(named: "search")
        #expect(found?.id == "2")
    }

    @Test("call(named:) returns nil when not found")
    func callNamedNotFound() {
        let calls = [
            Transcript.ToolCall(id: "1", toolName: "weather", arguments: GeneratedContent(kind: .null))
        ]

        let found = calls.call(named: "nonexistent")
        #expect(found == nil)
    }

    @Test("calls(named:) filters multiple matches")
    func callsNamed() {
        let calls = [
            Transcript.ToolCall(id: "1", toolName: "search", arguments: GeneratedContent(kind: .null)),
            Transcript.ToolCall(id: "2", toolName: "weather", arguments: GeneratedContent(kind: .null)),
            Transcript.ToolCall(id: "3", toolName: "search", arguments: GeneratedContent(kind: .null))
        ]

        let found = calls.calls(named: "search")
        #expect(found.count == 2)
    }

    @Test("calls(named:) returns empty when no matches")
    func callsNamedEmpty() {
        let calls = [
            Transcript.ToolCall(id: "1", toolName: "weather", arguments: GeneratedContent(kind: .null))
        ]

        let found = calls.calls(named: "nonexistent")
        #expect(found.isEmpty)
    }
}
