// MessageBuilder.swift
// SwiftAI

import Foundation

// MARK: - MessageBuilder

/// A result builder for declaratively constructing message arrays.
///
/// `MessageBuilder` enables a DSL-style syntax for creating conversation messages,
/// with support for conditionals, loops, and composing multiple message sources.
///
/// ## Overview
///
/// Result builders transform declarative code into arrays of `Message` objects,
/// making it easy to construct complex conversations with clean, readable syntax.
///
/// ## Usage
///
/// ### Simple Message List
/// ```swift
/// let messages = Messages {
///     Message.system("You are a helpful coding assistant.")
///     Message.user("What is Swift?")
/// }
/// ```
///
/// ### Conditional Messages
/// ```swift
/// let messages = Messages {
///     Message.system("You are helpful.")
///
///     if includeContext {
///         Message.user("Context: \(context)")
///     }
///
///     Message.user(userQuery)
/// }
/// ```
///
/// ### If-Else Branching
/// ```swift
/// let messages = Messages {
///     Message.system("You are helpful.")
///
///     if isExpert {
///         Message.system("Provide detailed technical explanations.")
///     } else {
///         Message.system("Keep explanations simple and beginner-friendly.")
///     }
///
///     Message.user(query)
/// }
/// ```
///
/// ### Looping Over Data
/// ```swift
/// let examples = [
///     (question: "What is 2+2?", answer: "4"),
///     (question: "What is 3+3?", answer: "6")
/// ]
///
/// let messages = Messages {
///     Message.system("You are a math tutor.")
///
///     for example in examples {
///         Message.user("Q: \(example.question)")
///         Message.assistant("A: \(example.answer)")
///     }
///
///     Message.user("Q: What is 5+5?")
/// }
/// ```
///
/// ### Combining Arrays
/// ```swift
/// let historyMessages: [Message] = loadChatHistory()
///
/// let messages = Messages {
///     Message.system("You are a helpful assistant.")
///     historyMessages  // Include entire array
///     Message.user("New question")
/// }
/// ```
///
/// ## Thread Safety
///
/// `MessageBuilder` is `Sendable` and can be safely used across concurrency boundaries.
/// All resulting message arrays are also `Sendable`.
@resultBuilder
public struct MessageBuilder: Sendable {

    // MARK: - Expression Builders

    /// Transforms a single message into an array.
    ///
    /// This enables writing individual `Message` values directly in the builder.
    ///
    /// ```swift
    /// Messages {
    ///     Message.user("Hello")  // Single message becomes [Message]
    /// }
    /// ```
    ///
    /// - Parameter expression: A single message.
    /// - Returns: An array containing the message.
    public static func buildExpression(_ expression: Message) -> [Message] {
        [expression]
    }

    /// Passes through an array of messages unchanged.
    ///
    /// This enables including existing message arrays directly in the builder.
    ///
    /// ```swift
    /// let history: [Message] = [...]
    /// Messages {
    ///     history  // Array passed through unchanged
    /// }
    /// ```
    ///
    /// - Parameter expression: An array of messages.
    /// - Returns: The same array unchanged.
    public static func buildExpression(_ expression: [Message]) -> [Message] {
        expression
    }

    // MARK: - Block Builders

    /// Combines multiple message arrays from a block into a single array.
    ///
    /// This is called for each block of statements in the builder.
    ///
    /// ```swift
    /// Messages {
    ///     Message.system("System")    // -> [Message]
    ///     Message.user("User")        // -> [Message]
    /// }
    /// // Results in [systemMessage, userMessage]
    /// ```
    ///
    /// - Parameter components: Variadic message arrays from each statement.
    /// - Returns: A flattened array of all messages in order.
    public static func buildBlock(_ components: [Message]...) -> [Message] {
        components.flatMap { $0 }
    }

    // MARK: - Control Flow

    /// Handles optional content when a condition is false.
    ///
    /// This enables `if` statements without an `else` branch.
    ///
    /// ```swift
    /// Messages {
    ///     if includeContext {
    ///         Message.user(context)  // Included if true
    ///     }
    ///     // If false, nothing is added
    /// }
    /// ```
    ///
    /// - Parameter component: An optional array, nil if condition was false.
    /// - Returns: The array if present, or an empty array.
    public static func buildOptional(_ component: [Message]?) -> [Message] {
        component ?? []
    }

    /// Handles the first branch of an if-else statement.
    ///
    /// Called when the `if` condition is true.
    ///
    /// ```swift
    /// Messages {
    ///     if isExpert {
    ///         Message.system("Be technical")  // This branch when true
    ///     } else {
    ///         Message.system("Be simple")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter component: Messages from the `if` branch.
    /// - Returns: The messages unchanged.
    public static func buildEither(first component: [Message]) -> [Message] {
        component
    }

    /// Handles the second branch of an if-else statement.
    ///
    /// Called when the `if` condition is false.
    ///
    /// ```swift
    /// Messages {
    ///     if isExpert {
    ///         Message.system("Be technical")
    ///     } else {
    ///         Message.system("Be simple")  // This branch when false
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter component: Messages from the `else` branch.
    /// - Returns: The messages unchanged.
    public static func buildEither(second component: [Message]) -> [Message] {
        component
    }

    /// Handles for-in loops by flattening iteration results.
    ///
    /// This enables iterating over collections to generate messages.
    ///
    /// ```swift
    /// let examples = [("Q1", "A1"), ("Q2", "A2")]
    /// Messages {
    ///     for (q, a) in examples {
    ///         Message.user(q)
    ///         Message.assistant(a)
    ///     }
    /// }
    /// // Results in 4 messages: user, assistant, user, assistant
    /// ```
    ///
    /// - Parameter components: An array of message arrays from each iteration.
    /// - Returns: A flattened array of all messages.
    public static func buildArray(_ components: [[Message]]) -> [Message] {
        components.flatMap { $0 }
    }

    /// Handles availability-limited code blocks.
    ///
    /// This enables using `#available` checks within the builder.
    ///
    /// ```swift
    /// Messages {
    ///     if #available(iOS 18, *) {
    ///         Message.system("Use new features")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter component: Messages from the availability-checked block.
    /// - Returns: The messages unchanged.
    public static func buildLimitedAvailability(_ component: [Message]) -> [Message] {
        component
    }

    /// Produces a final result from the builder.
    ///
    /// This is the final transformation applied to the built content.
    ///
    /// - Parameter component: The accumulated messages.
    /// - Returns: The final message array.
    public static func buildFinalResult(_ component: [Message]) -> [Message] {
        component
    }
}

// MARK: - Convenience Function

/// Creates a message array using the `MessageBuilder` DSL.
///
/// This function provides a clean entry point for building message arrays
/// with the declarative `MessageBuilder` syntax.
///
/// ## Usage
///
/// ```swift
/// let messages = Messages {
///     Message.system("You are a helpful assistant.")
///     Message.user("Hello!")
///
///     if includeContext {
///         Message.user("Context: \(context)")
///     }
///
///     for example in examples {
///         Message.user("Q: \(example.question)")
///         Message.assistant("A: \(example.answer)")
///     }
/// }
///
/// let response = try await provider.generate(
///     messages: messages,
///     model: .llama3_2_1b,
///     config: .default
/// )
/// ```
///
/// - Parameter builder: A closure using `MessageBuilder` syntax.
/// - Returns: An array of `Message` objects.
@inlinable
public func Messages(@MessageBuilder _ builder: () -> [Message]) -> [Message] {
    builder()
}

// MARK: - Async Variant

/// Creates a message array using async `MessageBuilder` DSL.
///
/// This variant supports asynchronous operations within the builder,
/// useful when message content needs to be fetched or computed asynchronously.
///
/// ## Usage
///
/// ```swift
/// let messages = await MessagesAsync {
///     Message.system("You are helpful.")
///
///     let context = await fetchContext()
///     Message.user("Context: \(context)")
///
///     Message.user(userQuery)
/// }
/// ```
///
/// - Parameter builder: An async closure using `MessageBuilder` syntax.
/// - Returns: An array of `Message` objects.
@inlinable
public func MessagesAsync(@MessageBuilder _ builder: () async -> [Message]) async -> [Message] {
    await builder()
}

// MARK: - Array Extension

extension Array where Element == Message {

    /// Creates a message array using the `MessageBuilder` DSL.
    ///
    /// Alternative syntax for building messages directly on the Array type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let messages: [Message] = .build {
    ///     Message.system("You are helpful.")
    ///     Message.user("Hello!")
    /// }
    /// ```
    ///
    /// - Parameter builder: A closure using `MessageBuilder` syntax.
    /// - Returns: An array of `Message` objects.
    @inlinable
    public static func build(@MessageBuilder _ builder: () -> [Message]) -> [Message] {
        builder()
    }
}
