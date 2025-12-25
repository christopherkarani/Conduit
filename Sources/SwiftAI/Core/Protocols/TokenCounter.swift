// TokenCounter.swift
// SwiftAI

import Foundation

// MARK: - TokenCounter Protocol

/// A type that can count tokens in text.
///
/// Token counting is essential for managing LLM interactions and understanding
/// resource usage. This protocol provides methods for counting tokens, encoding
/// text to token IDs, and decoding tokens back to text.
///
/// ## Why Token Counting Matters
///
/// Token counting is critical for several use cases:
///
/// ### Context Window Management
/// Every language model has a maximum context window (e.g., 4096, 8192, or 128K tokens).
/// Accurate token counting ensures you don't exceed the model's limits, preventing
/// truncation or errors during inference.
///
/// ```swift
/// let tokenCounter = provider.tokenCounter
/// let count = try await tokenCounter.countTokens(in: longDocument, for: .llama3_2_1b)
/// if count.count > 4096 {
///     // Truncate or chunk the input
/// }
/// ```
///
/// ### Cost Estimation
/// Cloud-based providers (like HuggingFace) charge per token. Token counting
/// enables cost estimation before making API calls.
///
/// ```swift
/// let inputTokens = try await tokenCounter.countTokens(in: prompt, for: model)
/// let estimatedCost = Double(inputTokens.count) * costPerToken
/// ```
///
/// ### Prompt Truncation
/// When conversations exceed context limits, token counting helps implement
/// intelligent truncation strategies (e.g., keep recent messages, summarize old ones).
///
/// ### Memory Management for Agents
/// SwiftAgents uses token counting to manage working memory, ensuring agent
/// conversations stay within context windows while retaining important information.
///
/// ## Tokenization Concepts
///
/// ### What is a Token?
/// A token is a unit of text that the model processes. Tokens can be:
/// - Whole words: "hello" → 1 token
/// - Subwords: "unhappiness" → ["un", "happiness"] → 2 tokens
/// - Characters: "🎉" → 1-3 tokens (depending on tokenizer)
///
/// The mapping from text to tokens is model-specific. Each model uses a different
/// tokenizer trained on its vocabulary.
///
/// ### Special Tokens
/// Language models use special tokens for control:
/// - `<|begin_of_text|>` (BOS): Marks the start of input
/// - `<|end_of_text|>` (EOS): Marks the end of generation
/// - `<|im_start|>`, `<|im_end|>`: Chat template delimiters
///
/// These tokens are invisible in text but count toward the context window.
///
/// ### Chat Templates
/// Chat models apply templates to format conversations:
///
/// ```
/// <|begin_of_text|><|start_header_id|>system<|end_header_id|>
/// You are a helpful assistant.<|eot_id|>
/// <|start_header_id|>user<|end_header_id|>
/// Hello!<|eot_id|>
/// <|start_header_id|>assistant<|end_header_id|>
/// ```
///
/// The `countTokens(in:for:)` method for messages includes this template overhead,
/// which can add 10-50 tokens depending on the model.
///
/// ## Thread Safety
///
/// All `TokenCounter` conformances must be `Sendable` and safe to call from
/// multiple concurrent tasks. Token counting operations are typically CPU-bound
/// and may involve loading tokenizer vocabularies from disk on first use.
///
/// ## Example: Context-Aware Prompting
///
/// ```swift
/// let tokenCounter = provider.tokenCounter
/// let systemPrompt = "You are a helpful assistant."
/// let userMessage = "Explain quantum computing."
///
/// let messages: [Message] = [
///     .system(systemPrompt),
///     .user(userMessage)
/// ]
///
/// let totalTokens = try await tokenCounter.countTokens(
///     in: messages,
///     for: .llama3_2_1b
/// )
///
/// print("Context usage: \(totalTokens.count) / 4096 tokens")
/// // Context usage: 127 / 4096 tokens (includes chat template overhead)
/// ```
///
/// ## See Also
/// - ``Message``: The message type used in conversations
/// - ``TokenCount``: The result type containing token count information
/// - ``ModelIdentifying``: Protocol for model identifiers
public protocol TokenCounter: Sendable {
    /// The model identifier type this counter works with.
    ///
    /// Each provider has its own model identifier type (e.g., `MLXModelID`,
    /// `HuggingFaceModelID`). The token counter must be compatible with the
    /// provider's identifier type.
    associatedtype ModelID: ModelIdentifying

    // MARK: - Token Counting

    /// Counts the number of tokens in the given text.
    ///
    /// This method tokenizes the input text using the model's tokenizer and
    /// returns the total token count. It does not include special tokens
    /// (BOS, EOS) unless they are part of the text itself.
    ///
    /// Use this for raw text token counting, such as:
    /// - Estimating prompt length before sending
    /// - Checking document sizes against context limits
    /// - Calculating costs for cloud inference
    ///
    /// ## Example
    /// ```swift
    /// let text = "Hello, world! How are you today?"
    /// let count = try await tokenCounter.countTokens(
    ///     in: text,
    ///     for: .llama3_2_1b
    /// )
    /// print(count.count) // e.g., 9 tokens
    /// ```
    ///
    /// ## Performance
    /// Token counting is typically fast (microseconds to milliseconds for short texts),
    /// but scales linearly with text length. For very long documents (>100K tokens),
    /// consider chunking the text and counting in batches.
    ///
    /// - Parameters:
    ///   - text: The input text to tokenize.
    ///   - model: The model identifier whose tokenizer to use.
    /// - Returns: A ``TokenCount`` struct with the total token count.
    /// - Throws: An error if the tokenizer cannot be loaded or tokenization fails.
    func countTokens(
        in text: String,
        for model: ModelID
    ) async throws -> TokenCount

    /// Counts tokens in a message array, including special tokens from the chat template.
    ///
    /// This method applies the model's chat template to format the conversation,
    /// then counts the resulting tokens. The count includes all special tokens
    /// added by the template (role markers, delimiters, BOS/EOS tokens).
    ///
    /// Use this for accurate context window calculations when working with
    /// conversational models.
    ///
    /// ## Chat Template Overhead
    /// Different models use different chat templates, which add varying amounts
    /// of overhead:
    ///
    /// - **Llama 3.2**: ~8-12 tokens per message (role headers + delimiters)
    /// - **Mistral**: ~6-10 tokens per message
    /// - **GPT**: ~4-6 tokens per message
    ///
    /// A conversation with 10 messages might use 60-120 tokens just for formatting.
    ///
    /// ## Example
    /// ```swift
    /// let messages: [Message] = [
    ///     .system("You are helpful."),
    ///     .user("Hello!"),
    ///     .assistant("Hi! How can I help?"),
    ///     .user("What's the weather?")
    /// ]
    ///
    /// let count = try await tokenCounter.countTokens(
    ///     in: messages,
    ///     for: .llama3_2_1b
    /// )
    ///
    /// print(count.count) // Total tokens including template overhead
    /// if let prompt = count.promptTokens {
    ///     print(prompt) // Tokens in the messages themselves
    /// }
    /// if let special = count.specialTokens {
    ///     print(special) // Overhead from chat template
    /// }
    /// ```
    ///
    /// ## Thread Safety
    /// This method is safe to call concurrently from multiple tasks. The chat
    /// template is applied in isolation for each call.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages to count.
    ///   - model: The model identifier whose tokenizer and chat template to use.
    /// - Returns: A ``TokenCount`` with total tokens and optional breakdown.
    /// - Throws: An error if the tokenizer or chat template cannot be loaded.
    func countTokens(
        in messages: [Message],
        for model: ModelID
    ) async throws -> TokenCount

    // MARK: - Encoding & Decoding

    /// Encodes text to token IDs using the model's tokenizer.
    ///
    /// This method converts text into the model's internal token representation.
    /// Token IDs are integers that index into the model's vocabulary. The same
    /// text may produce different token IDs with different models.
    ///
    /// Use encoding for:
    /// - Advanced prompt engineering (token-level control)
    /// - Implementing custom token limits (truncate at specific positions)
    /// - Debugging tokenization issues
    ///
    /// ## Example
    /// ```swift
    /// let text = "Hello, world!"
    /// let tokenIds = try await tokenCounter.encode(
    ///     text,
    ///     for: .llama3_2_1b
    /// )
    /// print(tokenIds) // [15339, 11, 1917, 0] (example)
    /// ```
    ///
    /// ## Special Tokens
    /// By default, encoding does NOT add special tokens (BOS/EOS). If you need
    /// the exact sequence the model will see during inference, use the provider's
    /// generation methods instead.
    ///
    /// - Parameters:
    ///   - text: The text to encode.
    ///   - model: The model identifier whose tokenizer to use.
    /// - Returns: An array of token IDs.
    /// - Throws: An error if encoding fails.
    func encode(
        _ text: String,
        for model: ModelID
    ) async throws -> [Int]

    /// Decodes token IDs back to text using the model's tokenizer.
    ///
    /// This method converts token IDs back into human-readable text. It is the
    /// inverse of ``encode(_:for:)``.
    ///
    /// Use decoding for:
    /// - Reconstructing text from token sequences
    /// - Debugging tokenization round-trips
    /// - Implementing token-level text processing
    ///
    /// ## Special Token Handling
    /// The `skipSpecialTokens` parameter controls whether special tokens are
    /// included in the output:
    ///
    /// ```swift
    /// let tokens = [128000, 15339, 11, 1917, 0, 128001] // [BOS, "Hello", ",", "world", "!", EOS]
    ///
    /// // With special tokens
    /// let withSpecial = try await tokenCounter.decode(
    ///     tokens,
    ///     for: .llama3_2_1b,
    ///     skipSpecialTokens: false
    /// )
    /// print(withSpecial) // "<|begin_of_text|>Hello, world!<|end_of_text|>"
    ///
    /// // Without special tokens
    /// let withoutSpecial = try await tokenCounter.decode(
    ///     tokens,
    ///     for: .llama3_2_1b,
    ///     skipSpecialTokens: true
    /// )
    /// print(withoutSpecial) // "Hello, world!"
    /// ```
    ///
    /// ## Round-Trip Guarantee
    /// Decoding the result of encoding should always recover the original text
    /// (modulo whitespace normalization in some tokenizers):
    ///
    /// ```swift
    /// let original = "Hello, world!"
    /// let tokens = try await tokenCounter.encode(original, for: model)
    /// let decoded = try await tokenCounter.decode(
    ///     tokens,
    ///     for: model,
    ///     skipSpecialTokens: true
    /// )
    /// assert(decoded == original)
    /// ```
    ///
    /// - Parameters:
    ///   - tokens: The token IDs to decode.
    ///   - model: The model identifier whose tokenizer to use.
    ///   - skipSpecialTokens: Whether to exclude special tokens from the output.
    ///     Defaults to `true` for cleaner text output.
    /// - Returns: The decoded text string.
    /// - Throws: An error if decoding fails or invalid token IDs are provided.
    func decode(
        _ tokens: [Int],
        for model: ModelID,
        skipSpecialTokens: Bool
    ) async throws -> String
}

// MARK: - Default Parameter Values

public extension TokenCounter {
    /// Decodes token IDs back to text, skipping special tokens by default.
    ///
    /// This convenience overload provides a cleaner API for the common case
    /// of decoding text without special tokens.
    ///
    /// - Parameters:
    ///   - tokens: The token IDs to decode.
    ///   - model: The model identifier whose tokenizer to use.
    /// - Returns: The decoded text string with special tokens removed.
    /// - Throws: An error if decoding fails.
    func decode(
        _ tokens: [Int],
        for model: ModelID
    ) async throws -> String {
        try await decode(tokens, for: model, skipSpecialTokens: true)
    }
}
