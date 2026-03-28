// FoundationModelsProviderTests.swift
// ConduitTests

import Foundation
import Testing
@testable import ConduitAdvanced

#if canImport(FoundationModels)
import FoundationModels

private let foundationModelsRuntimeAvailable: Bool = {
    if #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) {
        return SystemLanguageModel.default.isAvailable
    }
    return false
}()

@Suite("Foundation Models Provider")
struct FoundationModelsProviderTests {

    @Test("availability matches device capabilities")
    func availabilityMatchesDeviceCapabilities() async {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()

        #expect(await provider.isAvailable == DeviceCapabilities.current().supportsFoundationModels)
        #expect(await provider.isAvailable == foundationModelsRuntimeAvailable)
    }

    @Test("rejects non-Foundation Models identifiers")
    func rejectsNonFoundationModelsIdentifiers() async {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()

        await #expect(throws: AIError.self) {
            _ = try await provider.generate(
                messages: [.user("Hello")],
                model: .openAI("gpt-4o-mini"),
                config: .default
            )
        }
    }

    @Test(
        "generate returns text when Foundation Models runtime is available",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func generateReturnsText() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()
        let result = try await provider.generate(
            messages: [.user("Reply with one short sentence saying hello.")],
            model: .foundationModels,
            config: .default.maxTokens(24).temperature(0.2)
        )

        #expect(!result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test(
        "stream emits text when Foundation Models runtime is available",
        .enabled(if: foundationModelsRuntimeAvailable)
    )
    func streamEmitsText() async throws {
        guard #available(macOS 26.0, iOS 26.0, visionOS 26.0, *) else {
            return
        }
        let provider = FoundationModelsProvider()
        let stream = provider.stream(
            messages: [.user("Reply with a short greeting.")],
            model: .foundationModels,
            config: .default.maxTokens(16).temperature(0.2)
        )

        var combined = ""
        for try await chunk in stream {
            combined += chunk.text
        }

        #expect(!combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
#endif
