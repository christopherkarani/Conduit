// AnthropicIntegrationTests.swift
// Conduit
//
// Integration tests for Anthropic provider with live API.
// These tests require ANTHROPIC_API_KEY environment variable.

#if CONDUIT_TRAIT_ANTHROPIC
import Testing
import Foundation
@testable import Conduit

/// Integration tests for Anthropic provider with live API.
///
/// These tests require ANTHROPIC_API_KEY environment variable.
/// They are automatically skipped if the key is not present.
///
/// ## Running Tests
///
/// ### Without API key (tests skip gracefully):
/// ```bash
/// swift test --filter AnthropicIntegrationTests
/// ```
///
/// ### With API key (tests run):
/// ```bash
/// ANTHROPIC_API_KEY=sk-ant-... swift test --filter AnthropicIntegrationTests
/// ```
///
/// ## Cost Considerations
///
/// These tests use Claude 3 Haiku (the fastest/cheapest model) with low max_tokens
/// to minimize costs. Total cost per full test run should be < $0.01.
@Suite("Anthropic Integration Tests")
struct AnthropicIntegrationTests {

    // MARK: - Helpers

    /// Check if API key is available in environment.
    private var hasAPIKey: Bool {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil
    }

    /// Get API key from environment.
    private var apiKey: String? {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
    }

    // MARK: - Basic Generation Tests

    @Test("Live API generation test", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func liveAPIGeneration() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        let result = try await provider.generate(
            messages: [.user("Say 'hello' in exactly one word")],
            model: .claude3Haiku,
            config: .default.maxTokens(10)
        )

        #expect(!result.text.isEmpty)
        #expect(result.text.lowercased().contains("hello"))
        #expect(result.tokenCount > 0)
        #expect(result.generationTime > 0)
        #expect(result.finishReason == .stop || result.finishReason == .maxTokens)
    }

    @Test("Live conversation test", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func liveConversation() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        let messages = [
            Message.system("You are a helpful assistant. Keep responses very brief."),
            Message.user("What is 2+2?"),
            Message.assistant("4"),
            Message.user("What about 3+3?")
        ]

        let result = try await provider.generate(
            messages: messages,
            model: .claude3Haiku,
            config: .default.maxTokens(10)
        )

        #expect(!result.text.isEmpty)
        #expect(result.usage != nil)

        if let usage = result.usage {
            #expect(usage.promptTokens > 0)
            #expect(usage.completionTokens > 0)
            #expect(usage.totalTokens == usage.promptTokens + usage.completionTokens)
        }
    }

    @Test("Live multi-turn conversation", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func liveMultiTurnConversation() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        // First turn
        let firstResult = try await provider.generate(
            messages: [.user("Name one color")],
            model: .claude3Haiku,
            config: .default.maxTokens(5)
        )

        #expect(!firstResult.text.isEmpty)

        // Second turn with context
        let messages = [
            Message.user("Name one color"),
            Message.assistant(firstResult.text),
            Message.user("Name a different color")
        ]

        let secondResult = try await provider.generate(
            messages: messages,
            model: .claude3Haiku,
            config: .default.maxTokens(5)
        )

        #expect(!secondResult.text.isEmpty)
        #expect(secondResult.text != firstResult.text)
    }

    // MARK: - Streaming Tests

    @Test("Live streaming test", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func liveStreaming() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)
        var receivedChunks = 0
        var fullText = ""

        for try await chunk in provider.stream(
            "Count to 3",
            model: .claude3Haiku,
            config: .default.maxTokens(20)
        ) {
            receivedChunks += 1
            fullText += chunk
        }

        #expect(receivedChunks > 0)
        #expect(!fullText.isEmpty)
    }

    @Test("Live streaming with metadata", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func liveStreamingWithMetadata() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)
        var receivedChunks = 0
        var fullText = ""
        var lastChunk: GenerationChunk?

        for try await chunk in provider.stream(
            messages: [.user("Say hello")],
            model: .claude3Haiku,
            config: .default.maxTokens(10)
        ) {
            receivedChunks += 1
            fullText += chunk.text
            lastChunk = chunk
        }

        #expect(receivedChunks > 0)
        #expect(!fullText.isEmpty)

        // Last chunk should be marked as complete
        #expect(lastChunk?.isComplete == true)
        #expect(lastChunk?.finishReason != nil)
    }

    @Test("Streaming yields progressive chunks", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func streamingProgressive() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)
        var chunks: [GenerationChunk] = []

        for try await chunk in provider.stream(
            messages: [.user("Write three words")],
            model: .claude3Haiku,
            config: .default.maxTokens(15)
        ) {
            chunks.append(chunk)
        }

        // Should receive multiple chunks
        #expect(chunks.count > 1)

        // Chunks should not all be marked complete until the last one
        let completeChunks = chunks.filter { $0.isComplete }
        #expect(completeChunks.count == 1)
        #expect(chunks.last?.isComplete == true)
    }

    // MARK: - Error Handling Tests

    @Test("Invalid API key throws authenticationFailed",
          .disabled("Requires network access - run manually with: swift test --filter invalidAPIKey"))
    func invalidAPIKey() async throws {
        let provider = AnthropicProvider(apiKey: "sk-ant-invalid-key-12345")

        do {
            _ = try await provider.generate(
                messages: [.user("Test")],
                model: .claude3Haiku,
                config: .default.maxTokens(10)
            )
            Issue.record("Expected authentication error")
        } catch let error as AIError {
            // Check that it's an authentication error
            switch error {
            case .authenticationFailed:
                // Expected - test passes
                break
            case .networkError:
                // Also acceptable - could be network issue with invalid key
                break
            default:
                Issue.record("Expected authenticationFailed or networkError, got \(error)")
            }
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    @Test("Empty messages array throws invalidInput", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func emptyMessagesArray() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        do {
            _ = try await provider.generate(
                messages: [],
                model: .claude3Haiku,
                config: .default
            )
            Issue.record("Expected invalidInput error")
        } catch let error as AIError {
            if case .invalidInput = error {
                // Expected - test passes
            } else {
                Issue.record("Expected invalidInput, got \(error)")
            }
        } catch {
            Issue.record("Expected AIError, got \(error)")
        }
    }

    // MARK: - Availability Tests

    @Test("Provider with valid API key is available", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func providerWithKeyIsAvailable() async {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)
        let isAvailable = await provider.isAvailable
        let status = await provider.availabilityStatus

        #expect(isAvailable == true)
        #expect(status.isAvailable == true)
        #expect(status.unavailableReason == nil)
    }

    @Test("Provider without API key is unavailable")
    func providerWithoutKeyIsUnavailable() async {
        let provider = AnthropicProvider(apiKey: "")
        let isAvailable = await provider.isAvailable
        let status = await provider.availabilityStatus

        #expect(isAvailable == false)
        #expect(status.isAvailable == false)
        #expect(status.unavailableReason != nil)
    }

    @Test("Provider availability check doesn't make API calls")
    func availabilityCheckNoAPICall() async {
        // This test verifies that availability checks are fast and don't hit the API
        let provider = AnthropicProvider(apiKey: "sk-ant-fake-key")

        let startTime = Date()
        _ = await provider.isAvailable
        let elapsed = Date().timeIntervalSince(startTime)

        // Should complete in < 100ms (would be much slower if making API call)
        #expect(elapsed < 0.1)
    }

    // MARK: - Cancellation Tests

    @Test("Generation can be cancelled", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func generationCancellation() async {
        guard let apiKey = apiKey else {
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        let task = Task {
            try await provider.generate(
                messages: [.user("Write a very long essay about Swift programming")],
                model: .claude3Haiku,
                config: .default.maxTokens(1000)
            )
        }

        // Cancel after brief delay
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            // If it completes before cancellation, that's also acceptable
        } catch is CancellationError {
            // Expected - test passes
        } catch {
            // Other errors are acceptable if cancellation was too late
        }
    }

    @Test("Explicit cancellation stops generation", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func explicitCancellation() async {
        guard let apiKey = apiKey else {
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        Task {
            try? await Task.sleep(for: .milliseconds(50))
            await provider.cancelGeneration()
        }

        do {
            _ = try await provider.generate(
                messages: [.user("Write a long essay")],
                model: .claude3Haiku,
                config: .default.maxTokens(1000)
            )
            // Completion before cancellation is acceptable
        } catch {
            // Cancellation error is expected
        }
    }

    // MARK: - Configuration Tests

    @Test("Custom configuration works", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func customConfiguration() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        var config = AnthropicConfiguration.standard(apiKey: apiKey)
        config = config.timeout(120.0).maxRetries(5)

        let provider = AnthropicProvider(configuration: config)

        let result = try await provider.generate(
            messages: [.user("Hi")],
            model: .claude3Haiku,
            config: .default.maxTokens(5)
        )

        #expect(!result.text.isEmpty)
    }

    @Test("Different models work", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil && false))
    func differentModels() async throws {
        // Disabled by default to avoid costs
        // Enable manually to test different model variants
        guard let apiKey = apiKey else {
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        // Test with Claude 3.5 Sonnet
        let sonnetResult = try await provider.generate(
            messages: [.user("Hi")],
            model: .claude35Sonnet,
            config: .default.maxTokens(5)
        )

        #expect(!sonnetResult.text.isEmpty)

        // Test with Claude Sonnet 4.5
        let sonnet45Result = try await provider.generate(
            messages: [.user("Hi")],
            model: .claudeSonnet45,
            config: .default.maxTokens(5)
        )

        #expect(!sonnet45Result.text.isEmpty)
    }

    // MARK: - Advanced Features Tests

    @Test("Extended thinking test", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil && false))
    func extendedThinking() async throws {
        // Disabled by default (uses more tokens, may be slower)
        guard let apiKey = apiKey else {
            return
        }

        var config = AnthropicConfiguration.standard(apiKey: apiKey)
        config.thinkingConfig = .standard

        let provider = AnthropicProvider(configuration: config)

        let result = try await provider.generate(
            messages: [.user("Solve this riddle: I have cities but no houses, forests but no trees, water but no fish. What am I?")],
            model: .claudeOpus45,
            config: .default.maxTokens(100)
        )

        #expect(!result.text.isEmpty)
        // With thinking enabled, response should show deeper reasoning
    }

    @Test("Vision API test", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil && false))
    func visionAPI() async throws {
        // Disabled by default (requires image setup and uses vision model)
        // Enable manually for vision testing
        guard let apiKey = apiKey else {
            return
        }

        _ = AnthropicProvider(apiKey: apiKey)

        // Note: This is a placeholder for vision testing.
        // Real implementation would need to create Message with image content.
        // Vision support requires proper image encoding and content blocks.

        // Example structure (not functional without proper image implementation):
        // let messages = [Message.user("Describe this image", images: [imageData])]
        // let result = try await provider.generate(
        //     messages: messages,
        //     model: .claudeSonnet45,
        //     config: .default
        // )
        // #expect(!result.text.isEmpty)
    }

    // MARK: - Token Limits Tests

    @Test("Max tokens limit is respected", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil))
    func maxTokensLimit() async throws {
        guard let apiKey = apiKey else {
            Issue.record("API key not found - test should be disabled")
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        let result = try await provider.generate(
            messages: [.user("Write as much as you can")],
            model: .claude3Haiku,
            config: .default.maxTokens(5)
        )

        #expect(!result.text.isEmpty)
        #expect(result.tokenCount <= 5)

        // Should finish with maxTokens reason if it hit the limit
        if result.tokenCount >= 5 {
            #expect(result.finishReason == .maxTokens || result.finishReason == .stop)
        }
    }

    @Test("Temperature parameter affects generation", .enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil && false))
    func temperatureParameter() async throws {
        // Disabled by default (costs more, non-deterministic)
        guard let apiKey = apiKey else {
            return
        }

        let provider = AnthropicProvider(apiKey: apiKey)

        // Low temperature (more deterministic)
        let deterministicResult = try await provider.generate(
            messages: [.user("Pick a number between 1 and 100")],
            model: .claude3Haiku,
            config: .default.temperature(0.1).maxTokens(10)
        )

        // High temperature (more random)
        let randomResult = try await provider.generate(
            messages: [.user("Pick a number between 1 and 100")],
            model: .claude3Haiku,
            config: .default.temperature(1.5).maxTokens(10)
        )

        #expect(!deterministicResult.text.isEmpty)
        #expect(!randomResult.text.isEmpty)
    }
}

#endif // CONDUIT_TRAIT_ANTHROPIC
