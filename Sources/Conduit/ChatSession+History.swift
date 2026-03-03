// ChatSession+History.swift
// Conduit

import Foundation

// MARK: - History Management

extension ChatSession {

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
