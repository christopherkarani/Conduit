// VectorOpsCTests.swift
// ConduitCoreTests

import Foundation
import Testing
import ConduitCore

@Suite("Vector Operations C Tests")
struct VectorOpsCTests {

    // MARK: - Dot Product

    @Test("Dot product of known vectors")
    func dotProductKnown() {
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [4.0, 5.0, 6.0]
        // 1*4 + 2*5 + 3*6 = 32
        let result = conduit_dot_product(a, b, 3)
        #expect(abs(result - 32.0) < 0.0001)
    }

    @Test("Dot product of orthogonal vectors is 0")
    func dotProductOrthogonal() {
        let a: [Float] = [1.0, 0.0]
        let b: [Float] = [0.0, 1.0]
        let result = conduit_dot_product(a, b, 2)
        #expect(abs(result) < 0.0001)
    }

    @Test("Dot product with zero count returns 0")
    func dotProductEmpty() {
        let a: [Float] = [1.0]
        let b: [Float] = [1.0]
        let result = conduit_dot_product(a, b, 0)
        #expect(result == 0.0)
    }

    // MARK: - Cosine Similarity

    @Test("Cosine similarity of identical vectors is 1")
    func cosineSimilaritySame() {
        let a: [Float] = [1.0, 0.0, 0.0]
        let b: [Float] = [1.0, 0.0, 0.0]
        let result = conduit_cosine_similarity(a, b, 3)
        #expect(abs(result - 1.0) < 0.0001)
    }

    @Test("Cosine similarity of orthogonal vectors is 0")
    func cosineSimilarityOrthogonal() {
        let a: [Float] = [1.0, 0.0]
        let b: [Float] = [0.0, 1.0]
        let result = conduit_cosine_similarity(a, b, 2)
        #expect(abs(result) < 0.0001)
    }

    @Test("Cosine similarity of opposite vectors is -1")
    func cosineSimilarityOpposite() {
        let a: [Float] = [1.0, 0.0]
        let b: [Float] = [-1.0, 0.0]
        let result = conduit_cosine_similarity(a, b, 2)
        #expect(abs(result - (-1.0)) < 0.0001)
    }

    @Test("Cosine similarity returns 0 for zero vector")
    func cosineSimilarityZeroVector() {
        let a: [Float] = [0.0, 0.0]
        let b: [Float] = [1.0, 2.0]
        let result = conduit_cosine_similarity(a, b, 2)
        #expect(result == 0.0)
    }

    @Test("Cosine similarity with zero count returns 0")
    func cosineSimilarityEmpty() {
        let a: [Float] = [1.0]
        let b: [Float] = [1.0]
        let result = conduit_cosine_similarity(a, b, 0)
        #expect(result == 0.0)
    }

    // MARK: - Euclidean Distance

    @Test("Euclidean distance of identical vectors is 0")
    func euclideanDistanceSame() {
        let a: [Float] = [1.0, 2.0, 3.0]
        let b: [Float] = [1.0, 2.0, 3.0]
        let result = conduit_euclidean_distance(a, b, 3)
        #expect(abs(result) < 0.0001)
    }

    @Test("Euclidean distance of known vectors (3-4-5 triangle)")
    func euclideanDistanceKnown() {
        let a: [Float] = [0.0, 0.0]
        let b: [Float] = [3.0, 4.0]
        let result = conduit_euclidean_distance(a, b, 2)
        #expect(abs(result - 5.0) < 0.0001)
    }

    @Test("Euclidean distance with zero count returns 0")
    func euclideanDistanceEmpty() {
        let a: [Float] = [1.0]
        let b: [Float] = [1.0]
        let result = conduit_euclidean_distance(a, b, 0)
        #expect(result == 0.0)
    }

    // MARK: - Batch Cosine Similarity

    @Test("Batch cosine similarity matches individual calls")
    func batchCosineSimilarity() {
        let query: [Float] = [1.0, 0.0, 0.0]
        let vectors: [Float] = [
            1.0, 0.0, 0.0,   // identical → 1.0
            0.0, 1.0, 0.0,   // orthogonal → 0.0
            -1.0, 0.0, 0.0,  // opposite → -1.0
        ]
        var results: [Float] = [0.0, 0.0, 0.0]

        conduit_cosine_similarity_batch(query, vectors, 3, 3, &results)

        #expect(abs(results[0] - 1.0) < 0.0001)
        #expect(abs(results[1]) < 0.0001)
        #expect(abs(results[2] - (-1.0)) < 0.0001)
    }

    @Test("Batch cosine similarity with zero query returns all zeros")
    func batchCosineSimilarityZeroQuery() {
        let query: [Float] = [0.0, 0.0]
        let vectors: [Float] = [1.0, 2.0, 3.0, 4.0]
        var results: [Float] = [999.0, 999.0]

        conduit_cosine_similarity_batch(query, vectors, 2, 2, &results)

        #expect(results[0] == 0.0)
        #expect(results[1] == 0.0)
    }

    // MARK: - Parity with Swift EmbeddingResult

    @Test("C dot product matches Swift EmbeddingResult.dotProduct")
    func parityDotProduct() {
        let vecA: [Float] = [0.5, 1.5, -2.0, 0.3]
        let vecB: [Float] = [1.0, -0.5, 0.8, 2.1]

        // Swift reference
        let swiftResult = zip(vecA, vecB).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let cResult = conduit_dot_product(vecA, vecB, 4)

        #expect(abs(cResult - swiftResult) < 0.0001)
    }

    @Test("C cosine similarity matches Swift implementation for non-trivial vectors")
    func parityCosineSimilarity() {
        let vecA: [Float] = [0.5, 1.5, -2.0, 0.3]
        let vecB: [Float] = [1.0, -0.5, 0.8, 2.1]

        // Swift reference (from EmbeddingResult.cosineSimilarity)
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for i in vecA.indices {
            dot += vecA[i] * vecB[i]
            normA += vecA[i] * vecA[i]
            normB += vecB[i] * vecB[i]
        }
        let swiftResult = dot / (sqrt(normA) * sqrt(normB))

        let cResult = conduit_cosine_similarity(vecA, vecB, 4)
        #expect(abs(cResult - swiftResult) < 0.0001)
    }
}
