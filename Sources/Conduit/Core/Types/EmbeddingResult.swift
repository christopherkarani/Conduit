// EmbeddingResult.swift
// Conduit

import Foundation
import ConduitCore

/// The result of an embedding operation.
///
/// Contains the embedding vector along with the original text and
/// model information. Provides methods for computing similarity
/// and distance metrics between embeddings.
///
/// ## Usage
/// ```swift
/// let embedding = try await provider.embed("Hello world", model: .bgeSmall)
/// print("Dimensions: \(embedding.dimensions)")
///
/// let other = try await provider.embed("Hi there", model: .bgeSmall)
/// let similarity = embedding.cosineSimilarity(with: other)
/// print("Similarity: \(similarity)")
/// ```
public struct EmbeddingResult: Sendable, Hashable {
    /// The embedding vector.
    ///
    /// The dimensionality depends on the model used.
    /// Common sizes: 384 (small), 768 (base), 1024 (large).
    public let vector: [Float]

    /// The original text that was embedded.
    public let text: String

    /// The model used to generate the embedding.
    public let model: String

    /// Number of tokens in the input text.
    public let tokenCount: Int?

    /// Dimensionality of the embedding.
    public var dimensions: Int {
        vector.count
    }

    /// Creates an embedding result.
    ///
    /// - Parameters:
    ///   - vector: The embedding vector.
    ///   - text: The original text that was embedded.
    ///   - model: The model used for embedding.
    ///   - tokenCount: Optional token count of the input.
    public init(
        vector: [Float],
        text: String,
        model: String,
        tokenCount: Int? = nil
    ) {
        self.vector = vector
        self.text = text
        self.model = model
        self.tokenCount = tokenCount
    }

    // MARK: - Similarity Methods

    /// Computes cosine similarity with another embedding.
    ///
    /// Cosine similarity measures the cosine of the angle between two vectors.
    /// A value of 1 means identical direction, 0 means orthogonal, -1 means opposite.
    ///
    /// Formula: `dotProduct / (sqrt(normA) * sqrt(normB))`
    ///
    /// - Parameter other: The embedding to compare with.
    /// - Returns: Similarity score between -1 and 1 (1 = identical).
    ///            Returns 0 if vectors have different dimensions.
    public func cosineSimilarity(with other: EmbeddingResult) -> Float {
        guard vector.count == other.vector.count else { return 0 }
        return vector.withUnsafeBufferPointer { a in
            other.vector.withUnsafeBufferPointer { b in
                conduit_cosine_similarity(a.baseAddress, b.baseAddress, a.count)
            }
        }
    }

    /// Computes Euclidean distance to another embedding.
    ///
    /// Euclidean distance is the "straight line" distance between two points.
    /// Smaller values indicate more similar embeddings.
    ///
    /// Formula: `sqrt(sum of (a[i] - b[i])^2)`
    ///
    /// - Parameter other: The embedding to compare with.
    /// - Returns: Distance (0 = identical, larger = more different).
    ///            Returns `.infinity` if vectors have different dimensions.
    public func euclideanDistance(to other: EmbeddingResult) -> Float {
        guard vector.count == other.vector.count else { return .infinity }
        return vector.withUnsafeBufferPointer { a in
            other.vector.withUnsafeBufferPointer { b in
                conduit_euclidean_distance(a.baseAddress, b.baseAddress, a.count)
            }
        }
    }

    /// Computes dot product with another embedding.
    ///
    /// The dot product is a measure of how aligned two vectors are.
    /// For normalized vectors, this equals cosine similarity.
    ///
    /// Formula: `sum of a[i] * b[i]`
    ///
    /// - Parameter other: The embedding to compare with.
    /// - Returns: The dot product value.
    ///            Returns 0 if vectors have different dimensions.
    public func dotProduct(with other: EmbeddingResult) -> Float {
        guard vector.count == other.vector.count else { return 0 }
        return vector.withUnsafeBufferPointer { a in
            other.vector.withUnsafeBufferPointer { b in
                conduit_dot_product(a.baseAddress, b.baseAddress, a.count)
            }
        }
    }
}
