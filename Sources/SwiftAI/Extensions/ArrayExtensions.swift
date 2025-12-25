// ArrayExtensions.swift
// SwiftAI

import Foundation

// MARK: - Message Array Generation Extensions

extension Array where Element == Message {

    /// Generates a response from this message array.
    ///
    /// This convenience method allows calling generation directly on a message array,
    /// making conversational flows more natural and readable.
    ///
    /// ## Usage
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are a helpful assistant."),
    ///     .user("What is Swift?")
    /// ]
    ///
    /// let response = try await messages.generate(
    ///     with: provider,
    ///     model: .llama3_2_1b,
    ///     config: .default
    /// )
    /// print(response)
    /// ```
    ///
    /// ## SwiftUI Integration
    /// ```swift
    /// @State private var messages: [Message] = [.system("You are helpful.")]
    ///
    /// let answer = try await messages.generate(
    ///     with: mlxProvider,
    ///     model: .llama3_2_1b
    /// )
    /// messages.append(.assistant(answer))
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The text generation provider to use.
    ///   - model: The model identifier for generation.
    ///   - config: Configuration parameters for generation (defaults to `.default`).
    ///
    /// - Returns: The generated text as a string.
    ///
    /// - Throws: `AIError` if generation fails or if the message array is empty.
    ///
    /// - Note: This method returns only the generated text. For full metadata
    ///         (token counts, finish reason, etc.), call `provider.generate(messages:model:config:)` directly.
    public func generate<P: TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) async throws -> String {
        let result = try await provider.generate(messages: self, model: model, config: config)
        return result.text
    }

    /// Streams generation for these messages.
    ///
    /// Provides token-by-token streaming output from the message conversation,
    /// enabling real-time display and responsive UIs.
    ///
    /// ## Usage
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are a storyteller."),
    ///     .user("Write a short poem about AI.")
    /// ]
    ///
    /// let stream = messages.stream(
    ///     with: provider,
    ///     model: .llama3_2_1b,
    ///     config: .creative
    /// )
    ///
    /// var fullText = ""
    /// for try await token in stream {
    ///     print(token, terminator: "")
    ///     fullText += token
    /// }
    /// ```
    ///
    /// ## SwiftUI Real-Time Display
    /// ```swift
    /// @State private var streamedResponse = ""
    ///
    /// Task {
    ///     let stream = messages.stream(with: provider, model: .llama3_2_1b)
    ///     for try await token in stream {
    ///         streamedResponse += token
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The text generation provider to use.
    ///   - model: The model identifier for generation.
    ///   - config: Configuration parameters for generation (defaults to `.default`).
    ///
    /// - Returns: An `AsyncThrowingStream` that emits text fragments as they are generated.
    ///
    /// - Note: Canceling the task that iterates this stream will stop generation.
    ///         For metadata (finish reason, token counts), use `provider.streamWithMetadata(messages:model:config:)`.
    public func stream<P: TextGenerator>(
        with provider: P,
        model: P.ModelID,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let metadataStream = provider.streamWithMetadata(
                        messages: self,
                        model: model,
                        config: config
                    )

                    for try await chunk in metadataStream {
                        if !chunk.text.isEmpty {
                            continuation.yield(chunk.text)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Message Array Utilities

extension Array where Element == Message {

    /// Returns only user messages.
    ///
    /// Filters the message array to include only messages with `role: .user`,
    /// useful for analyzing user input or extracting conversation history.
    ///
    /// ## Usage
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are helpful."),
    ///     .user("Hello!"),
    ///     .assistant("Hi there!"),
    ///     .user("How are you?")
    /// ]
    ///
    /// let userMessages = messages.userMessages
    /// // Returns: [.user("Hello!"), .user("How are you?")]
    /// ```
    ///
    /// - Returns: An array containing only messages with `role: .user`.
    public var userMessages: [Message] {
        filter { $0.role == .user }
    }

    /// Returns only assistant messages.
    ///
    /// Filters the message array to include only messages with `role: .assistant`,
    /// useful for analyzing AI responses or building conversation summaries.
    ///
    /// ## Usage
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are helpful."),
    ///     .user("Hello!"),
    ///     .assistant("Hi there!"),
    ///     .user("How are you?"),
    ///     .assistant("I'm doing well!")
    /// ]
    ///
    /// let assistantMessages = messages.assistantMessages
    /// // Returns: [.assistant("Hi there!"), .assistant("I'm doing well!")]
    /// ```
    ///
    /// - Returns: An array containing only messages with `role: .assistant`.
    public var assistantMessages: [Message] {
        filter { $0.role == .assistant }
    }

    /// Returns the system message if present.
    ///
    /// Finds the first message with `role: .system` in the array.
    /// System messages typically appear at the start of conversations
    /// to set context and behavior for the assistant.
    ///
    /// ## Usage
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are a helpful coding assistant."),
    ///     .user("Hello!")
    /// ]
    ///
    /// if let systemMsg = messages.systemMessage {
    ///     print("System prompt: \(systemMsg.content.textValue)")
    /// }
    /// ```
    ///
    /// - Returns: The first system message, or `nil` if no system message exists.
    ///
    /// - Note: If multiple system messages exist, only the first is returned.
    ///         Best practice is to have at most one system message per conversation.
    public var systemMessage: Message? {
        first { $0.role == .system }
    }

    /// Returns messages without the system message.
    ///
    /// Creates a new array excluding any system messages, useful for
    /// processing conversation turns or when system context should be omitted.
    ///
    /// ## Usage
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are helpful."),
    ///     .user("Hello!"),
    ///     .assistant("Hi there!")
    /// ]
    ///
    /// let conversationOnly = messages.withoutSystem
    /// // Returns: [.user("Hello!"), .assistant("Hi there!")]
    /// ```
    ///
    /// ## Use Cases
    /// - Displaying conversation history without system prompts
    /// - Counting only user-assistant exchanges
    /// - Exporting conversation transcripts
    ///
    /// - Returns: An array with all system messages removed.
    public var withoutSystem: [Message] {
        filter { $0.role != .system }
    }

    /// Total text content length across all messages.
    ///
    /// Calculates the combined character count of text content
    /// in all messages. This provides a rough estimate of conversation
    /// size and can help determine when context trimming is needed.
    ///
    /// ## Usage
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are helpful."),
    ///     .user("Hello!"),
    ///     .assistant("Hi there! How can I help you today?")
    /// ]
    ///
    /// let length = messages.totalTextLength
    /// print("Total characters: \(length)")
    ///
    /// // Check if approaching context limits
    /// if messages.totalTextLength > 10000 {
    ///     // Consider summarizing or trimming older messages
    /// }
    /// ```
    ///
    /// - Returns: The sum of character counts across all message text content.
    ///
    /// - Note: This is a character count, not a token count. For accurate
    ///         token usage, use a `TokenCounter` conforming provider or
    ///         check `UsageStats` from generation results.
    public var totalTextLength: Int {
        reduce(0) { $0 + $1.content.textValue.count }
    }
}

// MARK: - String Array Embedding Extensions

extension Array where Element == String {

    /// Embeds all strings in batch.
    ///
    /// Generates vector embeddings for multiple text strings efficiently
    /// using batch processing. Returns embeddings in the same order as
    /// the input strings.
    ///
    /// ## Usage
    /// ```swift
    /// let documents = [
    ///     "Swift is a powerful programming language.",
    ///     "Python is known for its simplicity.",
    ///     "Rust ensures memory safety."
    /// ]
    ///
    /// let embeddings = try await documents.embed(
    ///     with: mlxProvider,
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// )
    ///
    /// for (text, embedding) in zip(documents, embeddings) {
    ///     print("\(text): \(embedding.dimensions)D vector")
    /// }
    /// ```
    ///
    /// ## Performance
    /// Batch embedding is more efficient than calling `embed(_:model:)`
    /// individually for each string, as providers can optimize parallel
    /// processing and reduce overhead.
    ///
    /// ## Ordering Guarantee
    /// The returned array maintains the same order as the input:
    /// `embeddings[i]` corresponds to input string at index `i`.
    ///
    /// - Parameters:
    ///   - provider: The embedding generator provider to use.
    ///   - model: The embedding model identifier.
    ///
    /// - Returns: An array of `EmbeddingResult` values, one per input string.
    ///
    /// - Throws: `AIError` if embedding fails for any string in the batch.
    ///
    /// - Note: Empty arrays return an empty result array without error.
    public func embed<P: EmbeddingGenerator>(
        with provider: P,
        model: P.ModelID
    ) async throws -> [EmbeddingResult] {
        try await provider.embedBatch(self, model: model)
    }

    /// Finds the most similar string to a query.
    ///
    /// Embeds all strings and the query, then finds the string with
    /// the highest cosine similarity to the query. Returns both the
    /// matching text and its similarity score.
    ///
    /// ## Usage
    /// ```swift
    /// let documents = [
    ///     "Swift is fast and efficient.",
    ///     "Python is simple to learn.",
    ///     "Rust provides memory safety.",
    ///     "Go is designed for concurrency."
    /// ]
    ///
    /// if let match = try await documents.findMostSimilar(
    ///     to: "performance and speed",
    ///     using: mlxProvider,
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// ) {
    ///     print("Best match: \(match.text)")
    ///     print("Similarity: \(match.similarity)")
    /// }
    /// // Output: Best match: "Swift is fast and efficient."
    /// //         Similarity: 0.82
    /// ```
    ///
    /// ## Semantic Search
    /// This method performs semantic search, finding meaning-based matches
    /// rather than keyword matches:
    /// - "dog" matches "canine" (synonyms)
    /// - "fast car" matches "rapid vehicle" (semantic equivalence)
    /// - "machine learning" matches "AI algorithms" (related concepts)
    ///
    /// ## Use Cases
    /// - Finding the most relevant document for a search query
    /// - Selecting the best example from a set of options
    /// - Identifying duplicate or near-duplicate content
    ///
    /// - Parameters:
    ///   - query: The search query text.
    ///   - provider: The embedding generator provider to use.
    ///   - model: The embedding model identifier.
    ///
    /// - Returns: A tuple with the most similar text and its similarity score (0.0-1.0),
    ///            or `nil` if the array is empty.
    ///
    /// - Throws: `AIError` if embedding fails.
    ///
    /// - Note: Similarity scores range from 0.0 (completely different) to 1.0 (identical).
    ///         Scores above 0.7 typically indicate strong semantic similarity.
    public func findMostSimilar<P: EmbeddingGenerator>(
        to query: String,
        using provider: P,
        model: P.ModelID
    ) async throws -> (text: String, similarity: Float)? {
        guard !isEmpty else { return nil }

        // Embed query and all strings
        let queryEmbedding = try await provider.embed(query, model: model)
        let embeddings = try await provider.embedBatch(self, model: model)

        // Find the most similar
        var maxSimilarity: Float = -.infinity
        var maxIndex = 0

        for (index, embedding) in embeddings.enumerated() {
            let similarity = queryEmbedding.cosineSimilarity(with: embedding)
            if similarity > maxSimilarity {
                maxSimilarity = similarity
                maxIndex = index
            }
        }

        return (text: self[maxIndex], similarity: maxSimilarity)
    }

    /// Ranks strings by similarity to a query.
    ///
    /// Embeds all strings and the query, computes similarity scores,
    /// and returns results sorted from most to least similar. Each
    /// result includes the text and its similarity score.
    ///
    /// ## Usage
    /// ```swift
    /// let documents = [
    ///     "Swift is fast and type-safe.",
    ///     "Python is simple and readable.",
    ///     "Rust ensures memory safety.",
    ///     "Go excels at concurrency."
    /// ]
    ///
    /// let ranked = try await documents.ranked(
    ///     bySimilarityTo: "performance optimization",
    ///     using: mlxProvider,
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// )
    ///
    /// for (text, score) in ranked {
    ///     print("\(score, format: .number.precision(.fractionLength(2))): \(text)")
    /// }
    /// // Output (example):
    /// // 0.85: Swift is fast and type-safe.
    /// // 0.72: Rust ensures memory safety.
    /// // 0.58: Go excels at concurrency.
    /// // 0.41: Python is simple and readable.
    /// ```
    ///
    /// ## Retrieval-Augmented Generation (RAG)
    /// ```swift
    /// // Find top 3 most relevant documents
    /// let topDocs = try await knowledgeBase.ranked(
    ///     bySimilarityTo: userQuery,
    ///     using: provider,
    ///     model: .mlx("all-MiniLM-L6-v2")
    /// ).prefix(3)
    ///
    /// let context = topDocs.map(\.text).joined(separator: "\n\n")
    /// let prompt = "Context:\n\(context)\n\nQuestion: \(userQuery)"
    /// let answer = try await textProvider.generate(prompt, model: .llama3_2_1b)
    /// ```
    ///
    /// ## Use Cases
    /// - Building search result rankings
    /// - Retrieval-Augmented Generation (RAG) workflows
    /// - Document clustering and organization
    /// - Recommendation systems
    ///
    /// - Parameters:
    ///   - query: The search query text.
    ///   - provider: The embedding generator provider to use.
    ///   - model: The embedding model identifier.
    ///
    /// - Returns: An array of tuples containing text and similarity scores,
    ///            sorted from highest to lowest similarity. Empty if the input array is empty.
    ///
    /// - Throws: `AIError` if embedding fails.
    ///
    /// - Note: Results are sorted in descending order by similarity.
    ///         Scores range from 0.0 (completely different) to 1.0 (identical).
    public func ranked<P: EmbeddingGenerator>(
        bySimilarityTo query: String,
        using provider: P,
        model: P.ModelID
    ) async throws -> [(text: String, similarity: Float)] {
        guard !isEmpty else { return [] }

        // Embed query and all strings
        let queryEmbedding = try await provider.embed(query, model: model)
        let embeddings = try await provider.embedBatch(self, model: model)

        // Compute similarities and pair with text
        let results: [(text: String, similarity: Float)] = zip(self, embeddings).map { text, embedding in
            (text: text, similarity: queryEmbedding.cosineSimilarity(with: embedding))
        }

        // Sort by similarity descending
        return results.sorted { $0.similarity > $1.similarity }
    }
}
