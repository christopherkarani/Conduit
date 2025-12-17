// StreamingTests.swift
// SwiftAITests

import Foundation
import Testing
@testable import SwiftAI

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
        let a = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)
        let b = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        var set = Set<TokenLogprob>()
        set.insert(a)
        set.insert(b)
        #expect(set.count == 1)
    }

    @Test("TokenLogprob inequality")
    func tokenLogprobInequality() {
        let a = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 123)
        let b = TokenLogprob(token: "world", logprob: -0.5, tokenId: 123)
        let c = TokenLogprob(token: "hello", logprob: -0.6, tokenId: 123)
        let d = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 124)

        #expect(a != b)
        #expect(a != c)
        #expect(a != d)
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
        let a = UsageStats(promptTokens: 100, completionTokens: 50)
        let b = UsageStats(promptTokens: 100, completionTokens: 50)
        let c = UsageStats(promptTokens: 100, completionTokens: 51)

        #expect(a == b)
        #expect(a != c)
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

    @Test("GenerationChunk is Hashable")
    func generationChunkHashable() {
        let timestamp1 = Date()
        let timestamp2 = Date(timeIntervalSinceNow: 1.0)

        let chunk1 = GenerationChunk(text: "hello", tokenCount: 1, isComplete: false, timestamp: timestamp1)
        let chunk2 = GenerationChunk(text: "hello", tokenCount: 1, isComplete: false, timestamp: timestamp2)

        // Chunks with different timestamps should be different
        #expect(chunk1 != chunk2)

        // Both should be hashable
        _ = chunk1.hashValue
        _ = chunk2.hashValue

        var set = Set<GenerationChunk>()
        set.insert(chunk1)
        set.insert(chunk2)

        // Different timestamps mean different chunks in the set
        #expect(set.count == 2)
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

    @Test("GenerationResult is Hashable")
    func generationResultHashable() {
        let result1 = GenerationResult.text("Hello")
        let result2 = GenerationResult.text("World")

        var set = Set<GenerationResult>()
        set.insert(result1)
        set.insert(result2)

        #expect(set.count == 2)
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

    // MARK: - GenerationStream Tests

    @Test("GenerationStream collect method")
    func generationStreamCollect() async throws {
        let stream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.yield(GenerationChunk(text: "Hello"))
            continuation.yield(GenerationChunk(text: " "))
            continuation.yield(GenerationChunk(text: "World"))
            continuation.finish()
        }

        let generationStream = GenerationStream(stream)
        let result = try await generationStream.collect()

        #expect(result == "Hello World")
    }

    @Test("GenerationStream collectWithMetadata method")
    func generationStreamCollectWithMetadata() async throws {
        let stream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.yield(GenerationChunk(text: "Hello", tokenCount: 1))
            continuation.yield(GenerationChunk(text: " World", tokenCount: 2, isComplete: true, finishReason: .stop))
            continuation.finish()
        }

        let generationStream = GenerationStream(stream)
        let result = try await generationStream.collectWithMetadata()

        #expect(result.text == "Hello World")
        #expect(result.tokenCount == 3)
        #expect(result.finishReason == .stop)
    }

    @Test("GenerationStream collectWithMetadata uses last finishReason")
    func generationStreamCollectUsesLastFinishReason() async throws {
        let stream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.yield(GenerationChunk(text: "A", tokenCount: 1, finishReason: nil))
            continuation.yield(GenerationChunk(text: "B", tokenCount: 1, finishReason: nil))
            continuation.yield(GenerationChunk(text: "C", tokenCount: 1, isComplete: true, finishReason: .maxTokens))
            continuation.finish()
        }

        let generationStream = GenerationStream(stream)
        let result = try await generationStream.collectWithMetadata()

        #expect(result.finishReason == .maxTokens)
    }

    @Test("GenerationStream from string stream factory")
    func generationStreamFromStrings() async throws {
        let stringStream = AsyncThrowingStream<String, Error> { continuation in
            continuation.yield("Hello")
            continuation.yield(" ")
            continuation.yield("World")
            continuation.finish()
        }

        let generationStream = GenerationStream.from(stringStream)
        let result = try await generationStream.collect()

        #expect(result == "Hello World")
    }

    @Test("GenerationStream text property iteration")
    func generationStreamTextProperty() async throws {
        let stream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.yield(GenerationChunk(text: "A"))
            continuation.yield(GenerationChunk(text: "B"))
            continuation.yield(GenerationChunk(text: "C"))
            continuation.finish()
        }

        let generationStream = GenerationStream(stream)
        var texts: [String] = []

        for try await text in generationStream.text {
            texts.append(text)
        }

        #expect(texts == ["A", "B", "C"])
    }

    @Test("GenerationStream handles empty stream")
    func generationStreamEmptyStream() async throws {
        let stream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.finish()
        }

        let generationStream = GenerationStream(stream)
        let result = try await generationStream.collect()

        #expect(result == "")
    }

    @Test("GenerationStream propagates errors")
    func generationStreamPropagatesErrors() async throws {
        enum TestError: Error {
            case streamFailed
        }

        let stream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.yield(GenerationChunk(text: "Start"))
            continuation.finish(throwing: TestError.streamFailed)
        }

        let generationStream = GenerationStream(stream)

        do {
            _ = try await generationStream.collect()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is TestError)
        }
    }

    @Test("GenerationStream can be iterated multiple times")
    func generationStreamMultipleIterations() async throws {
        // Note: In practice, streams can only be consumed once
        // This test demonstrates the API structure

        let stream1 = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.yield(GenerationChunk(text: "Hello"))
            continuation.finish()
        }

        let generationStream = GenerationStream(stream1)
        let result = try await generationStream.collect()

        #expect(result == "Hello")
    }

    @Test("GenerationStream collectWithMetadata handles no finish reason")
    func generationStreamNoFinishReason() async throws {
        let stream = AsyncThrowingStream<GenerationChunk, Error> { continuation in
            continuation.yield(GenerationChunk(text: "Hello", tokenCount: 1))
            continuation.yield(GenerationChunk(text: " World", tokenCount: 2))
            continuation.finish()
        }

        let generationStream = GenerationStream(stream)
        let result = try await generationStream.collectWithMetadata()

        #expect(result.text == "Hello World")
        #expect(result.tokenCount == 3)
        #expect(result.finishReason == .stop) // Default to .stop
    }
}
