// ModelLRUCacheTests.swift
// Conduit Tests
//
// This file requires the MLX trait to be enabled.

import XCTest
@testable import Conduit

#if canImport(StableDiffusion)
import StableDiffusion

final class ModelLRUCacheTests: XCTestCase {

    // MARK: - Basic Functionality Tests

    func testCacheInitialization() async {
        // Test default capacity
        let cache1 = ModelLRUCache()
        let count1 = await cache1.count
        XCTAssertEqual(count1, 0, "Cache should start empty")

        // Test custom capacity
        let cache2 = ModelLRUCache(capacity: 5)
        let count2 = await cache2.count
        XCTAssertEqual(count2, 0, "Cache with custom capacity should start empty")

        // Test minimum capacity enforcement
        let cache3 = ModelLRUCache(capacity: 0)
        // Should automatically use capacity of 1
        // We can't directly test the capacity, but we can verify it works
        let count3 = await cache3.count
        XCTAssertEqual(count3, 0, "Cache with invalid capacity should still work")
    }

    func testCacheContains() async throws {
        let cache = ModelLRUCache(capacity: 2)

        // Test empty cache
        let contains1 = await cache.contains(modelId: "test-model", variant: .sdxlTurbo)
        XCTAssertFalse(contains1, "Empty cache should not contain any models")

        // Create a mock model container
        let container = try createMockModelContainerOrSkip()

        // Add model to cache
        await cache.put(modelId: "test-model", variant: .sdxlTurbo, container: container)

        // Test contains after adding
        let contains2 = await cache.contains(modelId: "test-model", variant: .sdxlTurbo)
        XCTAssertTrue(contains2, "Cache should contain added model")

        // Test with different variant
        let contains3 = await cache.contains(modelId: "test-model", variant: .sd15)
        XCTAssertFalse(contains3, "Cache should not contain model with different variant")

        // Test with different model ID
        let contains4 = await cache.contains(modelId: "other-model", variant: .sdxlTurbo)
        XCTAssertFalse(contains4, "Cache should not contain model with different ID")
    }

    func testCachePutAndGet() async throws {
        let cache = ModelLRUCache(capacity: 2)
        let container = try createMockModelContainerOrSkip()

        // Test get on empty cache
        let result1 = await cache.get(modelId: "test-model", variant: .sdxlTurbo)
        XCTAssertNil(result1, "Get on empty cache should return nil")

        // Add model to cache
        await cache.put(modelId: "test-model", variant: .sdxlTurbo, container: container)

        // Test get after put
        let result2 = await cache.get(modelId: "test-model", variant: .sdxlTurbo)
        XCTAssertNotNil(result2, "Get should return cached model")

        // Verify count
        let count = await cache.count
        XCTAssertEqual(count, 1, "Cache should contain one model")
    }

    func testCacheRemove() async throws {
        let cache = ModelLRUCache(capacity: 2)
        let container = try createMockModelContainerOrSkip()

        // Add model
        await cache.put(modelId: "test-model", variant: .sdxlTurbo, container: container)

        // Verify it's in cache
        let contains1 = await cache.contains(modelId: "test-model", variant: .sdxlTurbo)
        XCTAssertTrue(contains1, "Model should be in cache after put")

        // Remove model
        await cache.remove(modelId: "test-model", variant: .sdxlTurbo)

        // Verify it's removed
        let contains2 = await cache.contains(modelId: "test-model", variant: .sdxlTurbo)
        XCTAssertFalse(contains2, "Model should be removed from cache")

        let count = await cache.count
        XCTAssertEqual(count, 0, "Cache should be empty after removal")
    }

    func testCacheClear() async throws {
        let cache = ModelLRUCache(capacity: 3)
        let container1 = try createMockModelContainerOrSkip()
        let container2 = try createMockModelContainerOrSkip()

        // Add multiple models
        await cache.put(modelId: "model1", variant: .sdxlTurbo, container: container1)
        await cache.put(modelId: "model2", variant: .sd15, container: container2)

        // Verify count
        let count1 = await cache.count
        XCTAssertEqual(count1, 2, "Cache should contain two models")

        // Clear cache
        await cache.clear()

        // Verify cache is empty
        let count2 = await cache.count
        XCTAssertEqual(count2, 0, "Cache should be empty after clear")

        let contains1 = await cache.contains(modelId: "model1", variant: .sdxlTurbo)
        let contains2 = await cache.contains(modelId: "model2", variant: .sd15)
        XCTAssertFalse(contains1, "Cache should not contain model1 after clear")
        XCTAssertFalse(contains2, "Cache should not contain model2 after clear")
    }

    // MARK: - LRU Eviction Tests

    func testLRUEviction() async throws {
        let cache = ModelLRUCache(capacity: 2)
        let container1 = try createMockModelContainerOrSkip()
        let container2 = try createMockModelContainerOrSkip()
        let container3 = try createMockModelContainerOrSkip()

        // Add first model
        await cache.put(modelId: "model1", variant: .sdxlTurbo, container: container1)

        // Small delay to ensure different timestamps
        try await Task.sleep(for: .milliseconds(10))

        // Add second model
        await cache.put(modelId: "model2", variant: .sdxlTurbo, container: container2)

        // Verify both are in cache
        let count1 = await cache.count
        XCTAssertEqual(count1, 2, "Cache should contain two models")

        // Small delay
        try await Task.sleep(for: .milliseconds(10))

        // Add third model (should evict model1 as it's the least recently used)
        await cache.put(modelId: "model3", variant: .sdxlTurbo, container: container3)

        // Verify cache still has 2 models
        let count2 = await cache.count
        XCTAssertEqual(count2, 2, "Cache should still contain two models after eviction")

        // Verify model1 was evicted
        let contains1 = await cache.contains(modelId: "model1", variant: .sdxlTurbo)
        XCTAssertFalse(contains1, "model1 should have been evicted (least recently used)")

        // Verify model2 and model3 are still in cache
        let contains2 = await cache.contains(modelId: "model2", variant: .sdxlTurbo)
        let contains3 = await cache.contains(modelId: "model3", variant: .sdxlTurbo)
        XCTAssertTrue(contains2, "model2 should still be in cache")
        XCTAssertTrue(contains3, "model3 should be in cache")
    }

    func testLRUAccessUpdatesOrder() async throws {
        let cache = ModelLRUCache(capacity: 2)
        let container1 = try createMockModelContainerOrSkip()
        let container2 = try createMockModelContainerOrSkip()
        let container3 = try createMockModelContainerOrSkip()

        // Add first model
        await cache.put(modelId: "model1", variant: .sdxlTurbo, container: container1)
        try await Task.sleep(for: .milliseconds(10))

        // Add second model
        await cache.put(modelId: "model2", variant: .sdxlTurbo, container: container2)
        try await Task.sleep(for: .milliseconds(10))

        // Access model1 (making it recently used)
        _ = await cache.get(modelId: "model1", variant: .sdxlTurbo)
        try await Task.sleep(for: .milliseconds(10))

        // Add third model (should evict model2, not model1)
        await cache.put(modelId: "model3", variant: .sdxlTurbo, container: container3)

        // Verify model1 is still in cache
        let contains1 = await cache.contains(modelId: "model1", variant: .sdxlTurbo)
        XCTAssertTrue(contains1, "model1 should still be in cache (was accessed recently)")

        // Verify model2 was evicted
        let contains2 = await cache.contains(modelId: "model2", variant: .sdxlTurbo)
        XCTAssertFalse(contains2, "model2 should have been evicted")

        // Verify model3 is in cache
        let contains3 = await cache.contains(modelId: "model3", variant: .sdxlTurbo)
        XCTAssertTrue(contains3, "model3 should be in cache")
    }

    // MARK: - Multiple Variants Tests

    func testMultipleVariantsCached() async throws {
        let cache = ModelLRUCache(capacity: 3)
        let container1 = try createMockModelContainerOrSkip()
        let container2 = try createMockModelContainerOrSkip()

        // Add same model ID with different variants
        await cache.put(modelId: "model", variant: .sdxlTurbo, container: container1)
        await cache.put(modelId: "model", variant: .sd15, container: container2)

        // Verify both are in cache as separate entries
        let count = await cache.count
        XCTAssertEqual(count, 2, "Cache should contain two entries (different variants)")

        let contains1 = await cache.contains(modelId: "model", variant: .sdxlTurbo)
        let contains2 = await cache.contains(modelId: "model", variant: .sd15)
        XCTAssertTrue(contains1, "sdxlTurbo variant should be in cache")
        XCTAssertTrue(contains2, "sd15 variant should be in cache")
    }

    func testUpdateExistingEntry() async throws {
        let cache = ModelLRUCache(capacity: 2)
        let container1 = try createMockModelContainerOrSkip()
        let container2 = try createMockModelContainerOrSkip()

        // Add model
        await cache.put(modelId: "model", variant: .sdxlTurbo, container: container1)

        // Verify count
        let count1 = await cache.count
        XCTAssertEqual(count1, 1, "Cache should contain one model")

        // Update same model (should not increase count)
        await cache.put(modelId: "model", variant: .sdxlTurbo, container: container2)

        // Verify count is still 1
        let count2 = await cache.count
        XCTAssertEqual(count2, 1, "Cache should still contain one model after update")

        // Verify model is still accessible
        let result = await cache.get(modelId: "model", variant: .sdxlTurbo)
        XCTAssertNotNil(result, "Updated model should be accessible")
    }

    // MARK: - Helper Methods

    /// Creates a mock model container for testing.
    ///
    /// Note: This creates a real ModelContainer with SDXL Turbo configuration.
    /// It does not load the actual weights, so it's lightweight for testing.
    private func createMockModelContainer() throws -> ModelContainer<TextToImageGenerator> {
        // Create a minimal container for testing
        // This will fail if MLX dependencies are not available, which is expected
        // in CI environments without Apple Silicon
        return try ModelContainer<TextToImageGenerator>.createTextToImageGenerator(
            configuration: .presetSDXLTurbo,
            loadConfiguration: LoadConfiguration()
        )
    }

    /// Helper to create a mock container or skip test if model files aren't available.
    private func createMockModelContainerOrSkip() throws -> ModelContainer<TextToImageGenerator> {
        do {
            return try createMockModelContainer()
        } catch {
            throw XCTSkip("Skipping test: SDXL Turbo model files not downloaded. Error: \(error.localizedDescription)")
        }
    }
}

#else
// Tests only run on Apple Silicon
final class ModelLRUCacheTests: XCTestCase {
    func testSkipOnNonAppleSilicon() {
        // This test always passes on non-Apple Silicon platforms
        XCTAssertTrue(true, "ModelLRUCache tests require Apple Silicon")
    }
}
#endif
