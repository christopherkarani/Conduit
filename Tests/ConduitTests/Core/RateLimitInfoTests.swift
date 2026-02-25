// RateLimitInfoTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("RateLimitInfo Tests")
struct RateLimitInfoTests {

    // MARK: - Header Parsing

    @Test("Parses all Anthropic headers")
    func parsesAllHeaders() {
        let headers: [String: String] = [
            "request-id": "req-abc123",
            "anthropic-organization-id": "org-xyz",
            "anthropic-ratelimit-requests-limit": "100",
            "anthropic-ratelimit-tokens-limit": "50000",
            "anthropic-ratelimit-requests-remaining": "95",
            "anthropic-ratelimit-tokens-remaining": "48000",
            "retry-after": "30"
        ]

        let info = RateLimitInfo(headers: headers)

        #expect(info.requestId == "req-abc123")
        #expect(info.organizationId == "org-xyz")
        #expect(info.limitRequests == 100)
        #expect(info.limitTokens == 50000)
        #expect(info.remainingRequests == 95)
        #expect(info.remainingTokens == 48000)
        #expect(info.retryAfter == 30)
    }

    @Test("Case-insensitive header matching")
    func caseInsensitive() {
        let headers: [String: String] = [
            "Request-Id": "req-upper",
            "Anthropic-Organization-Id": "org-upper",
            "Anthropic-Ratelimit-Requests-Limit": "200"
        ]

        let info = RateLimitInfo(headers: headers)

        #expect(info.requestId == "req-upper")
        #expect(info.organizationId == "org-upper")
        #expect(info.limitRequests == 200)
    }

    @Test("Missing headers produce nil values")
    func missingHeaders() {
        let info = RateLimitInfo(headers: [:])

        #expect(info.requestId == nil)
        #expect(info.organizationId == nil)
        #expect(info.limitRequests == nil)
        #expect(info.limitTokens == nil)
        #expect(info.remainingRequests == nil)
        #expect(info.remainingTokens == nil)
        #expect(info.resetRequests == nil)
        #expect(info.resetTokens == nil)
        #expect(info.retryAfter == nil)
    }

    @Test("Invalid numeric values produce nil")
    func invalidNumericValues() {
        let headers: [String: String] = [
            "anthropic-ratelimit-requests-limit": "not-a-number",
            "retry-after": "invalid"
        ]

        let info = RateLimitInfo(headers: headers)

        #expect(info.limitRequests == nil)
        #expect(info.retryAfter == nil)
    }

    // MARK: - Date Parsing

    @Test("Parses ISO8601 date with fractional seconds")
    func parsesDateWithFractional() {
        let headers: [String: String] = [
            "anthropic-ratelimit-requests-reset": "2025-01-15T10:30:00.500Z"
        ]

        let info = RateLimitInfo(headers: headers)
        #expect(info.resetRequests != nil)
    }

    @Test("Parses ISO8601 date without fractional seconds")
    func parsesDateWithoutFractional() {
        let headers: [String: String] = [
            "anthropic-ratelimit-tokens-reset": "2025-01-15T10:30:00Z"
        ]

        let info = RateLimitInfo(headers: headers)
        #expect(info.resetTokens != nil)
    }

    @Test("Invalid date string produces nil")
    func invalidDate() {
        let headers: [String: String] = [
            "anthropic-ratelimit-requests-reset": "not-a-date"
        ]

        let info = RateLimitInfo(headers: headers)
        #expect(info.resetRequests == nil)
    }

    // MARK: - Explicit Init

    @Test("Explicit init stores all values")
    func explicitInit() {
        let date = Date()
        let info = RateLimitInfo(
            requestId: "req-1",
            organizationId: "org-1",
            limitRequests: 100,
            limitTokens: 50000,
            remainingRequests: 95,
            remainingTokens: 48000,
            resetRequests: date,
            resetTokens: date,
            retryAfter: 60
        )

        #expect(info.requestId == "req-1")
        #expect(info.organizationId == "org-1")
        #expect(info.limitRequests == 100)
        #expect(info.limitTokens == 50000)
        #expect(info.remainingRequests == 95)
        #expect(info.remainingTokens == 48000)
        #expect(info.resetRequests == date)
        #expect(info.resetTokens == date)
        #expect(info.retryAfter == 60)
    }

    // MARK: - Hashable

    @Test("Equal RateLimitInfo values are equal")
    func equality() {
        let a = RateLimitInfo(requestId: "req-1", limitRequests: 100)
        let b = RateLimitInfo(requestId: "req-1", limitRequests: 100)
        #expect(a == b)
    }

    @Test("Different RateLimitInfo values are unequal")
    func inequality() {
        let a = RateLimitInfo(requestId: "req-1")
        let b = RateLimitInfo(requestId: "req-2")
        #expect(a != b)
    }

    // MARK: - Codable

    @Test("Codable round-trip preserves values")
    func codableRoundTrip() throws {
        let original = RateLimitInfo(
            requestId: "req-1",
            organizationId: "org-1",
            limitRequests: 100,
            limitTokens: 50000,
            remainingRequests: 95,
            remainingTokens: 48000,
            retryAfter: 30
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RateLimitInfo.self, from: data)

        #expect(original == decoded)
    }
}
