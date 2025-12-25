// StringExtensions.swift
// SwiftAI

import Foundation

// MARK: - String + TextGenerator

extension String {

    /// Generates a response using the given provider.
    ///
    /// This convenience method allows you to call text generation directly on a string,
    /// treating the string as the prompt.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider()
    /// let response = try await "What is Swift?".generate(
    ///     with: provider,
    ///     model: .llama3_2_1b,
    ///     config: .default
    /// )
    /// print(response)
    /// ```
    ///
    /// ## Example with Custom Config
    /// ```swift
    /// let config = GenerateConfig.default
    ///     .temperature(0.8)
    ///     .maxTokens(500)
    ///
    /// let story = try await "Write a sci-fi story:".generate(
    ///     with: mlxProvider,
    ///     model: .llama3_2_1b,
    ///     config: config
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The text generator provider to use (MLXProvider, HuggingFaceProvider, etc.).
    ///   - model: The model identifier to use for generation.
    ///   - config: Configuration parameters for generation. Defaults to `.default`.
    ///
    /// - Returns: The generated text response as a string.
    ///
    /// - Throws: `AIError` if generation fails due to model errors, network issues,
    ///           or invalid parameters.
    ///
    /// - SeeAlso: ``TextGenerator/generate(_:model:config:)``
    public func generate<P: TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) async throws -> String {
        try await provider.generate(self, model: model, config: config)
    }
}

// MARK: - String + Streaming

extension String {

    /// Streams tokens for this prompt.
    ///
    /// This convenience method allows you to stream text generation directly from a string,
    /// receiving tokens as they are generated in real-time.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider()
    ///
    /// for try await token in "Tell me a story".stream(
    ///     with: provider,
    ///     model: .llama3_2_1b
    /// ) {
    ///     print(token, terminator: "")
    /// }
    /// print() // New line after completion
    /// ```
    ///
    /// ## Usage with Custom Config
    /// ```swift
    /// let config = GenerateConfig.creative
    ///
    /// var fullText = ""
    /// for try await token in "Write a haiku about AI".stream(
    ///     with: provider,
    ///     model: .llama3_2_1b,
    ///     config: config
    /// ) {
    ///     print(token, terminator: "")
    ///     fullText += token
    /// }
    /// ```
    ///
    /// ## Stream Behavior
    /// - The stream emits text fragments (tokens) as they become available
    /// - The stream completes when generation finishes naturally or hits a stop condition
    /// - The stream throws if an error occurs during generation
    /// - Canceling the task that iterates the stream will stop generation
    ///
    /// - Parameters:
    ///   - provider: The text generator provider to use.
    ///   - model: The model identifier to use for generation.
    ///   - config: Configuration parameters for generation. Defaults to `.default`.
    ///
    /// - Returns: An `AsyncThrowingStream` that emits text fragments as they are generated.
    ///
    /// - Throws: Errors are thrown within the stream as `AIError` when generation fails.
    ///
    /// - SeeAlso: ``TextGenerator/stream(_:model:config:)``
    public func stream<P: TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<String, Error> {
        provider.stream(self, model: model, config: config)
    }
}

// MARK: - String + EmbeddingGenerator

extension String {

    /// Generates an embedding for this text.
    ///
    /// This convenience method allows you to generate embeddings directly from a string,
    /// converting the text into a dense vector representation that captures its semantic meaning.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider()
    /// let embedding = try await "Hello world".embed(
    ///     with: provider,
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// )
    ///
    /// print("Embedding dimensions: \(embedding.dimensions)")
    /// print("Vector: \(embedding.vector.prefix(5))...")
    /// ```
    ///
    /// ## Use Cases
    ///
    /// ### Semantic Search
    /// ```swift
    /// let query = "machine learning"
    /// let queryEmbedding = try await query.embed(with: provider, model: .bgeSmall)
    ///
    /// let documents = ["AI tutorial", "Cooking recipes", "ML algorithms"]
    /// let docEmbeddings = try await provider.embedBatch(documents, model: .bgeSmall)
    ///
    /// // Find most similar document
    /// let similarities = docEmbeddings.map { queryEmbedding.cosineSimilarity(with: $0) }
    /// let mostRelevant = similarities.enumerated().max(by: { $0.element < $1.element })
    /// ```
    ///
    /// ### Text Similarity
    /// ```swift
    /// let text1 = "The cat sat on the mat"
    /// let text2 = "A feline rested on the rug"
    ///
    /// let embedding1 = try await text1.embed(with: provider, model: model)
    /// let embedding2 = try await text2.embed(with: provider, model: model)
    ///
    /// let similarity = embedding1.cosineSimilarity(with: embedding2)
    /// print("Similarity: \(similarity)") // High value (~0.8-0.9) indicates similar meaning
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The embedding generator provider to use.
    ///   - model: The embedding model identifier to use.
    ///
    /// - Returns: An ``EmbeddingResult`` containing the embedding vector and metadata.
    ///
    /// - Throws: ``AIError`` if embedding fails. Common errors include:
    ///   - `.modelNotFound`: The specified model is not available
    ///   - `.modelNotLoaded`: The model needs to be loaded first
    ///   - `.inputTooLong`: Text exceeds the model's maximum length
    ///   - `.networkError`: Network issues (for cloud providers)
    ///
    /// - SeeAlso: ``EmbeddingGenerator/embed(_:model:)``
    public func embed<P: EmbeddingGenerator>(
        with provider: P,
        model: P.ModelID
    ) async throws -> EmbeddingResult {
        try await provider.embed(self, model: model)
    }
}

// MARK: - String + TokenCounter

extension String {

    /// Counts tokens in this string.
    ///
    /// This convenience method allows you to count tokens directly on a string,
    /// which is essential for managing context windows and estimating costs.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider()
    /// let text = "Hello, world! How are you today?"
    ///
    /// let count = try await text.tokenCount(
    ///     with: provider,
    ///     model: .llama3_2_1b
    /// )
    /// print("Token count: \(count)")
    /// ```
    ///
    /// ## Context Window Management
    /// ```swift
    /// let maxContextTokens = 4096
    /// let systemPrompt = "You are a helpful assistant."
    /// let userMessage = "Explain quantum computing in detail."
    ///
    /// let systemTokens = try await systemPrompt.tokenCount(with: provider, model: model)
    /// let userTokens = try await userMessage.tokenCount(with: provider, model: model)
    /// let totalTokens = systemTokens + userTokens
    ///
    /// if totalTokens <= maxContextTokens {
    ///     print("✓ Within context window (\(totalTokens)/\(maxContextTokens))")
    /// } else {
    ///     print("✗ Exceeds context window by \(totalTokens - maxContextTokens) tokens")
    /// }
    /// ```
    ///
    /// ## Cost Estimation
    /// ```swift
    /// let longDocument = "..." // Your document text
    /// let tokens = try await longDocument.tokenCount(with: provider, model: model)
    /// let costPerToken = 0.0001
    /// let estimatedCost = Double(tokens) * costPerToken
    /// print("Estimated cost: $\(estimatedCost)")
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The token counter provider to use.
    ///   - model: The model identifier whose tokenizer to use.
    ///
    /// - Returns: The number of tokens in this string.
    ///
    /// - Throws: An error if the tokenizer cannot be loaded or tokenization fails.
    ///
    /// - Note: This method counts only the raw text tokens and does not include
    ///         special tokens (BOS/EOS) or chat template overhead. For full
    ///         conversation token counts, use ``TokenCounter/countTokens(in:for:)``
    ///         with message arrays.
    ///
    /// - SeeAlso: ``TokenCounter/countTokens(in:for:)``
    public func tokenCount<P: TokenCounter>(
        with provider: P,
        model: P.ModelID
    ) async throws -> Int {
        let result = try await provider.countTokens(in: self, for: model)
        return result.count
    }
}

// MARK: - String + Semantic Similarity

extension String {

    /// Computes semantic similarity with another string.
    ///
    /// This convenience method generates embeddings for both strings and computes
    /// their cosine similarity, providing a measure of how semantically similar they are.
    ///
    /// ## Usage
    /// ```swift
    /// let provider = MLXProvider()
    ///
    /// let similarity = try await "The cat sat on the mat".similarity(
    ///     to: "A feline rested on the rug",
    ///     using: provider,
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// )
    ///
    /// print("Similarity: \(similarity)") // e.g., 0.87 (high similarity)
    /// ```
    ///
    /// ## Interpreting Similarity Scores
    /// Cosine similarity ranges from -1 to 1:
    /// - **0.9 - 1.0**: Nearly identical meaning (synonyms, paraphrases)
    /// - **0.7 - 0.9**: Highly related (same topic, similar concepts)
    /// - **0.5 - 0.7**: Moderately related (overlapping topics)
    /// - **0.3 - 0.5**: Loosely related (some shared concepts)
    /// - **0.0 - 0.3**: Weakly related or unrelated
    /// - **Below 0**: Typically indicates opposite meanings (rare with most models)
    ///
    /// ## Use Cases
    ///
    /// ### Duplicate Detection
    /// ```swift
    /// let threshold: Float = 0.85
    /// let articles = ["...", "...", "..."]
    ///
    /// for i in 0..<articles.count {
    ///     for j in (i+1)..<articles.count {
    ///         let similarity = try await articles[i].similarity(
    ///             to: articles[j],
    ///             using: provider,
    ///             model: model
    ///         )
    ///         if similarity > threshold {
    ///             print("Potential duplicate: articles[\(i)] and articles[\(j)]")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ### Query Matching
    /// ```swift
    /// let userQuery = "How do I sort an array?"
    /// let faqQuestions = [
    ///     "What is the best way to sort a list?",
    ///     "How can I order elements in a collection?",
    ///     "Where is the login button?"
    /// ]
    ///
    /// for question in faqQuestions {
    ///     let similarity = try await userQuery.similarity(
    ///         to: question,
    ///         using: provider,
    ///         model: model
    ///     )
    ///     if similarity > 0.7 {
    ///         print("Matched FAQ: \(question) (score: \(similarity))")
    ///     }
    /// }
    /// ```
    ///
    /// ### Content Recommendation
    /// ```swift
    /// let userInterest = "machine learning and artificial intelligence"
    /// let articles = ["Neural networks tutorial", "Cooking recipes", "Deep learning guide"]
    ///
    /// let scored = try await articles.asyncMap { article in
    ///     let score = try await userInterest.similarity(
    ///         to: article,
    ///         using: provider,
    ///         model: model
    ///     )
    ///     return (article, score)
    /// }
    ///
    /// let recommendations = scored
    ///     .sorted { $0.1 > $1.1 }
    ///     .prefix(5)
    ///     .map(\.0)
    /// ```
    ///
    /// ## Performance Note
    /// This method generates two embeddings and computes similarity. For comparing
    /// one text against many others, it's more efficient to generate the first
    /// embedding once and reuse it:
    ///
    /// ```swift
    /// let queryEmbedding = try await query.embed(with: provider, model: model)
    /// let scores = try await documents.asyncMap { doc in
    ///     let docEmbedding = try await doc.embed(with: provider, model: model)
    ///     return queryEmbedding.cosineSimilarity(with: docEmbedding)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - other: The string to compare with.
    ///   - provider: The embedding generator provider to use.
    ///   - model: The embedding model identifier to use.
    ///
    /// - Returns: Cosine similarity score between -1 and 1, where:
    ///   - 1 = identical meaning
    ///   - 0 = orthogonal/unrelated
    ///   - -1 = opposite meaning
    ///
    /// - Throws: ``AIError`` if embedding generation fails for either string.
    ///
    /// - Note: Both strings must be embedded using the same model for meaningful
    ///         similarity comparisons. Comparing embeddings from different models
    ///         will produce meaningless results.
    ///
    /// - SeeAlso:
    ///   - ``embed(with:model:)`` for generating individual embeddings
    ///   - ``EmbeddingResult/cosineSimilarity(with:)`` for manual similarity computation
    public func similarity<P: EmbeddingGenerator>(
        to other: String,
        using provider: P,
        model: P.ModelID
    ) async throws -> Float {
        // Generate embeddings for both strings
        let embedding1 = try await self.embed(with: provider, model: model)
        let embedding2 = try await other.embed(with: provider, model: model)

        // Compute and return cosine similarity
        return embedding1.cosineSimilarity(with: embedding2)
    }
}
