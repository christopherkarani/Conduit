// ChatSession.swift
// Conduit

import Foundation

#if canImport(Observation)
import Observation
#endif

// MARK: - WarmupConfig

/// Configuration for model warmup behavior in ChatSession.
///
/// Model warmup performs a minimal generation pass to pre-compile Metal shaders
/// and initialize the model's attention cache. This trades startup time for
/// improved first-message latency.
///
/// ## Performance Impact
///
/// - **Without warmup**: First message has ~2-4 second overhead (shader compilation)
/// - **With warmup**: First message latency is ~100-300ms (normal generation speed)
/// - **Warmup duration**: Typically 1-2 seconds during initialization
///
/// ## When to Use
///
/// **Use `.eager` warmup when:**
/// - The model is known at initialization time
/// - First-message latency is critical for user experience
/// - You're willing to pay the cost upfront during session creation
/// - Example: Chat interface where the user expects immediate responses
///
/// **Use `.default` (no warmup) when:**
/// - The model might change before first use
/// - Initialization speed is more important than first-message speed
/// - The session might be created but not immediately used
/// - Example: Pre-creating sessions for potential future conversations
///
/// ## Usage
///
/// ### Eager Warmup (Recommended for Active Chats)
///
/// ```swift
/// // Warmup automatically on init
/// let session = try await ChatSession(
///     provider: provider,
///     model: .llama3_2_1b,
///     warmup: .eager
/// )
/// // First message will be fast (~100-300ms)
/// ```
///
/// ### Default (No Warmup)
///
/// ```swift
/// // No warmup overhead during init
/// let session = ChatSession(
///     provider: provider,
///     model: .llama3_2_1b,
///     warmup: .default
/// )
/// // First message will include warmup time (~2-4s)
/// ```
///
/// ### Custom Warmup
///
/// ```swift
/// let customWarmup = WarmupConfig(
///     warmupOnInit: true,
///     prefillChars: 100,  // Larger cache warmup
///     warmupTokens: 10    // More tokens generated
/// )
/// let session = try await ChatSession(
///     provider: provider,
///     model: .llama3_2_1b,
///     warmup: customWarmup
/// )
/// ```
///
/// ## Properties
///
/// - `warmupOnInit`: If `true`, performs warmup during session initialization.
/// - `prefillChars`: Number of characters in the warmup prompt. Controls the
///   size of the attention cache that gets warmed up. Default: 50.
/// - `warmupTokens`: Number of tokens to generate during warmup. Higher values
///   warm up longer generation sequences but take longer. Default: 5.
///
/// ## Static Presets
///
/// - `.default`: No automatic warmup (`warmupOnInit: false`)
/// - `.eager`: Automatic warmup with default parameters (`warmupOnInit: true`)
public struct WarmupConfig: Sendable {
    /// Whether to perform warmup during session initialization.
    ///
    /// If `true`, the session initializer will call the provider's `warmUp()`
    /// method automatically. This trades initialization time for improved
    /// first-message latency.
    public var warmupOnInit: Bool

    /// Number of characters in the warmup prompt.
    ///
    /// Controls the size of the attention cache that gets warmed up. Larger
    /// values warm up the cache for longer prompts but take slightly longer.
    ///
    /// Default: 50 characters
    public var prefillChars: Int

    /// Number of tokens to generate during warmup.
    ///
    /// Higher values provide better warmup for longer generation sequences
    /// but increase warmup duration.
    ///
    /// Default: 5 tokens
    public var warmupTokens: Int

    /// Creates a custom warmup configuration.
    ///
    /// - Parameters:
    ///   - warmupOnInit: Whether to warmup on session init. Default: `false`.
    ///   - prefillChars: Number of warmup prompt characters. Default: `50`.
    ///   - warmupTokens: Number of tokens to generate. Default: `5`.
    public init(
        warmupOnInit: Bool = false,
        prefillChars: Int = 50,
        warmupTokens: Int = 5
    ) {
        self.warmupOnInit = warmupOnInit
        self.prefillChars = prefillChars
        self.warmupTokens = warmupTokens
    }

    /// Default configuration with no automatic warmup.
    ///
    /// First message will include warmup overhead (~2-4s), but session
    /// initialization is fast.
    public static let `default` = WarmupConfig(warmupOnInit: false)

    /// Eager warmup configuration.
    ///
    /// Performs warmup during session initialization. First message will be
    /// fast (~100-300ms), but session creation takes longer (~1-2s).
    public static let eager = WarmupConfig(warmupOnInit: true)
}

// MARK: - ChatSession

/// A stateful session manager for multi-turn chat conversations.
///
/// `ChatSession` provides a high-level interface for managing conversational
/// AI interactions. It handles message history, generation state, and provides
/// thread-safe access to session data using `NSLock` for synchronization.
///
/// ## Thread Safety
///
/// This class uses `NSLock` for thread-safe access to mutable state. The lock
/// is never held across `await` points to prevent deadlocks. State is captured
/// before async operations begin.
///
/// ## Usage
///
/// ### Basic Conversation
///
/// ```swift
/// let provider = MLXProvider()
/// let session = ChatSession(
///     provider: provider,
///     model: .llama3_2_1b
/// )
///
/// // Set system prompt
/// session.setSystemPrompt("You are a helpful coding assistant.")
///
/// // Send messages
/// let response = try await session.send("What is Swift?")
/// print(response)
///
/// // Continue the conversation
/// let followUp = try await session.send("Show me an example.")
/// print(followUp)
/// ```
///
/// ### Streaming Response
///
/// ```swift
/// let stream = session.stream("Write a haiku about Swift")
/// for try await token in stream {
///     print(token, terminator: "")
/// }
/// ```
///
/// ### History Management
///
/// ```swift
/// // Clear conversation (keeps system prompt)
/// session.clearHistory()
///
/// // Undo last exchange
/// session.undoLastExchange()
///
/// // Inject previous history
/// session.injectHistory(savedMessages)
/// ```
///
/// ### Cancellation
///
/// ```swift
/// // Cancel ongoing generation
/// await session.cancel()
/// ```
///
/// ## Observation
///
/// ChatSession is `@Observable`, allowing SwiftUI views to automatically
/// update when state changes:
///
/// ```swift
/// struct ChatView: View {
///     @State var session: ChatSession<MLXProvider>
///
///     var body: some View {
///         VStack {
///             ForEach(session.messages) { message in
///                 MessageView(message: message)
///             }
///             if session.isGenerating {
///                 ProgressView()
///             }
///         }
///     }
/// }
/// ```
///
/// - Note: This class is marked as `@unchecked Sendable` because thread safety
///   is enforced manually using `NSLock`. The lock is never held across await points.
#if canImport(Observation)
@Observable
#endif
public final class ChatSession<Provider: AIProvider & TextGenerator>: @unchecked Sendable {

    // MARK: - Properties

    /// The AI provider used for generation.
    public let provider: Provider

    /// The model identifier to use for generation.
    public let model: Provider.ModelID

    /// The conversation history.
    ///
    /// Messages are stored in chronological order. Use factory methods
    /// like `send(_:)` to add messages rather than modifying directly.
    public private(set) var messages: [Message] = []

    /// Whether a generation is currently in progress.
    ///
    /// Use this to show loading indicators in your UI.
    public private(set) var isGenerating: Bool = false

    /// Configuration for text generation.
    ///
    /// Can be modified between calls to `send(_:)` or `stream(_:)`.
    public var config: GenerateConfig

    /// Optional tool executor used for tool-call continuation in `send(_:)`.
    ///
    /// When set, `send(_:)` will execute `GenerationResult.toolCalls` and continue
    /// generation by appending tool output messages until the model returns no tool calls.
    /// If `nil`, tool-call responses are treated as invalid input errors.
    public var toolExecutor: ToolExecutor?

    /// Maximum number of tool-call rounds allowed in a single `send(_:)` request.
    ///
    /// A "round" is one model response containing at least one tool call followed by
    /// executing those calls. This bounds continuation loops and prevents runaway cycles.
    ///
    /// Values less than zero are treated as zero during execution.
    public var maxToolCallRounds: Int = 8

    /// The most recent error that occurred during generation.
    ///
    /// Reset to `nil` at the start of each new generation attempt.
    public private(set) var lastError: Error?

    /// The current generation task for cancellation support.
    private var generationTask: Task<Void, Never>?

    /// Cancellation flag used by non-streaming send loops.
    ///
    /// `cancel()` can be invoked from a different task than `send(_:)`, so
    /// `send(_:)` polls this flag between awaits to stop promptly.
    private var cancellationRequested: Bool = false

    /// Lock for thread-safe access to mutable state.
    private let lock = NSLock()

    // MARK: - Initialization

    /// Creates a new chat session.
    ///
    /// This synchronous initializer does not perform warmup. For automatic warmup
    /// during initialization, use the async `init(provider:model:config:warmup:)`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let provider = MLXProvider()
    /// let session = ChatSession(
    ///     provider: provider,
    ///     model: .llama3_2_1b,
    ///     config: .default.temperature(0.8)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use for generation.
    ///   - model: The model identifier for generation.
    ///   - config: Configuration for generation. Defaults to `.default`.
    public init(
        provider: Provider,
        model: Provider.ModelID,
        config: GenerateConfig = .default
    ) {
        self.provider = provider
        self.model = model
        self.config = config
    }

    /// Creates a new chat session with optional automatic warmup.
    ///
    /// If `warmup.warmupOnInit` is `true`, this initializer performs a minimal
    /// generation pass to pre-compile Metal shaders and initialize the model's
    /// attention cache. This trades initialization time (~1-2s) for improved
    /// first-message latency (~100-300ms vs ~2-4s).
    ///
    /// ## Usage
    ///
    /// ### With Eager Warmup (Recommended for Active Chats)
    ///
    /// ```swift
    /// let session = try await ChatSession(
    ///     provider: provider,
    ///     model: .llama3_2_1b,
    ///     warmup: .eager
    /// )
    /// // First message will be fast
    /// ```
    ///
    /// ### Without Warmup
    ///
    /// ```swift
    /// let session = try await ChatSession(
    ///     provider: provider,
    ///     model: .llama3_2_1b,
    ///     warmup: .default  // or omit, .default is the default
    /// )
    /// // First message will include warmup overhead
    /// ```
    ///
    /// ## When to Use Eager Warmup
    ///
    /// Use `.eager` warmup when:
    /// - The model is known at initialization time
    /// - First-message latency is critical for UX
    /// - The session will be used immediately
    ///
    /// Use `.default` (no warmup) when:
    /// - Initialization speed is more important
    /// - The session might not be used immediately
    /// - The model might change before first use
    ///
    /// - Parameters:
    ///   - provider: The AI provider to use for generation.
    ///   - model: The model identifier for generation.
    ///   - config: Configuration for generation. Defaults to `.default`.
    ///   - warmup: Warmup configuration. Defaults to `.default` (no warmup).
    ///
    /// - Throws: `AIError` if warmup fails (only when `warmup.warmupOnInit` is `true`).
    public init(
        provider: Provider,
        model: Provider.ModelID,
        config: GenerateConfig = .default,
        warmup: WarmupConfig = .default
    ) async throws {
        self.provider = provider
        self.model = model
        self.config = config

        // Perform warmup if requested
        if warmup.warmupOnInit {
            // Generate warmup text from prefillChars count
            let warmupText = String(repeating: "Hi! ", count: max(1, warmup.prefillChars / 4))
            try await provider.warmUp(
                model: model,
                prefillText: String(warmupText.prefix(warmup.prefillChars)),
                maxTokens: warmup.warmupTokens
            )
        }
    }

    deinit {
        generationTask?.cancel()
    }

    // MARK: - Thread-Safe State Access

    /// Executes a closure with the lock held.
    ///
    /// - Warning: Never call async functions inside this closure.
    ///   The lock must not be held across await points.
    ///
    /// - Parameter body: The closure to execute while holding the lock.
    /// - Returns: The value returned by the closure.
    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    /// Throws `AIError.cancelled` when cancellation has been requested.
    private func throwIfCancelled() throws {
        if withLock({ cancellationRequested }) {
            throw AIError.cancelled
        }
    }

    // MARK: - System Prompt

    /// Sets or replaces the system prompt.
    ///
    /// If a system message already exists at the beginning of the history,
    /// it is replaced. Otherwise, a new system message is inserted at the
    /// beginning.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// session.setSystemPrompt("You are a helpful coding assistant.")
    ///
    /// // Later, update the prompt
    /// session.setSystemPrompt("You are a creative writing assistant.")
    /// ```
    ///
    /// - Parameter prompt: The system prompt text.
    public func setSystemPrompt(_ prompt: String) {
        withLock {
            let systemMessage = Message.system(prompt)

            if !messages.isEmpty, messages[0].role == .system {
                messages[0] = systemMessage
            } else {
                messages.insert(systemMessage, at: 0)
            }
        }
    }

    // MARK: - Send Message

    /// Sends a message and waits for the complete response.
    ///
    /// This method:
    /// 1. Adds the user message to history
    /// 2. Calls the provider to generate a response
    /// 3. Adds the assistant response to history
    /// 4. Returns the response text
    ///
    /// On error, the user message is removed from history and the error
    /// is stored in `lastError`.
    ///
    /// ## Thread Safety
    ///
    /// State is captured before async operations. The lock is never held
    /// across await points.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// do {
    ///     let response = try await session.send("What is Swift?")
    ///     print(response)
    /// } catch {
    ///     print("Generation failed: \(error)")
    /// }
    /// ```
    ///
    /// - Parameter content: The user message text.
    /// - Returns: The generated response text.
    /// - Throws: `AIError` if generation fails, or `CancellationError` if cancelled.
    @discardableResult
    public func send(_ content: String) async throws -> String {
        // Create user message and prepare state
        let userMessage = Message.user(content)

        // Capture state and add user message under lock
        let capturedState: (messages: [Message], config: GenerateConfig, toolExecutor: ToolExecutor?, maxToolCallRounds: Int) = withLock {
            lastError = nil
            isGenerating = true
            cancellationRequested = false
            messages.append(userMessage)
            return (messages, config, toolExecutor, max(0, maxToolCallRounds))
        }

        // Capture model outside lock (immutable after initialization)
        let currentModel = model
        let currentMessages = capturedState.messages
        let currentConfig = capturedState.config
        let currentToolExecutor = capturedState.toolExecutor
        let currentMaxToolCallRounds = capturedState.maxToolCallRounds

        do {
            var loopMessages = currentMessages
            var turnMessages: [Message] = []
            var toolRoundCount = 0
            var finalResponseText = ""

            while true {
                try Task.checkCancellation()
                try throwIfCancelled()

                // Perform generation outside of lock
                let result = try await provider.generate(
                    messages: loopMessages,
                    model: currentModel,
                    config: currentConfig
                )

                try Task.checkCancellation()
                try throwIfCancelled()

                // Preserve tool call metadata on assistant messages for providers
                // that require prior assistant tool-call blocks in history.
                let assistantMessage = Message(
                    role: .assistant,
                    content: .text(result.text),
                    metadata: MessageMetadata(
                        tokenCount: result.tokenCount,
                        generationTime: result.generationTime,
                        model: currentModel.rawValue,
                        tokensPerSecond: result.tokensPerSecond,
                        toolCalls: result.toolCalls.isEmpty ? nil : result.toolCalls
                    )
                )

                turnMessages.append(assistantMessage)
                loopMessages.append(assistantMessage)

                guard !result.toolCalls.isEmpty else {
                    finalResponseText = result.text
                    break
                }

                guard toolRoundCount < currentMaxToolCallRounds else {
                    throw AIError.invalidInput(
                        "Tool-call loop exceeded maxToolCallRounds (\(currentMaxToolCallRounds))."
                    )
                }

                guard let currentToolExecutor else {
                    throw AIError.invalidInput(
                        "Tool calls were requested but ChatSession.toolExecutor is nil."
                    )
                }

                let toolOutputs = try await currentToolExecutor.execute(toolCalls: result.toolCalls)
                try Task.checkCancellation()
                try throwIfCancelled()
                for output in toolOutputs {
                    let toolMessage = Message.toolOutput(output)
                    turnMessages.append(toolMessage)
                    loopMessages.append(toolMessage)
                }

                toolRoundCount += 1
            }

            // Update state under lock
            withLock {
                messages.append(contentsOf: turnMessages)
                isGenerating = false
                cancellationRequested = false
            }

            return finalResponseText

        } catch {
            // On error, remove user message and store error
            withLock {
                // Remove the user message we just added
                if let index = messages.lastIndex(where: { $0.id == userMessage.id }) {
                    messages.remove(at: index)
                }
                lastError = error
                isGenerating = false
                cancellationRequested = false
            }

            throw error
        }
    }

    // MARK: - Stream Message

    /// Sends a message and streams the response tokens.
    ///
    /// This method returns an async stream that yields tokens as they are
    /// generated. Messages are added to history when the stream completes.
    ///
    /// ## Stream Lifecycle
    ///
    /// 1. User message is added to history
    /// 2. Stream yields tokens as they arrive
    /// 3. On completion, assistant message is added to history
    /// 4. On error, user message is removed and error is stored
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let stream = session.stream("Write a poem about Swift")
    /// var fullResponse = ""
    /// do {
    ///     for try await token in stream {
    ///         print(token, terminator: "")
    ///         fullResponse += token
    ///     }
    /// } catch {
    ///     print("Streaming failed: \(error)")
    /// }
    /// ```
    ///
    /// ## Cancellation
    ///
    /// Breaking out of the for-await loop or cancelling the enclosing task
    /// will stop generation and clean up properly.
    ///
    /// - Parameter content: The user message text.
    /// - Returns: An async throwing stream of response tokens.
    public func stream(_ content: String) -> AsyncThrowingStream<String, Error> {
        let userMessage = Message.user(content)

        // Prepare state and capture messages under lock
        let currentMessages: [Message] = withLock {
            lastError = nil
            isGenerating = true
            cancellationRequested = false
            messages.append(userMessage)
            return messages
        }

        // Capture model and config for the async operation
        let currentModel = model
        let currentConfig = config

        return AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                var fullText = ""
                var streamError: Error?

                do {
                    // Get the stream from provider using streamWithMetadata
                    // which accepts messages array
                    let providerStream = self.provider.streamWithMetadata(
                        messages: currentMessages,
                        model: currentModel,
                        config: currentConfig
                    )

                    // Iterate and yield tokens
                    for try await chunk in providerStream {
                        // Check for cancellation
                        try Task.checkCancellation()

                        // Yield the token (text is non-optional in GenerationChunk)
                        let tokenText = chunk.text
                        continuation.yield(tokenText)
                        fullText += tokenText
                    }

                } catch is CancellationError {
                    streamError = AIError.cancelled

                } catch {
                    streamError = error
                }

                // Finalize state under lock
                self.withLock {
                    if let error = streamError {
                        // Remove user message on error
                        if let index = self.messages.lastIndex(where: { $0.id == userMessage.id }) {
                            self.messages.remove(at: index)
                        }
                        self.lastError = error
                    } else {
                        // Add assistant message on success
                        let assistantMessage = Message(
                            role: .assistant,
                            content: .text(fullText),
                            metadata: MessageMetadata(model: currentModel.rawValue)
                        )
                        self.messages.append(assistantMessage)
                    }
                    self.isGenerating = false
                }

                // Finish the stream
                if let error = streamError {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }

            // Store task reference for cancellation (safely, before continuation callbacks run)
            self.withLock {
                self.generationTask = task
            }

            // Handle stream cancellation
            continuation.onTermination = { @Sendable [weak self] termination in
                if case .cancelled = termination {
                    task.cancel()
                }
                guard let strongSelf = self else { return }
                strongSelf.withLock {
                    strongSelf.generationTask = nil
                }
            }
        }
    }

    // MARK: - History Management

    /// Clears all messages except the system prompt.
    ///
    /// If a system message exists at the beginning of the history,
    /// it is preserved. All other messages are removed.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// session.clearHistory()
    /// // System prompt is preserved, conversation is reset
    /// ```
    public func clearHistory() {
        withLock {
            if let systemMessage = messages.first, systemMessage.role == .system {
                messages = [systemMessage]
            } else {
                messages = []
            }
        }
    }

    /// Removes the last user-assistant exchange from history.
    ///
    /// This removes the most recent pair of user and assistant messages,
    /// allowing you to "undo" the last conversation turn.
    ///
    /// If the last message is a user message without a response, only
    /// that user message is removed.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // After an unsatisfactory response
    /// session.undoLastExchange()
    /// // Try again with different phrasing
    /// let response = try await session.send("Let me rephrase...")
    /// ```
    public func undoLastExchange() {
        withLock {
            guard !messages.isEmpty else { return }

            // Remove assistant message if it's the last one
            if messages.last?.role == .assistant {
                messages.removeLast()
            }

            // Remove user message if it's now the last one
            if messages.last?.role == .user {
                messages.removeLast()
            }
        }
    }

    /// Injects a conversation history, preserving the current system prompt.
    ///
    /// If the current session has a system prompt, it is preserved and
    /// the injected history (minus any system messages) is appended.
    ///
    /// If the current session has no system prompt but the injected
    /// history has one, that system prompt is used.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Load saved conversation
    /// let savedMessages = loadMessagesFromDisk()
    /// session.injectHistory(savedMessages)
    /// ```
    ///
    /// - Parameter history: The messages to inject.
    public func injectHistory(_ history: [Message]) {
        withLock {
            // Check for existing system prompt
            let existingSystemPrompt: Message? = messages.first?.role == .system
                ? messages.first
                : nil

            // Filter out system messages from injected history
            let nonSystemMessages = history.filter { $0.role != .system }

            // Check for system prompt in injected history
            let injectedSystemPrompt = history.first { $0.role == .system }

            // Build new message list
            if let existingPrompt = existingSystemPrompt {
                // Keep existing system prompt
                messages = [existingPrompt] + nonSystemMessages
            } else if let injectedPrompt = injectedSystemPrompt {
                // Use injected system prompt
                messages = [injectedPrompt] + nonSystemMessages
            } else {
                // No system prompt
                messages = nonSystemMessages
            }
        }
    }

    // MARK: - Cancellation

    /// Cancels any in-progress generation.
    ///
    /// This method:
    /// 1. Cancels the current generation task
    /// 2. Calls the provider's `cancelGeneration()` method
    ///
    /// After cancellation, `isGenerating` will be set to `false` and
    /// `lastError` will contain an `AIError.cancelled`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Start streaming in the background
    /// Task {
    ///     for try await token in session.stream("Long request...") {
    ///         print(token, terminator: "")
    ///     }
    /// }
    ///
    /// // Cancel from another context
    /// await session.cancel()
    /// ```
    public func cancel() async {
        // Get and clear task under lock
        let task: Task<Void, Never>? = withLock {
            let currentTask = generationTask
            generationTask = nil
            cancellationRequested = true
            return currentTask
        }

        // Cancel the task
        task?.cancel()

        // Cancel at the provider level
        await provider.cancelGeneration()

        // Update state
        withLock {
            if isGenerating {
                isGenerating = false
                lastError = AIError.cancelled
            }
        }
    }

    // MARK: - Computed Properties

    /// The total number of messages in the conversation.
    ///
    /// Includes system, user, and assistant messages.
    public var messageCount: Int {
        withLock { messages.count }
    }

    /// The number of user messages in the conversation.
    ///
    /// Useful for tracking the number of conversation turns.
    public var userMessageCount: Int {
        withLock {
            messages.filter { $0.role == .user }.count
        }
    }

    /// Whether the session has an active system prompt.
    public var hasSystemPrompt: Bool {
        withLock {
            messages.first?.role == .system
        }
    }

    /// The current system prompt, if any.
    public var systemPrompt: String? {
        withLock {
            guard let first = messages.first, first.role == .system else {
                return nil
            }
            return first.content.textValue
        }
    }
}
