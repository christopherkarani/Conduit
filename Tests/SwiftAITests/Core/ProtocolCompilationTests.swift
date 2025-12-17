// ProtocolCompilationTests.swift
// SwiftAI
//
// Tests to verify all Phase 2 protocols compile correctly and can be used
// as generic constraints. These tests ensure the protocols are well-formed
// and can be conformed to by concrete types.

import XCTest
@testable import SwiftAI

// MARK: - Mock Types

/// Mock model identifier for testing protocol conformance.
struct MockModelID: ModelIdentifying {
    let rawValue: String

    var displayName: String { rawValue }
    var provider: ProviderType { .mlx }
    var description: String { rawValue }
}

/// Mock AI provider for testing protocol conformance.
///
/// This actor demonstrates that a type can successfully conform to
/// the AIProvider protocol and satisfies all its requirements.
actor MockProvider: AIProvider {
    typealias Response = GenerationResult
    typealias StreamChunk = GenerationChunk
    typealias ModelID = MockModelID

    // MARK: - Availability

    var isAvailable: Bool {
        get async { true }
    }

    var availabilityStatus: ProviderAvailability {
        get async { .available }
    }

    // MARK: - Text Generation

    func generate(
        messages: [Message],
        model: MockModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        // Stub implementation for compilation testing
        GenerationResult(
            text: "Mock response",
            tokenCount: 2,
            generationTime: 0.1,
            tokensPerSecond: 20.0,
            finishReason: .stop
        )
    }

    nonisolated func stream(
        messages: [Message],
        model: MockModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(GenerationChunk(
                text: "Mock",
                tokenCount: 1,
                isComplete: false
            ))
            continuation.yield(GenerationChunk(
                text: " response",
                tokenCount: 1,
                isComplete: true
            ))
            continuation.finish()
        }
    }

    // MARK: - Cancellation

    func cancelGeneration() async {
        // Stub implementation
    }
}

/// Mock text generator for testing TextGenerator protocol conformance.
actor MockTextGenerator: TextGenerator {
    typealias ModelID = MockModelID

    func generate(
        _ prompt: String,
        model: MockModelID,
        config: GenerateConfig
    ) async throws -> String {
        "Mock text response to: \(prompt)"
    }

    func generate(
        messages: [Message],
        model: MockModelID,
        config: GenerateConfig
    ) async throws -> GenerationResult {
        GenerationResult(
            text: "Mock conversation response",
            tokenCount: 3,
            generationTime: 0.15,
            tokensPerSecond: 20.0,
            finishReason: .stop
        )
    }

    nonisolated func stream(
        _ prompt: String,
        model: MockModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("Mock")
            continuation.yield(" stream")
            continuation.finish()
        }
    }

    nonisolated func streamWithMetadata(
        messages: [Message],
        model: MockModelID,
        config: GenerateConfig
    ) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(GenerationChunk(
                text: "Chunk",
                tokenCount: 1,
                isComplete: false
            ))
            continuation.yield(GenerationChunk(
                text: " data",
                tokenCount: 1,
                isComplete: true
            ))
            continuation.finish()
        }
    }
}

/// Mock embedding generator for testing EmbeddingGenerator protocol conformance.
actor MockEmbeddingGenerator: EmbeddingGenerator {
    typealias ModelID = MockModelID

    func embed(
        _ text: String,
        model: MockModelID
    ) async throws -> EmbeddingResult {
        // Return a simple mock embedding vector
        EmbeddingResult(
            vector: Array(repeating: 0.1, count: 384),
            text: text,
            model: model.rawValue,
            tokenCount: text.split(separator: " ").count
        )
    }

    func embedBatch(
        _ texts: [String],
        model: MockModelID
    ) async throws -> [EmbeddingResult] {
        var results: [EmbeddingResult] = []
        for text in texts {
            results.append(try await embed(text, model: model))
        }
        return results
    }
}

/// Mock transcriber for testing Transcriber protocol conformance.
actor MockTranscriber: Transcriber {
    typealias ModelID = MockModelID

    func transcribe(
        audioURL url: URL,
        model: MockModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult {
        TranscriptionResult(
            text: "Mock transcription from URL",
            segments: [
                TranscriptionSegment(id: 0, startTime: 0, endTime: 1.5, text: "Mock"),
                TranscriptionSegment(id: 1, startTime: 1.5, endTime: 3.0, text: "transcription")
            ],
            duration: 3.0,
            processingTime: 0.5
        )
    }

    func transcribe(
        audioData data: Data,
        model: MockModelID,
        config: TranscriptionConfig
    ) async throws -> TranscriptionResult {
        TranscriptionResult(
            text: "Mock transcription from data",
            segments: [],
            duration: 0.0,
            processingTime: 0.0
        )
    }

    nonisolated func streamTranscription(
        audioURL url: URL,
        model: MockModelID,
        config: TranscriptionConfig
    ) -> AsyncThrowingStream<TranscriptionSegment, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(TranscriptionSegment(
                id: 0, startTime: 0, endTime: 1.5, text: "Mock"
            ))
            continuation.yield(TranscriptionSegment(
                id: 1, startTime: 1.5, endTime: 3.0, text: "transcription"
            ))
            continuation.finish()
        }
    }
}

/// Mock token counter for testing TokenCounter protocol conformance.
actor MockTokenCounter: TokenCounter {
    typealias ModelID = MockModelID

    func countTokens(
        in text: String,
        for model: MockModelID
    ) async throws -> TokenCount {
        // Simple approximation: 4 chars per token
        TokenCount(count: max(1, text.count / 4))
    }

    func countTokens(
        in messages: [Message],
        for model: MockModelID
    ) async throws -> TokenCount {
        // Return mock count with breakdown
        TokenCount(count: 50, promptTokens: 45, specialTokens: 5)
    }

    func encode(
        _ text: String,
        for model: MockModelID
    ) async throws -> [Int] {
        // Return mock token IDs
        Array(0..<max(1, text.count / 4))
    }

    func decode(
        _ tokens: [Int],
        for model: MockModelID,
        skipSpecialTokens: Bool
    ) async throws -> String {
        "decoded text with \(tokens.count) tokens"
    }
}

/// Mock model manager for testing ModelManaging protocol conformance.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
actor MockModelManager: ModelManaging {
    typealias ModelID = MockModelID

    private var cachedModelIds: Set<String> = []

    func availableModels() async throws -> [ModelInfo] {
        [
            ModelInfo(
                identifier: .mlx("test/model-1"),
                name: "Test Model 1",
                description: "A test model",
                size: .small,
                diskSize: .megabytes(100),
                contextWindow: 4096,
                capabilities: [.textGeneration]
            ),
            ModelInfo(
                identifier: .mlx("test/model-2"),
                name: "Test Model 2",
                description: "Another test model",
                size: .medium,
                diskSize: .gigabytes(2),
                contextWindow: 8192,
                capabilities: [.textGeneration, .codeGeneration]
            )
        ]
    }

    func cachedModels() async -> [CachedModelInfo] {
        cachedModelIds.map { id in
            CachedModelInfo(
                identifier: .mlx(id),
                path: URL(fileURLWithPath: "/tmp/models/\(id)"),
                size: .megabytes(50),
                downloadedAt: Date(),
                lastAccessedAt: Date()
            )
        }
    }

    func isCached(_ model: MockModelID) async -> Bool {
        cachedModelIds.contains(model.rawValue)
    }

    func download(
        _ model: MockModelID,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL {
        // Simulate progress updates
        progress(DownloadProgress(bytesDownloaded: 0, totalBytes: 100, filesCompleted: 0, totalFiles: 1))
        progress(DownloadProgress(bytesDownloaded: 50, totalBytes: 100, filesCompleted: 0, totalFiles: 1))
        progress(DownloadProgress(bytesDownloaded: 100, totalBytes: 100, filesCompleted: 1, totalFiles: 1))
        cachedModelIds.insert(model.rawValue)
        return URL(fileURLWithPath: "/tmp/models/\(model.rawValue)")
    }

    nonisolated func download(_ model: MockModelID) -> DownloadTask {
        DownloadTask(model: ModelIdentifier.mlx(model.rawValue))
    }

    func delete(_ model: MockModelID) async throws {
        cachedModelIds.remove(model.rawValue)
    }

    func clearCache() async throws {
        cachedModelIds.removeAll()
    }

    func cacheSize() async -> ByteCount {
        .megabytes(cachedModelIds.count * 50)
    }
}

// MARK: - Protocol Compilation Tests

/// Tests that verify Phase 2 protocols compile correctly.
///
/// These tests ensure that:
/// 1. Mock implementations can conform to protocols
/// 2. Protocols can be used as generic constraints
/// 3. Associated types work correctly
/// 4. Protocol extensions provide expected functionality
final class ProtocolCompilationTests: XCTestCase {

    // MARK: - AIProvider Protocol Tests

    func testMockProviderConformsToAIProvider() async throws {
        let provider = MockProvider()

        // Test availability
        let isAvailable = await provider.isAvailable
        XCTAssertTrue(isAvailable, "Mock provider should be available")

        let status = await provider.availabilityStatus
        XCTAssertTrue(status.isAvailable, "Mock provider status should be available")
        XCTAssertNil(status.unavailableReason, "Available provider should have no unavailable reason")
    }

    func testAIProviderGenerate() async throws {
        let provider = MockProvider()
        let messages = [Message.user("test")]
        let model = MockModelID(rawValue: "test-model")
        let config = GenerateConfig.default

        let result = try await provider.generate(
            messages: messages,
            model: model,
            config: config
        )

        XCTAssertEqual(result.text, "Mock response")
        XCTAssertEqual(result.tokenCount, 2)
        XCTAssertGreaterThan(result.generationTime, 0)
        XCTAssertGreaterThan(result.tokensPerSecond, 0)
    }

    func testAIProviderStream() async throws {
        let provider = MockProvider()
        let messages = [Message.user("test")]
        let model = MockModelID(rawValue: "test-model")
        let config = GenerateConfig.default

        let stream = provider.stream(
            messages: messages,
            model: model,
            config: config
        )

        var chunks: [GenerationChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.count, 2, "Stream should yield 2 chunks")
        XCTAssertEqual(chunks[0].text, "Mock")
        XCTAssertFalse(chunks[0].isComplete, "First chunk should not be complete")
        XCTAssertEqual(chunks[1].text, " response")
        XCTAssertTrue(chunks[1].isComplete, "Last chunk should be complete")
    }

    func testAIProviderCancellation() async {
        let provider = MockProvider()

        // Should not throw or crash
        await provider.cancelGeneration()
    }

    // MARK: - ModelIdentifying Protocol Tests

    func testMockModelIDConformsToModelIdentifying() {
        let model = MockModelID(rawValue: "test/model")

        XCTAssertEqual(model.rawValue, "test/model")
        XCTAssertEqual(model.displayName, "test/model")
        XCTAssertEqual(model.provider, .mlx)
        XCTAssertEqual(model.description, "test/model")
    }

    func testModelIdentifyingIsHashable() {
        let model1 = MockModelID(rawValue: "model-1")
        let model2 = MockModelID(rawValue: "model-2")
        let model3 = MockModelID(rawValue: "model-1")

        let modelSet: Set<MockModelID> = [model1, model2, model3]
        XCTAssertEqual(modelSet.count, 2, "Set should contain 2 unique models")

        XCTAssertTrue(modelSet.contains(model1))
        XCTAssertTrue(modelSet.contains(model2))
    }

    func testModelIdentifyingIsSendable() async {
        let model = MockModelID(rawValue: "test-model")

        // Should be safe to send across actor boundaries
        await Task {
            XCTAssertEqual(model.rawValue, "test-model")
        }.value
    }

    // MARK: - TextGenerator Protocol Tests

    func testTextGeneratorSimpleGenerate() async throws {
        let generator = MockTextGenerator()
        let model = MockModelID(rawValue: "test-model")

        let result = try await generator.generate(
            "Hello",
            model: model,
            config: .default
        )

        XCTAssertTrue(result.contains("Hello"), "Response should mention the prompt")
    }

    func testTextGeneratorConversationGenerate() async throws {
        let generator = MockTextGenerator()
        let messages = [Message.user("test")]
        let model = MockModelID(rawValue: "test-model")

        let result = try await generator.generate(
            messages: messages,
            model: model,
            config: .default
        )

        XCTAssertFalse(result.text.isEmpty, "Result should have text")
        XCTAssertGreaterThan(result.tokenCount, 0)
    }

    func testTextGeneratorStream() async throws {
        let generator = MockTextGenerator()
        let model = MockModelID(rawValue: "test-model")

        let stream = generator.stream(
            "Test prompt",
            model: model,
            config: .default
        )

        var fullText = ""
        for try await token in stream {
            fullText += token
        }

        XCTAssertEqual(fullText, "Mock stream")
    }

    func testTextGeneratorStreamWithMetadata() async throws {
        let generator = MockTextGenerator()
        let messages = [Message.user("test")]
        let model = MockModelID(rawValue: "test-model")

        let stream = generator.streamWithMetadata(
            messages: messages,
            model: model,
            config: .default
        )

        var chunks: [GenerationChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.count, 2)
        XCTAssertTrue(chunks.last?.isComplete ?? false, "Last chunk should be complete")
    }

    func testTextGeneratorDefaultImplementations() async throws {
        let generator = MockTextGenerator()
        let model = MockModelID(rawValue: "test-model")

        // Test convenience method without config parameter
        let simpleResult = try await generator.generate("Test", model: model)
        XCTAssertFalse(simpleResult.isEmpty)

        let conversationResult = try await generator.generate(
            messages: [Message.user("test")],
            model: model
        )
        XCTAssertFalse(conversationResult.text.isEmpty)

        let simpleStream = generator.stream("Test", model: model)
        var hasContent = false
        for try await _ in simpleStream {
            hasContent = true
        }
        XCTAssertTrue(hasContent)

        let metadataStream = generator.streamWithMetadata(
            messages: [Message.user("test")],
            model: model
        )
        var hasChunks = false
        for try await _ in metadataStream {
            hasChunks = true
        }
        XCTAssertTrue(hasChunks)
    }

    // MARK: - EmbeddingGenerator Protocol Tests

    func testEmbeddingGeneratorEmbed() async throws {
        let generator = MockEmbeddingGenerator()
        let model = MockModelID(rawValue: "embedding-model")

        let result = try await generator.embed(
            "Test text for embedding",
            model: model
        )

        XCTAssertEqual(result.dimensions, 384, "Mock embedding should have 384 dimensions")
        XCTAssertNotNil(result.tokenCount, "Should include token count")
    }

    func testEmbeddingGeneratorBatch() async throws {
        let generator = MockEmbeddingGenerator()
        let model = MockModelID(rawValue: "embedding-model")

        let texts = [
            "First document",
            "Second document",
            "Third document"
        ]

        let results = try await generator.embedBatch(texts, model: model)

        XCTAssertEqual(results.count, 3, "Should return same number of results as inputs")

        for result in results {
            XCTAssertEqual(result.dimensions, 384)
            XCTAssertNotNil(result.tokenCount)
        }
    }

    func testEmbeddingGeneratorEmptyBatch() async throws {
        let generator = MockEmbeddingGenerator()
        let model = MockModelID(rawValue: "embedding-model")

        let results = try await generator.embedBatch([], model: model)
        XCTAssertTrue(results.isEmpty, "Empty input should return empty results")
    }

    // MARK: - Generic Constraints Tests

    func testProtocolsAsGenericConstraints() async throws {
        // This test verifies protocols can be used as generic constraints
        await testGenericProvider(MockProvider())
        await testGenericTextGenerator(MockTextGenerator())
        await testGenericEmbeddingGenerator(MockEmbeddingGenerator())
    }

    // Helper function using AIProvider as generic constraint
    func testGenericProvider<P: AIProvider>(_ provider: P) async where P.ModelID == MockModelID {
        let isAvailable = await provider.isAvailable
        XCTAssertTrue(isAvailable)
    }

    // Helper function using TextGenerator as generic constraint
    func testGenericTextGenerator<T: TextGenerator>(_ generator: T) async where T.ModelID == MockModelID {
        // Compilation test - verifies protocol can be used as constraint
        XCTAssertTrue(true)
    }

    // Helper function using EmbeddingGenerator as generic constraint
    func testGenericEmbeddingGenerator<E: EmbeddingGenerator>(_ generator: E) async where E.ModelID == MockModelID {
        // Compilation test - verifies protocol can be used as constraint
        XCTAssertTrue(true)
    }

    // MARK: - Associated Types Tests

    func testAssociatedTypesAreCorrect() {
        // This test verifies that associated types are properly defined
        // and can be accessed from the conforming types

        // MockProvider associated types
        XCTAssertTrue(GenerationResult.self == MockProvider.Response.self)
        XCTAssertTrue(GenerationChunk.self == MockProvider.StreamChunk.self)
        XCTAssertTrue(MockModelID.self == MockProvider.ModelID.self)

        // MockTextGenerator associated types
        XCTAssertTrue(MockModelID.self == MockTextGenerator.ModelID.self)

        // MockEmbeddingGenerator associated types
        XCTAssertTrue(MockModelID.self == MockEmbeddingGenerator.ModelID.self)
    }

    // MARK: - Sendable Conformance Tests

    func testTypesAreSendable() async {
        // Test that protocol types are Sendable and can cross actor boundaries
        let provider = MockProvider()
        let textGen = MockTextGenerator()
        let embedGen = MockEmbeddingGenerator()

        await Task {
            _ = await provider.isAvailable
            _ = try? await textGen.generate(
                "test",
                model: MockModelID(rawValue: "test"),
                config: .default
            )
            _ = try? await embedGen.embed(
                "test",
                model: MockModelID(rawValue: "test")
            )
        }.value

        // If compilation succeeds, Sendable conformance is correct
        XCTAssertTrue(true)
    }

    // MARK: - ProviderType Tests

    func testProviderTypeEnum() {
        let mlx = ProviderType.mlx
        let huggingFace = ProviderType.huggingFace
        let foundationModels = ProviderType.foundationModels

        XCTAssertEqual(mlx.displayName, "MLX (Local)")
        XCTAssertEqual(huggingFace.displayName, "HuggingFace (Cloud)")
        XCTAssertEqual(foundationModels.displayName, "Apple Foundation Models")

        XCTAssertFalse(mlx.requiresNetwork)
        XCTAssertTrue(huggingFace.requiresNetwork)
        XCTAssertFalse(foundationModels.requiresNetwork)
    }

    func testProviderTypeIsCaseIterable() {
        let allCases = ProviderType.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.mlx))
        XCTAssertTrue(allCases.contains(.huggingFace))
        XCTAssertTrue(allCases.contains(.foundationModels))
    }

    func testProviderTypeIsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let mlx = ProviderType.mlx
        let encoded = try encoder.encode(mlx)
        let decoded = try decoder.decode(ProviderType.self, from: encoded)

        XCTAssertEqual(decoded, mlx)
    }

    // MARK: - ProviderAvailability Tests

    func testProviderAvailabilityAvailable() {
        let available = ProviderAvailability.available

        XCTAssertTrue(available.isAvailable)
        XCTAssertNil(available.unavailableReason)
    }

    func testProviderAvailabilityUnavailable() {
        let unavailable = ProviderAvailability.unavailable(.deviceNotSupported)

        XCTAssertFalse(unavailable.isAvailable)
        XCTAssertNotNil(unavailable.unavailableReason)
        XCTAssertEqual(unavailable.unavailableReason, .deviceNotSupported)
    }

    func testUnavailabilityReasonDescriptions() {
        XCTAssertEqual(
            UnavailabilityReason.deviceNotSupported.description,
            "Device not supported"
        )

        XCTAssertEqual(
            UnavailabilityReason.osVersionNotMet(required: "iOS 18").description,
            "Requires iOS 18 or later"
        )

        XCTAssertEqual(
            UnavailabilityReason.appleIntelligenceDisabled.description,
            "Apple Intelligence is not enabled"
        )

        XCTAssertEqual(
            UnavailabilityReason.modelDownloading(progress: 0.5).description,
            "Model downloading (50%)"
        )

        XCTAssertEqual(
            UnavailabilityReason.modelNotDownloaded.description,
            "Model not downloaded"
        )

        XCTAssertEqual(
            UnavailabilityReason.noNetwork.description,
            "No network connection"
        )

        XCTAssertEqual(
            UnavailabilityReason.apiKeyMissing.description,
            "API key not configured"
        )

        XCTAssertEqual(
            UnavailabilityReason.unknown("Custom reason").description,
            "Custom reason"
        )
    }

    // MARK: - Transcriber Protocol Tests

    func testTranscriberFromURL() async throws {
        let transcriber = MockTranscriber()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        let model = MockModelID(rawValue: "whisper")

        let result = try await transcriber.transcribe(
            audioURL: url,
            model: model,
            config: .default
        )

        XCTAssertFalse(result.text.isEmpty, "Transcription should have text")
        XCTAssertEqual(result.segments.count, 2, "Should have 2 segments")
        XCTAssertEqual(result.segments[0].text, "Mock")
        XCTAssertEqual(result.segments[1].text, "transcription")
    }

    func testTranscriberFromData() async throws {
        let transcriber = MockTranscriber()
        let data = Data("fake audio".utf8)
        let model = MockModelID(rawValue: "whisper")

        let result = try await transcriber.transcribe(
            audioData: data,
            model: model,
            config: .default
        )

        XCTAssertFalse(result.text.isEmpty)
    }

    func testTranscriberStreaming() async throws {
        let transcriber = MockTranscriber()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        let model = MockModelID(rawValue: "whisper")

        let stream = transcriber.streamTranscription(
            audioURL: url,
            model: model,
            config: .default
        )

        var segments: [TranscriptionSegment] = []
        for try await segment in stream {
            segments.append(segment)
        }

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].startTime, 0)
        XCTAssertEqual(segments[1].endTime, 3.0)
    }

    // MARK: - TokenCounter Protocol Tests

    func testTokenCounterCountText() async throws {
        let counter = MockTokenCounter()
        let model = MockModelID(rawValue: "test-model")

        let result = try await counter.countTokens(
            in: "Hello world this is a test",
            for: model
        )

        XCTAssertGreaterThan(result.count, 0)
    }

    func testTokenCounterCountMessages() async throws {
        let counter = MockTokenCounter()
        let messages = [Message.user("test1"), Message.user("test2")]
        let model = MockModelID(rawValue: "test-model")

        let result = try await counter.countTokens(
            in: messages,
            for: model
        )

        XCTAssertEqual(result.count, 50)
        XCTAssertEqual(result.promptTokens, 45)
        XCTAssertEqual(result.specialTokens, 5)
    }

    func testTokenCounterEncode() async throws {
        let counter = MockTokenCounter()
        let model = MockModelID(rawValue: "test-model")

        let tokens = try await counter.encode(
            "Hello world",
            for: model
        )

        XCTAssertFalse(tokens.isEmpty, "Should return token IDs")
    }

    func testTokenCounterDecode() async throws {
        let counter = MockTokenCounter()
        let model = MockModelID(rawValue: "test-model")

        let text = try await counter.decode(
            [1, 2, 3, 4, 5],
            for: model,
            skipSpecialTokens: true
        )

        XCTAssertTrue(text.contains("5"), "Should mention token count")
    }

    func testTokenCounterDecodeDefaultParameter() async throws {
        let counter = MockTokenCounter()
        let model = MockModelID(rawValue: "test-model")

        // Test the default parameter extension
        let text = try await counter.decode([1, 2, 3], for: model)
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - ModelManaging Protocol Tests

    @available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
    func testModelManagerAvailableModels() async throws {
        let manager = MockModelManager()

        let models = try await manager.availableModels()

        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].name, "Test Model 1")
        XCTAssertNotNil(models[0].size)
    }

    @available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
    func testModelManagerCachedModels() async {
        let manager = MockModelManager()

        let cached = await manager.cachedModels()

        XCTAssertTrue(cached.isEmpty, "Initially no models cached")
    }

    @available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
    func testModelManagerDownloadAndCache() async throws {
        let manager = MockModelManager()
        let model = MockModelID(rawValue: "test-model")

        // Initially not cached
        let isCachedBefore = await manager.isCached(model)
        XCTAssertFalse(isCachedBefore)

        // Download (progress callback is @Sendable so we can't safely mutate outside)
        _ = try await manager.download(model) { progress in
            // Just verify progress callback is called (we can't easily count in Sendable closure)
            _ = progress.fractionCompleted
        }

        // Now cached
        let isCachedAfter = await manager.isCached(model)
        XCTAssertTrue(isCachedAfter)

        let cached = await manager.cachedModels()
        XCTAssertEqual(cached.count, 1)
    }

    @available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
    func testModelManagerDelete() async throws {
        let manager = MockModelManager()
        let model = MockModelID(rawValue: "test-model")

        // Download first
        _ = try await manager.download(model) { _ in }
        let isCachedAfterDownload = await manager.isCached(model)
        XCTAssertTrue(isCachedAfterDownload)

        // Delete
        try await manager.delete(model)
        let isCachedAfterDelete = await manager.isCached(model)
        XCTAssertFalse(isCachedAfterDelete)
    }

    @available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
    func testModelManagerClearCache() async throws {
        let manager = MockModelManager()
        let model1 = MockModelID(rawValue: "model-1")
        let model2 = MockModelID(rawValue: "model-2")

        // Download multiple models
        _ = try await manager.download(model1) { _ in }
        _ = try await manager.download(model2) { _ in }

        let cachedBefore = await manager.cachedModels()
        XCTAssertEqual(cachedBefore.count, 2)

        // Clear cache
        try await manager.clearCache()

        let cachedAfter = await manager.cachedModels()
        XCTAssertTrue(cachedAfter.isEmpty)
    }

    @available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
    func testModelManagerCacheSize() async throws {
        let manager = MockModelManager()
        let model = MockModelID(rawValue: "test-model")

        let sizeBefore = await manager.cacheSize()
        XCTAssertEqual(sizeBefore.bytes, 0)

        _ = try await manager.download(model) { _ in }

        let sizeAfter = await manager.cacheSize()
        XCTAssertGreaterThan(sizeAfter.bytes, 0)
    }

    @available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
    func testModelManagerDownloadTask() async {
        let manager = MockModelManager()
        let model = MockModelID(rawValue: "test-model")

        let task = manager.download(model)  // This is now nonisolated, no await needed

        // Task should exist and be in pending or downloading state
        XCTAssertTrue(task.state.isActive)
    }
}
