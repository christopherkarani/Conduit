// OpenAIProviderReasoningTests.swift
// Conduit Tests
//
// Tests for OpenRouter reasoning/thinking mode support.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("OpenAI Provider Reasoning Tests")
struct OpenAIProviderReasoningTests {

    // MARK: - ReasoningEffort Tests

    @Suite("ReasoningEffort Type")
    struct ReasoningEffortTypeTests {

        @Test("ReasoningEffort has all levels")
        func effortLevels() {
            let levels = ReasoningEffort.allCases
            #expect(levels.contains(.xhigh))
            #expect(levels.contains(.high))
            #expect(levels.contains(.medium))
            #expect(levels.contains(.low))
            #expect(levels.contains(.minimal))
            #expect(levels.contains(.none))
        }

        @Test("ReasoningEffort raw values match API")
        func effortRawValues() {
            #expect(ReasoningEffort.xhigh.rawValue == "xhigh")
            #expect(ReasoningEffort.high.rawValue == "high")
            #expect(ReasoningEffort.medium.rawValue == "medium")
            #expect(ReasoningEffort.low.rawValue == "low")
            #expect(ReasoningEffort.minimal.rawValue == "minimal")
            #expect(ReasoningEffort.none.rawValue == "none")
        }

        @Test("ReasoningEffort conforms to Sendable")
        func sendableConformance() {
            let effort: any Sendable = ReasoningEffort.high
            #expect(effort is ReasoningEffort)
        }

        @Test("ReasoningEffort Codable round-trip")
        func codableRoundTrip() throws {
            for effort in ReasoningEffort.allCases {
                let encoded = try JSONEncoder().encode(effort)
                let decoded = try JSONDecoder().decode(ReasoningEffort.self, from: encoded)
                #expect(effort == decoded)
            }
        }
    }

    // MARK: - ReasoningConfig Tests

    @Suite("ReasoningConfig Type")
    struct ReasoningConfigTypeTests {

        @Test("ReasoningConfig creation with effort")
        func reasoningConfigWithEffort() {
            let config = ReasoningConfig(effort: .high)
            #expect(config.effort == .high)
            #expect(config.maxTokens == nil)
            #expect(config.exclude == nil)
        }

        @Test("ReasoningConfig creation with maxTokens")
        func reasoningConfigWithMaxTokens() {
            let config = ReasoningConfig(maxTokens: 2000)
            #expect(config.maxTokens == 2000)
            #expect(config.effort == nil)
        }

        @Test("ReasoningConfig creation with enabled flag")
        func reasoningConfigEnabled() {
            let config = ReasoningConfig(enabled: true)
            #expect(config.enabled == true)
        }

        @Test("ReasoningConfig creation with exclude flag")
        func reasoningConfigExclude() {
            let config = ReasoningConfig(effort: .high, exclude: true)
            #expect(config.effort == .high)
            #expect(config.exclude == true)
        }

        @Test("ReasoningConfig conforms to Sendable")
        func sendableConformance() {
            let config: any Sendable = ReasoningConfig(effort: .medium)
            #expect(config is ReasoningConfig)
        }

        @Test("ReasoningConfig conforms to Codable")
        func codableConformance() throws {
            let original = ReasoningConfig(effort: .high, maxTokens: 1500, exclude: false)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ReasoningConfig.self, from: encoded)

            #expect(decoded.effort == .high)
            #expect(decoded.maxTokens == 1500)
            #expect(decoded.exclude == false)
        }
    }

    // MARK: - ReasoningDetail Tests

    @Suite("ReasoningDetail Type")
    struct ReasoningDetailTypeTests {

        @Test("ReasoningDetail has required properties")
        func reasoningDetailProperties() {
            let detail = ReasoningDetail(
                id: "rd_1",
                type: "reasoning.text",
                format: "anthropic-claude-v1",
                index: 0,
                content: "Some reasoning"
            )

            #expect(detail.id == "rd_1")
            #expect(detail.type == "reasoning.text")
            #expect(detail.format == "anthropic-claude-v1")
            #expect(detail.index == 0)
            #expect(detail.content == "Some reasoning")
        }

        @Test("ReasoningDetail conforms to Sendable")
        func sendableConformance() {
            let detail: any Sendable = ReasoningDetail(
                id: "rd_1",
                type: "reasoning.text",
                format: "test",
                index: 0,
                content: nil
            )
            #expect(detail is ReasoningDetail)
        }

        @Test("ReasoningDetail Codable round-trip")
        func codableRoundTrip() throws {
            let original = ReasoningDetail(
                id: "rd_test",
                type: "reasoning.summary",
                format: "anthropic-claude-v1",
                index: 1,
                content: "Summary of reasoning"
            )

            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(ReasoningDetail.self, from: encoded)

            #expect(decoded.id == original.id)
            #expect(decoded.type == original.type)
            #expect(decoded.content == original.content)
        }
    }

    // MARK: - GenerateConfig Integration Tests

    @Suite("GenerateConfig Integration")
    struct GenerateConfigIntegrationTests {

        @Test("GenerateConfig has reasoning property")
        func reasoningProperty() {
            let config = GenerateConfig.default
            #expect(config.reasoning == nil)
        }

        @Test("GenerateConfig fluent API for reasoning with effort")
        func fluentAPIReasoningEffort() {
            let config = GenerateConfig.default
                .reasoning(.high)

            #expect(config.reasoning?.effort == .high)
        }

        @Test("GenerateConfig fluent API for reasoning with config")
        func fluentAPIReasoningConfig() {
            let reasoningConfig = ReasoningConfig(effort: .medium, maxTokens: 2000, exclude: true)
            let config = GenerateConfig.default
                .reasoning(reasoningConfig)

            #expect(config.reasoning?.effort == .medium)
            #expect(config.reasoning?.maxTokens == 2000)
            #expect(config.reasoning?.exclude == true)
        }

        @Test("GenerateConfig reasoning preserves other settings")
        func reasoningPreservesSettings() {
            let config = GenerateConfig.default
                .temperature(0.5)
                .maxTokens(500)
                .reasoning(.high)

            #expect(config.temperature == 0.5)
            #expect(config.maxTokens == 500)
            #expect(config.reasoning?.effort == .high)
        }

        @Test("GenerateConfig reasoning is included in Codable")
        func reasoningCodable() throws {
            let config = GenerateConfig.default
                .reasoning(.medium)

            let encoded = try JSONEncoder().encode(config)
            let decoded = try JSONDecoder().decode(GenerateConfig.self, from: encoded)

            #expect(decoded.reasoning?.effort == .medium)
        }
    }

    // MARK: - Compatibility Tests

    @Suite("Compatibility")
    struct CompatibilityTests {

        @Test("Reasoning preserved in config copy")
        func reasoningPreservedInCopy() {
            let config = GenerateConfig.default
                .reasoning(.high)
                .temperature(0.5)

            let modified = config.maxTokens(1000)

            #expect(modified.reasoning?.effort == .high)
            #expect(modified.temperature == 0.5)
            #expect(modified.maxTokens == 1000)
        }
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
