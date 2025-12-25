// MLXModelCacheTests.swift
// SwiftAITests

import Foundation
import Testing
@testable import SwiftAI

#if arch(arm64)
import MLX
import MLXLMCommon
import MLXLLM

@Suite("MLXModelCache Tests")
struct MLXModelCacheTests {

    @Test("Cache stores and retrieves models", .disabled("Requires actual MLX model - use integration tests"))
    func testCacheStoreAndRetrieve() async {
        let cache = MLXModelCache.shared

        // This test is disabled because it requires loading an actual MLX model
        // which is expensive and should be done in integration tests, not unit tests
        // To enable this test, provide a real model loading mechanism or use integration test suite

        // Create a mock cached model
        guard let mockContainer = try? createMockModelContainer() else {
            Issue.record("Cannot create mock ModelContainer - test requires real MLX model")
            return
        }

        let capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            contextWindowSize: 2048
        )
        let model = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )

        // Store the model
        await cache.set(model, forKey: "test-model")

        // Retrieve the model
        let retrieved = await cache.get("test-model")
        #expect(retrieved != nil)
        #expect(retrieved?.capabilities.supportsTextGeneration == true)
        #expect(retrieved?.weightsSize.bytes == ByteCount.megabytes(500).bytes)

        // Cleanup
        await cache.remove("test-model")
    }

    @Test("Cache contains check works correctly", .disabled("Requires actual MLX model - use integration tests"))
    func testCacheContains() async {
        let cache = MLXModelCache.shared

        guard let mockContainer = try? createMockModelContainer() else {
            Issue.record("Cannot create mock ModelContainer - test requires real MLX model")
            return
        }

        let capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            contextWindowSize: 2048
        )
        let model = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )

        // Initially not cached
        #expect(await cache.contains("test-model-2") == false)

        // Store the model
        await cache.set(model, forKey: "test-model-2")

        // Now it should be cached
        #expect(await cache.contains("test-model-2") == true)

        // Cleanup
        await cache.remove("test-model-2")
    }

    @Test("Cache remove works correctly", .disabled("Requires actual MLX model - use integration tests"))
    func testCacheRemove() async {
        let cache = MLXModelCache.shared

        guard let mockContainer = try? createMockModelContainer() else {
            Issue.record("Cannot create mock ModelContainer - test requires real MLX model")
            return
        }

        let capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            contextWindowSize: 2048
        )
        let model = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )

        // Store the model
        await cache.set(model, forKey: "test-model-3")
        #expect(await cache.contains("test-model-3") == true)

        // Remove the model
        await cache.remove("test-model-3")
        #expect(await cache.contains("test-model-3") == false)
    }

    @Test("Cache removeAll clears all models", .disabled("Requires actual MLX model - use integration tests"))
    func testCacheRemoveAll() async {
        let cache = MLXModelCache.shared

        guard let mockContainer = try? createMockModelContainer() else {
            Issue.record("Cannot create mock ModelContainer - test requires real MLX model")
            return
        }

        let capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            contextWindowSize: 2048
        )

        // Store multiple models
        for i in 4...6 {
            let model = MLXModelCache.CachedModel(
                container: mockContainer,
                capabilities: capabilities,
                weightsSize: .megabytes(500)
            )
            await cache.set(model, forKey: "test-model-\(i)")
        }

        let statsBefore = await cache.cacheStats()
        #expect(statsBefore.cachedModelCount >= 3)

        // Remove all
        await cache.removeAll()

        let statsAfter = await cache.cacheStats()
        #expect(statsAfter.cachedModelCount == 0)
        #expect(statsAfter.totalMemoryUsage.bytes == 0)
    }

    @Test("Cache stats reflect current state", .disabled("Requires actual MLX model - use integration tests"))
    func testCacheStats() async {
        let cache = MLXModelCache.shared

        guard let mockContainer = try? createMockModelContainer() else {
            Issue.record("Cannot create mock ModelContainer - test requires real MLX model")
            return
        }

        let capabilities = ModelCapabilities(
            supportsVision: false,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            contextWindowSize: 2048
        )

        // Clear cache first
        await cache.removeAll()

        // Store models with different sizes
        let model1 = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .megabytes(500)
        )
        let model2 = MLXModelCache.CachedModel(
            container: mockContainer,
            capabilities: capabilities,
            weightsSize: .gigabytes(1)
        )

        await cache.set(model1, forKey: "model-1")
        await cache.set(model2, forKey: "model-2")

        let stats = await cache.cacheStats()
        #expect(stats.cachedModelCount == 2)
        #expect(stats.totalMemoryUsage.bytes >= ByteCount.megabytes(1500).bytes) // 500MB + 1GB
        #expect(stats.modelIds.contains("model-1"))
        #expect(stats.modelIds.contains("model-2"))

        // Cleanup
        await cache.removeAll()
    }

    @Test("Current model tracking works")
    func testCurrentModelTracking() async {
        let cache = MLXModelCache.shared

        // Set current model
        await cache.setCurrentModel("test-model-tracking")
        #expect(await cache.getCurrentModelId() == "test-model-tracking")

        // Clear current model
        let nilString: String? = nil
        await cache.setCurrentModel(nilString)
        #expect(await cache.getCurrentModelId() == nil)
    }

    // MARK: - Helpers

    private func createMockModelContainer() throws -> ModelContainer {
        // Creating a real ModelContainer requires:
        // 1. A valid model configuration
        // 2. A loaded model (expensive)
        // 3. A processor and tokenizer
        //
        // For unit tests, these should be disabled and moved to integration tests
        // that can handle the overhead of loading real MLX models.
        //
        // If you need to test with real models, use the integration test suite
        // or provide a lightweight model specifically for testing.

        throw TestError.mockModelNotAvailable
    }

    enum TestError: Error {
        case mockModelNotAvailable
    }
}

#else
// Non-ARM64 platforms - provide empty test suite
@Suite("MLXModelCache Tests (Skipped on non-ARM64)")
struct MLXModelCacheTests {
    @Test("MLX tests skipped on non-ARM64 platforms")
    func testSkipped() {
        // This test always passes but indicates tests were skipped
        #expect(true)
    }
}
#endif
