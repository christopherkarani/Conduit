// GenerationChunkTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("GenerationChunk Tests")
struct GenerationChunkTests {

    // MARK: - Initialization

    @Test("Default init stores text with default values")
    func defaultInit() {
        let chunk = GenerationChunk(text: "Hello")

        #expect(chunk.text == "Hello")
        #expect(chunk.tokenCount == 1)
        #expect(chunk.tokenId == nil)
        #expect(chunk.logprob == nil)
        #expect(chunk.topLogprobs == nil)
        #expect(chunk.tokensPerSecond == nil)
        #expect(!chunk.isComplete)
        #expect(chunk.finishReason == nil)
        #expect(chunk.usage == nil)
        #expect(chunk.partialToolCall == nil)
        #expect(chunk.completedToolCalls == nil)
        #expect(chunk.reasoningDetails == nil)
    }

    @Test("Full init stores all properties")
    func fullInit() {
        let timestamp = Date()
        let usage = UsageStats(promptTokens: 10, completionTokens: 20)
        let logprob = TokenLogprob(token: "hello", logprob: -0.5)

        let chunk = GenerationChunk(
            text: "test",
            tokenCount: 2,
            tokenId: 42,
            logprob: -0.3,
            topLogprobs: [logprob],
            tokensPerSecond: 50.0,
            isComplete: true,
            finishReason: .stop,
            timestamp: timestamp,
            usage: usage
        )

        #expect(chunk.text == "test")
        #expect(chunk.tokenCount == 2)
        #expect(chunk.tokenId == 42)
        #expect(chunk.logprob == -0.3)
        #expect(chunk.topLogprobs?.count == 1)
        #expect(chunk.tokensPerSecond == 50.0)
        #expect(chunk.isComplete)
        #expect(chunk.finishReason == .stop)
        #expect(chunk.timestamp == timestamp)
        #expect(chunk.usage == usage)
    }

    // MARK: - Factory Methods

    @Test(".completion() creates final chunk with empty text")
    func completionFactory() {
        let chunk = GenerationChunk.completion(finishReason: .stop)

        #expect(chunk.text == "")
        #expect(chunk.tokenCount == 0)
        #expect(chunk.isComplete)
        #expect(chunk.finishReason == .stop)
    }

    @Test(".completion() with maxTokens reason")
    func completionMaxTokens() {
        let chunk = GenerationChunk.completion(finishReason: .maxTokens)

        #expect(chunk.isComplete)
        #expect(chunk.finishReason == .maxTokens)
    }

    // MARK: - Computed Properties

    @Test("hasToolCallUpdates is false with no tool data")
    func hasToolCallUpdatesFalse() {
        let chunk = GenerationChunk(text: "test")
        #expect(!chunk.hasToolCallUpdates)
    }

    @Test("hasToolCallUpdates is true with partial tool call")
    func hasToolCallUpdatesPartial() {
        let partial = PartialToolCall(
            id: "call-1",
            toolName: "weather",
            index: 0,
            argumentsFragment: "{\"loc\":"
        )
        let chunk = GenerationChunk(text: "", partialToolCall: partial)
        #expect(chunk.hasToolCallUpdates)
    }

    @Test("hasToolCallUpdates is true with completed tool calls")
    func hasToolCallUpdatesCompleted() {
        let toolCall = Transcript.ToolCall(
            id: "call-1",
            toolName: "weather",
            arguments: GeneratedContent.null
        )
        let chunk = GenerationChunk(text: "", completedToolCalls: [toolCall])
        #expect(chunk.hasToolCallUpdates)
    }

    @Test("hasToolCallUpdates is false with empty completed tool calls array")
    func hasToolCallUpdatesEmptyCompleted() {
        let chunk = GenerationChunk(text: "", completedToolCalls: [])
        #expect(!chunk.hasToolCallUpdates)
    }

    @Test("hasReasoningDetails is false with nil")
    func hasReasoningDetailsFalse() {
        let chunk = GenerationChunk(text: "test")
        #expect(!chunk.hasReasoningDetails)
    }

    @Test("hasReasoningDetails is false with empty array")
    func hasReasoningDetailsEmpty() {
        let chunk = GenerationChunk(text: "test", reasoningDetails: [])
        #expect(!chunk.hasReasoningDetails)
    }

    // MARK: - Equatable

    @Test("Equal chunks are equal")
    func equality() {
        let timestamp = Date()
        let a = GenerationChunk(text: "hello", timestamp: timestamp)
        let b = GenerationChunk(text: "hello", timestamp: timestamp)
        #expect(a == b)
    }

    @Test("Different text makes chunks unequal")
    func inequalityText() {
        let timestamp = Date()
        let a = GenerationChunk(text: "hello", timestamp: timestamp)
        let b = GenerationChunk(text: "world", timestamp: timestamp)
        #expect(a != b)
    }

    @Test("Different timestamps make chunks unequal")
    func inequalityTimestamp() {
        let a = GenerationChunk(text: "hello", timestamp: Date(timeIntervalSince1970: 0))
        let b = GenerationChunk(text: "hello", timestamp: Date(timeIntervalSince1970: 1))
        #expect(a != b)
    }
}

// MARK: - maxToolCallIndex Tests

@Suite("maxToolCallIndex Tests")
struct MaxToolCallIndexTests {

    @Test("maxToolCallIndex is 100")
    func value() {
        #expect(maxToolCallIndex == 100)
    }
}
