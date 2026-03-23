// StreamingTests.swift
// ConduitTests

import Foundation
import Testing
@testable import ConduitAdvanced

/// Comprehensive test suite for Phase 6 streaming and result types.
///
/// Tests cover:
/// - FinishReason enum
/// - TokenLogprob struct
/// - UsageStats struct
/// - GenerationChunk struct
/// - GenerationResult struct
/// - GenerationStream AsyncSequence
@Suite("Streaming Types")
struct StreamingTests {

    // MARK: - FinishReason Tests

    @Test("All FinishReason cases exist")
    func finishReasonAllCases() {
        let cases: [FinishReason] = [.stop, .maxTokens, .stopSequence, .cancelled, .contentFilter, .toolCall]
        #expect(cases.count == 6)
    }

    @Test("FinishReason raw values are snake_case")
    func finishReasonRawValues() {
        #expect(FinishReason.stop.rawValue == "stop")
        #expect(FinishReason.maxTokens.rawValue == "max_tokens")
        #expect(FinishReason.stopSequence.rawValue == "stop_sequence")
        #expect(FinishReason.cancelled.rawValue == "cancelled")
        #expect(FinishReason.contentFilter.rawValue == "content_filter")
        #expect(FinishReason.toolCall.rawValue == "tool_call")
    }

    @Test("FinishReason Codable round-trip", arguments: [
        FinishReason.stop,
        .maxTokens,
        .stopSequence,
        .cancelled,
        .contentFilter,
        .toolCall
    ])
    func finishReasonCodable(reason: FinishReason) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(reason)
        let decoded = try decoder.decode(FinishReason.self, from: encoded)

        #expect(decoded == reason)
    }

    // MARK: - TokenLogprob Tests

    @Test("TokenLogprob initialization")
    func tokenLogprobInitialization() {
        let logprob = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)

        #expect(logprob.token == "hello")
        #expect(logprob.logprob == -0.5)
        #expect(logprob.tokenId == 123)
    }

    @Test("TokenLogprob probability computation")
    func tokenLogprobProbability() {
        let logprob = TokenLogprob(token: "test", logprob: 0.0, tokenId: 1)
        #expect(abs(logprob.probability - 1.0) < 0.001)

        let logprob2 = TokenLogprob(token: "test", logprob: -Float.infinity, tokenId: 2)
        #expect(abs(logprob2.probability - 0.0) < 0.001)

        let logprob3 = TokenLogprob(token: "test", logprob: -1.0, tokenId: 3)
        #expect(abs(logprob3.probability - exp(-1.0)) < 0.001)
    }

    @Test("TokenLogprob is Hashable")
    func tokenLogprobHashable() {
        let logprob1 = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)
        let logprob2 = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)

        #expect(logprob1 == logprob2)
        #expect(logprob1.hashValue == logprob2.hashValue)

        var set = Set<TokenLogprob>()
        set.insert(logprob1)
        set.insert(logprob2)
        #expect(set.count == 1)
    }

    @Test("TokenLogprob inequality")
    func tokenLogprobInequality() {
        let baseLogprob = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)
        let differentToken = TokenLogprob(token: "world", logprob: -0.5, tokenId: 123)
        let differentLogprob = TokenLogprob(token: "hello", logprob: -0.6, tokenId: 123)
        let differentTokenId = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 124)

        #expect(baseLogprob != differentToken)
        #expect(baseLogprob != differentLogprob)
        #expect(baseLogprob != differentTokenId)
    }

    // MARK: - UsageStats Tests

    @Test("UsageStats totalTokens computation")
    func usageStatsTotalTokens() {
        let stats = UsageStats(promptTokens: 100, completionTokens: 50)
        #expect(stats.totalTokens == 150)

        let stats2 = UsageStats(promptTokens: 0, completionTokens: 100)
        #expect(stats2.totalTokens == 100)

        let stats3 = UsageStats(promptTokens: 75, completionTokens: 0)
        #expect(stats3.totalTokens == 75)
    }

    @Test("UsageStats Codable round-trip")
    func usageStatsCodable() throws {
        let original = UsageStats(promptTokens: 100, completionTokens: 50)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(UsageStats.self, from: encoded)

        #expect(decoded.promptTokens == original.promptTokens)
        #expect(decoded.completionTokens == original.completionTokens)
        #expect(decoded.totalTokens == original.totalTokens)
    }

    @Test("UsageStats is Equatable")
    func usageStatsEquatable() {
        let stats1 = UsageStats(promptTokens: 100, completionTokens: 50)
        let stats2 = UsageStats(promptTokens: 100, completionTokens: 50)
        let stats3 = UsageStats(promptTokens: 100, completionTokens: 51)

        #expect(stats1 == stats2)
        #expect(stats1 != stats3)
    }

    // MARK: - GenerationChunk Tests

    @Test("GenerationChunk default values")
    func generationChunkDefaults() {
        let chunk = GenerationChunk(text: "hello")

        #expect(chunk.text == "hello")
        #expect(chunk.tokenCount == 1)
        #expect(chunk.isComplete == false)
        #expect(chunk.finishReason == nil)
        #expect(chunk.tokenId == nil)
        #expect(chunk.logprob == nil)
        #expect(chunk.topLogprobs == nil)
    }

    @Test("GenerationChunk with all parameters")
    func generationChunkFullInit() {
        let topLogprobs = [TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)]
        let chunk = GenerationChunk(
            text: "hello",
            tokenCount: 1,
            tokenId: 123,
            logprob: -0.5,
            topLogprobs: topLogprobs,
            tokensPerSecond: 25.0,
            isComplete: true,
            finishReason: .stop
        )

        #expect(chunk.text == "hello")
        #expect(chunk.tokenCount == 1)
        #expect(chunk.tokenId == 123)
        #expect(chunk.logprob == -0.5)
        #expect(chunk.topLogprobs?.count == 1)
        #expect(chunk.tokensPerSecond == 25.0)
        #expect(chunk.isComplete == true)
        #expect(chunk.finishReason == .stop)
    }

    @Test("GenerationChunk completion factory")
    func generationChunkCompletion() {
        let chunk = GenerationChunk.completion(finishReason: .stop)

        #expect(chunk.text == "")
        #expect(chunk.tokenCount == 0)
        #expect(chunk.isComplete == true)
        #expect(chunk.finishReason == .stop)
    }

    @Test("GenerationChunk completion factory with all reasons", arguments: [
        FinishReason.stop,
        .maxTokens,
        .stopSequence,
        .cancelled,
        .contentFilter,
        .toolCall
    ])
    func generationChunkCompletionReasons(reason: FinishReason) {
        let chunk = GenerationChunk.completion(finishReason: reason)

        #expect(chunk.isComplete == true)
        #expect(chunk.finishReason == reason)
    }

    @Test("GenerationChunk is Equatable")
    func generationChunkEquatable() {
        let timestamp1 = Date()
        let timestamp2 = Date(timeIntervalSinceNow: 1.0)

        let chunk1 = GenerationChunk(text: "hello", tokenCount: 1, isComplete: false, timestamp: timestamp1)
        let chunk2 = GenerationChunk(text: "hello", tokenCount: 1, isComplete: false, timestamp: timestamp2)

        // Chunks with different timestamps should be different
        #expect(chunk1 != chunk2)
    }

    @Test("GenerationChunk timestamp is set")
    func generationChunkTimestamp() {
        let before = Date()
        let chunk = GenerationChunk(text: "test")
        let after = Date()

        #expect(chunk.timestamp >= before)
        #expect(chunk.timestamp <= after)
    }

    // MARK: - GenerationResult Tests

    @Test("GenerationResult text factory")
    func generationResultTextFactory() {
        let result = GenerationResult.text("Hello world")

        #expect(result.text == "Hello world")
        #expect(result.finishReason == .stop)
        #expect(result.tokenCount == 0)
    }

    @Test("GenerationResult full initialization")
    func generationResultFullInit() {
        let result = GenerationResult(
            text: "test response",
            tokenCount: 10,
            generationTime: 1.5,
            tokensPerSecond: 6.67,
            finishReason: .maxTokens,
            logprobs: [TokenLogprob(token: "test", logprob: -0.5, tokenId: 1)],
            usage: UsageStats(promptTokens: 5, completionTokens: 10)
        )

        #expect(result.text == "test response")
        #expect(result.tokenCount == 10)
        #expect(result.generationTime == 1.5)
        #expect(result.tokensPerSecond == 6.67)
        #expect(result.finishReason == .maxTokens)
        #expect(result.usage?.totalTokens == 15)
        #expect(result.logprobs?.count == 1)
    }

    @Test("GenerationResult finishReason is required")
    func generationResultRequiresFinishReason() {
        let result = GenerationResult(
            text: "test",
            tokenCount: 10,
            generationTime: 1.0,
            tokensPerSecond: 10.0,
            finishReason: .stop
        )

        #expect(result.finishReason == .stop)
    }

    @Test("GenerationResult equality")
    func generationResultEquality() {
        let result1 = GenerationResult(
            text: "test",
            tokenCount: 10,
            generationTime: 1.0,
            tokensPerSecond: 10.0,
            finishReason: .stop
        )

        let result2 = GenerationResult(
            text: "test",
            tokenCount: 10,
            generationTime: 1.0,
            tokensPerSecond: 10.0,
            finishReason: .stop
        )

        #expect(result1 == result2)
    }

}
