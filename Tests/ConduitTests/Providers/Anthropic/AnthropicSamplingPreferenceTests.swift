// AnthropicSamplingPreferenceTests.swift
// Conduit
//
// Tests for the Anthropic provider's temperature/top_p sampling preference logic.
// Anthropic's Messages API rejects requests that specify both `temperature` and
// `top_p`; the provider must send only one. The selection rule is:
//
//   - If the caller explicitly set `top_p` to a non-default value AND left
//     `temperature` at the default → send top_p only (nucleus sampling).
//   - Otherwise → send temperature only.
//
// These tests pin that contract so future refactors can't silently regress
// `.topP(0.95)` requests by always preferring temperature.

#if CONDUIT_TRAIT_ANTHROPIC
import Testing
import Foundation
@testable import ConduitAdvanced

@Suite("Anthropic temperature/top_p sampling preference")
struct AnthropicSamplingPreferenceTests {
    private func provider() -> AnthropicProvider {
        AnthropicProvider(configuration: .standard(apiKey: "sk-test-only"))
    }

    private func userMessage(_ text: String = "hi") -> [Message] {
        [Message(role: .user, content: .text(text))]
    }

    private let model: ModelIdentifier = .anthropic("claude-sonnet-4.5")

    @Test("Default config sends temperature only — never both")
    func defaultConfigSendsTemperatureOnly() async throws {
        let request = try await provider().buildRequestBody(
            messages: userMessage(),
            model: model,
            config: .default
        )
        #expect(request.temperature != nil)
        #expect(request.topP == nil)
    }

    @Test("Explicit `.topP(0.95)` with default temperature sends top_p only (regression for #58 review)")
    func explicitTopPSendsTopPOnly() async throws {
        let config = GenerateConfig.default.topP(0.95)
        let request = try await provider().buildRequestBody(
            messages: userMessage(),
            model: model,
            config: config
        )
        #expect(request.temperature == nil, "Anthropic must drop temperature when caller explicitly set top_p")
        #expect(abs((request.topP ?? 0) - 0.95) < 0.001)
    }

    @Test("Explicit `.temperature(0.3)` with default top_p sends temperature only")
    func explicitTemperatureSendsTemperatureOnly() async throws {
        let config = GenerateConfig.default.temperature(0.3)
        let request = try await provider().buildRequestBody(
            messages: userMessage(),
            model: model,
            config: config
        )
        #expect(abs((request.temperature ?? 0) - 0.3) < 0.0001)
        #expect(request.topP == nil)
    }

    @Test("Explicit both non-default falls back to temperature (documented preference order)")
    func explicitBothPreferenceTemperature() async throws {
        let config = GenerateConfig.default
            .temperature(0.5)
            .topP(0.95)
        let request = try await provider().buildRequestBody(
            messages: userMessage(),
            model: model,
            config: config
        )
        // Ambiguous case: caller set both. We pick temperature, matching
        // OpenAI provider's preference order. The Anthropic API would
        // reject with both → we ensure exactly one goes on the wire.
        #expect(request.temperature != nil)
        #expect(request.topP == nil)
    }

    @Test("Never sends both — invariant across config-builder permutations")
    func neverSendsBoth() async throws {
        let configs: [GenerateConfig] = [
            .default,
            .default.temperature(0.0),
            .default.temperature(0.7),  // explicit-equal-to-default — treated as default
            .default.temperature(2.0),
            .default.topP(0.1),
            .default.topP(0.5),
            .default.topP(1.0),
            .default.temperature(0.5).topP(0.95),
            .default.temperature(0.0).topP(0.0)
        ]
        for config in configs {
            let request = try await provider().buildRequestBody(
                messages: userMessage(),
                model: model,
                config: config
            )
            // Anthropic invariant: at most one of temperature/top_p may be sent.
            let bothSent = (request.temperature != nil) && (request.topP != nil)
            #expect(!bothSent, "config sent both temperature and top_p (Anthropic would reject)")
        }
    }
}

#endif
