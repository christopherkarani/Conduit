// EmbeddingGenerator.swift
// SwiftAI
//
// Protocol for generating vector embeddings from text.

import Foundation

// MARK: - EmbeddingGenerator Protocol

/// A type that can generate vector embeddings from text.
///
/// Embeddings are dense numerical representations of text that capture semantic meaning
/// in a high-dimensional vector space. Text with similar meanings produces similar
/// embeddings, enabling powerful applications in information retrieval and AI.
///
/// ## What are Embeddings?
///
/// Embeddings transform text into fixed-length vectors of floating-point numbers.
/// Unlike simple word-counting methods, embeddings encode:
/// - Semantic meaning (synonyms produce similar vectors)
/// - Contextual relationships (word meaning varies by context)
/// - Hierarchical concepts (broader and narrower topics)
///
/// For example:
/// - "dog" and "canine" will have similar embeddings
/// - "king" - "man" + "woman" ≈ "queen" (vector arithmetic captures relationships)
///
/// ## Common Use Cases
///
/// ### 1. Semantic Search & Similarity
/// Find documents that match the meaning of a query, not just keywords:
/// ```swift
/// let queryEmbedding = try await provider.embed("machine learning", model: .mlx("all-MiniLM-L6-v2"))
/// let docEmbeddings = try await provider.embedBatch(documents, model: .mlx("all-MiniLM-L6-v2"))
///
/// // Find most similar documents using cosine similarity
/// let similarities = docEmbeddings.map { cosineSimilarity(queryEmbedding.embedding, $0.embedding) }
/// ```
///
/// ### 2. Retrieval-Augmented Generation (RAG)
/// Retrieve relevant context for language model prompts:
/// ```swift
/// // 1. Embed your knowledge base
/// let chunks = splitDocumentIntoChunks(document)
/// let embeddings = try await provider.embedBatch(chunks, model: .mlx("all-MiniLM-L6-v2"))
///
/// // 2. Store embeddings in vector database
/// await vectorDB.insert(chunks, embeddings: embeddings)
///
/// // 3. Retrieve relevant chunks for a query
/// let queryEmbedding = try await provider.embed(userQuery, model: .mlx("all-MiniLM-L6-v2"))
/// let relevantChunks = await vectorDB.search(queryEmbedding, topK: 5)
///
/// // 4. Generate answer using retrieved context
/// let prompt = buildPrompt(query: userQuery, context: relevantChunks)
/// let answer = try await textProvider.generate(prompt, model: .llama3_2_1B)
/// ```
///
/// ### 3. Clustering & Classification
/// Group similar texts or classify documents:
/// ```swift
/// let embeddings = try await provider.embedBatch(articles, model: .mlx("all-MiniLM-L6-v2"))
/// let clusters = kMeansClustering(embeddings.map(\.embedding), k: 5)
/// // Articles with similar topics will be in the same cluster
/// ```
///
/// ### 4. Recommendation Systems
/// Recommend content based on semantic similarity:
/// ```swift
/// let userInterests = try await provider.embed(userProfile, model: .mlx("all-MiniLM-L6-v2"))
/// let contentEmbeddings = try await provider.embedBatch(articles, model: .mlx("all-MiniLM-L6-v2"))
///
/// // Recommend articles most similar to user interests
/// let recommendations = contentEmbeddings
///     .sorted { cosineSimilarity(userInterests.embedding, $0.embedding) >
///               cosineSimilarity(userInterests.embedding, $1.embedding) }
///     .prefix(10)
/// ```
///
/// ## Provider Implementations
///
/// Different providers offer different embedding models:
/// - **MLX**: Local embedding models (e.g., `all-MiniLM-L6-v2`, `bge-small-en-v1.5`)
/// - **HuggingFace**: Cloud-based embedding endpoints
/// - **Apple Foundation Models**: Not available (language models only)
///
/// ## Performance Considerations
///
/// - Use `embedBatch(_:model:)` for multiple texts to benefit from batching optimizations
/// - Cache embeddings when possible; they're deterministic for the same text and model
/// - Choose embedding models based on your use case:
///   - **Small models** (384 dims): Fast, less accurate (e.g., `all-MiniLM-L6-v2`)
///   - **Medium models** (768 dims): Balanced (e.g., `bge-base-en-v1.5`)
///   - **Large models** (1024+ dims): Slower, more accurate (e.g., `bge-large-en-v1.5`)
///
/// ## Conformance Requirements
///
/// Types conforming to `EmbeddingGenerator` must:
/// - Be `Sendable` for Swift 6.2 concurrency safety
/// - Define a `ModelID` type conforming to `ModelIdentifying`
/// - Implement both single and batch embedding methods
/// - Handle errors by throwing `AIError` or provider-specific errors
///
/// ## Example Implementation
///
/// ```swift
/// public actor MyEmbeddingProvider: EmbeddingGenerator {
///     public typealias ModelID = MyModelIdentifier
///
///     public func embed(_ text: String, model: ModelID) async throws -> EmbeddingResult {
///         // Generate embedding vector
///         let vector = try await computeEmbedding(text, using: model)
///         return EmbeddingResult(embedding: vector, tokenCount: countTokens(text))
///     }
///
///     public func embedBatch(_ texts: [String], model: ModelID) async throws -> [EmbeddingResult] {
///         // Optimize batch processing
///         return try await withThrowingTaskGroup(of: (Int, EmbeddingResult).self) { group in
///             for (index, text) in texts.enumerated() {
///                 group.addTask {
///                     let result = try await self.embed(text, model: model)
///                     return (index, result)
///                 }
///             }
///
///             var results = [(Int, EmbeddingResult)]()
///             for try await result in group {
///                 results.append(result)
///             }
///             return results.sorted { $0.0 < $1.0 }.map(\.1)
///         }
///     }
/// }
/// ```
///
/// ## See Also
/// - ``EmbeddingResult`` for the structure of returned embeddings
/// - ``ModelIdentifying`` for model identification
/// - ``AIProvider`` for the complete provider protocol
public protocol EmbeddingGenerator: Sendable {
    /// The type used to identify models for this provider.
    ///
    /// Each provider defines its own model identifier type that conforms
    /// to ``ModelIdentifying``. This allows type-safe model selection.
    associatedtype ModelID: ModelIdentifying

    // MARK: - Single Text Embedding

    /// Generates an embedding vector for the given text.
    ///
    /// Transforms the input text into a dense numerical representation
    /// that captures its semantic meaning. The resulting vector can be
    /// used for similarity comparisons, search, clustering, and more.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider()
    /// let result = try await provider.embed(
    ///     "SwiftAI is a unified inference framework",
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// )
    ///
    /// print("Embedding dimensions: \(result.dimensions)")
    /// print("Tokens processed: \(result.tokenCount ?? 0)")
    /// // Use result.embedding for similarity comparisons
    /// ```
    ///
    /// ## Performance
    /// For embedding multiple texts, prefer ``embedBatch(_:model:)``
    /// which can optimize batch processing and reduce overhead.
    ///
    /// - Parameters:
    ///   - text: The input text to embed. Empty strings may produce
    ///           zero vectors or throw an error depending on the provider.
    ///   - model: The embedding model to use. Different models produce
    ///            embeddings with different dimensions and characteristics.
    ///
    /// - Returns: An ``EmbeddingResult`` containing the embedding vector
    ///            and optional metadata like token count.
    ///
    /// - Throws: ``AIError`` if embedding fails. Common errors include:
    ///   - `.modelNotFound`: The specified model is not available
    ///   - `.modelNotLoaded`: The model needs to be loaded first
    ///   - `.inputTooLong`: Text exceeds the model's maximum length
    ///   - `.networkError`: Network issues (for cloud providers)
    ///   - `.apiKeyMissing`: API key not configured (for cloud providers)
    func embed(
        _ text: String,
        model: ModelID
    ) async throws -> EmbeddingResult

    // MARK: - Batch Embedding

    /// Generates embeddings for multiple texts in a batch.
    ///
    /// Batch processing is often more efficient than calling ``embed(_:model:)``
    /// multiple times, as providers can optimize parallel processing and
    /// reduce network/computation overhead.
    ///
    /// ## Usage
    /// ```swift
    /// let documents = [
    ///     "Swift is a powerful programming language.",
    ///     "Machine learning enables intelligent applications.",
    ///     "SwiftAI provides unified inference across providers."
    /// ]
    ///
    /// let provider = MLXProvider()
    /// let results = try await provider.embedBatch(
    ///     documents,
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// )
    ///
    /// // Results are in the same order as input texts
    /// for (text, result) in zip(documents, results) {
    ///     print("\(text): \(result.dimensions)D vector")
    /// }
    /// ```
    ///
    /// ## Ordering Guarantee
    /// The returned array maintains the same order as the input texts.
    /// `results[i]` corresponds to `texts[i]`.
    ///
    /// ## Error Handling
    /// If any embedding fails, the entire batch may fail depending on
    /// the provider implementation. For more control, consider calling
    /// ``embed(_:model:)`` individually and handling errors per-text.
    ///
    /// - Parameters:
    ///   - texts: An array of input texts to embed. Empty arrays return
    ///            an empty results array.
    ///   - model: The embedding model to use. All texts are embedded
    ///            using the same model.
    ///
    /// - Returns: An array of ``EmbeddingResult`` values, one for each
    ///            input text, in the same order.
    ///
    /// - Throws: ``AIError`` if batch embedding fails. See ``embed(_:model:)``
    ///           for common error cases.
    func embedBatch(
        _ texts: [String],
        model: ModelID
    ) async throws -> [EmbeddingResult]
}

// MARK: - Default Implementations

extension EmbeddingGenerator {
    /// Default implementation of batch embedding using sequential processing.
    ///
    /// Providers can override this to provide optimized batch processing.
    /// This default implementation calls ``embed(_:model:)`` for each text
    /// sequentially, which is simple but may be slower than provider-specific
    /// batching optimizations.
    ///
    /// ## Note
    /// This is a fallback implementation. Providers should implement
    /// their own optimized batch processing when possible.
    public func embedBatch(
        _ texts: [String],
        model: ModelID
    ) async throws -> [EmbeddingResult] {
        var results: [EmbeddingResult] = []
        results.reserveCapacity(texts.count)

        for text in texts {
            let result = try await embed(text, model: model)
            results.append(result)
        }

        return results
    }
}
