// EmbeddingResultTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("EmbeddingResult Tests")
struct EmbeddingResultTests {

    // MARK: - Test Data

    static let sampleEmbedding = EmbeddingResult(
        vector: [0.1, 0.2, 0.3],
        text: "Hello",
        model: "test-model",
        tokenCount: 1
    )

    // MARK: - Initialization

    @Test("Init stores all properties")
    func initProperties() {
        let result = EmbeddingResult(
            vector: [1.0, 2.0, 3.0],
            text: "test text",
            model: "bge-small",
            tokenCount: 5
        )
        #expect(result.vector == [1.0, 2.0, 3.0])
        #expect(result.text == "test text")
        #expect(result.model == "bge-small")
        #expect(result.tokenCount == 5)
    }

    @Test("Init defaults tokenCount to nil")
    func initDefaultTokenCount() {
        let result = EmbeddingResult(
            vector: [1.0],
            text: "hi",
            model: "model"
        )
        #expect(result.tokenCount == nil)
    }

    // MARK: - Dimensions

    @Test("dimensions returns vector count")
    func dimensions() {
        let result = EmbeddingResult(
            vector: [0.1, 0.2, 0.3, 0.4, 0.5],
            text: "test",
            model: "model"
        )
        #expect(result.dimensions == 5)
    }

    @Test("dimensions is zero for empty vector")
    func dimensionsEmpty() {
        let result = EmbeddingResult(
            vector: [],
            text: "empty",
            model: "model"
        )
        #expect(result.dimensions == 0)
    }

    // MARK: - Cosine Similarity

    @Test("cosineSimilarity of identical vectors is 1")
    func cosineSimilaritySame() {
        let a = EmbeddingResult(vector: [1.0, 0.0, 0.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [1.0, 0.0, 0.0], text: "b", model: "m")
        let similarity = a.cosineSimilarity(with: b)
        #expect(abs(similarity - 1.0) < 0.0001)
    }

    @Test("cosineSimilarity of orthogonal vectors is 0")
    func cosineSimilarityOrthogonal() {
        let a = EmbeddingResult(vector: [1.0, 0.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [0.0, 1.0], text: "b", model: "m")
        let similarity = a.cosineSimilarity(with: b)
        #expect(abs(similarity) < 0.0001)
    }

    @Test("cosineSimilarity of opposite vectors is -1")
    func cosineSimilarityOpposite() {
        let a = EmbeddingResult(vector: [1.0, 0.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [-1.0, 0.0], text: "b", model: "m")
        let similarity = a.cosineSimilarity(with: b)
        #expect(abs(similarity - (-1.0)) < 0.0001)
    }

    @Test("cosineSimilarity returns 0 for different dimensions")
    func cosineSimilarityDifferentDimensions() {
        let a = EmbeddingResult(vector: [1.0, 2.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [1.0, 2.0, 3.0], text: "b", model: "m")
        #expect(a.cosineSimilarity(with: b) == 0)
    }

    @Test("cosineSimilarity returns 0 for zero vector")
    func cosineSimilarityZeroVector() {
        let a = EmbeddingResult(vector: [0.0, 0.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [1.0, 2.0], text: "b", model: "m")
        #expect(a.cosineSimilarity(with: b) == 0)
    }

    // MARK: - Euclidean Distance

    @Test("euclideanDistance of identical vectors is 0")
    func euclideanDistanceSame() {
        let a = EmbeddingResult(vector: [1.0, 2.0, 3.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [1.0, 2.0, 3.0], text: "b", model: "m")
        #expect(abs(a.euclideanDistance(to: b)) < 0.0001)
    }

    @Test("euclideanDistance of known vectors is correct")
    func euclideanDistanceKnown() {
        let a = EmbeddingResult(vector: [0.0, 0.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [3.0, 4.0], text: "b", model: "m")
        let distance = a.euclideanDistance(to: b)
        #expect(abs(distance - 5.0) < 0.0001)
    }

    @Test("euclideanDistance returns infinity for different dimensions")
    func euclideanDistanceDifferentDimensions() {
        let a = EmbeddingResult(vector: [1.0, 2.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [1.0, 2.0, 3.0], text: "b", model: "m")
        #expect(a.euclideanDistance(to: b) == .infinity)
    }

    // MARK: - Dot Product

    @Test("dotProduct of known vectors is correct")
    func dotProductKnown() {
        let a = EmbeddingResult(vector: [1.0, 2.0, 3.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [4.0, 5.0, 6.0], text: "b", model: "m")
        // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
        let result = a.dotProduct(with: b)
        #expect(abs(result - 32.0) < 0.0001)
    }

    @Test("dotProduct of orthogonal vectors is 0")
    func dotProductOrthogonal() {
        let a = EmbeddingResult(vector: [1.0, 0.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [0.0, 1.0], text: "b", model: "m")
        #expect(abs(a.dotProduct(with: b)) < 0.0001)
    }

    @Test("dotProduct returns 0 for different dimensions")
    func dotProductDifferentDimensions() {
        let a = EmbeddingResult(vector: [1.0, 2.0], text: "a", model: "m")
        let b = EmbeddingResult(vector: [1.0, 2.0, 3.0], text: "b", model: "m")
        #expect(a.dotProduct(with: b) == 0)
    }

    // MARK: - Hashable

    @Test("Equal embeddings have same hash")
    func hashableEqual() {
        let a = EmbeddingResult(vector: [1.0, 2.0], text: "hello", model: "m")
        let b = EmbeddingResult(vector: [1.0, 2.0], text: "hello", model: "m")
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Embeddings work in Set")
    func hashableSet() {
        let a = EmbeddingResult(vector: [1.0, 2.0], text: "hello", model: "m")
        let b = EmbeddingResult(vector: [1.0, 2.0], text: "hello", model: "m")
        let c = EmbeddingResult(vector: [3.0, 4.0], text: "world", model: "m")
        let set: Set<EmbeddingResult> = [a, b, c]
        #expect(set.count == 2)
    }

    // MARK: - Sendable

    @Test("EmbeddingResult is Sendable")
    func sendable() async {
        let result = Self.sampleEmbedding
        let text = await Task { result.text }.value
        #expect(text == "Hello")
    }
}
