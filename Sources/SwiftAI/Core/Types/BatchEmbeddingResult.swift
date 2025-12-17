// BatchEmbeddingResult.swift
// SwiftAI

import Foundation

/// Result of a batch embedding operation.
///
/// Contains multiple embedding results from a single batch request,
/// along with aggregate statistics. Provides methods for finding
/// the most similar embedding to a query.
///
/// ## Usage
/// ```swift
/// let texts = ["hello", "world", "foo", "bar"]
/// let batch = try await provider.embedBatch(texts, model: .bgeSmall)
///
/// let query = try await provider.embed("greeting", model: .bgeSmall)
/// if let (best, score) = batch.mostSimilar(to: query) {
///     print("Most similar: '\(best.text)' with score \(score)")
/// }
/// ```
public struct BatchEmbeddingResult: Sendable {
    /// Individual embedding results.
    public let embeddings: [EmbeddingResult]

    /// Total processing time for the batch.
    public let processingTime: TimeInterval

    /// Total tokens processed across all inputs.
    public var totalTokens: Int {
        embeddings.compactMap(\.tokenCount).reduce(0, +)
    }

    /// Creates a batch embedding result.
    ///
    /// - Parameters:
    ///   - embeddings: The individual embedding results.
    ///   - processingTime: Total time taken for the batch.
    public init(embeddings: [EmbeddingResult], processingTime: TimeInterval) {
        self.embeddings = embeddings
        self.processingTime = processingTime
    }

    // MARK: - Similarity Methods

    /// Finds the most similar embedding to a query.
    ///
    /// Compares the query embedding against all embeddings in the batch
    /// using cosine similarity and returns the best match.
    ///
    /// - Parameter query: The embedding to search for.
    /// - Returns: A tuple of the most similar embedding and its similarity score,
    ///            or `nil` if the batch is empty.
    public func mostSimilar(to query: EmbeddingResult) -> (result: EmbeddingResult, similarity: Float)? {
        embeddings
            .map { ($0, query.cosineSimilarity(with: $0)) }
            .max { $0.1 < $1.1 }
    }

    /// Ranks embeddings by similarity to a query.
    ///
    /// Computes cosine similarity between the query and all embeddings,
    /// returning them sorted in descending order by similarity.
    ///
    /// - Parameter query: The embedding to compare against.
    /// - Returns: Array of tuples containing each embedding and its
    ///            similarity score, sorted from most to least similar.
    public func ranked(by query: EmbeddingResult) -> [(result: EmbeddingResult, similarity: Float)] {
        embeddings
            .map { ($0, query.cosineSimilarity(with: $0)) }
            .sorted { $0.1 > $1.1 }
    }
}
