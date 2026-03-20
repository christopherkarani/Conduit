// ConduitFacade.swift
// Conduit

import Foundation
import ConduitAdvanced

public typealias AnyTool = any ConduitAdvanced.Tool
public typealias GeneratedImage = ConduitAdvanced.GeneratedImage
public typealias ImageGenerationConfig = ConduitAdvanced.ImageGenerationConfig
public typealias ImageGenerationProgress = ConduitAdvanced.ImageGenerationProgress

public let conduitVersion = ConduitAdvanced.conduitVersion

// MARK: - Model

public struct Model: Sendable, Hashable, Codable, ExpressibleByStringLiteral {
    public enum Family: String, Sendable, Hashable, Codable, CaseIterable {
        case openAI
        case anthropic
        case huggingFace
        case mlx
        case mlxLocal
        case llama
        case coreML
        case foundationModels
        case kimi
        case miniMax
        case custom
    }

    public let id: String
    public let family: Family

    public init(_ id: String, family: Family = .custom) {
        self.id = id
        self.family = family
    }

    public init(stringLiteral value: String) {
        self.id = value
        self.family = .custom
    }

    public static func openAI(_ id: String) -> Self { .init(id, family: .openAI) }
    public static func anthropic(_ id: String) -> Self { .init(id, family: .anthropic) }
    public static func huggingFace(_ id: String) -> Self { .init(id, family: .huggingFace) }
    public static func mlx(_ id: String) -> Self { .init(id, family: .mlx) }
    public static func mlxLocal(_ path: String) -> Self { .init(path, family: .mlxLocal) }
    public static func llama(_ path: String) -> Self { .init(path, family: .llama) }
    public static func coreML(_ path: String) -> Self { .init(path, family: .coreML) }
    public static func kimi(_ id: String) -> Self { .init(id, family: .kimi) }
    public static func miniMax(_ id: String) -> Self { .init(id, family: .miniMax) }
    public static var foundationModels: Self { .init("apple-foundation-models", family: .foundationModels) }
}

extension Model {
    fileprivate init(_ raw: ConduitAdvanced.Model) {
        self.id = raw.id
        self.family = Family(rawValue: raw.family.rawValue) ?? .custom
    }

    fileprivate var raw: ConduitAdvanced.Model {
        switch family {
        case .openAI: return .openAI(id)
        case .anthropic: return .anthropic(id)
        case .huggingFace: return .huggingFace(id)
        case .mlx: return .mlx(id)
        case .mlxLocal: return .mlxLocal(id)
        case .llama: return .llama(id)
        case .coreML: return .coreML(id)
        case .foundationModels: return .foundationModels
        case .kimi: return .kimi(id)
        case .miniMax: return .miniMax(id)
        case .custom: return .init(id, family: .custom)
        }
    }
}

// MARK: - Run Options

public struct RunOptions: Sendable, Hashable {
    public var maxTokens: Int?
    public var temperature: Float
    public var topP: Float
    public var stopSequences: [String]
    public var seed: UInt64?

    public init(
        maxTokens: Int? = nil,
        temperature: Float = 1.0,
        topP: Float = 1.0,
        stopSequences: [String] = [],
        seed: UInt64? = nil
    ) {
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.stopSequences = stopSequences
        self.seed = seed
    }

    public static let `default` = RunOptions()
}

extension RunOptions {
    fileprivate init(_ raw: ConduitAdvanced.GenerateConfig) {
        self.maxTokens = raw.maxTokens
        self.temperature = raw.temperature
        self.topP = raw.topP
        self.stopSequences = raw.stopSequences
        self.seed = raw.seed
    }

    fileprivate var raw: ConduitAdvanced.GenerateConfig {
        var config = ConduitAdvanced.GenerateConfig.default
        config.maxTokens = maxTokens
        config.temperature = temperature
        config.topP = topP
        config.stopSequences = stopSequences
        config.seed = seed
        return config
    }
}

// MARK: - Tool Builder

@resultBuilder
public enum ToolSetBuilder {
    public static func buildBlock(_ components: [AnyTool]...) -> [AnyTool] {
        components.flatMap { $0 }
    }

    public static func buildExpression<T: ConduitAdvanced.Tool>(_ expression: T) -> [AnyTool] {
        [expression]
    }

    public static func buildExpression(_ expression: [AnyTool]) -> [AnyTool] {
        expression
    }

    public static func buildOptional(_ component: [AnyTool]?) -> [AnyTool] {
        component ?? []
    }

    public static func buildEither(first component: [AnyTool]) -> [AnyTool] {
        component
    }

    public static func buildEither(second component: [AnyTool]) -> [AnyTool] {
        component
    }

    public static func buildArray(_ components: [[AnyTool]]) -> [AnyTool] {
        components.flatMap { $0 }
    }
}

// MARK: - Provider

public struct Provider {
    fileprivate let raw: ConduitAdvanced.Provider
    fileprivate let imageGenerator: AnyImageGenerator?

    private init(
        raw: ConduitAdvanced.Provider,
        imageGenerator: AnyImageGenerator? = nil
    ) {
        self.raw = raw
        self.imageGenerator = imageGenerator
    }

    #if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
    public struct OpenAIOptions {
        public enum APIStyle: String, Sendable, Hashable, Codable {
            case chat
            case responses
        }

        public var timeout: TimeInterval
        public var maxRetries: Int
        public var api: APIStyle

        public init(timeout: TimeInterval = 60, maxRetries: Int = 3, api: APIStyle = .chat) {
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.api = api
        }
    }

    public static func openAI(
        apiKey: String,
        configure: (inout OpenAIOptions) -> Void = { _ in },
        expert: ((inout ConduitAdvanced.Provider.OpenAIOptions) -> Void)? = nil
    ) -> Self {
        var options = OpenAIOptions()
        configure(&options)

        let raw = ConduitAdvanced.Provider.openAI(apiKey: apiKey) { raw in
            raw.timeout = options.timeout
            raw.maxRetries = options.maxRetries
            raw.api = options.api == .responses ? .responses : .chat
            expert?(&raw)
        }

        return .init(
            raw: raw,
            imageGenerator: AnyImageGenerator(ConduitAdvanced.OpenAIProvider(apiKey: apiKey))
        )
    }

    public static func openRouter(
        apiKey: String,
        configure: (inout OpenAIOptions) -> Void = { _ in },
        expert: ((inout ConduitAdvanced.Provider.OpenAIOptions) -> Void)? = nil
    ) -> Self {
        var options = OpenAIOptions()
        configure(&options)

        let raw = ConduitAdvanced.Provider.openRouter(apiKey: apiKey) { raw in
            raw.timeout = options.timeout
            raw.maxRetries = options.maxRetries
            raw.api = options.api == .responses ? .responses : .chat
            expert?(&raw)
        }

        return .init(raw: raw)
    }
    #endif

    #if CONDUIT_TRAIT_ANTHROPIC
    public struct AnthropicOptions {
        public var timeout: TimeInterval
        public var maxRetries: Int
        public var thinkingBudgetTokens: Int?

        public init(timeout: TimeInterval = 60, maxRetries: Int = 3, thinkingBudgetTokens: Int? = nil) {
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.thinkingBudgetTokens = thinkingBudgetTokens
        }
    }

    public static func anthropic(
        apiKey: String,
        configure: (inout AnthropicOptions) -> Void = { _ in },
        expert: ((inout ConduitAdvanced.Provider.AnthropicOptions) -> Void)? = nil
    ) -> Self {
        var options = AnthropicOptions()
        configure(&options)

        let raw = ConduitAdvanced.Provider.anthropic(apiKey: apiKey) { raw in
            raw.timeout = options.timeout
            raw.maxRetries = options.maxRetries
            raw.thinkingBudgetTokens = options.thinkingBudgetTokens
            expert?(&raw)
        }

        return .init(raw: raw)
    }
    #endif

    #if CONDUIT_TRAIT_MLX
    public struct MLXOptions {
        public var memoryLimit: ConduitAdvanced.ByteCount?
        public var prefillStepSize: Int
        public var kvQuantizationBits: Int?

        public init(
            memoryLimit: ConduitAdvanced.ByteCount? = nil,
            prefillStepSize: Int = 512,
            kvQuantizationBits: Int? = nil
        ) {
            self.memoryLimit = memoryLimit
            self.prefillStepSize = prefillStepSize
            self.kvQuantizationBits = kvQuantizationBits
        }
    }

    public static func mlx(
        configure: (inout MLXOptions) -> Void = { _ in },
        expert: ((inout ConduitAdvanced.Provider.MLXOptions) -> Void)? = nil
    ) -> Self {
        var options = MLXOptions()
        configure(&options)

        let raw = ConduitAdvanced.Provider.mlx { raw in
            raw.memoryLimit = options.memoryLimit
            raw.prefillStepSize = options.prefillStepSize
            raw.kvQuantizationBits = options.kvQuantizationBits
            expert?(&raw)
        }

        return .init(
            raw: raw,
            imageGenerator: AnyImageGenerator(ConduitAdvanced.MLXImageProvider())
        )
    }
    #endif

    public struct HuggingFaceOptions {
        public var timeout: TimeInterval
        public var maxRetries: Int

        public init(timeout: TimeInterval = 60, maxRetries: Int = 3) {
            self.timeout = timeout
            self.maxRetries = maxRetries
        }
    }

    public static func huggingFace(
        token: String? = nil,
        configure: (inout HuggingFaceOptions) -> Void = { _ in },
        expert: ((inout ConduitAdvanced.Provider.HuggingFaceOptions) -> Void)? = nil
    ) -> Self {
        var options = HuggingFaceOptions()
        configure(&options)

        let raw = ConduitAdvanced.Provider.huggingFace(token: token) { raw in
            raw.timeout = options.timeout
            raw.maxRetries = options.maxRetries
            expert?(&raw)
        }

        let imageGenerator: AnyImageGenerator
        if let token {
            imageGenerator = AnyImageGenerator(ConduitAdvanced.HuggingFaceProvider(token: token))
        } else {
            imageGenerator = AnyImageGenerator(ConduitAdvanced.HuggingFaceProvider())
        }

        return .init(raw: raw, imageGenerator: imageGenerator)
    }

    #if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
    public static func kimi(apiKey: String) -> Self {
        .init(raw: ConduitAdvanced.Provider.kimi(apiKey: apiKey))
    }
    #endif

    #if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
    public static func miniMax(apiKey: String? = nil) -> Self {
        .init(raw: ConduitAdvanced.Provider.miniMax(apiKey: apiKey))
    }
    #endif

    public static func custom<P: ConduitAdvanced.AIProvider & ConduitAdvanced.TextGenerator>(
        _ provider: P,
        mapModel: @escaping @Sendable (Model) throws -> P.ModelID,
        prepare: (@Sendable (P.ModelID) async throws -> Void)? = nil,
        release: (@Sendable () async -> Void)? = nil
    ) -> Self {
        .init(
            raw: ConduitAdvanced.Provider.custom(
                provider,
                mapModel: { advancedModel in
                    try mapModel(Model(advancedModel))
                },
                prepare: prepare,
                release: release
            )
        )
    }
}

// MARK: - Conduit

public struct Conduit {
    public let provider: Provider
    private let raw: ConduitAdvanced.Conduit

    public init(_ provider: Provider) {
        self.provider = provider
        self.raw = ConduitAdvanced.Conduit(provider.raw)
    }

    public func session(
        model: Model,
        configure: (inout Session.Options) -> Void = { _ in }
    ) throws -> Session {
        var options = Session.Options()
        configure(&options)

        let advancedSession = try raw.session(model: model.raw) { advancedOptions in
            advancedOptions = options.raw
        }
        return Session(advancedSession)
    }

    public var images: Images {
        Images(provider: provider)
    }

    public struct Images {
        private let provider: Provider

        fileprivate init(provider: Provider) {
            self.provider = provider
        }

        public var isAvailable: Bool {
            provider.imageGenerator != nil
        }

        public func generate(
            prompt: String,
            negativePrompt: String? = nil,
            config: ImageGenerationConfig = .default,
            onProgress: (@Sendable (ImageGenerationProgress) -> Void)? = nil
        ) async throws -> GeneratedImage {
            guard let generator = provider.imageGenerator else {
                throw ConduitAdvanced.AIError.invalidInput(
                    "Selected provider does not expose image generation in facade mode"
                )
            }

            return try await generator.generateImage(
                prompt: prompt,
                negativePrompt: negativePrompt,
                config: config,
                onProgress: onProgress
            )
        }

        public func cancel() async {
            guard let generator = provider.imageGenerator else { return }
            await generator.cancelGeneration()
        }
    }
}

// MARK: - Session

public struct Session {
    public enum ToolRetryCondition: String, Sendable, Hashable, Codable {
        case never
        case retryableAIErrors
        case allFailuresExceptCancellation

        fileprivate var raw: ConduitAdvanced.ToolExecutor.RetryPolicy.Condition {
            switch self {
            case .never:
                return .never
            case .retryableAIErrors:
                return .retryableAIErrors
            case .allFailuresExceptCancellation:
                return .allFailuresExceptCancellation
            }
        }
    }

    public struct Options {
        fileprivate var raw: ConduitAdvanced.Session.Options

        public init(run: RunOptions = .default) {
            self.raw = .init(run: run.raw)
        }

        public var run: RunOptions {
            get { RunOptions(raw.run) }
            set {
                raw.run { config in
                    config = newValue.raw
                }
            }
        }

        public mutating func run(_ update: (inout RunOptions) -> Void) {
            var value = RunOptions(raw.run)
            update(&value)
            raw.run { config in
                config = value.raw
            }
        }

        public mutating func tools(@ToolSetBuilder _ build: () -> [AnyTool]) {
            raw.tools {
                build()
            }
        }

        public mutating func toolRetry(
            maxAttempts: Int = 1,
            condition: ToolRetryCondition = .retryableAIErrors
        ) {
            raw.toolRetry(
                .init(
                    maxAttempts: maxAttempts,
                    condition: condition.raw
                )
            )
        }

        public mutating func maxToolRounds(_ value: Int) {
            raw.maxToolRounds(value)
        }
    }

    public struct Output<Value: Sendable>: Sendable {
        public let text: String
        public let value: Value
    }

    private let raw: ConduitAdvanced.Session

    fileprivate init(_ raw: ConduitAdvanced.Session) {
        self.raw = raw
    }

    @inline(__always)
    public func run(_ prompt: String) async throws -> String {
        try await raw.run(prompt)
    }

    @inline(__always)
    public func run<T: Decodable & Sendable>(
        _ prompt: String,
        as type: T.Type = T.self,
        decoder: JSONDecoder = .init()
    ) async throws -> Output<T> {
        let output = try await raw.run(prompt, as: type, decoder: decoder)
        return Output(text: output.text, value: output.value)
    }

    @inline(__always)
    public func stream(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        raw.stream(prompt)
    }

    @inline(__always)
    public func cancel() async {
        await raw.cancel()
    }

    @inline(__always)
    public func prepare() async throws {
        try await raw.prepare()
    }

    @inline(__always)
    public func releaseResources() async {
        await raw.releaseResources()
    }
}

// MARK: - Any Image Generator

fileprivate struct AnyImageGenerator: Sendable {
    private let generateImpl: @Sendable (
        String,
        String?,
        ImageGenerationConfig,
        (@Sendable (ImageGenerationProgress) -> Void)?
    ) async throws -> GeneratedImage

    private let cancelImpl: @Sendable () async -> Void

    init(_ base: any ConduitAdvanced.ImageGenerator) {
        self.generateImpl = { prompt, negativePrompt, config, onProgress in
            try await base.generateImage(
                prompt: prompt,
                negativePrompt: negativePrompt,
                config: config,
                onProgress: onProgress
            )
        }

        self.cancelImpl = {
            await base.cancelGeneration()
        }
    }

    func generateImage(
        prompt: String,
        negativePrompt: String?,
        config: ImageGenerationConfig,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)?
    ) async throws -> GeneratedImage {
        try await generateImpl(prompt, negativePrompt, config, onProgress)
    }

    func cancelGeneration() async {
        await cancelImpl()
    }
}
