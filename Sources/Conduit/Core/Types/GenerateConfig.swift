// GenerateConfig.swift
// Conduit

import Foundation

// MARK: - GenerateConfigProtocol

/// Protocol defining the interface for generation configuration.
///
/// This protocol abstracts the common properties needed for text generation
/// across both local and cloud providers, enabling protocol-based configuration
/// composition.
public protocol GenerateConfigProtocol: Sendable, Codable {
    /// Maximum number of tokens to generate.
    var maxTokens: Int? { get set }

    /// Minimum number of tokens to generate before stopping.
    var minTokens: Int? { get set }

    /// Controls randomness in token selection (0.0-2.0).
    var temperature: Float { get set }

    /// Nucleus sampling threshold (0.0-1.0).
    var topP: Float { get set }

    /// Only consider the top K most likely tokens at each step.
    var topK: Int? { get set }

    /// Penalty for repeating tokens (0.0-2.0).
    var repetitionPenalty: Float { get set }

    /// Penalty based on token frequency (-2.0 to 2.0).
    var frequencyPenalty: Float { get set }

    /// Penalty based on token presence (-2.0 to 2.0).
    var presencePenalty: Float { get set }

    /// Stop sequences that will terminate generation.
    var stopSequences: [String] { get set }

    /// Random seed for reproducible generation.
    var seed: UInt64? { get set }

    /// Whether to return log probabilities for generated tokens.
    var returnLogprobs: Bool { get set }

    /// Number of top log probabilities to return per token.
    var topLogprobs: Int? { get set }

    /// User ID for tracking usage per user in provider analytics.
    var userId: String? { get set }

    /// Service tier selection for capacity management.
    var serviceTier: ServiceTier? { get set }

    /// Tools available for the model to use during generation.
    var tools: [Transcript.ToolDefinition] { get set }

    /// Controls how the model chooses which tool to use.
    var toolChoice: ToolChoice { get set }

    /// Whether to allow parallel tool calls.
    var parallelToolCalls: ParallelToolMode { get set }

    /// Maximum number of tool calls allowed in a single model response.
    var maxToolCalls: Int? { get set }

    /// Response format for structured output.
    var responseFormat: ResponseFormat? { get set }

    /// Configuration for extended thinking/reasoning mode.
    var reasoning: ReasoningConfig? { get set }

    /// Provider/runtime feature overrides for local execution.
    var runtimeFeatures: ProviderRuntimeFeatureConfiguration? { get set }

    /// Runtime policy overrides merged with provider-level policy.
    var runtimePolicyOverride: ProviderRuntimePolicyOverride? { get set }
}

// MARK: - Default Implementations

extension GenerateConfigProtocol {
    /// Returns a copy with the specified maximum token count.
    public func maxTokens(_ value: Int?) -> Self {
        var copy = self
        copy.maxTokens = value
        return copy
    }

    /// Returns a copy with the specified minimum token count.
    public func minTokens(_ value: Int?) -> Self {
        var copy = self
        copy.minTokens = value
        return copy
    }

    /// Returns a copy with the specified temperature.
    public func temperature(_ value: Float) -> Self {
        var copy = self
        copy.temperature = max(0, min(2, value))
        return copy
    }

    /// Returns a copy with the specified top-P value.
    public func topP(_ value: Float) -> Self {
        var copy = self
        copy.topP = max(0, min(1, value))
        return copy
    }

    /// Returns a copy with the specified top-K value.
    public func topK(_ value: Int?) -> Self {
        var copy = self
        copy.topK = value
        return copy
    }

    /// Returns a copy with the specified repetition penalty.
    public func repetitionPenalty(_ value: Float) -> Self {
        var copy = self
        copy.repetitionPenalty = value
        return copy
    }

    /// Returns a copy with the specified frequency penalty.
    public func frequencyPenalty(_ value: Float) -> Self {
        var copy = self
        copy.frequencyPenalty = value
        return copy
    }

    /// Returns a copy with the specified presence penalty.
    public func presencePenalty(_ value: Float) -> Self {
        var copy = self
        copy.presencePenalty = value
        return copy
    }

    /// Returns a copy with the specified stop sequences.
    public func stopSequences(_ sequences: [String]) -> Self {
        var copy = self
        copy.stopSequences = sequences
        return copy
    }

    /// Returns a copy with the specified random seed.
    public func seed(_ value: UInt64?) -> Self {
        var copy = self
        copy.seed = value
        return copy
    }

    /// Returns a copy configured to return log probabilities.
    public func withLogprobs(top: Int = 5) -> Self {
        var copy = self
        copy.returnLogprobs = true
        copy.topLogprobs = top
        return copy
    }

    /// Returns a copy with the specified user ID for tracking.
    public func userId(_ id: String) -> Self {
        var copy = self
        copy.userId = id
        return copy
    }

    /// Returns a copy with the specified service tier.
    public func serviceTier(_ tier: ServiceTier) -> Self {
        var copy = self
        copy.serviceTier = tier
        return copy
    }

    /// Returns a copy with the specified tools.
    public func tools(_ definitions: [Transcript.ToolDefinition]) -> Self {
        var copy = self
        copy.tools = definitions
        return copy
    }

    /// Returns a copy with tools from Tool instances.
    public func tools(_ tools: [any Tool]) -> Self {
        var copy = self
        copy.tools = tools.map { tool in
            Transcript.ToolDefinition(tool: tool)
        }
        return copy
    }

    /// Returns a copy with the specified tool choice.
    public func toolChoice(_ choice: ToolChoice) -> Self {
        var copy = self
        copy.toolChoice = choice
        return copy
    }

    /// Returns a copy with the specified parallel tool calls mode.
    public func parallelToolCalls(_ mode: ParallelToolMode) -> Self {
        var copy = self
        copy.parallelToolCalls = mode
        return copy
    }

    /// Returns a copy with the specified maximum number of tool calls.
    public func maxToolCalls(_ value: Int?) -> Self {
        var copy = self
        copy.maxToolCalls = value
        return copy
    }

    /// Returns a copy with the specified response format.
    public func responseFormat(_ format: ResponseFormat) -> Self {
        var copy = self
        copy.responseFormat = format
        return copy
    }

    /// Returns a copy with the specified reasoning configuration.
    public func reasoning(_ config: ReasoningConfig) -> Self {
        var copy = self
        copy.reasoning = config
        return copy
    }

    /// Returns a copy with reasoning enabled at the specified effort level.
    public func reasoning(_ effort: ReasoningEffort) -> Self {
        var copy = self
        copy.reasoning = ReasoningConfig(effort: effort)
        return copy
    }

    /// Returns a copy with provider/runtime feature overrides.
    public func runtimeFeatures(_ config: ProviderRuntimeFeatureConfiguration?) -> Self {
        var copy = self
        copy.runtimeFeatures = config
        return copy
    }

    /// Returns a copy with provider/runtime policy overrides.
    public func runtimePolicyOverride(_ policy: ProviderRuntimePolicyOverride?) -> Self {
        var copy = self
        copy.runtimePolicyOverride = policy
        return copy
    }
}

// MARK: - LocalGenerateConfig

/// Local provider configuration for text generation.
///
/// Contains parameters common to all local providers (MLX, Llama, CoreML, etc.).
public struct LocalGenerateConfig: Sendable, Codable, GenerateConfigProtocol {
    // MARK: - Token Limits

    /// Maximum number of tokens to generate.
    public var maxTokens: Int?

    /// Minimum number of tokens to generate before stopping.
    public var minTokens: Int?

    // MARK: - Sampling Parameters

    /// Controls randomness in token selection (0.0-2.0, clamped automatically).
    public var temperature: Float

    /// Nucleus sampling threshold (0.0-1.0, clamped automatically).
    public var topP: Float

    /// Only consider the top K most likely tokens at each step.
    public var topK: Int?

    // MARK: - Penalty Parameters

    /// Penalty for repeating tokens (0.0-2.0).
    public var repetitionPenalty: Float

    /// Stop sequences that will terminate generation.
    public var stopSequences: [String]

    /// Random seed for reproducible generation.
    public var seed: UInt64?

    // MARK: - Logprobs Output

    /// Whether to return log probabilities for generated tokens.
    public var returnLogprobs: Bool

    /// Number of top log probabilities to return per token.
    public var topLogprobs: Int?

    // MARK: - Tool Use

    /// Tools available for the model to use during generation.
    public var tools: [Transcript.ToolDefinition]

    /// Controls how the model chooses which tool to use.
    public var toolChoice: ToolChoice

    /// Whether to allow parallel tool calls.
    public var parallelToolCalls: ParallelToolMode

    /// Maximum number of tool calls allowed in a single model response.
    public var maxToolCalls: Int?

    // MARK: - Provider Runtime Features

    /// Provider/runtime feature overrides for local execution.
    public var runtimeFeatures: ProviderRuntimeFeatureConfiguration?

    /// Runtime policy overrides merged with provider-level policy.
    public var runtimePolicyOverride: ProviderRuntimePolicyOverride?

    // MARK: - Cloud-specific properties (not applicable to local)

    /// Not applicable to local providers.
    public var frequencyPenalty: Float {
        get { 0.0 }
        set { }
    }

    /// Not applicable to local providers.
    public var presencePenalty: Float {
        get { 0.0 }
        set { }
    }

    /// Not applicable to local providers.
    public var userId: String? {
        get { nil }
        set { }
    }

    /// Not applicable to local providers.
    public var serviceTier: ServiceTier? {
        get { nil }
        set { }
    }

    /// Not applicable to local providers.
    public var responseFormat: ResponseFormat? {
        get { nil }
        set { }
    }

    /// Not applicable to local providers.
    public var reasoning: ReasoningConfig? {
        get { nil }
        set { }
    }

    // MARK: - Initialization

    public init(
        maxTokens: Int? = 1024,
        minTokens: Int? = nil,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        topK: Int? = nil,
        repetitionPenalty: Float = 1.0,
        stopSequences: [String] = [],
        seed: UInt64? = nil,
        returnLogprobs: Bool = false,
        topLogprobs: Int? = nil,
        tools: [Transcript.ToolDefinition] = [],
        toolChoice: ToolChoice = .auto,
        parallelToolCalls: ParallelToolMode = .default,
        maxToolCalls: Int? = nil,
        runtimeFeatures: ProviderRuntimeFeatureConfiguration? = nil,
        runtimePolicyOverride: ProviderRuntimePolicyOverride? = nil
    ) {
        self.maxTokens = maxTokens
        self.minTokens = minTokens
        self.temperature = max(0, min(2, temperature))
        self.topP = max(0, min(1, topP))
        self.topK = topK
        self.repetitionPenalty = repetitionPenalty
        self.stopSequences = stopSequences
        self.seed = seed
        self.returnLogprobs = returnLogprobs
        self.topLogprobs = topLogprobs
        self.tools = tools
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
        self.maxToolCalls = maxToolCalls
        self.runtimeFeatures = runtimeFeatures
        self.runtimePolicyOverride = runtimePolicyOverride
    }

    // MARK: - Static Presets

    public static let `default` = LocalGenerateConfig()
}

// MARK: - CloudGenerateConfig

/// Cloud provider configuration for text generation.
///
/// Contains parameters specific to cloud API providers (OpenAI, Anthropic, etc.).
public struct CloudGenerateConfig: Sendable, Codable, GenerateConfigProtocol {
    // MARK: - Penalty Parameters

    /// Penalty based on token frequency in the generated text (-2.0 to 2.0).
    public var frequencyPenalty: Float

    /// Penalty based on token presence in the generated text (-2.0 to 2.0).
    public var presencePenalty: Float

    // MARK: - Provider Analytics

    /// User ID for tracking usage per user in provider analytics.
    public var userId: String?

    /// Service tier selection for capacity management.
    public var serviceTier: ServiceTier?

    // MARK: - Reasoning

    /// Configuration for extended thinking/reasoning mode.
    public var reasoning: ReasoningConfig?

    // MARK: - Response Format

    /// Response format for structured output.
    public var responseFormat: ResponseFormat?

    // MARK: - Local-specific properties (not applicable to cloud)

    /// Not applicable to cloud providers.
    public var maxTokens: Int? {
        get { nil }
        set { }
    }

    /// Not applicable to cloud providers.
    public var minTokens: Int? {
        get { nil }
        set { }
    }

    /// Not applicable to cloud providers.
    public var temperature: Float {
        get { 0.7 }
        set { }
    }

    /// Not applicable to cloud providers.
    public var topP: Float {
        get { 0.9 }
        set { }
    }

    /// Not applicable to cloud providers.
    public var topK: Int? {
        get { nil }
        set { }
    }

    /// Not applicable to cloud providers.
    public var repetitionPenalty: Float {
        get { 1.0 }
        set { }
    }

    /// Not applicable to cloud providers.
    public var stopSequences: [String] {
        get { [] }
        set { }
    }

    /// Not applicable to cloud providers.
    public var seed: UInt64? {
        get { nil }
        set { }
    }

    /// Not applicable to cloud providers.
    public var returnLogprobs: Bool {
        get { false }
        set { }
    }

    /// Not applicable to cloud providers.
    public var topLogprobs: Int? {
        get { nil }
        set { }
    }

    /// Not applicable to cloud providers.
    public var tools: [Transcript.ToolDefinition] {
        get { [] }
        set { }
    }

    /// Not applicable to cloud providers.
    public var toolChoice: ToolChoice {
        get { .auto }
        set { }
    }

    /// Not applicable to cloud providers.
    public var parallelToolCalls: ParallelToolMode {
        get { .default }
        set { }
    }

    /// Not applicable to cloud providers.
    public var maxToolCalls: Int? {
        get { nil }
        set { }
    }

    /// Not applicable to cloud providers.
    public var runtimeFeatures: ProviderRuntimeFeatureConfiguration? {
        get { nil }
        set { }
    }

    /// Not applicable to cloud providers.
    public var runtimePolicyOverride: ProviderRuntimePolicyOverride? {
        get { nil }
        set { }
    }

    // MARK: - Initialization

    public init(
        frequencyPenalty: Float = 0.0,
        presencePenalty: Float = 0.0,
        userId: String? = nil,
        serviceTier: ServiceTier? = nil,
        reasoning: ReasoningConfig? = nil,
        responseFormat: ResponseFormat? = nil
    ) {
        self.frequencyPenalty = frequencyPenalty
        self.presencePenalty = presencePenalty
        self.userId = userId
        self.serviceTier = serviceTier
        self.reasoning = reasoning
        self.responseFormat = responseFormat
    }

    // MARK: - Static Presets

    public static let `default` = CloudGenerateConfig()
}

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
public struct GenerateConfig: Sendable, Codable, GenerateConfigProtocol {

    // MARK: - Composed Configuration

    /// Local provider configuration.
    public var local: LocalGenerateConfig

    /// Cloud provider configuration.
    public var cloud: CloudGenerateConfig

    // MARK: - Forwarded Properties (Local)

    public var maxTokens: Int? {
        get { local.maxTokens }
        set { local.maxTokens = newValue }
    }

    public var minTokens: Int? {
        get { local.minTokens }
        set { local.minTokens = newValue }
    }

    public var temperature: Float {
        get { local.temperature }
        set { local.temperature = max(0, min(2, newValue)) }
    }

    public var topP: Float {
        get { local.topP }
        set { local.topP = max(0, min(1, newValue)) }
    }

    public var topK: Int? {
        get { local.topK }
        set { local.topK = newValue }
    }

    public var repetitionPenalty: Float {
        get { local.repetitionPenalty }
        set { local.repetitionPenalty = newValue }
    }

    public var stopSequences: [String] {
        get { local.stopSequences }
        set { local.stopSequences = newValue }
    }

    public var seed: UInt64? {
        get { local.seed }
        set { local.seed = newValue }
    }

    public var returnLogprobs: Bool {
        get { local.returnLogprobs }
        set { local.returnLogprobs = newValue }
    }

    public var topLogprobs: Int? {
        get { local.topLogprobs }
        set { local.topLogprobs = newValue }
    }

    public var tools: [Transcript.ToolDefinition] {
        get { local.tools }
        set { local.tools = newValue }
    }

    public var toolChoice: ToolChoice {
        get { local.toolChoice }
        set { local.toolChoice = newValue }
    }

    public var parallelToolCalls: ParallelToolMode {
        get { local.parallelToolCalls }
        set { local.parallelToolCalls = newValue }
    }

    public var maxToolCalls: Int? {
        get { local.maxToolCalls }
        set { local.maxToolCalls = newValue }
    }

    public var runtimeFeatures: ProviderRuntimeFeatureConfiguration? {
        get { local.runtimeFeatures }
        set { local.runtimeFeatures = newValue }
    }

    public var runtimePolicyOverride: ProviderRuntimePolicyOverride? {
        get { local.runtimePolicyOverride }
        set { local.runtimePolicyOverride = newValue }
    }

    // MARK: - Forwarded Properties (Cloud)

    public var frequencyPenalty: Float {
        get { cloud.frequencyPenalty }
        set { cloud.frequencyPenalty = newValue }
    }

    public var presencePenalty: Float {
        get { cloud.presencePenalty }
        set { cloud.presencePenalty = newValue }
    }

    public var userId: String? {
        get { cloud.userId }
        set { cloud.userId = newValue }
    }

    public var serviceTier: ServiceTier? {
        get { cloud.serviceTier }
        set { cloud.serviceTier = newValue }
    }

    public var reasoning: ReasoningConfig? {
        get { cloud.reasoning }
        set { cloud.reasoning = newValue }
    }

    public var responseFormat: ResponseFormat? {
        get { cloud.responseFormat }
        set { cloud.responseFormat = newValue }
    }

    // MARK: - Initialization

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
        parallelToolCalls: ParallelToolMode = .default,
        maxToolCalls: Int? = nil,
        responseFormat: ResponseFormat? = nil,
        reasoning: ReasoningConfig? = nil,
        runtimeFeatures: ProviderRuntimeFeatureConfiguration? = nil,
        runtimePolicyOverride: ProviderRuntimePolicyOverride? = nil
    ) {
        self.local = LocalGenerateConfig(
            maxTokens: maxTokens,
            minTokens: minTokens,
            temperature: temperature,
            topP: topP,
            topK: topK,
            repetitionPenalty: repetitionPenalty,
            stopSequences: stopSequences,
            seed: seed,
            returnLogprobs: returnLogprobs,
            topLogprobs: topLogprobs,
            tools: tools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls,
            maxToolCalls: maxToolCalls,
            runtimeFeatures: runtimeFeatures,
            runtimePolicyOverride: runtimePolicyOverride
        )
        self.cloud = CloudGenerateConfig(
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            userId: userId,
            serviceTier: serviceTier,
            reasoning: reasoning,
            responseFormat: responseFormat
        )
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case maxTokens, minTokens, temperature, topP, topK
        case repetitionPenalty, frequencyPenalty, presencePenalty
        case stopSequences, seed
        case returnLogprobs, topLogprobs
        case userId, serviceTier
        case tools, toolChoice, parallelToolCalls, maxToolCalls
        case responseFormat, reasoning
        case runtimeFeatures, runtimePolicyOverride
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        let minTokens = try container.decodeIfPresent(Int.self, forKey: .minTokens)
        let temperature = try container.decode(Float.self, forKey: .temperature)
        let topP = try container.decode(Float.self, forKey: .topP)
        let topK = try container.decodeIfPresent(Int.self, forKey: .topK)
        let repetitionPenalty = try container.decode(Float.self, forKey: .repetitionPenalty)
        let frequencyPenalty = try container.decode(Float.self, forKey: .frequencyPenalty)
        let presencePenalty = try container.decode(Float.self, forKey: .presencePenalty)
        let stopSequences = try container.decode([String].self, forKey: .stopSequences)
        let seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        let returnLogprobs = try container.decode(Bool.self, forKey: .returnLogprobs)
        let topLogprobs = try container.decodeIfPresent(Int.self, forKey: .topLogprobs)
        let userId = try container.decodeIfPresent(String.self, forKey: .userId)
        let serviceTier = try container.decodeIfPresent(ServiceTier.self, forKey: .serviceTier)
        let tools = try container.decode([Transcript.ToolDefinition].self, forKey: .tools)
        let toolChoice = try container.decode(ToolChoice.self, forKey: .toolChoice)
        let parallelToolCalls = try container.decodeIfPresent(ParallelToolMode.self, forKey: .parallelToolCalls)
        let maxToolCalls = try container.decodeIfPresent(Int.self, forKey: .maxToolCalls)
        let responseFormat = try container.decodeIfPresent(ResponseFormat.self, forKey: .responseFormat)
        let reasoning = try container.decodeIfPresent(ReasoningConfig.self, forKey: .reasoning)
        let runtimeFeatures = try container.decodeIfPresent(ProviderRuntimeFeatureConfiguration.self, forKey: .runtimeFeatures)
        let runtimePolicyOverride = try container.decodeIfPresent(ProviderRuntimePolicyOverride.self, forKey: .runtimePolicyOverride)

        self.local = LocalGenerateConfig(
            maxTokens: maxTokens,
            minTokens: minTokens,
            temperature: temperature,
            topP: topP,
            topK: topK,
            repetitionPenalty: repetitionPenalty,
            stopSequences: stopSequences,
            seed: seed,
            returnLogprobs: returnLogprobs,
            topLogprobs: topLogprobs,
            tools: tools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls ?? .default,
            maxToolCalls: maxToolCalls,
            runtimeFeatures: runtimeFeatures,
            runtimePolicyOverride: runtimePolicyOverride
        )
        self.cloud = CloudGenerateConfig(
            frequencyPenalty: frequencyPenalty,
            presencePenalty: presencePenalty,
            userId: userId,
            serviceTier: serviceTier,
            reasoning: reasoning,
            responseFormat: responseFormat
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(minTokens, forKey: .minTokens)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(topP, forKey: .topP)
        try container.encodeIfPresent(topK, forKey: .topK)
        try container.encode(repetitionPenalty, forKey: .repetitionPenalty)
        try container.encode(frequencyPenalty, forKey: .frequencyPenalty)
        try container.encode(presencePenalty, forKey: .presencePenalty)
        try container.encode(stopSequences, forKey: .stopSequences)
        try container.encodeIfPresent(seed, forKey: .seed)
        try container.encode(returnLogprobs, forKey: .returnLogprobs)
        try container.encodeIfPresent(topLogprobs, forKey: .topLogprobs)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(serviceTier, forKey: .serviceTier)
        try container.encode(tools, forKey: .tools)
        try container.encode(toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(parallelToolCalls, forKey: .parallelToolCalls)
        try container.encodeIfPresent(maxToolCalls, forKey: .maxToolCalls)
        try container.encodeIfPresent(responseFormat, forKey: .responseFormat)
        try container.encodeIfPresent(reasoning, forKey: .reasoning)
        try container.encodeIfPresent(runtimeFeatures, forKey: .runtimeFeatures)
        try container.encodeIfPresent(runtimePolicyOverride, forKey: .runtimePolicyOverride)
    }

    // MARK: - Static Presets

    public static let `default` = GenerateConfig()

    public static let creative = GenerateConfig(
        temperature: 0.9,
        topP: 0.95,
        frequencyPenalty: 0.5
    )

    public static let precise = GenerateConfig(
        temperature: 0.1,
        topP: 0.5,
        repetitionPenalty: 1.1
    )

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
    ///     .parallelToolCalls(.enabled)
    /// ```
    ///
    /// - Parameter mode: The parallel tool calls mode to use.
    /// - Returns: A new configuration with the updated setting.
    public func parallelToolCalls(_ mode: ParallelToolMode) -> GenerateConfig {
        var copy = self
        copy.parallelToolCalls = mode
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
    @available(*, deprecated, renamed: "parallelToolCalls(_:)", message: "Use parallelToolCalls(.enabled) or parallelToolCalls(.disabled) instead")
    public func parallelToolCalls(_ enabled: Bool) -> GenerateConfig {
        var copy = self
        copy.parallelToolCalls = ParallelToolMode(enabled)
        return copy
    }

    /// Returns a copy with the specified maximum number of tool calls.
    ///
    /// - Parameter value: Maximum number of tool calls allowed per response, or `nil` to unset.
    /// - Returns: A new configuration with the updated setting.
    public func maxToolCalls(_ value: Int?) -> GenerateConfig {
        var copy = self
        copy.maxToolCalls = value
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

    /// Returns a copy with provider/runtime feature overrides.
    ///
    /// - Parameter config: Runtime feature overrides, or `nil` to clear overrides.
    /// - Returns: A new configuration with updated runtime feature controls.
    public func runtimeFeatures(_ config: ProviderRuntimeFeatureConfiguration?) -> GenerateConfig {
        var copy = self
        copy.runtimeFeatures = config
        return copy
    }

    /// Returns a copy with provider/runtime policy overrides.
    ///
    /// - Parameter policy: Runtime policy overrides, or `nil` to clear overrides.
    /// - Returns: A new configuration with updated runtime policy overrides.
    public func runtimePolicyOverride(_ policy: ProviderRuntimePolicyOverride?) -> GenerateConfig {
        var copy = self
        copy.runtimePolicyOverride = policy
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
///     .toolChoice(.named("get_weather"))
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
    case named(String)

    /// Model must use the specified tool.
    ///
    /// Forces the model to call a specific tool by name.
    ///
    /// - Parameter name: The name of the tool to use.
    @available(*, deprecated, renamed: "named")
    public static func tool(name: String) -> ToolChoice {
        .named(name)
    }
}

// MARK: - ParallelToolMode

/// Controls whether the model can make parallel tool calls.
///
/// `ParallelToolMode` allows you to specify whether the model should be allowed
/// to call multiple tools simultaneously within a single response.
///
/// ## Usage
/// ```swift
/// // Allow parallel tool calls (default behavior)
/// let config = GenerateConfig.default
///     .tools([WeatherTool(), SearchTool()])
///     .parallelToolCalls(.enabled)
///
/// // Disable parallel tool calls
/// let config = GenerateConfig.default
///     .tools([WeatherTool()])
///     .parallelToolCalls(.disabled)
///
/// // Use provider default
/// let config = GenerateConfig.default
///     .tools([WeatherTool()])
///     .parallelToolCalls(.default)
/// ```
///
/// ## Provider Support
/// - **OpenAI**: Full support for parallel tool calls
/// - **Anthropic**: May ignore this setting
public enum ParallelToolMode: Sendable, Hashable, Codable {

    /// Allow parallel tool calls (model may call multiple tools at once).
    case enabled

    /// Disallow parallel tool calls (model calls one tool at a time).
    case disabled

    /// Use the provider's default behavior.
    ///
    /// This is equivalent to not specifying the setting.
    case `default`

    /// Converts the mode to an optional boolean for provider compatibility.
    ///
    /// - Returns: `true` for `.enabled`, `false` for `.disabled`, `nil` for `.default`.
    public var boolValue: Bool? {
        switch self {
        case .enabled: return true
        case .disabled: return false
        case .default: return nil
        }
    }

    /// Creates a mode from an optional boolean.
    ///
    /// - Parameter bool: `true` for `.enabled`, `false` for `.disabled`, `nil` for `.default`.
    public init(_ bool: Bool?) {
        switch bool {
        case .some(true): self = .enabled
        case .some(false): self = .disabled
        case .none: self = .default
        }
    }
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
