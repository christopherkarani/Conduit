// TokenLogprobTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("TokenLogprob Tests")
struct TokenLogprobTests {

    // MARK: - Initialization

    @Test("Init stores all properties")
    func initProperties() {
        let logprob = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 42)
        #expect(logprob.token == "hello")
        #expect(logprob.logprob == -0.5)
        #expect(logprob.tokenId == 42)
    }

    @Test("Init defaults tokenId to nil")
    func initDefaultTokenId() {
        let logprob = TokenLogprob(token: "world", logprob: -1.0)
        #expect(logprob.tokenId == nil)
    }

    // MARK: - Probability

    @Test("probability computes exp of logprob")
    func probabilityComputation() {
        let logprob = TokenLogprob(token: "a", logprob: 0.0)
        // exp(0) = 1.0
        #expect(abs(logprob.probability - 1.0) < 0.0001)
    }

    @Test("probability of -1 is approximately 0.368")
    func probabilityNegativeOne() {
        let logprob = TokenLogprob(token: "b", logprob: -1.0)
        // exp(-1) ≈ 0.3679
        #expect(abs(logprob.probability - exp(-1.0)) < 0.0001)
    }

    @Test("probability of very negative logprob is near 0")
    func probabilityVeryNegative() {
        let logprob = TokenLogprob(token: "c", logprob: -100.0)
        #expect(logprob.probability >= 0)
        #expect(logprob.probability < 0.0001)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let original = TokenLogprob(token: "hello", logprob: -0.5, tokenId: 42)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenLogprob.self, from: data)
        #expect(decoded.token == original.token)
        #expect(decoded.logprob == original.logprob)
        #expect(decoded.tokenId == original.tokenId)
    }

    @Test("Codable round-trip with nil tokenId")
    func codableRoundTripNilTokenId() throws {
        let original = TokenLogprob(token: "world", logprob: -1.0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenLogprob.self, from: data)
        #expect(decoded.token == original.token)
        #expect(decoded.logprob == original.logprob)
        #expect(decoded.tokenId == nil)
    }

    // MARK: - Hashable

    @Test("Equal TokenLogprobs have same hash")
    func hashableEqual() {
        let a = TokenLogprob(token: "x", logprob: -0.5, tokenId: 1)
        let b = TokenLogprob(token: "x", logprob: -0.5, tokenId: 1)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different TokenLogprobs are not equal")
    func hashableNotEqual() {
        let a = TokenLogprob(token: "x", logprob: -0.5, tokenId: 1)
        let b = TokenLogprob(token: "y", logprob: -0.5, tokenId: 1)
        #expect(a != b)
    }

    @Test("TokenLogprobs work in Set")
    func hashableSet() {
        let a = TokenLogprob(token: "x", logprob: -0.5)
        let b = TokenLogprob(token: "x", logprob: -0.5)
        let c = TokenLogprob(token: "y", logprob: -1.0)
        let set: Set<TokenLogprob> = [a, b, c]
        #expect(set.count == 2)
    }

    // MARK: - Sendable

    @Test("TokenLogprob is Sendable")
    func sendable() async {
        let logprob = TokenLogprob(token: "test", logprob: -0.5, tokenId: 10)
        let token = await Task { logprob.token }.value
        #expect(token == "test")
    }
}
