// EmbeddingTests.swift
// SwiftAI

import XCTest
@testable import SwiftAI

/// Comprehensive test suite for embedding types.
///
/// Tests cover:
/// - EmbeddingResult similarity methods
/// - BatchEmbeddingResult ranking
/// - Edge cases and dimension mismatches
final class EmbeddingTests: XCTestCase {

    // MARK: - EmbeddingResult Tests

    func testEmbeddingResultDimensions() {
        let embedding = EmbeddingResult(vector: [1, 2, 3, 4, 5], text: "test", model: "test-model")
        XCTAssertEqual(embedding.dimensions, 5)
    }

    // MARK: - Cosine Similarity Tests

    func testCosineSimilarityIdenticalVectors() {
        let a = EmbeddingResult(vector: [1, 0, 0], text: "a", model: "test")
        let b = EmbeddingResult(vector: [1, 0, 0], text: "b", model: "test")
        XCTAssertEqual(a.cosineSimilarity(with: b), 1.0, accuracy: 0.0001, "Identical vectors should have similarity 1.0")
    }

    func testCosineSimilarityOrthogonalVectors() {
        let a = EmbeddingResult(vector: [1, 0, 0], text: "a", model: "test")
        let b = EmbeddingResult(vector: [0, 1, 0], text: "b", model: "test")
        XCTAssertEqual(a.cosineSimilarity(with: b), 0.0, accuracy: 0.0001, "Orthogonal vectors should have similarity 0.0")
    }

    func testCosineSimilarityOppositeVectors() {
        let a = EmbeddingResult(vector: [1, 0, 0], text: "a", model: "test")
        let b = EmbeddingResult(vector: [-1, 0, 0], text: "b", model: "test")
        XCTAssertEqual(a.cosineSimilarity(with: b), -1.0, accuracy: 0.0001, "Opposite vectors should have similarity -1.0")
    }

    func testCosineSimilarityDimensionMismatch() {
        let a = EmbeddingResult(vector: [1, 0], text: "a", model: "test")
        let b = EmbeddingResult(vector: [1, 0, 0], text: "b", model: "test")
        XCTAssertEqual(a.cosineSimilarity(with: b), 0.0, "Dimension mismatch should return 0")
    }

    func testCosineSimilarityNonUnitVectors() {
        let a = EmbeddingResult(vector: [3, 4], text: "a", model: "test")  // magnitude 5
        let b = EmbeddingResult(vector: [6, 8], text: "b", model: "test")  // magnitude 10, same direction
        XCTAssertEqual(a.cosineSimilarity(with: b), 1.0, accuracy: 0.0001, "Parallel non-unit vectors should have similarity 1.0")
    }

    // MARK: - Euclidean Distance Tests

    func testEuclideanDistanceIdenticalVectors() {
        let a = EmbeddingResult(vector: [1, 2, 3], text: "a", model: "test")
        let b = EmbeddingResult(vector: [1, 2, 3], text: "b", model: "test")
        XCTAssertEqual(a.euclideanDistance(to: b), 0.0, accuracy: 0.0001, "Identical vectors should have distance 0")
    }

    func testEuclideanDistanceKnownValue() {
        let a = EmbeddingResult(vector: [0, 0, 0], text: "a", model: "test")
        let b = EmbeddingResult(vector: [3, 4, 0], text: "b", model: "test")
        XCTAssertEqual(a.euclideanDistance(to: b), 5.0, accuracy: 0.0001, "Distance should be 5 (3-4-5 triangle)")
    }

    func testEuclideanDistanceDimensionMismatch() {
        let a = EmbeddingResult(vector: [1, 0], text: "a", model: "test")
        let b = EmbeddingResult(vector: [1, 0, 0], text: "b", model: "test")
        XCTAssertEqual(a.euclideanDistance(to: b), .infinity, "Dimension mismatch should return infinity")
    }

    // MARK: - Dot Product Tests

    func testDotProductOrthogonal() {
        let a = EmbeddingResult(vector: [1, 0, 0], text: "a", model: "test")
        let b = EmbeddingResult(vector: [0, 1, 0], text: "b", model: "test")
        XCTAssertEqual(a.dotProduct(with: b), 0.0, accuracy: 0.0001, "Orthogonal vectors should have dot product 0")
    }

    func testDotProductKnownValue() {
        let a = EmbeddingResult(vector: [1, 2, 3], text: "a", model: "test")
        let b = EmbeddingResult(vector: [4, 5, 6], text: "b", model: "test")
        XCTAssertEqual(a.dotProduct(with: b), 32.0, accuracy: 0.0001, "Dot product should be 1*4 + 2*5 + 3*6 = 32")
    }

    func testDotProductDimensionMismatch() {
        let a = EmbeddingResult(vector: [1, 2], text: "a", model: "test")
        let b = EmbeddingResult(vector: [1, 2, 3], text: "b", model: "test")
        XCTAssertEqual(a.dotProduct(with: b), 0.0, "Dimension mismatch should return 0")
    }

    // MARK: - BatchEmbeddingResult Tests

    func testBatchMostSimilar() {
        let query = EmbeddingResult(vector: [1, 0], text: "query", model: "test")
        let batch = BatchEmbeddingResult(embeddings: [
            EmbeddingResult(vector: [0, 1], text: "orthogonal", model: "test"),
            EmbeddingResult(vector: [1, 0], text: "same", model: "test"),
            EmbeddingResult(vector: [0.5, 0.5], text: "partial", model: "test")
        ], processingTime: 0.1)

        let result = batch.mostSimilar(to: query)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.result.text, "same", "Most similar should be the identical vector")
        XCTAssertEqual(result?.similarity ?? 0, 1.0, accuracy: 0.0001)
    }

    func testBatchMostSimilarEmptyBatch() {
        let query = EmbeddingResult(vector: [1, 0], text: "query", model: "test")
        let batch = BatchEmbeddingResult(embeddings: [], processingTime: 0.0)

        let result = batch.mostSimilar(to: query)
        XCTAssertNil(result, "Empty batch should return nil")
    }

    func testBatchRankedDescendingOrder() {
        let query = EmbeddingResult(vector: [1, 0], text: "query", model: "test")
        let batch = BatchEmbeddingResult(embeddings: [
            EmbeddingResult(vector: [0, 1], text: "orth", model: "test"),       // similarity 0
            EmbeddingResult(vector: [1, 0], text: "same", model: "test"),       // similarity 1
            EmbeddingResult(vector: [-1, 0], text: "opposite", model: "test")   // similarity -1
        ], processingTime: 0.1)

        let ranked = batch.ranked(by: query)
        XCTAssertEqual(ranked.count, 3)
        XCTAssertEqual(ranked[0].result.text, "same", "First should be most similar")
        XCTAssertEqual(ranked[1].result.text, "orth", "Second should be orthogonal")
        XCTAssertEqual(ranked[2].result.text, "opposite", "Third should be least similar")
    }

    func testBatchTotalTokens() {
        let batch = BatchEmbeddingResult(embeddings: [
            EmbeddingResult(vector: [1], text: "a", model: "test", tokenCount: 10),
            EmbeddingResult(vector: [1], text: "b", model: "test", tokenCount: 20),
            EmbeddingResult(vector: [1], text: "c", model: "test", tokenCount: nil)
        ], processingTime: 0.1)

        XCTAssertEqual(batch.totalTokens, 30, "Should sum only non-nil token counts")
    }

    // MARK: - Hashable Tests

    func testEmbeddingResultHashable() {
        let a = EmbeddingResult(vector: [1, 2, 3], text: "test", model: "model")
        let b = EmbeddingResult(vector: [1, 2, 3], text: "test", model: "model")
        XCTAssertEqual(a, b)

        var set = Set<EmbeddingResult>()
        set.insert(a)
        XCTAssertTrue(set.contains(b))
    }
}
