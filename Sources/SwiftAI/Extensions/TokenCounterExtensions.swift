// TokenCounterExtensions.swift
// SwiftAI

import Foundation

// MARK: - Context Window Utilities

extension TokenCounter {

    /// Estimates whether messages fit within a context window.
    ///
    /// Counts tokens in the message array and checks against the context
    /// size, reserving space for the model's output.
    ///
    /// - Parameters:
    ///   - messages: The messages to check.
    ///   - model: The model whose tokenizer should be used.
    ///   - contextSize: The total context window size.
    ///   - reserveForOutput: Tokens to reserve for generation (default: 1024).
    /// - Returns: A tuple with (fits, tokenCount, availableTokens).
    /// - Throws: If token counting fails.
    ///
    /// ## Usage
    /// ```swift
    /// let (fits, tokens, available) = try await provider.estimateFits(
    ///     messages: conversation,
    ///     model: .llama3_2_1b,
    ///     contextSize: .context8K,
    ///     reserveForOutput: 1024
    /// )
    /// if !fits {
    ///     print("Need to truncate: \(tokens) tokens, only \(available) available")
    /// }
    /// ```
    public func estimateFits(
        messages: [Message],
        model: ModelID,
        contextSize: Int,
        reserveForOutput: Int = 1024
    ) async throws -> (fits: Bool, tokens: Int, available: Int) {
        let count = try await countTokens(in: messages, for: model)
        let available = contextSize - reserveForOutput
        return (count.count <= available, count.count, available)
    }

    /// Truncates messages to fit within a context window.
    ///
    /// Removes the oldest non-system messages until the conversation fits.
    /// System messages are always preserved at the beginning.
    ///
    /// - Parameters:
    ///   - messages: The messages to truncate.
    ///   - model: The model whose tokenizer should be used.
    ///   - contextSize: The total context window size.
    ///   - reserveForOutput: Tokens to reserve for generation (default: 1024).
    /// - Returns: A truncated array of messages that fits in context.
    /// - Throws: If token counting fails.
    ///
    /// ## Truncation Strategy
    /// 1. System messages are never removed
    /// 2. Oldest non-system messages are removed first
    /// 3. Continues until messages fit or only system messages remain
    ///
    /// ## Usage
    /// ```swift
    /// let truncated = try await provider.truncateToFit(
    ///     messages: longConversation,
    ///     model: .llama3_2_1b,
    ///     contextSize: .context4K
    /// )
    /// ```
    public func truncateToFit(
        messages: [Message],
        model: ModelID,
        contextSize: Int,
        reserveForOutput: Int = 1024
    ) async throws -> [Message] {
        var result = messages
        let targetSize = contextSize - reserveForOutput

        // Initial count
        var currentCount = try await countTokens(in: result, for: model).count

        // Remove oldest non-system messages until we fit
        while currentCount > targetSize && result.count > 1 {
            // Find first non-system message to remove
            guard let indexToRemove = result.firstIndex(where: { $0.role != .system }) else {
                // Only system messages left - can't truncate further
                break
            }

            result.remove(at: indexToRemove)
            currentCount = try await countTokens(in: result, for: model).count
        }

        return result
    }

    /// Chunks text into segments that fit within a token limit.
    ///
    /// Useful for RAG (Retrieval-Augmented Generation) workflows where
    /// long documents need to be split into digestible chunks.
    ///
    /// - Parameters:
    ///   - text: The text to chunk.
    ///   - model: The model whose tokenizer should be used.
    ///   - maxTokensPerChunk: Maximum tokens per chunk.
    ///   - overlap: Number of overlapping tokens between chunks (default: 0).
    /// - Returns: An array of text chunks.
    /// - Throws: If tokenization fails.
    ///
    /// ## Overlap
    /// Setting `overlap > 0` creates sliding windows that share context:
    /// - Chunk 1: tokens [0..<100]
    /// - Chunk 2: tokens [80..<180] (with overlap=20)
    /// - Chunk 3: tokens [160..<260]
    ///
    /// ## Usage
    /// ```swift
    /// let chunks = try await provider.chunk(
    ///     text: longDocument,
    ///     model: .llama3_2_1b,
    ///     maxTokensPerChunk: 512,
    ///     overlap: 50
    /// )
    /// for chunk in chunks {
    ///     let embedding = try await provider.embed(chunk, model: .bgeSmall)
    ///     // Store embedding for retrieval
    /// }
    /// ```
    public func chunk(
        text: String,
        model: ModelID,
        maxTokensPerChunk: Int,
        overlap: Int = 0
    ) async throws -> [String] {
        // Encode the full text to tokens
        let tokens = try await encode(text, for: model)

        // If it fits in one chunk, return as-is
        guard tokens.count > maxTokensPerChunk else {
            return [text]
        }

        var chunks: [String] = []
        var startIndex = 0

        while startIndex < tokens.count {
            let endIndex = min(startIndex + maxTokensPerChunk, tokens.count)
            let chunkTokens = Array(tokens[startIndex..<endIndex])

            // Decode this chunk back to text
            let chunkText = try await decode(chunkTokens, for: model, skipSpecialTokens: true)
            chunks.append(chunkText)

            // Advance start, accounting for overlap
            let advance = maxTokensPerChunk - overlap
            if advance <= 0 {
                // Prevent infinite loop if overlap >= maxTokensPerChunk
                startIndex = endIndex
            } else {
                startIndex += advance
            }

            // Exit if we've reached or passed the end
            if startIndex >= tokens.count { break }
        }

        return chunks
    }
}

// MARK: - Batch Operations

extension TokenCounter {

    /// Counts tokens for multiple texts in parallel.
    ///
    /// - Parameters:
    ///   - texts: The texts to count.
    ///   - model: The model whose tokenizer should be used.
    /// - Returns: Token counts in the same order as input texts.
    /// - Throws: If any token counting operation fails.
    public func countTokensBatch(
        in texts: [String],
        for model: ModelID
    ) async throws -> [TokenCount] {
        try await withThrowingTaskGroup(of: (Int, TokenCount).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let count = try await self.countTokens(in: text, for: model)
                    return (index, count)
                }
            }

            // Collect results maintaining order
            var results = Array<TokenCount?>(repeating: nil, count: texts.count)
            for try await (index, count) in group {
                results[index] = count
            }

            return results.compactMap { $0 }
        }
    }

    /// Checks if all provided texts fit within a context window.
    ///
    /// - Parameters:
    ///   - texts: The texts to check.
    ///   - model: The model whose tokenizer should be used.
    ///   - contextSize: The context window size.
    /// - Returns: `true` if the combined token count fits.
    public func allFitInContext(
        texts: [String],
        model: ModelID,
        contextSize: Int
    ) async throws -> Bool {
        let counts = try await countTokensBatch(in: texts, for: model)
        let total = counts.reduce(0) { $0 + $1.count }
        return total <= contextSize
    }
}

// MARK: - Convenience Methods

extension TokenCounter {

    /// Counts tokens and returns just the count integer.
    ///
    /// A simpler interface when you only need the count.
    public func tokenCount(
        in text: String,
        for model: ModelID
    ) async throws -> Int {
        try await countTokens(in: text, for: model).count
    }

    /// Calculates remaining context space after accounting for messages.
    ///
    /// - Parameters:
    ///   - messages: Current messages.
    ///   - model: The model.
    ///   - contextSize: Total context size.
    /// - Returns: Remaining tokens available.
    public func remainingContext(
        after messages: [Message],
        model: ModelID,
        contextSize: Int
    ) async throws -> Int {
        let count = try await countTokens(in: messages, for: model)
        return count.remainingIn(context: contextSize)
    }
}
