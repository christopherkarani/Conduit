// TokenCountTests.swift
// SwiftAI Tests

import XCTest
@testable import SwiftAI

/// Comprehensive test suite for TokenCount and context size helpers.
///
/// Tests cover:
/// - TokenCount initialization (basic and full)
/// - Context window helpers (fitsInContext, remainingIn, percentageOf, wouldExceed)
/// - Convenience factories (simple, fromMessages)
/// - Protocol conformances (Hashable, Codable, CustomStringConvertible, Sendable)
/// - Int context constants (4K through 1M)
/// - Context description helpers
/// - Real-world integration scenarios
final class TokenCountTests: XCTestCase {

    // MARK: - Initialization Tests

    func testBasicInitialization() {
        let count = TokenCount(count: 100)

        XCTAssertEqual(count.count, 100, "Count should be 100")
        XCTAssertEqual(count.text, "", "Text should be empty by default")
        XCTAssertEqual(count.tokenizer, "", "Tokenizer should be empty by default")
        XCTAssertNil(count.tokenIds, "TokenIds should be nil by default")
        XCTAssertNil(count.tokens, "Tokens should be nil by default")
        XCTAssertNil(count.promptTokens, "PromptTokens should be nil by default")
        XCTAssertNil(count.specialTokens, "SpecialTokens should be nil by default")
    }

    func testFullInitialization() {
        let count = TokenCount(
            count: 50,
            text: "Hello world",
            tokenizer: "llama",
            tokenIds: [1, 2, 3],
            tokens: ["Hello", " ", "world"],
            promptTokens: 45,
            specialTokens: 5
        )

        XCTAssertEqual(count.count, 50, "Count should be 50")
        XCTAssertEqual(count.text, "Hello world", "Text should match input")
        XCTAssertEqual(count.tokenizer, "llama", "Tokenizer should be 'llama'")
        XCTAssertEqual(count.tokenIds, [1, 2, 3], "TokenIds should match input")
        XCTAssertEqual(count.tokens, ["Hello", " ", "world"], "Tokens should match input")
        XCTAssertEqual(count.promptTokens, 45, "PromptTokens should be 45")
        XCTAssertEqual(count.specialTokens, 5, "SpecialTokens should be 5")
    }

    func testInitializationWithPartialData() {
        let count = TokenCount(
            count: 100,
            text: "test",
            tokenizer: "gpt2"
        )

        XCTAssertEqual(count.count, 100)
        XCTAssertEqual(count.text, "test")
        XCTAssertEqual(count.tokenizer, "gpt2")
        XCTAssertNil(count.tokenIds, "Optional fields should remain nil")
        XCTAssertNil(count.tokens, "Optional fields should remain nil")
    }

    // MARK: - Context Window Helper Tests

    func testFitsInContext() {
        let count = TokenCount(count: 2000, text: "test", tokenizer: "test")

        XCTAssertTrue(count.fitsInContext(of: 4096), "2000 tokens should fit in 4096 context")
        XCTAssertTrue(count.fitsInContext(of: 2000), "Exactly 2000 tokens should fit in 2000 context")
        XCTAssertFalse(count.fitsInContext(of: 1999), "2000 tokens should not fit in 1999 context")
        XCTAssertFalse(count.fitsInContext(of: 1000), "2000 tokens should not fit in 1000 context")
    }

    func testFitsInContextEdgeCases() {
        let zeroCount = TokenCount(count: 0, text: "", tokenizer: "test")
        XCTAssertTrue(zeroCount.fitsInContext(of: 0), "Zero tokens should fit in zero context")
        XCTAssertTrue(zeroCount.fitsInContext(of: 100), "Zero tokens should fit in any context")

        let largeCount = TokenCount(count: 1_000_000, text: "", tokenizer: "test")
        XCTAssertFalse(largeCount.fitsInContext(of: 4096), "1M tokens should not fit in 4K context")
        XCTAssertTrue(largeCount.fitsInContext(of: 1_000_000), "1M tokens should fit in 1M context")
    }

    func testRemainingInContext() {
        let count = TokenCount(count: 1000, text: "test", tokenizer: "test")

        XCTAssertEqual(count.remainingIn(context: 4096), 3096, "Remaining should be 4096 - 1000")
        XCTAssertEqual(count.remainingIn(context: 1000), 0, "No tokens remaining when exactly at limit")
        XCTAssertEqual(count.remainingIn(context: 500), 0, "Should return 0, not negative, when over limit")
        XCTAssertEqual(count.remainingIn(context: 0), 0, "Should handle zero context")
    }

    func testRemainingInContextVariousSizes() {
        let count = TokenCount(count: 5000, text: "test", tokenizer: "test")

        XCTAssertEqual(count.remainingIn(context: 8192), 3192)
        XCTAssertEqual(count.remainingIn(context: 16384), 11384)
        XCTAssertEqual(count.remainingIn(context: 4096), 0, "Over limit returns 0")
    }

    func testPercentageOfContext() {
        let count = TokenCount(count: 2048, text: "test", tokenizer: "test")

        XCTAssertEqual(count.percentageOf(context: 4096), 50.0, accuracy: 0.01, "2048/4096 should be 50%")
        XCTAssertEqual(count.percentageOf(context: 2048), 100.0, accuracy: 0.01, "2048/2048 should be 100%")
        XCTAssertEqual(count.percentageOf(context: 1024), 200.0, accuracy: 0.01, "Over 100% is valid (2048/1024)")
        XCTAssertEqual(count.percentageOf(context: 8192), 25.0, accuracy: 0.01, "2048/8192 should be 25%")
    }

    func testPercentageOfZeroContext() {
        let count = TokenCount(count: 100, text: "test", tokenizer: "test")

        XCTAssertEqual(count.percentageOf(context: 0), 0.0, accuracy: 0.01, "Should handle division by zero gracefully")
    }

    func testPercentageOfZeroTokens() {
        let count = TokenCount(count: 0, text: "", tokenizer: "test")

        XCTAssertEqual(count.percentageOf(context: 4096), 0.0, accuracy: 0.01, "Zero tokens should be 0%")
    }

    func testWouldExceed() {
        let count = TokenCount(count: 3000, text: "test", tokenizer: "test")

        XCTAssertFalse(count.wouldExceed(adding: 1000, contextSize: 4096), "3000 + 1000 = 4000 < 4096")
        XCTAssertFalse(count.wouldExceed(adding: 1096, contextSize: 4096), "3000 + 1096 = 4096, exactly fits")
        XCTAssertTrue(count.wouldExceed(adding: 1097, contextSize: 4096), "3000 + 1097 = 4097 > 4096")
        XCTAssertTrue(count.wouldExceed(adding: 2000, contextSize: 4096), "3000 + 2000 = 5000 > 4096")
    }

    func testWouldExceedEdgeCases() {
        let count = TokenCount(count: 0, text: "", tokenizer: "test")
        XCTAssertFalse(count.wouldExceed(adding: 100, contextSize: 100), "Adding to empty exactly at limit")
        XCTAssertTrue(count.wouldExceed(adding: 101, contextSize: 100), "Adding to empty over limit")

        let maxCount = TokenCount(count: 4096, text: "", tokenizer: "test")
        XCTAssertTrue(maxCount.wouldExceed(adding: 1, contextSize: 4096), "Already at limit")
    }

    // MARK: - Convenience Initializer Tests

    func testSimpleFactory() {
        let count = TokenCount.simple(42)

        XCTAssertEqual(count.count, 42, "Count should be 42")
        XCTAssertEqual(count.text, "", "Text should be empty")
        XCTAssertEqual(count.tokenizer, "", "Tokenizer should be empty")
        XCTAssertNil(count.tokenIds)
        XCTAssertNil(count.tokens)
        XCTAssertNil(count.promptTokens)
        XCTAssertNil(count.specialTokens)
    }

    func testSimpleFactoryZero() {
        let count = TokenCount.simple(0)
        XCTAssertEqual(count.count, 0)
    }

    func testFromMessagesFactory() {
        let count = TokenCount.fromMessages(
            count: 100,
            promptTokens: 80,
            specialTokens: 20,
            tokenizer: "llama"
        )

        XCTAssertEqual(count.count, 100, "Total count should be 100")
        XCTAssertEqual(count.promptTokens, 80, "Prompt tokens should be 80")
        XCTAssertEqual(count.specialTokens, 20, "Special tokens should be 20")
        XCTAssertEqual(count.tokenizer, "llama", "Tokenizer should be 'llama'")
        XCTAssertEqual(count.text, "", "Text should be empty for message-based count")
    }

    func testFromMessagesFactoryRealisticValues() {
        // Simulate a chat with overhead
        let count = TokenCount.fromMessages(
            count: 127,
            promptTokens: 115,
            specialTokens: 12,
            tokenizer: "llama3.2"
        )

        XCTAssertEqual(count.count, 127)
        XCTAssertEqual(count.promptTokens, 115)
        XCTAssertEqual(count.specialTokens, 12)
    }

    // MARK: - Protocol Conformance Tests

    func testHashable() {
        let count1 = TokenCount(count: 100, text: "test", tokenizer: "llama")
        let count2 = TokenCount(count: 100, text: "test", tokenizer: "llama")
        let count3 = TokenCount(count: 200, text: "test", tokenizer: "llama")

        var set = Set<TokenCount>()
        set.insert(count1)
        set.insert(count2)
        set.insert(count3)

        XCTAssertEqual(set.count, 2, "count1 and count2 should be equal, set should have 2 unique items")
        XCTAssertTrue(set.contains(count1))
        XCTAssertTrue(set.contains(count3))
    }

    func testHashableWithDifferentOptionalValues() {
        let count1 = TokenCount(count: 100, text: "test", tokenizer: "llama", tokenIds: [1, 2, 3])
        let count2 = TokenCount(count: 100, text: "test", tokenizer: "llama", tokenIds: nil)

        XCTAssertNotEqual(count1, count2, "Different optional values should result in inequality")
    }

    func testCodableRoundTrip() throws {
        let original = TokenCount(
            count: 100,
            text: "Hello",
            tokenizer: "llama",
            tokenIds: [1, 2, 3],
            tokens: ["He", "llo"],
            promptTokens: 90,
            specialTokens: 10
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TokenCount.self, from: data)

        XCTAssertEqual(original.count, decoded.count)
        XCTAssertEqual(original.text, decoded.text)
        XCTAssertEqual(original.tokenizer, decoded.tokenizer)
        XCTAssertEqual(original.tokenIds, decoded.tokenIds)
        XCTAssertEqual(original.tokens, decoded.tokens)
        XCTAssertEqual(original.promptTokens, decoded.promptTokens)
        XCTAssertEqual(original.specialTokens, decoded.specialTokens)
    }

    func testCodableWithNilValues() throws {
        let original = TokenCount(count: 50, text: "test", tokenizer: "gpt2")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TokenCount.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertNil(decoded.tokenIds)
        XCTAssertNil(decoded.tokens)
        XCTAssertNil(decoded.promptTokens)
        XCTAssertNil(decoded.specialTokens)
    }

    func testCodableSimpleFactory() throws {
        let original = TokenCount.simple(42)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TokenCount.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testDescription() {
        let count = TokenCount(
            count: 100,
            text: "test",
            tokenizer: "llama",
            promptTokens: 80,
            specialTokens: 20
        )

        let description = count.description
        XCTAssertTrue(description.contains("100"), "Description should contain count")
        XCTAssertTrue(description.contains("prompt"), "Description should mention prompt tokens")
        XCTAssertTrue(description.contains("80"), "Description should show prompt token count")
        XCTAssertTrue(description.contains("special"), "Description should mention special tokens")
        XCTAssertTrue(description.contains("20"), "Description should show special token count")
        XCTAssertTrue(description.contains("llama"), "Description should include tokenizer")
    }

    func testDescriptionMinimal() {
        let count = TokenCount.simple(42)

        let description = count.description
        XCTAssertTrue(description.contains("42"), "Description should contain count")
        XCTAssertTrue(description.contains("token"), "Description should say 'tokens'")
    }

    func testDescriptionWithoutOptionalFields() {
        let count = TokenCount(count: 50, text: "test", tokenizer: "gpt2")

        let description = count.description
        XCTAssertTrue(description.contains("50"))
        XCTAssertTrue(description.contains("gpt2"))
        XCTAssertFalse(description.contains("prompt"), "Should not mention nil prompt tokens")
        XCTAssertFalse(description.contains("special"), "Should not mention nil special tokens")
    }

    // MARK: - Equality Tests

    func testEquality() {
        let count1 = TokenCount(count: 100, text: "test", tokenizer: "llama")
        let count2 = TokenCount(count: 100, text: "test", tokenizer: "llama")

        XCTAssertEqual(count1, count2, "Identical token counts should be equal")
    }

    func testInequalityDifferentCount() {
        let count1 = TokenCount(count: 100, text: "test", tokenizer: "llama")
        let count2 = TokenCount(count: 101, text: "test", tokenizer: "llama")

        XCTAssertNotEqual(count1, count2, "Different counts should not be equal")
    }

    func testInequalityDifferentText() {
        let count1 = TokenCount(count: 100, text: "test1", tokenizer: "llama")
        let count2 = TokenCount(count: 100, text: "test2", tokenizer: "llama")

        XCTAssertNotEqual(count1, count2, "Different text should not be equal")
    }

    func testInequalityDifferentTokenizer() {
        let count1 = TokenCount(count: 100, text: "test", tokenizer: "llama")
        let count2 = TokenCount(count: 100, text: "test", tokenizer: "gpt2")

        XCTAssertNotEqual(count1, count2, "Different tokenizers should not be equal")
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        let count = TokenCount(count: 100, text: "test", tokenizer: "llama")

        // Test that TokenCount can be sent across concurrency boundaries
        await Task {
            XCTAssertEqual(count.count, 100)
            XCTAssertEqual(count.text, "test")
        }.value
    }

    func testSendableInAsyncStream() async {
        let counts = [
            TokenCount.simple(10),
            TokenCount.simple(20),
            TokenCount.simple(30)
        ]

        let stream = AsyncStream<TokenCount> { continuation in
            for count in counts {
                continuation.yield(count)
            }
            continuation.finish()
        }

        var received: [TokenCount] = []
        for await count in stream {
            received.append(count)
        }

        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received[0].count, 10)
        XCTAssertEqual(received[1].count, 20)
        XCTAssertEqual(received[2].count, 30)
    }
}

// MARK: - Context Constants Tests

final class ContextConstantsTests: XCTestCase {

    func testContext4K() {
        XCTAssertEqual(Int.context4K, 4096, "4K context should be 4,096 tokens")
    }

    func testContext8K() {
        XCTAssertEqual(Int.context8K, 8192, "8K context should be 8,192 tokens")
    }

    func testContext16K() {
        XCTAssertEqual(Int.context16K, 16384, "16K context should be 16,384 tokens")
    }

    func testContext32K() {
        XCTAssertEqual(Int.context32K, 32768, "32K context should be 32,768 tokens")
    }

    func testContext64K() {
        XCTAssertEqual(Int.context64K, 65536, "64K context should be 65,536 tokens")
    }

    func testContext128K() {
        XCTAssertEqual(Int.context128K, 131072, "128K context should be 131,072 tokens")
    }

    func testContext200K() {
        XCTAssertEqual(Int.context200K, 200000, "200K context should be 200,000 tokens")
    }

    func testContext1M() {
        XCTAssertEqual(Int.context1M, 1000000, "1M context should be 1,000,000 tokens")
    }

    func testContextDescription4K() {
        XCTAssertEqual(Int.context4K.contextDescription, "4K", "4096 should display as '4K'")
    }

    func testContextDescription8K() {
        XCTAssertEqual(Int.context8K.contextDescription, "8K", "8192 should display as '8K'")
    }

    func testContextDescription128K() {
        XCTAssertEqual(Int.context128K.contextDescription, "128K", "131072 should display as '128K'")
    }

    func testContextDescription200K() {
        XCTAssertEqual(Int.context200K.contextDescription, "200K", "200000 should display as '200K'")
    }

    func testContextDescription1M() {
        XCTAssertEqual(Int.context1M.contextDescription, "1M", "1000000 should display as '1M'")
    }

    func testContextDescriptionNonStandard() {
        XCTAssertEqual(500.contextDescription, "500", "Values less than 1K should display as-is")
        // Non-standard values use binary K (÷1024)
        XCTAssertEqual(5000.contextDescription, "4K", "5000/1024 = 4 → '4K'")
        XCTAssertEqual(5500.contextDescription, "5K", "5500/1024 = 5 → '5K'")
        XCTAssertEqual(10240.contextDescription, "10K", "10240/1024 = 10 → '10K'")
    }

    func testContextDescriptionZero() {
        XCTAssertEqual(0.contextDescription, "0", "Zero should display as '0'")
    }

    func testIsStandardContextSize() {
        XCTAssertTrue(Int.context4K.isStandardContextSize, "4K should be standard")
        XCTAssertTrue(Int.context8K.isStandardContextSize, "8K should be standard")
        XCTAssertTrue(Int.context16K.isStandardContextSize, "16K should be standard")
        XCTAssertTrue(Int.context32K.isStandardContextSize, "32K should be standard")
        XCTAssertTrue(Int.context64K.isStandardContextSize, "64K should be standard")
        XCTAssertTrue(Int.context128K.isStandardContextSize, "128K should be standard")
        XCTAssertTrue(Int.context200K.isStandardContextSize, "200K should be standard")
        XCTAssertTrue(Int.context1M.isStandardContextSize, "1M should be standard")
    }

    func testIsNotStandardContextSize() {
        XCTAssertFalse(5000.isStandardContextSize, "5000 is not a standard context size")
        XCTAssertFalse(10000.isStandardContextSize, "10000 is not a standard context size")
        XCTAssertFalse(0.isStandardContextSize, "0 is not a standard context size")
        XCTAssertFalse(100.isStandardContextSize, "100 is not a standard context size")
    }
}

// MARK: - Usage with Context Tests

final class TokenCountContextUsageTests: XCTestCase {

    /// Tests using TokenCount with context constants together.
    func testFitsInStandardContexts() {
        let smallCount = TokenCount(count: 2000, text: "small", tokenizer: "test")
        let mediumCount = TokenCount(count: 10000, text: "medium", tokenizer: "test")
        let largeCount = TokenCount(count: 100000, text: "large", tokenizer: "test")

        // Small fits in all
        XCTAssertTrue(smallCount.fitsInContext(of: .context4K), "2000 should fit in 4K")
        XCTAssertTrue(smallCount.fitsInContext(of: .context8K), "2000 should fit in 8K")
        XCTAssertTrue(smallCount.fitsInContext(of: .context128K), "2000 should fit in 128K")

        // Medium fits in larger contexts
        XCTAssertFalse(mediumCount.fitsInContext(of: .context4K), "10000 should not fit in 4K")
        XCTAssertFalse(mediumCount.fitsInContext(of: .context8K), "10000 should not fit in 8K")
        XCTAssertTrue(mediumCount.fitsInContext(of: .context16K), "10000 should fit in 16K")
        XCTAssertTrue(mediumCount.fitsInContext(of: .context32K), "10000 should fit in 32K")

        // Large needs very large context
        XCTAssertFalse(largeCount.fitsInContext(of: .context64K), "100000 should not fit in 64K")
        XCTAssertTrue(largeCount.fitsInContext(of: .context128K), "100000 should fit in 128K")
        XCTAssertTrue(largeCount.fitsInContext(of: .context200K), "100000 should fit in 200K")
    }

    func testReserveForOutput() {
        let count = TokenCount(count: 7000, text: "prompt", tokenizer: "test")

        // With 8K context, we have 8192 - 7000 = 1192 remaining
        let remaining = count.remainingIn(context: .context8K)
        XCTAssertEqual(remaining, 1192, "Should have 1192 tokens remaining in 8K context")

        // If we reserve 1024 for output, we need: 7000 + 1024 = 8024 < 8192 ✓
        let reserveForOutput = 1024
        let available = count.remainingIn(context: .context8K)
        XCTAssertGreaterThanOrEqual(available, reserveForOutput, "Should have enough space for output")
        XCTAssertFalse(count.wouldExceed(adding: reserveForOutput, contextSize: .context8K))
    }

    func testReserveForOutputExceedsContext() {
        let count = TokenCount(count: 7500, text: "prompt", tokenizer: "test")

        // With 8K context, we have 8192 - 7500 = 692 remaining
        let remaining = count.remainingIn(context: .context8K)
        XCTAssertEqual(remaining, 692)

        // If we want to reserve 1024 for output, we don't have enough
        let reserveForOutput = 1024
        XCTAssertLessThan(remaining, reserveForOutput, "Not enough space for desired output")
        XCTAssertTrue(count.wouldExceed(adding: reserveForOutput, contextSize: .context8K))

        // Need to use a larger context
        XCTAssertFalse(count.wouldExceed(adding: reserveForOutput, contextSize: .context16K))
    }

    func testContextUsagePercentages() {
        let count = TokenCount(count: 2048, text: "prompt", tokenizer: "test")

        // Check various context sizes
        XCTAssertEqual(count.percentageOf(context: .context4K), 50.0, accuracy: 0.01)
        XCTAssertEqual(count.percentageOf(context: .context8K), 25.0, accuracy: 0.01)
        XCTAssertEqual(count.percentageOf(context: .context16K), 12.5, accuracy: 0.01)
        XCTAssertEqual(count.percentageOf(context: .context32K), 6.25, accuracy: 0.01)
    }

    func testSelectingAppropriateContextSize() {
        let count = TokenCount(count: 5000, text: "document", tokenizer: "test")

        // Find the smallest context that fits
        let contextSizes = [
            Int.context4K,
            Int.context8K,
            Int.context16K,
            Int.context32K,
            Int.context64K
        ]

        let appropriateSize = contextSizes.first { count.fitsInContext(of: $0) }
        XCTAssertEqual(appropriateSize, Int.context8K, "8K is the smallest context that fits 5000 tokens")
    }

    func testChunkingLargeDocument() {
        // Document too large for any single context
        let largeDocument = TokenCount(count: 500000, text: "large", tokenizer: "test")

        XCTAssertFalse(largeDocument.fitsInContext(of: .context128K))
        XCTAssertFalse(largeDocument.fitsInContext(of: .context200K))

        // Would need to chunk into ~5 pieces for 128K context
        let chunkSize = 120000 // Leave room for template overhead
        let chunksNeeded = (largeDocument.count + chunkSize - 1) / chunkSize // Ceiling division
        XCTAssertEqual(chunksNeeded, 5, "Should need 5 chunks for 500K tokens with 120K chunk size")
    }

    func testRealWorldConversationScenario() {
        // Simulate a real conversation with system prompt, user message, and history
        let systemPrompt = TokenCount(count: 50, text: "system", tokenizer: "llama")
        let conversationHistory = TokenCount(count: 2000, text: "history", tokenizer: "llama")
        let userMessage = TokenCount(count: 100, text: "user", tokenizer: "llama")
        let templateOverhead = TokenCount(count: 30, text: "", tokenizer: "llama")

        let totalInputTokens = systemPrompt.count + conversationHistory.count
            + userMessage.count + templateOverhead.count
        let inputCount = TokenCount(count: totalInputTokens, text: "combined", tokenizer: "llama")

        XCTAssertEqual(inputCount.count, 2180, "Total input should be 2180 tokens")

        // Reserve space for response
        let maxOutputTokens = 1000
        XCTAssertFalse(
            inputCount.wouldExceed(adding: maxOutputTokens, contextSize: .context4K),
            "Should fit in 4K context"
        )

        let usedPercentage = Double(inputCount.count + maxOutputTokens) / Double(Int.context4K) * 100
        XCTAssertLessThan(usedPercentage, 80.0, "Should use less than 80% of context including output")
    }
}
