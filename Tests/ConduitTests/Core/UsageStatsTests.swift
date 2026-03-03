// UsageStatsTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("UsageStats Tests")
struct UsageStatsTests {

    // MARK: - Initialization

    @Test("Init stores prompt and completion tokens")
    func initialization() {
        let usage = UsageStats(promptTokens: 100, completionTokens: 50)

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 50)
    }

    // MARK: - Computed Properties

    @Test("totalTokens sums prompt and completion tokens")
    func totalTokens() {
        let usage = UsageStats(promptTokens: 100, completionTokens: 50)
        #expect(usage.totalTokens == 150)
    }

    @Test("totalTokens with zero values")
    func totalTokensZero() {
        let usage = UsageStats(promptTokens: 0, completionTokens: 0)
        #expect(usage.totalTokens == 0)
    }

    @Test("totalTokens with large values")
    func totalTokensLarge() {
        let usage = UsageStats(promptTokens: 100_000, completionTokens: 50_000)
        #expect(usage.totalTokens == 150_000)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves values")
    func codableRoundTrip() throws {
        let original = UsageStats(promptTokens: 42, completionTokens: 17)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UsageStats.self, from: data)

        #expect(decoded.promptTokens == 42)
        #expect(decoded.completionTokens == 17)
    }

    @Test("JSON encoding produces expected keys")
    func jsonKeys() throws {
        let usage = UsageStats(promptTokens: 10, completionTokens: 20)
        let data = try JSONEncoder().encode(usage)
        let json = try JSONDecoder().decode([String: Int].self, from: data)

        #expect(json["promptTokens"] == 10)
        #expect(json["completionTokens"] == 20)
        // totalTokens is computed, should not appear in JSON
        #expect(json["totalTokens"] == nil)
    }

    // MARK: - Hashable

    @Test("Equal UsageStats have same hash")
    func hashEquality() {
        let a = UsageStats(promptTokens: 10, completionTokens: 20)
        let b = UsageStats(promptTokens: 10, completionTokens: 20)

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different UsageStats are unequal")
    func hashInequality() {
        let a = UsageStats(promptTokens: 10, completionTokens: 20)
        let b = UsageStats(promptTokens: 10, completionTokens: 30)

        #expect(a != b)
    }

    @Test("UsageStats can be used in a Set")
    func setUsage() {
        let a = UsageStats(promptTokens: 10, completionTokens: 20)
        let b = UsageStats(promptTokens: 30, completionTokens: 40)

        var set: Set<UsageStats> = []
        set.insert(a)
        set.insert(b)

        #expect(set.count == 2)
    }
}
