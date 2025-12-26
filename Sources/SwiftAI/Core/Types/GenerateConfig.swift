// GenerateConfig.swift
// SwiftAI

import Foundation

// MARK: - GenerateConfig

/// Configuration parameters for text generation.
///
/// `GenerateConfig` controls various aspects of text generation including
/// sampling parameters, token limits, penalties, and output options.
///
/// ## Usage
/// ```swift
/// // Use defaults
/// let config = GenerateConfig.default
///
/// // Use a preset
/// let creativeConfig = GenerateConfig.creative
///
/// // Customize with fluent API
/// let customConfig = GenerateConfig.default
///     .temperature(0.8)
///     .maxTokens(500)
///     .stopSequences(["END"])
///
/// // Use in generation
/// let response = try await provider.generate(
///     messages: messages,
///     model: .llama3_2_1b,
///     config: customConfig
/// )
/// ```
///
/// ## Presets
/// - `default`: Balanced configuration (temperature: 0.7, topP: 0.9)
/// - `creative`: High creativity (temperature: 0.9, topP: 0.95)
/// - `precise`: Low randomness (temperature: 0.1, topP: 0.5)
/// - `code`: Optimized for code generation (temperature: 0.2)
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct GenerateConfig: Sendable, Hashable, Codable {

    // MARK: - Token Limits

    /// Maximum number of tokens to generate.
    ///
    /// If `nil`, the provider's default limit is used.
    ///
    /// - Note: Actual generation may stop earlier due to stop sequences
    ///         or natural completion.
    public var maxTokens: Int?

    /// Minimum number of tokens to generate before stopping.
    ///
    /// Useful for ensuring the model produces substantive output.
    public var minTokens: Int?

    // MARK: - Sampling Parameters

    /// Controls randomness in token selection.
    ///
    /// - Range: 0.0 to 2.0 (clamped automatically)
    /// - Low (0.0-0.3): Deterministic, focused output
    /// - Medium (0.4-0.7): Balanced creativity and coherence
    /// - High (0.8-2.0): More random and creative output
    ///
    /// - Note: Values outside 0-2 range are automatically clamped.
    public var temperature: Float

    /// Nucleus sampling: only consider tokens with cumulative probability mass of topP.
    ///
    /// - Range: 0.0 to 1.0 (clamped automatically)
    /// - Low (0.1-0.5): Conservative, predictable output
    /// - Medium (0.6-0.8): Balanced diversity
    /// - High (0.9-1.0): Maximum diversity
    ///
    /// - Note: Values outside 0-1 range are automatically clamped.
    public var topP: Float

    /// Only consider the top K most likely tokens at each step.
    ///
    /// If `nil`, no top-K filtering is applied.
    ///
    /// - Note: Lower values make output more focused; higher values
    ///         allow more diversity.
    public var topK: Int?

    // MARK: - Penalty Parameters

    /// Penalty for repeating tokens (exponential).
    ///
    /// - Range: 0.0 to 2.0
    /// - 1.0: No penalty (default)
    /// - Greater than 1.0: Discourage repetition
    /// - Less than 1.0: Encourage repetition
    public var repetitionPenalty: Float

    /// Penalty based on token frequency in the generated text.
    ///
    /// - Range: -2.0 to 2.0
    /// - Positive: Discourage frequent tokens
    /// - Negative: Encourage frequent tokens
    /// - 0.0: No penalty (default)
    public var frequencyPenalty: Float

    /// Penalty based on token presence in the generated text.
    ///
    /// - Range: -2.0 to 2.0
    /// - Positive: Discourage repeated tokens
    /// - Negative: Encourage repeated tokens
    /// - 0.0: No penalty (default)
    public var presencePenalty: Float

    // MARK: - Stop Conditions

    /// Sequences that will stop generation when encountered.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default
    ///     .stopSequences(["END", "\n\n\n", "User:"])
    /// ```
    ///
    /// - Note: Generation stops when any stop sequence is generated.
    public var stopSequences: [String]

    // MARK: - Reproducibility

    /// Random seed for reproducible generation.
    ///
    /// If `nil`, generation is non-deterministic.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.seed(42)
    /// // Same seed + same config + same prompt = same output
    /// ```
    public var seed: UInt64?

    // MARK: - Logprobs Output

    /// Whether to return log probabilities for generated tokens.
    public var returnLogprobs: Bool

    /// Number of top log probabilities to return per token.
    ///
    /// Only used if `returnLogprobs` is `true`.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.withLogprobs(top: 5)
    /// ```
    public var topLogprobs: Int?

    // MARK: - Provider Analytics

    /// User ID for tracking usage per user in provider analytics.
    ///
    /// When set, allows tracking usage and costs by user in provider
    /// dashboards (e.g., Anthropic console).
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.userId("user_12345")
    /// ```
    public var userId: String?

    /// Service tier selection for capacity management.
    ///
    /// Controls routing priority for the request. Some providers
    /// offer different service tiers with varying capacity guarantees.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.serviceTier(.auto)
    /// ```
    public var serviceTier: ServiceTier?

    // MARK: - Tool Use

    /// Tools available for the model to use during generation.
    ///
    /// When tools are provided, the model may choose to call them instead of
    /// generating text, returning tool call requests in the response.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default
    ///     .tools([WeatherTool(), SearchTool()])
    ///     .toolChoice(.auto)
    /// ```
    public var availableTools: [ToolDefinition]

    /// Controls how the model chooses which tool to use.
    ///
    /// - `.auto`: Model decides whether to use a tool (default)
    /// - `.required`: Model must use a tool
    /// - `.none`: Model should not use any tools
    /// - `.tool(name:)`: Model must use the specified tool
    public var toolChoice: ToolChoice

    // MARK: - Initialization

    /// Creates a generation configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - maxTokens: Maximum tokens to generate (default: 1024).
    ///   - minTokens: Minimum tokens to generate (default: nil).
    ///   - temperature: Sampling temperature, 0-2 range (default: 0.7).
    ///   - topP: Nucleus sampling threshold, 0-1 range (default: 0.9).
    ///   - topK: Top-K filtering (default: nil).
    ///   - repetitionPenalty: Repetition penalty multiplier (default: 1.0).
    ///   - frequencyPenalty: Frequency penalty, -2 to 2 (default: 0.0).
    ///   - presencePenalty: Presence penalty, -2 to 2 (default: 0.0).
    ///   - stopSequences: Sequences that stop generation (default: []).
    ///   - seed: Random seed for reproducibility (default: nil).
    ///   - returnLogprobs: Whether to return log probabilities (default: false).
    ///   - topLogprobs: Number of top logprobs per token (default: nil).
    ///   - userId: User ID for per-user usage tracking (default: nil).
    ///   - serviceTier: Service tier for capacity management (default: nil).
    ///   - tools: Tools available for the model to use (default: []).
    ///   - toolChoice: How the model should choose tools (default: .auto).
    public init(
        maxTokens: Int? = 1024,
        minTokens: Int? = nil,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        topK: Int? = nil,
        repetitionPenalty: Float = 1.0,
        frequencyPenalty: Float = 0.0,
        presencePenalty: Float = 0.0,
        stopSequences: [String] = [],
        seed: UInt64? = nil,
        returnLogprobs: Bool = false,
        topLogprobs: Int? = nil,
        userId: String? = nil,
        serviceTier: ServiceTier? = nil,
        tools: [ToolDefinition] = [],
        toolChoice: ToolChoice = .auto
    ) {
        self.maxTokens = maxTokens
        self.minTokens = minTokens
        self.temperature = max(0, min(2, temperature))
        self.topP = max(0, min(1, topP))
        self.topK = topK
        self.repetitionPenalty = repetitionPenalty
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.stopSequences = stopSequences
        self.seed = seed
        self.returnLogprobs = returnLogprobs
        self.topLogprobs = topLogprobs
        self.userId = userId
        self.serviceTier = serviceTier
        self.availableTools = tools
        self.toolChoice = toolChoice
    }

    // MARK: - Static Presets

    /// Default balanced configuration.
    ///
    /// Good for general-purpose text generation with moderate creativity.
    ///
    /// ## Configuration
    /// - maxTokens: 1024
    /// - temperature: 0.7
    /// - topP: 0.9
    /// - repetitionPenalty: 1.0
    public static let `default` = GenerateConfig()

    /// Creative configuration with high randomness.
    ///
    /// Optimized for creative writing, brainstorming, and diverse outputs.
    ///
    /// ## Configuration
    /// - temperature: 0.9
    /// - topP: 0.95
    /// - frequencyPenalty: 0.5
    ///
    /// ## Usage
    /// ```swift
    /// let story = try await provider.generate(
    ///     "Write a sci-fi story:",
    ///     model: .llama3_2_1b,
    ///     config: .creative
    /// )
    /// ```
    public static let creative = GenerateConfig(
        temperature: 0.9,
        topP: 0.95,
        frequencyPenalty: 0.5
    )

    /// Precise configuration with low randomness.
    ///
    /// Optimized for factual responses, instructions, and deterministic output.
    ///
    /// ## Configuration
    /// - temperature: 0.1
    /// - topP: 0.5
    /// - repetitionPenalty: 1.1
    ///
    /// ## Usage
    /// ```swift
    /// let answer = try await provider.generate(
    ///     "Explain quantum entanglement:",
    ///     model: .llama3_2_1b,
    ///     config: .precise
    /// )
    /// ```
    public static let precise = GenerateConfig(
        temperature: 0.1,
        topP: 0.5,
        repetitionPenalty: 1.1
    )

    /// Code generation configuration.
    ///
    /// Optimized for generating code with appropriate stop sequences.
    ///
    /// ## Configuration
    /// - temperature: 0.2
    /// - topP: 0.9
    /// - stopSequences: ["```", "\n\n\n"]
    ///
    /// ## Usage
    /// ```swift
    /// let code = try await provider.generate(
    ///     "Write a Swift function to sort an array:",
    ///     model: .llama3_2_1b,
    ///     config: .code
    /// )
    /// ```
    public static let code = GenerateConfig(
        temperature: 0.2,
        topP: 0.9,
        stopSequences: ["```", "\n\n\n"]
    )
}

// MARK: - Fluent API

extension GenerateConfig {

    /// Returns a copy with the specified maximum token count.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.maxTokens(500)
    /// ```
    ///
    /// - Parameter value: Maximum tokens to generate, or `nil` for provider default.
    /// - Returns: A new configuration with the updated value.
    public func maxTokens(_ value: Int?) -> GenerateConfig {
        var copy = self
        copy.maxTokens = value
        return copy
    }

    /// Returns a copy with the specified minimum token count.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.minTokens(50)
    /// ```
    ///
    /// - Parameter value: Minimum tokens to generate.
    /// - Returns: A new configuration with the updated value.
    public func minTokens(_ value: Int?) -> GenerateConfig {
        var copy = self
        copy.minTokens = value
        return copy
    }

    /// Returns a copy with the specified temperature.
    ///
    /// Temperature is automatically clamped to the valid range [0.0, 2.0].
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.temperature(0.8)
    /// ```
    ///
    /// - Parameter value: Sampling temperature (0.0 = deterministic, 2.0 = very random).
    /// - Returns: A new configuration with the clamped temperature.
    public func temperature(_ value: Float) -> GenerateConfig {
        var copy = self
        copy.temperature = max(0, min(2, value))
        return copy
    }

    /// Returns a copy with the specified top-P value.
    ///
    /// Top-P is automatically clamped to the valid range [0.0, 1.0].
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.topP(0.95)
    /// ```
    ///
    /// - Parameter value: Nucleus sampling threshold (0.0 = conservative, 1.0 = diverse).
    /// - Returns: A new configuration with the clamped top-P value.
    public func topP(_ value: Float) -> GenerateConfig {
        var copy = self
        copy.topP = max(0, min(1, value))
        return copy
    }

    /// Returns a copy with the specified top-K value.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.topK(40)
    /// ```
    ///
    /// - Parameter value: Number of top tokens to consider, or `nil` for no filtering.
    /// - Returns: A new configuration with the updated value.
    public func topK(_ value: Int?) -> GenerateConfig {
        var copy = self
        copy.topK = value
        return copy
    }

    /// Returns a copy with the specified repetition penalty.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.repetitionPenalty(1.2)
    /// ```
    ///
    /// - Parameter value: Repetition penalty multiplier (1.0 = no penalty).
    /// - Returns: A new configuration with the updated value.
    public func repetitionPenalty(_ value: Float) -> GenerateConfig {
        var copy = self
        copy.repetitionPenalty = value
        return copy
    }

    /// Returns a copy with the specified frequency penalty.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.frequencyPenalty(0.5)
    /// ```
    ///
    /// - Parameter value: Frequency penalty (-2.0 to 2.0, 0.0 = no penalty).
    /// - Returns: A new configuration with the updated value.
    public func frequencyPenalty(_ value: Float) -> GenerateConfig {
        var copy = self
        copy.frequencyPenalty = value
        return copy
    }

    /// Returns a copy with the specified presence penalty.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.presencePenalty(0.3)
    /// ```
    ///
    /// - Parameter value: Presence penalty (-2.0 to 2.0, 0.0 = no penalty).
    /// - Returns: A new configuration with the updated value.
    public func presencePenalty(_ value: Float) -> GenerateConfig {
        var copy = self
        copy.presencePenalty = value
        return copy
    }

    /// Returns a copy with the specified stop sequences.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default
    ///     .stopSequences(["END", "STOP", "\n\n"])
    /// ```
    ///
    /// - Parameter sequences: Sequences that will stop generation when encountered.
    /// - Returns: A new configuration with the updated stop sequences.
    public func stopSequences(_ sequences: [String]) -> GenerateConfig {
        var copy = self
        copy.stopSequences = sequences
        return copy
    }

    /// Returns a copy with the specified random seed.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.seed(42)
    /// // Same seed = reproducible output
    /// ```
    ///
    /// - Parameter value: Random seed for reproducibility, or `nil` for non-deterministic.
    /// - Returns: A new configuration with the updated seed.
    public func seed(_ value: UInt64?) -> GenerateConfig {
        var copy = self
        copy.seed = value
        return copy
    }

    /// Returns a copy configured to return log probabilities.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.withLogprobs(top: 5)
    /// ```
    ///
    /// - Parameter top: Number of top log probabilities per token (default: 5).
    /// - Returns: A new configuration with logprobs enabled.
    public func withLogprobs(top: Int = 5) -> GenerateConfig {
        var copy = self
        copy.returnLogprobs = true
        copy.topLogprobs = top
        return copy
    }

    /// Returns a copy with the specified user ID for tracking.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.userId("user_12345")
    /// ```
    ///
    /// - Parameter id: User ID for per-user usage tracking.
    /// - Returns: A new configuration with the updated user ID.
    public func userId(_ id: String) -> GenerateConfig {
        var copy = self
        copy.userId = id
        return copy
    }

    /// Returns a copy with the specified service tier.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.serviceTier(.auto)
    /// ```
    ///
    /// - Parameter tier: Service tier for capacity management.
    /// - Returns: A new configuration with the updated service tier.
    public func serviceTier(_ tier: ServiceTier) -> GenerateConfig {
        var copy = self
        copy.serviceTier = tier
        return copy
    }

    /// Returns a copy with the specified tools.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.tools([
    ///     ToolDefinition(name: "weather", description: "Get weather", parameters: WeatherTool.parameters)
    /// ])
    /// ```
    ///
    /// - Parameter definitions: Tool definitions to make available.
    /// - Returns: A new configuration with the tools.
    public func tools(_ definitions: [ToolDefinition]) -> GenerateConfig {
        var copy = self
        copy.availableTools = definitions
        return copy
    }

    /// Returns a copy with tools from AITool instances.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.tools([WeatherTool(), SearchTool()])
    /// ```
    ///
    /// - Parameter aiTools: AITool instances to make available.
    /// - Returns: A new configuration with the tools.
    public func tools(_ aiTools: [any AITool]) -> GenerateConfig {
        var copy = self
        copy.availableTools = aiTools.map { tool in
            ToolDefinition(
                name: tool.name,
                description: tool.description,
                parameters: type(of: tool).parameters
            )
        }
        return copy
    }

    /// Returns a copy with the specified tool choice.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default
    ///     .tools([WeatherTool()])
    ///     .toolChoice(.required)
    /// ```
    ///
    /// - Parameter choice: How the model should choose tools.
    /// - Returns: A new configuration with the tool choice.
    public func toolChoice(_ choice: ToolChoice) -> GenerateConfig {
        var copy = self
        copy.toolChoice = choice
        return copy
    }
}

// MARK: - ToolDefinition

/// Definition of a tool that can be used by language models.
///
/// A `ToolDefinition` describes a tool's interface to the LLM, including
/// its name, description, and parameter schema. This is used when passing
/// tools to the generation configuration.
///
/// ## Usage
/// ```swift
/// let tool = ToolDefinition(
///     name: "get_weather",
///     description: "Get current weather for a city",
///     parameters: WeatherTool.parameters
/// )
///
/// let config = GenerateConfig.default.tools([tool])
/// ```
///
/// ## From AITool
/// You can also use the fluent API with `AITool` instances directly:
/// ```swift
/// let config = GenerateConfig.default.tools([WeatherTool(), SearchTool()])
/// ```
public struct ToolDefinition: Sendable, Hashable, Codable {

    /// The unique name of the tool.
    ///
    /// This name is used by the LLM to reference the tool and should
    /// follow naming conventions expected by the provider.
    public let name: String

    /// A description of what the tool does.
    ///
    /// This helps the LLM understand when and how to use the tool.
    public let description: String

    /// The schema describing the tool's parameters.
    ///
    /// Defines the structure and constraints of arguments the tool accepts.
    public let parameters: Schema

    /// Creates a new tool definition.
    ///
    /// - Parameters:
    ///   - name: The unique name of the tool.
    ///   - description: A description of what the tool does.
    ///   - parameters: The schema for the tool's parameters.
    public init(name: String, description: String, parameters: Schema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - ToolChoice

/// Controls how the model chooses which tool to use.
///
/// `ToolChoice` allows you to specify the model's behavior when tools
/// are available, from fully automatic selection to requiring specific tools.
///
/// ## Usage
/// ```swift
/// // Let the model decide
/// let config = GenerateConfig.default
///     .tools([WeatherTool()])
///     .toolChoice(.auto)
///
/// // Force tool usage
/// let config = GenerateConfig.default
///     .tools([WeatherTool()])
///     .toolChoice(.required)
///
/// // Use a specific tool
/// let config = GenerateConfig.default
///     .tools([WeatherTool(), SearchTool()])
///     .toolChoice(.tool(name: "get_weather"))
/// ```
public enum ToolChoice: Sendable, Hashable, Codable {

    /// Model decides whether to use a tool.
    ///
    /// The model will analyze the conversation and decide if a tool
    /// call is appropriate. This is the default behavior.
    case auto

    /// Model must use a tool.
    ///
    /// The model is required to call at least one tool. Use this
    /// when you need guaranteed tool usage.
    case required

    /// Model should not use any tools.
    ///
    /// Disables tool calling even when tools are provided.
    case none

    /// Model must use the specified tool.
    ///
    /// Forces the model to call a specific tool by name.
    ///
    /// - Parameter name: The name of the tool to use.
    case tool(name: String)
}

// MARK: - ServiceTier

/// API service tier options for capacity management.
///
/// Some providers offer different service tiers that control
/// routing priority and capacity guarantees for requests.
///
/// ## Usage
/// ```swift
/// let config = GenerateConfig.default.serviceTier(.auto)
/// ```
///
/// ## Provider Support
/// - **Anthropic**: Supports `auto` and `standardOnly`
/// - **Other providers**: May ignore this setting
public enum ServiceTier: String, Sendable, Hashable, Codable {

    /// Automatic tier selection (default).
    ///
    /// The provider automatically selects the best available
    /// tier based on current capacity and account settings.
    case auto = "auto"

    /// Standard capacity only.
    ///
    /// Disables priority routing and uses only standard capacity.
    /// This may result in slower response times during high load
    /// but ensures consistent behavior.
    case standardOnly = "standard_only"
}
