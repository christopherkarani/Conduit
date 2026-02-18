// GenerationResultTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("GenerationResult Tests")
struct GenerationResultTests {

    // MARK: - Initialization

    @Test("Full initialization stores all properties")
    func fullInit() {
        let usage = UsageStats(promptTokens: 10, completionTokens: 20)
        let rateLimit = RateLimitInfo(requestId: "req-1")
        let logprob = TokenLogprob(token: "hello", logprob: -0.5)

        let result = GenerationResult(
            text: "Hello world",
            tokenCount: 5,
            generationTime: 1.2,
            tokensPerSecond: 4.17,
            finishReason: .stop,
            logprobs: [logprob],
            usage: usage,
            rateLimitInfo: rateLimit,
            toolCalls: [],
            reasoningDetails: []
        )

        #expect(result.text == "Hello world")
        #expect(result.tokenCount == 5)
        #expect(result.generationTime == 1.2)
        #expect(result.tokensPerSecond == 4.17)
        #expect(result.finishReason == .stop)
        #expect(result.logprobs?.count == 1)
        #expect(result.usage == usage)
        #expect(result.rateLimitInfo == rateLimit)
        #expect(result.toolCalls.isEmpty)
        #expect(result.reasoningDetails.isEmpty)
    }

    @Test("Default parameters produce empty collections")
    func defaultParams() {
        let result = GenerationResult(
            text: "test",
            tokenCount: 1,
            generationTime: 0.1,
            tokensPerSecond: 10,
            finishReason: .stop
        )

        #expect(result.logprobs == nil)
        #expect(result.usage == nil)
        #expect(result.rateLimitInfo == nil)
        #expect(result.toolCalls.isEmpty)
        #expect(result.reasoningDetails.isEmpty)
    }

    // MARK: - Factory Methods

    @Test(".text() factory creates result with default metadata")
    func textFactory() {
        let result = GenerationResult.text("Hello")

        #expect(result.text == "Hello")
        #expect(result.tokenCount == 0)
        #expect(result.generationTime == 0)
        #expect(result.tokensPerSecond == 0)
        #expect(result.finishReason == .stop)
        #expect(result.toolCalls.isEmpty)
        #expect(result.reasoningDetails.isEmpty)
    }

    // MARK: - Computed Properties

    @Test("hasToolCalls returns false when no tool calls")
    func hasToolCallsFalse() {
        let result = GenerationResult.text("Hello")
        #expect(!result.hasToolCalls)
    }

    @Test("hasReasoningDetails returns false when empty")
    func hasReasoningDetailsFalse() {
        let result = GenerationResult.text("Hello")
        #expect(!result.hasReasoningDetails)
    }

    // MARK: - Equatable

    @Test("Equal results compare equal")
    func equality() {
        let a = GenerationResult.text("Hello")
        let b = GenerationResult.text("Hello")
        #expect(a == b)
    }

    @Test("Different text makes results unequal")
    func inequality() {
        let a = GenerationResult.text("Hello")
        let b = GenerationResult.text("World")
        #expect(a != b)
    }

    @Test("Different finish reasons make results unequal")
    func inequalityFinishReason() {
        let a = GenerationResult(
            text: "Hello", tokenCount: 0, generationTime: 0,
            tokensPerSecond: 0, finishReason: .stop
        )
        let b = GenerationResult(
            text: "Hello", tokenCount: 0, generationTime: 0,
            tokensPerSecond: 0, finishReason: .maxTokens
        )
        #expect(a != b)
    }

    // MARK: - Message Bridge

    @Test("assistantMessage creates message with correct role and content")
    func assistantMessage() {
        let result = GenerationResult(
            text: "Response text",
            tokenCount: 10,
            generationTime: 0.5,
            tokensPerSecond: 20,
            finishReason: .stop
        )

        let message = result.assistantMessage()

        #expect(message.role == .assistant)
        #expect(message.content.textValue == "Response text")
        #expect(message.metadata?.tokenCount == 10)
        #expect(message.metadata?.generationTime == 0.5)
        #expect(message.metadata?.tokensPerSecond == 20)
    }

    @Test("assistantMessage with no tool calls has nil toolCalls in metadata")
    func assistantMessageNoToolCalls() {
        let result = GenerationResult.text("Hello")
        let message = result.assistantMessage()
        #expect(message.metadata?.toolCalls == nil)
    }
}
