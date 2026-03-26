import Foundation

// MARK: - MessagesBuilder

/// A result builder for declaratively constructing message arrays with SwiftUI-style syntax.
///
/// `MessagesBuilder` enables a DSL-style syntax for creating conversation messages,
/// with support for role-based helpers, multimodal content, conditionals, and loops.
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
///     System("You are a helpful coding assistant.")
///     User("What is Swift?")
/// }
/// ```
///
/// ### Multimodal Content
/// ```swift
/// let messages = Messages {
///     System("You are a helpful assistant.")
///     User {
///         Text("What's in this image?")
///         Image(data: imageBase64, mimeType: "image/jpeg")
///     }
/// }
/// ```
///
/// ### Conditional Messages
/// ```swift
/// let messages = Messages {
///     System("You are helpful.")
///
///     if includeContext {
///         User("Context: \(context)")
///     }
///
///     User(userQuery)
/// }
/// ```
///
/// ### If-Else Branching
/// ```swift
/// let messages = Messages {
///     System("You are helpful.")
///
///     if isExpert {
///         System("Provide detailed technical explanations.")
///     } else {
///         System("Keep explanations simple.")
///     }
///
///     User(query)
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
///     System("You are a math tutor.")
///
///     for example in examples {
///         User("Q: \(example.question)")
///         Assistant("A: \(example.answer)")
///     }
///
///     User("Q: What is 5+5?")
/// }
/// ```
@resultBuilder
public struct MessagesBuilder: Sendable {

    // MARK: - Expression Builders

    /// Transforms a single message into an array.
    public static func buildExpression(_ expression: Message) -> [Message] {
        [expression]
    }

    /// Transforms a message role helper into an array.
    public static func buildExpression(_ expression: some MessageConvertible) -> [Message] {
        [expression.asMessage()]
    }

    /// Passes through an array of messages unchanged.
    public static func buildExpression(_ expression: [Message]) -> [Message] {
        expression
    }

    /// Transforms an array of message convertibles into an array of messages.
    public static func buildExpression(_ expression: [some MessageConvertible]) -> [Message] {
        expression.map { $0.asMessage() }
    }

    // MARK: - Block Builders

    /// Combines multiple message arrays from a block into a single array.
    public static func buildBlock(_ components: [Message]...) -> [Message] {
        components.flatMap { $0 }
    }

    // MARK: - Control Flow

    /// Handles optional content when a condition is false.
    public static func buildOptional(_ component: [Message]?) -> [Message] {
        component ?? []
    }

    /// Handles the first branch of an if-else statement.
    public static func buildEither(first component: [Message]) -> [Message] {
        component
    }

    /// Handles the second branch of an if-else statement.
    public static func buildEither(second component: [Message]) -> [Message] {
        component
    }

    /// Handles for-in loops by flattening iteration results.
    public static func buildArray(_ components: [[Message]]) -> [Message] {
        components.flatMap { $0 }
    }

    /// Handles availability-limited code blocks.
    public static func buildLimitedAvailability(_ component: [Message]) -> [Message] {
        component
    }

    /// Produces a final result from the builder.
    public static func buildFinalResult(_ component: [Message]) -> [Message] {
        component
    }
}

// MARK: - MessageConvertible Protocol

/// A type that can be converted to a `Message`.
///
/// Conforming types provide a convenient way to create messages using
/// SwiftUI-style syntax within result builders.
public protocol MessageConvertible: Sendable {
    /// Returns the message representation of this value.
    func asMessage() -> Message
}

// MARK: - Message Role Helpers

/// A system message that sets context and behavior for the assistant.
///
/// ## Usage
/// ```swift
/// let messages = Messages {
///     System("You are a helpful coding assistant.")
///     User("Write a function to sort an array.")
/// }
/// ```
public struct System: MessageConvertible {
    private let content: String

    /// Creates a system message with the specified content.
    ///
    /// - Parameter content: The system instructions.
    public init(_ content: String) {
        self.content = content
    }

    public func asMessage() -> Message {
        Message(role: .system, content: .text(content))
    }
}

/// A user message representing human input to the conversation.
///
/// ## Usage
/// ### Simple Text
/// ```swift
/// let messages = Messages {
///     User("What is Swift?")
/// }
/// ```
///
/// ### Multimodal Content
/// ```swift
/// let messages = Messages {
///     User {
///         Text("Describe this image:")
///         Image(data: imageBase64, mimeType: "image/jpeg")
///     }
/// }
/// ```
public struct User: MessageConvertible {
    private let content: Message.Content

    /// Creates a user message with text content.
    ///
    /// - Parameter text: The user's message text.
    public init(_ text: String) {
        self.content = .text(text)
    }

    /// Creates a user message with multimodal content parts.
    ///
    /// - Parameter parts: A closure that builds content parts using `ContentBuilder`.
    public init(@ContentBuilder _ parts: () -> [Message.ContentPart]) {
        let partsArray = parts()
        if partsArray.count == 1, case .text(let text) = partsArray[0] {
            self.content = .text(text)
        } else {
            self.content = .parts(partsArray)
        }
    }

    public func asMessage() -> Message {
        Message(role: .user, content: content)
    }
}

/// An assistant message representing AI-generated responses.
///
/// ## Usage
/// ```swift
/// let messages = Messages {
///     User("What is Swift?")
///     Assistant("Swift is a powerful programming language...")
/// }
/// ```
public struct Assistant: MessageConvertible {
    private let content: String

    /// Creates an assistant message with the specified content.
    ///
    /// - Parameter content: The assistant's response text.
    public init(_ content: String) {
        self.content = content
    }

    public func asMessage() -> Message {
        Message(role: .assistant, content: .text(content))
    }
}

// MARK: - Content Part Helpers

/// Text content for multimodal messages.
///
/// ## Usage
/// ```swift
/// let messages = Messages {
///     User {
///         Text("What's in this image?")
///         Image(data: imageData, mimeType: "image/jpeg")
///     }
/// }
/// ```
public struct Text: Sendable {
    let content: String

    /// Creates text content with the specified string.
    ///
    /// - Parameter content: The text content.
    public init(_ content: String) {
        self.content = content
    }

    /// Converts this text to a message content part.
    public func asContentPart() -> Message.ContentPart {
        .text(content)
    }
}

/// Image content for multimodal messages.
///
/// ## Usage
/// ```swift
/// let messages = Messages {
///     User {
///         Text("Describe this image:")
///         Image(data: base64Data, mimeType: "image/jpeg")
///     }
/// }
/// ```
public struct Image: Sendable {
    let base64Data: String
    let mimeType: String

    /// Creates image content from Base64-encoded data.
    ///
    /// - Parameters:
    ///   - data: The Base64-encoded image string.
    ///   - mimeType: The MIME type (defaults to "image/jpeg").
    public init(data: String, mimeType: String = "image/jpeg") {
        self.base64Data = data
        self.mimeType = mimeType
    }

    /// Converts this image to a message content part.
    public func asContentPart() -> Message.ContentPart {
        .image(Message.ImageContent(base64Data: base64Data, mimeType: mimeType))
    }
}

/// Audio content for multimodal messages.
///
/// ## Usage
/// ```swift
/// let messages = Messages {
///     User {
///         Text("What is being said in this audio?")
///         Audio(data: audioBase64, format: .wav)
///     }
/// }
/// ```
public struct Audio: Sendable {
    let base64Data: String
    let format: Message.AudioFormat

    /// Creates audio content from Base64-encoded data.
    ///
    /// - Parameters:
    ///   - data: The Base64-encoded audio string.
    ///   - format: The audio format.
    public init(data: String, format: Message.AudioFormat) {
        self.base64Data = data
        self.format = format
    }

    /// Converts this audio to a message content part.
    public func asContentPart() -> Message.ContentPart {
        .audio(Message.AudioContent(base64Data: base64Data, format: format))
    }
}

// MARK: - ContentBuilder

/// A result builder for constructing multimodal content parts.
@resultBuilder
public struct ContentBuilder: Sendable {

    /// Transforms text content into a content part.
    public static func buildExpression(_ expression: Text) -> [Message.ContentPart] {
        [expression.asContentPart()]
    }

    /// Transforms image content into a content part.
    public static func buildExpression(_ expression: Image) -> [Message.ContentPart] {
        [expression.asContentPart()]
    }

    /// Transforms audio content into a content part.
    public static func buildExpression(_ expression: Audio) -> [Message.ContentPart] {
        [expression.asContentPart()]
    }

    /// Transforms a string literal into a text content part.
    public static func buildExpression(_ expression: String) -> [Message.ContentPart] {
        [.text(expression)]
    }

    /// Combines multiple content part arrays into a single array.
    public static func buildBlock(_ components: [Message.ContentPart]...) -> [Message.ContentPart] {
        components.flatMap { $0 }
    }

    /// Handles optional content.
    public static func buildOptional(_ component: [Message.ContentPart]?) -> [Message.ContentPart] {
        component ?? []
    }

    /// Handles the first branch of an if-else statement.
    public static func buildEither(first component: [Message.ContentPart]) -> [Message.ContentPart] {
        component
    }

    /// Handles the second branch of an if-else statement.
    public static func buildEither(second component: [Message.ContentPart]) -> [Message.ContentPart] {
        component
    }

    /// Handles for-in loops.
    public static func buildArray(_ components: [[Message.ContentPart]]) -> [Message.ContentPart] {
        components.flatMap { $0 }
    }

    /// Handles availability-limited code blocks.
    public static func buildLimitedAvailability(_ component: [Message.ContentPart]) -> [Message.ContentPart] {
        component
    }

    /// Produces a final result from the builder.
    public static func buildFinalResult(_ component: [Message.ContentPart]) -> [Message.ContentPart] {
        component
    }
}

// MARK: - ConfigBuilder

/// A result builder for declaratively constructing `GenerateConfig`.
///
/// `ConfigBuilder` enables a DSL-style syntax for configuring text generation,
/// with support for sampling parameters, tools, response format, and reasoning.
///
/// ## Overview
///
/// Result builders transform declarative code into a `GenerateConfig` object,
/// making it easy to configure generation with clean, readable syntax.
///
/// ## Usage
///
/// ### Basic Configuration
/// ```swift
/// let config = Generate {
///     Sampling(temperature: 0.7, topP: 0.9)
///     MaxTokens(1024)
/// }
/// ```
///
/// ### With Tools
/// ```swift
/// let config = Generate {
///     Sampling(temperature: 0.7)
///     Tools(WeatherTool(), SearchTool())
///     ToolChoice(.auto)
/// }
/// ```
///
/// ### With Reasoning
/// ```swift
/// let config = Generate {
///     Sampling(temperature: 0.5)
///     Reasoning(effort: .high)
/// }
/// ```
///
/// ### Conditional Configuration
/// ```swift
/// let config = Generate {
///     Sampling(temperature: creative ? 0.9 : 0.5)
///
///     if includeTools {
///         Tools(WeatherTool())
///     }
///
///     if let format = responseFormat {
///         ResponseFormat(format)
///     }
/// }
/// ```
@resultBuilder
public struct ConfigBuilder: Sendable {

    // MARK: - Expression Builders

    /// Transforms a config modifier into the accumulated config.
    public static func buildExpression(_ expression: some ConfigModifier) -> GenerateConfig {
        expression.apply(to: .default)
    }

    /// Transforms an optional config modifier.
    public static func buildExpression(_ expression: (some ConfigModifier)?) -> GenerateConfig {
        expression?.apply(to: .default) ?? .default
    }

    // MARK: - Block Builders

    /// Combines multiple config modifiers into a single config.
    public static func buildBlock(_ components: GenerateConfig...) -> GenerateConfig {
        components.reduce(GenerateConfig.default) { current, next in
            // Merge next into current, with next taking precedence for overlapping values
            mergeConfigs(base: current, override: next)
        }
    }

    // MARK: - Control Flow

    /// Handles optional config.
    public static func buildOptional(_ component: GenerateConfig?) -> GenerateConfig {
        component ?? .default
    }

    /// Handles the first branch of an if-else statement.
    public static func buildEither(first component: GenerateConfig) -> GenerateConfig {
        component
    }

    /// Handles the second branch of an if-else statement.
    public static func buildEither(second component: GenerateConfig) -> GenerateConfig {
        component
    }

    /// Handles for-in loops by merging all configs.
    public static func buildArray(_ components: [GenerateConfig]) -> GenerateConfig {
        components.reduce(GenerateConfig.default) { current, next in
            mergeConfigs(base: current, override: next)
        }
    }

    /// Handles availability-limited code blocks.
    public static func buildLimitedAvailability(_ component: GenerateConfig) -> GenerateConfig {
        component
    }

    /// Produces a final result from the builder.
    public static func buildFinalResult(_ component: GenerateConfig) -> GenerateConfig {
        component
    }

    // MARK: - Private Helpers

    private static func mergeConfigs(base: GenerateConfig, override: GenerateConfig) -> GenerateConfig {
        // Create a copy of base and apply non-default values from override
        var result = base

        // Only override if the override value differs from default
        if override.maxTokens != GenerateConfig.default.maxTokens {
            result.maxTokens = override.maxTokens
        }
        if override.minTokens != GenerateConfig.default.minTokens {
            result.minTokens = override.minTokens
        }
        if override.temperature != GenerateConfig.default.temperature {
            result.temperature = override.temperature
        }
        if override.topP != GenerateConfig.default.topP {
            result.topP = override.topP
        }
        if override.topK != GenerateConfig.default.topK {
            result.topK = override.topK
        }
        if override.repetitionPenalty != GenerateConfig.default.repetitionPenalty {
            result.repetitionPenalty = override.repetitionPenalty
        }
        if override.frequencyPenalty != GenerateConfig.default.frequencyPenalty {
            result.frequencyPenalty = override.frequencyPenalty
        }
        if override.presencePenalty != GenerateConfig.default.presencePenalty {
            result.presencePenalty = override.presencePenalty
        }
        if !override.stopSequences.isEmpty {
            result.stopSequences = override.stopSequences
        }
        if override.seed != GenerateConfig.default.seed {
            result.seed = override.seed
        }
        if override.returnLogprobs != GenerateConfig.default.returnLogprobs {
            result.returnLogprobs = override.returnLogprobs
        }
        if override.topLogprobs != GenerateConfig.default.topLogprobs {
            result.topLogprobs = override.topLogprobs
        }
        if override.userId != nil {
            result.userId = override.userId
        }
        if override.serviceTier != nil {
            result.serviceTier = override.serviceTier
        }
        if !override.tools.isEmpty {
            result.tools = override.tools
        }
        if override.toolChoice != GenerateConfig.default.toolChoice {
            result.toolChoice = override.toolChoice
        }
        if override.parallelToolCalls != GenerateConfig.default.parallelToolCalls {
            result.parallelToolCalls = override.parallelToolCalls
        }
        if override.maxToolCalls != nil {
            result.maxToolCalls = override.maxToolCalls
        }
        if override.responseFormat != nil {
            result.responseFormat = override.responseFormat
        }
        if override.reasoning != nil {
            result.reasoning = override.reasoning
        }

        return result
    }
}

// MARK: - ConfigModifier Protocol

/// A type that can modify a `GenerateConfig`.
///
/// Conforming types provide a convenient way to configure generation
/// using SwiftUI-style syntax within result builders.
public protocol ConfigModifier: Sendable {
    /// Applies this modifier to the given config and returns the modified config.
    ///
    /// - Parameter config: The base configuration to modify.
    /// - Returns: A new configuration with modifications applied.
    func apply(to config: GenerateConfig) -> GenerateConfig
}

// MARK: - Config Section Helpers

/// Specifies sampling parameters for generation.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     Sampling(temperature: 0.7, topP: 0.9)
/// }
/// ```
public struct Sampling: ConfigModifier {
    private let temperature: Float?
    private let topP: Float?
    private let topK: Int?

    /// Creates sampling parameters with the specified values.
    ///
    /// - Parameters:
    ///   - temperature: Controls randomness (0.0-2.0).
    ///   - topP: Nucleus sampling threshold (0.0-1.0).
    ///   - topK: Number of top tokens to consider.
    public init(
        temperature: Float? = nil,
        topP: Float? = nil,
        topK: Int? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        var result = config
        if let temperature = temperature {
            result.temperature = max(0, min(2, temperature))
        }
        if let topP = topP {
            result.topP = max(0, min(1, topP))
        }
        if let topK = topK {
            result.topK = topK
        }
        return result
    }
}

/// Specifies penalties to discourage repetition.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     Sampling(temperature: 0.7)
///     Penalties(frequency: 0.5, presence: 0.3)
/// }
/// ```
public struct Penalties: ConfigModifier {
    private let frequency: Float?
    private let presence: Float?
    private let repetition: Float?

    /// Creates penalty parameters with the specified values.
    ///
    /// - Parameters:
    ///   - frequency: Penalty based on token frequency (-2.0 to 2.0).
    ///   - presence: Penalty based on token presence (-2.0 to 2.0).
    ///   - repetition: Repetition penalty multiplier (0.0 to 2.0).
    public init(
        frequency: Float? = nil,
        presence: Float? = nil,
        repetition: Float? = nil
    ) {
        self.frequency = frequency
        self.presence = presence
        self.repetition = repetition
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        var result = config
        if let frequency = frequency {
            result.frequencyPenalty = frequency
        }
        if let presence = presence {
            result.presencePenalty = presence
        }
        if let repetition = repetition {
            result.repetitionPenalty = repetition
        }
        return result
    }
}

/// Specifies token limits for generation.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     MaxTokens(1024)
///     MinTokens(50)
/// }
/// ```
public struct MaxTokens: ConfigModifier {
    private let value: Int

    /// Creates a max tokens modifier.
    ///
    /// - Parameter value: Maximum tokens to generate.
    public init(_ value: Int) {
        self.value = value
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.maxTokens(value)
    }
}

/// Specifies minimum token count for generation.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     MinTokens(50)
/// }
/// ```
public struct MinTokens: ConfigModifier {
    private let value: Int

    /// Creates a min tokens modifier.
    ///
    /// - Parameter value: Minimum tokens to generate.
    public init(_ value: Int) {
        self.value = value
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.minTokens(value)
    }
}

/// Specifies stop sequences for generation.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     StopSequences("END", "STOP", "\n\n")
/// }
/// ```
public struct StopSequences: ConfigModifier {
    private let sequences: [String]

    /// Creates a stop sequences modifier.
    ///
    /// - Parameter sequences: Sequences that will stop generation.
    public init(_ sequences: String...) {
        self.sequences = sequences
    }

    /// Creates a stop sequences modifier from an array.
    ///
    /// - Parameter sequences: Sequences that will stop generation.
    public init(_ sequences: [String]) {
        self.sequences = sequences
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.stopSequences(sequences)
    }
}

/// Specifies a random seed for reproducible generation.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     Seed(42)
/// }
/// ```
public struct Seed: ConfigModifier {
    private let value: UInt64

    /// Creates a seed modifier.
    ///
    /// - Parameter value: Random seed for reproducibility.
    public init(_ value: UInt64) {
        self.value = value
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.seed(value)
    }
}

/// Specifies tools available for the model to use.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     Tools(WeatherTool(), SearchTool())
/// }
/// ```
public struct Tools: ConfigModifier {
    private let tools: [any Tool]

    /// Creates a tools modifier.
    ///
    /// - Parameter tools: Tool instances to make available.
    public init(_ tools: any Tool...) {
        self.tools = tools
    }

    /// Creates a tools modifier from an array.
    ///
    /// - Parameter tools: Tool instances to make available.
    public init(_ tools: [any Tool]) {
        self.tools = tools
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.tools(tools)
    }
}

/// Specifies tool definitions available for the model to use.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     ToolDefinitions(toolDef1, toolDef2)
/// }
/// ```
public struct ToolDefinitions: ConfigModifier {
    private let definitions: [Transcript.ToolDefinition]

    /// Creates a tool definitions modifier.
    ///
    /// - Parameter definitions: Tool definitions to make available.
    public init(_ definitions: Transcript.ToolDefinition...) {
        self.definitions = definitions
    }

    /// Creates a tool definitions modifier from an array.
    ///
    /// - Parameter definitions: Tool definitions to make available.
    public init(_ definitions: [Transcript.ToolDefinition]) {
        self.definitions = definitions
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.tools(definitions)
    }
}

/// Specifies how the model should choose tools.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     Tools(WeatherTool())
///     ConfigToolChoice(.required)
/// }
/// ```
public struct ConfigToolChoice: ConfigModifier {
    private let choice: ToolChoice

    /// Creates a tool choice modifier.
    ///
    /// - Parameter choice: How the model should choose tools.
    public init(_ choice: ToolChoice) {
        self.choice = choice
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.toolChoice(choice)
    }
}

/// Specifies the response format for structured output.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     ConfigResponseFormat(.jsonObject)
/// }
/// ```
public struct ConfigResponseFormat: ConfigModifier {
    private let format: ResponseFormat

    /// Creates a response format modifier.
    ///
    /// - Parameter format: The response format to use.
    public init(_ format: ResponseFormat) {
        self.format = format
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.responseFormat(format)
    }
}

/// Specifies reasoning configuration for extended thinking.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     Reasoning(effort: .high)
/// }
///
/// let config = Generate {
///     Reasoning(maxTokens: 2000)
/// }
/// ```
public struct Reasoning: ConfigModifier {
    private let effort: ReasoningEffort?
    private let maxTokens: Int?
    private let exclude: Bool?

    /// Creates a reasoning configuration with effort level.
    ///
    /// - Parameters:
    ///   - effort: The reasoning effort level.
    ///   - exclude: Whether to exclude reasoning from response.
    public init(effort: ReasoningEffort, exclude: Bool? = nil) {
        self.effort = effort
        self.maxTokens = nil
        self.exclude = exclude
    }

    /// Creates a reasoning configuration with token budget.
    ///
    /// - Parameters:
    ///   - maxTokens: Maximum tokens for reasoning.
    ///   - exclude: Whether to exclude reasoning from response.
    public init(maxTokens: Int, exclude: Bool? = nil) {
        self.effort = nil
        self.maxTokens = maxTokens
        self.exclude = exclude
    }

    /// Creates a reasoning configuration with both effort and token budget.
    ///
    /// - Parameters:
    ///   - effort: The reasoning effort level.
    ///   - maxTokens: Maximum tokens for reasoning.
    ///   - exclude: Whether to exclude reasoning from response.
    public init(
        effort: ReasoningEffort? = nil,
        maxTokens: Int? = nil,
        exclude: Bool? = nil
    ) {
        self.effort = effort
        self.maxTokens = maxTokens
        self.exclude = exclude
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        let reasoningConfig = ReasoningConfig(
            effort: effort,
            maxTokens: maxTokens,
            exclude: exclude
        )
        return config.reasoning(reasoningConfig)
    }
}

/// Specifies user ID for per-user tracking.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     UserId("user_12345")
/// }
/// ```
public struct UserId: ConfigModifier {
    private let id: String

    /// Creates a user ID modifier.
    ///
    /// - Parameter id: User ID for tracking.
    public init(_ id: String) {
        self.id = id
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.userId(id)
    }
}

/// Specifies service tier for capacity management.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     ConfigServiceTier(.auto)
/// }
/// ```
public struct ConfigServiceTier: ConfigModifier {
    private let tier: ServiceTier

    /// Creates a service tier modifier.
    ///
    /// - Parameter tier: Service tier for capacity management.
    public init(_ tier: ServiceTier) {
        self.tier = tier
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.serviceTier(tier)
    }
}

/// Enables log probability output.
///
/// ## Usage
/// ```swift
/// let config = Generate {
///     Logprobs(top: 5)
/// }
/// ```
public struct Logprobs: ConfigModifier {
    private let top: Int

    /// Creates a logprobs modifier.
    ///
    /// - Parameter top: Number of top log probabilities per token (default: 5).
    public init(top: Int = 5) {
        self.top = top
    }

    public func apply(to config: GenerateConfig) -> GenerateConfig {
        config.withLogprobs(top: top)
    }
}

// MARK: - Convenience Functions

/// Creates a message array using the `MessagesBuilder` DSL.
///
/// ## Usage
///
/// ```swift
/// let messages = Messages {
///     System("You are a helpful assistant.")
///     User("Hello!")
///
///     if includeContext {
///         User("Context: \(context)")
///     }
///
///     for example in examples {
///         User("Q: \(example.question)")
///         Assistant("A: \(example.answer)")
///     }
/// }
/// ```
///
/// - Parameter builder: A closure using `MessagesBuilder` syntax.
/// - Returns: An array of `Message` objects.
@inlinable
public func Messages(@MessagesBuilder _ builder: () -> [Message]) -> [Message] {
    builder()
}

/// Creates a `GenerateConfig` using the `ConfigBuilder` DSL.
///
/// ## Usage
///
/// ```swift
/// let config = Generate {
///     Sampling(temperature: 0.7, topP: 0.9)
///     MaxTokens(1024)
///
///     if includeTools {
///         Tools(WeatherTool())
///     }
/// }
/// ```
///
/// - Parameter builder: A closure using `ConfigBuilder` syntax.
/// - Returns: A `GenerateConfig` object.
@inlinable
public func Generate(@ConfigBuilder _ builder: () -> GenerateConfig) -> GenerateConfig {
    builder()
}

// MARK: - Async Variants

/// Creates a message array using async `MessagesBuilder` DSL.
///
/// This variant supports asynchronous operations within the builder,
/// useful when message content needs to be fetched or computed asynchronously.
///
/// ## Usage
///
/// ```swift
/// let messages = await MessagesAsync {
///     System("You are helpful.")
///
///     let context = await fetchContext()
///     User("Context: \(context)")
///
///     User(userQuery)
/// }
/// ```
///
/// - Parameter builder: An async closure using `MessagesBuilder` syntax.
/// - Returns: An array of `Message` objects.
@inlinable
public func MessagesAsync(@MessagesBuilder _ builder: () async -> [Message]) async -> [Message] {
    await builder()
}

/// Creates a `GenerateConfig` using async `ConfigBuilder` DSL.
///
/// This variant supports asynchronous operations within the builder.
///
/// ## Usage
///
/// ```swift
/// let config = await GenerateAsync {
///     Sampling(temperature: 0.7)
///
///     let tools = await loadTools()
///     Tools(tools)
/// }
/// ```
///
/// - Parameter builder: An async closure using `ConfigBuilder` syntax.
/// - Returns: A `GenerateConfig` object.
@inlinable
public func GenerateAsync(@ConfigBuilder _ builder: () async -> GenerateConfig) async -> GenerateConfig {
    await builder()
}

// MARK: - Array Extensions

extension Array where Element == Message {

    /// Creates a message array using the `MessagesBuilder` DSL.
    ///
    /// Alternative syntax for building messages directly on the Array type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let messages: [Message] = .build {
    ///     System("You are helpful.")
    ///     User("Hello!")
    /// }
    /// ```
    ///
    /// - Parameter builder: A closure using `MessagesBuilder` syntax.
    /// - Returns: An array of `Message` objects.
    @inlinable
    public static func build(@MessagesBuilder _ builder: () -> [Message]) -> [Message] {
        builder()
    }
}

extension GenerateConfig {

    /// Creates a `GenerateConfig` using the `ConfigBuilder` DSL.
    ///
    /// Alternative syntax for building config directly on the type.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let config = GenerateConfig.build {
    ///     Sampling(temperature: 0.7)
    ///     MaxTokens(1024)
    /// }
    /// ```
    ///
    /// - Parameter builder: A closure using `ConfigBuilder` syntax.
    /// - Returns: A `GenerateConfig` object.
    @inlinable
    public static func build(@ConfigBuilder _ builder: () -> GenerateConfig) -> GenerateConfig {
        builder()
    }
}
