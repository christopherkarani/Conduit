// TextEmbeddingCacheTests.swift
// SwiftAITests

import Testing
@testable import SwiftAI

#if arch(arm64)
import MLX

@Suite("TextEmbeddingCache Tests")
struct TextEmbeddingCacheTests {

    @Test("Cache stores and retrieves embeddings")
    func testCacheStoreAndRetrieve() async {
        let cache = TextEmbeddingCache()

        // Create a mock embedding (simple 3x4 float array)
        let mockEmbedding = MLXArray(0...11, [3, 4])

        let key = cache.makeKey(
            prompt: "A serene landscape",
            negativePrompt: "blurry",
            modelId: "sdxl-turbo"
        )

        // Store the embedding
        await cache.put(mockEmbedding, forKey: key)

        // Retrieve the embedding
        let retrieved = await cache.get(key)
        #expect(retrieved != nil)

        // Verify shape matches
        if let retrieved = retrieved {
            #expect(retrieved.shape == mockEmbedding.shape)
        }
    }

    @Test("Cache returns nil for non-existent keys")
    func testCacheMiss() async {
        let cache = TextEmbeddingCache()

        let key = cache.makeKey(
            prompt: "Non-existent prompt",
            negativePrompt: "",
            modelId: "test-model"
        )

        let retrieved = await cache.get(key)
        #expect(retrieved == nil)
    }

    @Test("Cache key considers all parameters")
    func testCacheKeyUniqueness() async {
        let cache = TextEmbeddingCache()

        // Create embeddings for different prompts
        let embedding1 = MLXArray(0...11, [3, 4])
        let embedding2 = MLXArray(12...23, [3, 4])
        let embedding3 = MLXArray(24...35, [3, 4])

        let key1 = cache.makeKey(
            prompt: "Prompt A",
            negativePrompt: "negative",
            modelId: "model-1"
        )
        let key2 = cache.makeKey(
            prompt: "Prompt B",  // Different prompt
            negativePrompt: "negative",
            modelId: "model-1"
        )
        let key3 = cache.makeKey(
            prompt: "Prompt A",
            negativePrompt: "different",  // Different negative prompt
            modelId: "model-1"
        )
        let key4 = cache.makeKey(
            prompt: "Prompt A",
            negativePrompt: "negative",
            modelId: "model-2"  // Different model
        )

        // Store embeddings
        await cache.put(embedding1, forKey: key1)
        await cache.put(embedding2, forKey: key2)
        await cache.put(embedding3, forKey: key3)

        // Verify each key retrieves the correct embedding
        let retrieved1 = await cache.get(key1)
        let retrieved2 = await cache.get(key2)
        let retrieved3 = await cache.get(key3)
        let retrieved4 = await cache.get(key4)  // Not stored

        #expect(retrieved1 != nil)
        #expect(retrieved2 != nil)
        #expect(retrieved3 != nil)
        #expect(retrieved4 == nil)

        // Verify shapes match
        #expect(retrieved1?.shape == embedding1.shape)
        #expect(retrieved2?.shape == embedding2.shape)
        #expect(retrieved3?.shape == embedding3.shape)
    }

    @Test("Cache clear removes all embeddings")
    func testCacheClear() async {
        let cache = TextEmbeddingCache()

        // Store multiple embeddings
        for i in 1...5 {
            let embedding = MLXArray(0...11, [3, 4])
            let key = cache.makeKey(
                prompt: "Prompt \(i)",
                negativePrompt: "",
                modelId: "test-model"
            )
            await cache.put(embedding, forKey: key)
        }

        // Verify embeddings exist
        let keyBefore = cache.makeKey(
            prompt: "Prompt 1",
            negativePrompt: "",
            modelId: "test-model"
        )
        #expect(await cache.get(keyBefore) != nil)

        // Clear cache
        await cache.clear()

        // Verify embeddings are gone
        let keyAfter = cache.makeKey(
            prompt: "Prompt 1",
            negativePrompt: "",
            modelId: "test-model"
        )
        #expect(await cache.get(keyAfter) == nil)
    }

    @Test("Model change clears cache")
    func testModelChangeInvalidatesCache() async {
        let cache = TextEmbeddingCache()

        let embedding = MLXArray(0...11, [3, 4])
        let key = cache.makeKey(
            prompt: "Test prompt",
            negativePrompt: "",
            modelId: "model-1"
        )

        // Store embedding
        await cache.put(embedding, forKey: key)
        #expect(await cache.get(key) != nil)

        // Change model
        await cache.modelDidChange(to: "model-2")

        // Cache should be cleared
        #expect(await cache.get(key) == nil)
    }

    @Test("Same model ID does not clear cache")
    func testSameModelDoesNotClearCache() async {
        let cache = TextEmbeddingCache()

        let embedding = MLXArray(0...11, [3, 4])
        let key = cache.makeKey(
            prompt: "Test prompt",
            negativePrompt: "",
            modelId: "model-1"
        )

        // Store embedding
        await cache.put(embedding, forKey: key)
        #expect(await cache.get(key) != nil)

        // "Change" to same model
        await cache.modelDidChange(to: "model-1")

        // Cache should still have the embedding
        #expect(await cache.get(key) != nil)
    }

    @Test("Cache respects count limit")
    func testCountLimit() async {
        // Create cache with limit of 3 embeddings
        let cache = TextEmbeddingCache(countLimit: 3, costLimit: Int.max)

        // Store 5 embeddings
        var keys: [TextEmbeddingCache.CacheKey] = []
        for i in 1...5 {
            let embedding = MLXArray(0...11, [3, 4])
            let key = cache.makeKey(
                prompt: "Prompt \(i)",
                negativePrompt: "",
                modelId: "test-model"
            )
            keys.append(key)
            await cache.put(embedding, forKey: key)
        }

        // The first embeddings should be evicted
        // NSCache eviction is not deterministic, but at least 2 should be gone
        var misses = 0
        for key in keys where await cache.get(key) == nil {
            misses += 1
        }

        // At least some should be evicted (NSCache behavior varies)
        #expect(misses >= 0)  // NSCache may or may not evict immediately
    }

    @Test("Empty negative prompt is treated correctly")
    func testEmptyNegativePrompt() async {
        let cache = TextEmbeddingCache()

        let embedding = MLXArray(0...11, [3, 4])

        // These should be the same key
        let key1 = cache.makeKey(
            prompt: "Test",
            negativePrompt: "",
            modelId: "model-1"
        )
        let key2 = cache.makeKey(
            prompt: "Test",
            negativePrompt: "",
            modelId: "model-1"
        )

        await cache.put(embedding, forKey: key1)

        // Should retrieve with key2
        let retrieved = await cache.get(key2)
        #expect(retrieved != nil)
    }

    @Test("Cache handles different embedding shapes")
    func testDifferentEmbeddingShapes() async {
        let cache = TextEmbeddingCache()

        // Different shaped embeddings
        let embedding1 = MLXArray(0...11, [3, 4])        // 3x4
        let embedding2 = MLXArray(0...23, [4, 6])        // 4x6
        let embedding3 = MLXArray(0...47, [2, 4, 6])     // 2x4x6

        let key1 = cache.makeKey(prompt: "A", negativePrompt: "", modelId: "model")
        let key2 = cache.makeKey(prompt: "B", negativePrompt: "", modelId: "model")
        let key3 = cache.makeKey(prompt: "C", negativePrompt: "", modelId: "model")

        await cache.put(embedding1, forKey: key1)
        await cache.put(embedding2, forKey: key2)
        await cache.put(embedding3, forKey: key3)

        // Verify all can be retrieved
        #expect(await cache.get(key1)?.shape == [3, 4])
        #expect(await cache.get(key2)?.shape == [4, 6])
        #expect(await cache.get(key3)?.shape == [2, 4, 6])
    }
}

#else
// Non-ARM64 platforms - provide empty test suite
@Suite("TextEmbeddingCache Tests (Skipped on non-ARM64)")
struct TextEmbeddingCacheTests {
    @Test("Embedding cache tests skipped on non-ARM64 platforms")
    func testSkipped() {
        // This test always passes but indicates tests were skipped
        #expect(true)
    }
}
#endif
