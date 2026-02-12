// GenerateConfig.swift
// Conduit

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
/// - `Codable`: Full JSON encoding/decoding support
public struct GenerateConfig: Sendable, Codable {

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
    public var tools: [Transcript.ToolDefinition]

    /// Controls how the model chooses which tool to use.
    ///
    /// - `.auto`: Model decides whether to use a tool (default)
    /// - `.required`: Model must use a tool
    /// - `.none`: Model should not use any tools
    /// - `.tool(name:)`: Model must use the specified tool
    public var toolChoice: ToolChoice

    /// Whether to allow parallel tool calls.
    ///
    /// When `true`, the model may call multiple tools in a single response.
    /// Default is `true` for most providers.
    public var parallelToolCalls: Bool?

    // MARK: - Response Format

    /// Response format for structured output.
    ///
    /// Controls whether the model returns plain text, JSON, or schema-validated JSON.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.responseFormat(.jsonObject)
    /// ```
    public var responseFormat: ResponseFormat?

    // MARK: - Reasoning

    /// Configuration for extended thinking/reasoning mode.
    ///
    /// When set, enables the model to perform extended reasoning before responding.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.reasoning(.high)
    /// ```
    public var reasoning: ReasoningConfig?

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
    ///   - parallelToolCalls: Whether to allow parallel tool calls (default: nil).
    ///   - responseFormat: Response format for structured output (default: nil).
    ///   - reasoning: Configuration for reasoning mode (default: nil).
    ///
    /// - Note: Dont set temperature and topP for Anthropic models
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
        tools: [Transcript.ToolDefinition] = [],
        toolChoice: ToolChoice = .auto,
        parallelToolCalls: Bool? = nil,
        responseFormat: ResponseFormat? = nil,
        reasoning: ReasoningConfig? = nil
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
        self.tools = tools
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
        self.responseFormat = responseFormat
        self.reasoning = reasoning
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

// MARK: - GenerationOptions Bridge

extension GenerateConfig {

    /// Creates a runtime generation config from prompt-level `GenerationOptions`.
    ///
    /// This bridge keeps defaults from `base` and applies explicitly provided
    /// option values on top, including sampling strategy and token limits.
    ///
    /// - Parameters:
    ///   - options: Prompt-level generation options.
    ///   - responseFormat: Optional response format to carry into runtime config.
    ///   - base: Base runtime config to preserve existing defaults/overrides.
    public init(
        options: GenerationOptions,
        responseFormat: ResponseFormat? = nil,
        base: GenerateConfig = .default
    ) {
        var config = base

        if let temperature = options.temperature {
            config = config.temperature(Float(temperature))
        }

        if let maximumResponseTokens = options.maximumResponseTokens {
            config = config.maxTokens(maximumResponseTokens)
        }

        if let sampling = options.sampling {
            switch sampling.mode {
            case .greedy:
                // Preserve greedy intent across providers by disabling top-p/top-k
                // and forcing temperature to 0.
                config = config.temperature(0).topP(0).topK(nil).seed(nil)
            case .topK(let k, seed: let seed):
                let topK = k > 0 ? k : nil
                // top-k and top-p are alternative sampling controls.
                config = config.topP(0).topK(topK).seed(seed)
            case .nucleus(let threshold, seed: let seed):
                config = config.topP(Float(threshold)).topK(nil).seed(seed)
            }
        }

        if let responseFormat {
            config = config.responseFormat(responseFormat)
        }

        self = config
    }
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
    ///     Transcript.ToolDefinition(name: "weather", description: "Get weather", parameters: WeatherTool.parameters)
    /// ])
    /// ```
    ///
    /// - Parameter definitions: Tool definitions to make available.
    /// - Returns: A new configuration with the tools.
    public func tools(_ definitions: [Transcript.ToolDefinition]) -> GenerateConfig {
        var copy = self
        copy.tools = definitions
        return copy
    }

    /// Returns a copy with tools from Tool instances.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.tools([WeatherTool(), SearchTool()])
    /// ```
    ///
    /// - Parameter tools: Tool instances to make available.
    /// - Returns: A new configuration with the tools.
    public func tools(_ tools: [any Tool]) -> GenerateConfig {
        var copy = self
        copy.tools = tools.map { tool in
            Transcript.ToolDefinition(tool: tool)
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

    /// Returns a copy with the specified parallel tool calls setting.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default
    ///     .tools([myTool])
    ///     .parallelToolCalls(false)
    /// ```
    ///
    /// - Parameter enabled: Whether to allow parallel tool calls.
    /// - Returns: A new configuration with the updated setting.
    public func parallelToolCalls(_ enabled: Bool) -> GenerateConfig {
        var copy = self
        copy.parallelToolCalls = enabled
        return copy
    }

    /// Returns a copy with the specified response format.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.responseFormat(.jsonObject)
    /// ```
    ///
    /// - Parameter format: The response format to use.
    /// - Returns: A new configuration with the updated format.
    public func responseFormat(_ format: ResponseFormat) -> GenerateConfig {
        var copy = self
        copy.responseFormat = format
        return copy
    }

    /// Returns a copy with the specified reasoning configuration.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.reasoning(.high)
    /// ```
    ///
    /// - Parameter config: The reasoning configuration.
    /// - Returns: A new configuration with reasoning enabled.
    public func reasoning(_ config: ReasoningConfig) -> GenerateConfig {
        var copy = self
        copy.reasoning = config
        return copy
    }

    /// Returns a copy with reasoning enabled at the specified effort level.
    ///
    /// ## Usage
    /// ```swift
    /// let config = GenerateConfig.default.reasoning(.high)
    /// ```
    ///
    /// - Parameter effort: The reasoning effort level.
    /// - Returns: A new configuration with reasoning enabled.
    public func reasoning(_ effort: ReasoningEffort) -> GenerateConfig {
        var copy = self
        copy.reasoning = ReasoningConfig(effort: effort)
        return copy
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

// MARK: - ResponseFormat

/// Response format options for structured output.
///
/// Controls the format of the model's response, enabling JSON mode
/// or strict JSON schema validation.
///
/// ## Usage
/// ```swift
/// // JSON object mode (flexible JSON)
/// let config = GenerateConfig.default.responseFormat(.jsonObject)
///
/// // JSON schema mode (strict validation)
/// let schema = User.generationSchema
/// let config = GenerateConfig.default.responseFormat(.jsonSchema(name: "User", schema: schema))
/// ```
///
/// ## Provider Support
/// - **OpenAI/OpenRouter**: Full support for all modes
/// - **Anthropic**: Structured modes are enforced through deterministic
///   system instructions (no native response-format validation)
public enum ResponseFormat: Sendable, Codable {

    /// Plain text output (default).
    ///
    /// No special formatting applied. The model returns natural text.
    case text

    /// JSON object mode.
    ///
    /// The model is instructed to return valid JSON. The structure
    /// is flexible and determined by the prompt.
    case jsonObject

    /// JSON schema mode with strict validation.
    ///
    /// The model must return JSON conforming to the provided schema.
    /// This enables reliable structured output parsing.
    ///
    /// - Parameters:
    ///   - name: A name for the schema (required by some providers).
    ///   - schema: The JSON schema defining the expected structure.
    case jsonSchema(name: String, schema: GenerationSchema)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case name
        case schema
    }

    private enum FormatType: String, Codable {
        case text
        case jsonObject = "json_object"
        case jsonSchema = "json_schema"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text:
            try container.encode(FormatType.text, forKey: .type)
        case .jsonObject:
            try container.encode(FormatType.jsonObject, forKey: .type)
        case .jsonSchema(let name, let schema):
            try container.encode(FormatType.jsonSchema, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(schema, forKey: .schema)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(FormatType.self, forKey: .type)
        switch type {
        case .text:
            self = .text
        case .jsonObject:
            self = .jsonObject
        case .jsonSchema:
            let name = try container.decode(String.self, forKey: .name)
            let schema = try container.decode(GenerationSchema.self, forKey: .schema)
            self = .jsonSchema(name: name, schema: schema)
        }
    }
}

// MARK: - ReasoningEffort

/// Reasoning effort levels for extended thinking.
///
/// Controls how much computational effort the model spends on
/// internal reasoning before responding.
///
/// ## Usage
/// ```swift
/// let config = GenerateConfig.default.reasoning(.high)
/// ```
///
/// ## Provider Support
/// - **OpenRouter**: Supported for Claude 3.7 Sonnet :thinking and o1 models
/// - **Anthropic**: Use `ThinkingConfig` instead
public enum ReasoningEffort: String, Sendable, Hashable, Codable, CaseIterable {
    /// Extra high effort - maximum reasoning time.
    case xhigh
    /// High effort - extensive reasoning.
    case high
    /// Medium effort - balanced reasoning.
    case medium
    /// Low effort - light reasoning.
    case low
    /// Minimal effort - very brief reasoning.
    case minimal
    /// No reasoning - standard generation.
    case none
}

// MARK: - ReasoningConfig

/// Configuration for extended thinking/reasoning mode.
///
/// Enables models to perform extended reasoning before responding,
/// potentially improving quality for complex tasks.
///
/// ## Usage
/// ```swift
/// // Simple effort-based config
/// let config = GenerateConfig.default.reasoning(.high)
///
/// // Detailed config with token budget
/// let reasoningConfig = ReasoningConfig(effort: .high, maxTokens: 2000)
/// let config = GenerateConfig.default.reasoning(reasoningConfig)
///
/// // Hide reasoning from response
/// let config = GenerateConfig.default.reasoning(ReasoningConfig(effort: .high, exclude: true))
/// ```
///
/// ## API Format
/// ```json
/// {
///   "reasoning": {
///     "effort": "high",
///     "max_tokens": 2000,
///     "exclude": false
///   }
/// }
/// ```
public struct ReasoningConfig: Sendable, Hashable, Codable {

    /// Reasoning effort level.
    ///
    /// Controls how much computational effort is spent on reasoning.
    public var effort: ReasoningEffort?

    /// Maximum tokens for reasoning.
    ///
    /// Directly allocates a token budget for reasoning. Alternative to effort.
    public var maxTokens: Int?

    /// Whether to exclude reasoning from the response.
    ///
    /// When `true`, reasoning details are not included in the response.
    public var exclude: Bool?

    /// Whether reasoning is enabled.
    ///
    /// Used by some models (like o1) that use a simple enabled flag.
    public var enabled: Bool?

    // MARK: - Initialization

    /// Creates a reasoning configuration.
    ///
    /// - Parameters:
    ///   - effort: Reasoning effort level.
    ///   - maxTokens: Maximum tokens for reasoning.
    ///   - exclude: Whether to exclude reasoning from response.
    ///   - enabled: Whether reasoning is enabled.
    public init(
        effort: ReasoningEffort? = nil,
        maxTokens: Int? = nil,
        exclude: Bool? = nil,
        enabled: Bool? = nil
    ) {
        self.effort = effort
        self.maxTokens = maxTokens
        self.exclude = exclude
        self.enabled = enabled
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case effort
        case maxTokens = "max_tokens"
        case exclude
        case enabled
    }
}

// MARK: - ReasoningDetail

/// A reasoning block from the model's extended thinking.
///
/// Represents one segment of the model's reasoning process.
///
/// ## Types
/// - `reasoning.text`: Human-readable reasoning content
/// - `reasoning.summary`: Summary of the reasoning process
/// - `reasoning.encrypted`: Encrypted reasoning (provider-specific)
public struct ReasoningDetail: Sendable, Hashable, Codable {

    /// Unique identifier for this reasoning block.
    public let id: String

    /// The type of reasoning block.
    ///
    /// Common values:
    /// - `"reasoning.text"`: Plain text reasoning
    /// - `"reasoning.summary"`: Summary block
    /// - `"reasoning.encrypted"`: Encrypted content
    public let type: String

    /// The format of the reasoning content.
    ///
    /// Example: `"anthropic-claude-v1"`
    public let format: String

    /// Index of this block in the reasoning sequence.
    public let index: Int

    /// The reasoning content (if available).
    ///
    /// May be `nil` for encrypted blocks.
    public let content: String?

    /// Creates a reasoning detail.
    public init(
        id: String,
        type: String,
        format: String,
        index: Int,
        content: String?
    ) {
        self.id = id
        self.type = type
        self.format = format
        self.index = index
        self.content = content
    }
}
