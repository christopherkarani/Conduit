// FinishReasonTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("FinishReason Tests")
struct FinishReasonTests {

    // MARK: - Raw Values

    @Test("All raw values match expected wire format")
    func rawValues() {
        #expect(FinishReason.stop.rawValue == "stop")
        #expect(FinishReason.maxTokens.rawValue == "max_tokens")
        #expect(FinishReason.stopSequence.rawValue == "stop_sequence")
        #expect(FinishReason.cancelled.rawValue == "cancelled")
        #expect(FinishReason.contentFilter.rawValue == "content_filter")
        #expect(FinishReason.toolCall.rawValue == "tool_call")
        #expect(FinishReason.toolCalls.rawValue == "tool_calls")
        #expect(FinishReason.pauseTurn.rawValue == "pause_turn")
        #expect(FinishReason.modelContextWindowExceeded.rawValue == "model_context_window_exceeded")
    }

    // MARK: - isToolCallRequest

    @Test("isToolCallRequest returns true for toolCall")
    func isToolCallRequestSingular() {
        #expect(FinishReason.toolCall.isToolCallRequest)
    }

    @Test("isToolCallRequest returns true for toolCalls")
    func isToolCallRequestPlural() {
        #expect(FinishReason.toolCalls.isToolCallRequest)
    }

    @Test("isToolCallRequest returns false for non-tool-call reasons",
          arguments: [
            FinishReason.stop,
            .maxTokens,
            .stopSequence,
            .cancelled,
            .contentFilter,
            .pauseTurn,
            .modelContextWindowExceeded
          ])
    func isToolCallRequestFalse(reason: FinishReason) {
        #expect(!reason.isToolCallRequest)
    }

    // MARK: - Codable

    @Test("Codable round-trip for all cases",
          arguments: [
            FinishReason.stop,
            .maxTokens,
            .stopSequence,
            .cancelled,
            .contentFilter,
            .toolCall,
            .toolCalls,
            .pauseTurn,
            .modelContextWindowExceeded
          ])
    func codableRoundTrip(reason: FinishReason) throws {
        let data = try JSONEncoder().encode(reason)
        let decoded = try JSONDecoder().decode(FinishReason.self, from: data)
        #expect(reason == decoded)
    }

    @Test("Decodes from raw value string")
    func decodesFromString() throws {
        let json = Data("\"max_tokens\"".utf8)
        let decoded = try JSONDecoder().decode(FinishReason.self, from: json)
        #expect(decoded == .maxTokens)
    }

    @Test("Decodes tool_call from wire format")
    func decodesToolCall() throws {
        let json = Data("\"tool_call\"".utf8)
        let decoded = try JSONDecoder().decode(FinishReason.self, from: json)
        #expect(decoded == .toolCall)
    }

    @Test("Decodes tool_calls from wire format")
    func decodesToolCalls() throws {
        let json = Data("\"tool_calls\"".utf8)
        let decoded = try JSONDecoder().decode(FinishReason.self, from: json)
        #expect(decoded == .toolCalls)
    }

    // MARK: - Hashable

    @Test("Can be used in a Set")
    func hashable() {
        let reasons: Set<FinishReason> = [.stop, .maxTokens, .stop]
        #expect(reasons.count == 2)
    }
}
