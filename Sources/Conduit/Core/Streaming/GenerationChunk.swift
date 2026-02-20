// GenerationChunk.swift
// Conduit

import Foundation

// MARK: - Tool Call Constants

/// Maximum allowed index for parallel tool calls in a single response.
///
/// This constant defines the upper bound (inclusive) for the `PartialToolCall.index` property,
/// establishing a validated range of `0...100` for tool call indices.
///
/// ## Rationale
///
/// The limit of 100 parallel tool calls is based on several considerations:
///
/// - **Practical sufficiency**: Most real-world use cases involve 1-10 parallel tool calls.
///   Even complex agentic workflows rarely exceed a dozen concurrent operations.
///
/// - **Memory management**: The streaming tool call accumulator uses dictionaries keyed by
///   index. Unbounded indices could lead to memory exhaustion through malicious or malformed
///   server responses.
///
/// - **Provider compatibility**: Neither OpenAI nor Anthropic document a specific limit for
///   parallel tool calls, but 100 provides an extremely generous buffer while maintaining
///   reasonable bounds.
///
/// - **Defense in depth**: Validating indices prevents potential integer overflow issues
///   and ensures predictable behavior across all providers.
///
/// ## Usage
///
/// This constant is used internally to validate `PartialToolCall.index` values:
///
/// ```swift
/// precondition((0...maxToolCallIndex).contains(index))
/// ```
///
/// - SeeAlso: ``PartialToolCall``
/// - SeeAlso: ``PartialToolCall/index``
public let maxToolCallIndex = 100

// MARK: - PartialToolCall

/// A partial tool call being streamed.
///
/// During streaming, tool call arguments arrive as JSON fragments.
/// This struct represents the current state of a tool call being assembled.
///
/// ## Usage
///
/// ```swift
/// for try await chunk in stream {
///     if let partial = chunk.partialToolCall {
///         print("Tool \(partial.toolName) receiving: \(partial.argumentsFragment)")
///     }
///     if let completed = chunk.completedToolCalls {
///         // Execute completed tool calls
///         for call in completed {
///             let result = try await executor.execute(call)
///         }
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// `PartialToolCall` is `Sendable` and can be safely passed across actor boundaries.
public struct PartialToolCall: Sendable, Hashable {
    /// Unique identifier for this tool call.
    public let id: String

    /// Name of the tool being called.
    public let toolName: String

    /// Index of this tool call in the response (for multiple parallel tool calls).
    ///
    /// When a model invokes multiple tools in a single response, each tool call is assigned
    /// a unique index starting from 0. This index is used to correlate streaming argument
    /// fragments with the correct tool call accumulator.
    ///
    /// ## Valid Range
    ///
    /// The index must be in the range `0...100` (see ``maxToolCallIndex``). This bound exists to:
    /// - Prevent unbounded memory allocation in streaming accumulators
    /// - Provide defense against malformed server responses
    /// - Ensure predictable behavior across all providers
    ///
    /// Most real-world use cases involve indices 0-9, as models rarely invoke more than
    /// 10 tools in parallel.
    ///
    /// - Precondition: Must be in range `0...maxToolCallIndex` (0...100).
    /// - SeeAlso: ``maxToolCallIndex``
    public let index: Int

    /// Current accumulated arguments JSON fragment.
    public let argumentsFragment: String

    /// Creates a partial tool call.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for this tool call. Must not be empty.
    ///   - toolName: Name of the tool being called. Must not be empty.
    ///   - index: Index of this tool call in the response. Must be in range `0...maxToolCallIndex`.
    ///   - argumentsFragment: Current accumulated arguments JSON fragment.
    ///
    /// - Precondition: `id` must not be empty.
    /// - Precondition: `toolName` must not be empty.
    /// - Precondition: `index` must be in range `0...maxToolCallIndex` (0...100).
    public init(id: String, toolName: String, index: Int, argumentsFragment: String) {
        precondition(!id.isEmpty, "PartialToolCall id must not be empty")
        precondition(!toolName.isEmpty, "PartialToolCall toolName must not be empty")
        precondition(
            (0...maxToolCallIndex).contains(index),
            "PartialToolCall index must be in range 0...\(maxToolCallIndex), got \(index)"
        )

        self.id = id
        self.toolName = toolName
        self.index = index
        self.argumentsFragment = argumentsFragment
    }

    /// Creates a partial tool call only if the inputs are valid.
    ///
    /// This is a safe alternative to the preconditioned initializer and
    /// is intended for use when parsing external provider responses.
    public static func validated(
        id: String,
        toolName: String,
        index: Int,
        argumentsFragment: String
    ) -> PartialToolCall? {
        guard !id.isEmpty,
              !toolName.isEmpty,
              (0...maxToolCallIndex).contains(index) else {
            return nil
        }

        return PartialToolCall(
            id: id,
            toolName: toolName,
            index: index,
            argumentsFragment: argumentsFragment
        )
    }
}

// MARK: - GenerationChunk

/// A single chunk of streamed generation output.
///
/// Represents one or more tokens yielded during streaming generation.
/// Each chunk contains the generated text, timing information, and
/// optional probability data.
///
/// ## Usage
/// ```swift
/// for try await chunk in stream {
///     print(chunk.text, terminator: "")
///     if chunk.isComplete {
///         print("\nFinished: \(chunk.finishReason ?? .stop)")
///     }
/// }
/// ```
public struct GenerationChunk: Sendable, Equatable {
    /// The generated text in this chunk.
    public let text: String

    /// Number of tokens in this chunk (usually 1).
    public let tokenCount: Int

    /// Token ID if available.
    public let tokenId: Int?

    /// Log probability of this token.
    public let logprob: Float?

    /// Top alternative tokens with their probabilities.
    public let topLogprobs: [TokenLogprob]?

    /// Generation speed at this point (tokens per second).
    public let tokensPerSecond: Double?

    /// Whether this is the final chunk.
    public let isComplete: Bool

    /// Reason generation stopped (only set on final chunk).
    public let finishReason: FinishReason?

    /// Timestamp when this chunk was generated.
    public let timestamp: Date

    /// Usage statistics from the final message_delta event.
    ///
    /// Only populated in the final chunk when streaming completes.
    /// Contains input and output token counts for the entire generation.
    public let usage: UsageStats?

    /// Partial tool call update during streaming.
    ///
    /// When a tool call's arguments are being streamed, each chunk may contain
    /// an update to the arguments JSON. Use this to show progress or for early parsing.
    public let partialToolCall: PartialToolCall?

    /// Completed tool calls in this chunk.
    ///
    /// Set in the final chunk when streaming tool calls are complete.
    /// Contains fully assembled tool calls ready for execution.
    public let completedToolCalls: [Transcript.ToolCall]?

    /// Reasoning details streamed alongside the response (if provided).
    ///
    /// Populated when providers emit reasoning blocks in streaming mode.
    public let reasoningDetails: [ReasoningDetail]?

    /// Whether this chunk contains tool call updates.
    public var hasToolCallUpdates: Bool {
        partialToolCall != nil || (completedToolCalls?.isEmpty == false)
    }

    /// Whether this chunk contains reasoning details.
    public var hasReasoningDetails: Bool {
        reasoningDetails?.isEmpty == false
    }

    /// Creates a generation chunk.
    ///
    /// - Parameters:
    ///   - text: The generated text in this chunk.
    ///   - tokenCount: Number of tokens (default: 1).
    ///   - tokenId: Optional token ID.
    ///   - logprob: Optional log probability.
    ///   - topLogprobs: Optional top alternative tokens.
    ///   - tokensPerSecond: Optional generation speed.
    ///   - isComplete: Whether this is the final chunk.
    ///   - finishReason: Reason generation stopped (for final chunk).
    ///   - timestamp: Chunk creation time (default: now).
    ///   - usage: Optional usage statistics (for final chunk).
    ///   - partialToolCall: Partial tool call update during streaming.
    ///   - completedToolCalls: Completed tool calls in this chunk.
    public init(
        text: String,
        tokenCount: Int = 1,
        tokenId: Int? = nil,
        logprob: Float? = nil,
        topLogprobs: [TokenLogprob]? = nil,
        tokensPerSecond: Double? = nil,
        isComplete: Bool = false,
        finishReason: FinishReason? = nil,
        timestamp: Date = Date(),
        usage: UsageStats? = nil,
        partialToolCall: PartialToolCall? = nil,
        completedToolCalls: [Transcript.ToolCall]? = nil,
        reasoningDetails: [ReasoningDetail]? = nil
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.tokenId = tokenId
        self.logprob = logprob
        self.topLogprobs = topLogprobs
        self.tokensPerSecond = tokensPerSecond
        self.isComplete = isComplete
        self.finishReason = finishReason
        self.timestamp = timestamp
        self.usage = usage
        self.partialToolCall = partialToolCall
        self.completedToolCalls = completedToolCalls
        self.reasoningDetails = reasoningDetails
    }

    // MARK: - Factory Methods

    /// Creates a completion chunk indicating generation has finished.
    ///
    /// - Parameter finishReason: The reason generation stopped.
    /// - Returns: A chunk marking the end of generation.
    public static func completion(finishReason: FinishReason) -> GenerationChunk {
        GenerationChunk(
            text: "",
            tokenCount: 0,
            isComplete: true,
            finishReason: finishReason
        )
    }
}

// MARK: - Equatable Conformance

extension GenerationChunk {
    public static func == (lhs: GenerationChunk, rhs: GenerationChunk) -> Bool {
        lhs.text == rhs.text &&
        lhs.tokenCount == rhs.tokenCount &&
        lhs.tokenId == rhs.tokenId &&
        lhs.logprob == rhs.logprob &&
        lhs.topLogprobs == rhs.topLogprobs &&
        lhs.tokensPerSecond == rhs.tokensPerSecond &&
        lhs.isComplete == rhs.isComplete &&
        lhs.finishReason == rhs.finishReason &&
        lhs.timestamp == rhs.timestamp &&
        lhs.usage == rhs.usage &&
        lhs.partialToolCall == rhs.partialToolCall &&
        lhs.completedToolCalls == rhs.completedToolCalls &&
        lhs.reasoningDetails == rhs.reasoningDetails
    }
}
