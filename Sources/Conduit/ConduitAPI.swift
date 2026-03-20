// ConduitAPI.swift
// Conduit
//
// Concise facade API for agent-first and human-first ergonomics.

import Foundation

// MARK: - Short Names

/// Concise alias for generation options.
public typealias RunOptions = GenerateConfig

/// Unified model descriptor used by the facade API.
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

    public init(stringLiteral value: StringLiteralType) {
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
    init(_ identifier: ModelIdentifier) {
        switch identifier {
        case .openAI(let id):
            self = .openAI(id)
        case .anthropic(let id):
            self = .anthropic(id)
        case .mlx(let id):
            self = .mlx(id)
        case .mlxLocal(let path):
            self = .mlxLocal(path)
        case .llama(let path):
            self = .llama(path)
        case .coreml(let path):
            self = .coreML(path)
        case .huggingFace(let id):
            self = .huggingFace(id)
        case .foundationModels:
            self = .foundationModels
        case .kimi(let id):
            self = .kimi(id)
        case .miniMax(let id):
            self = .miniMax(id)
        }
    }

    var asModelIdentifier: ModelIdentifier? {
        switch family {
        case .mlx:
            return .mlx(id)
        case .mlxLocal:
            return .mlxLocal(id)
        case .llama:
            return .llama(id)
        case .coreML:
            return .coreml(id)
        case .huggingFace:
            return .huggingFace(id)
        case .foundationModels:
            return .foundationModels
        case .kimi:
            return .kimi(id)
        case .openAI, .anthropic, .miniMax, .custom:
            return nil
        }
    }
}

// MARK: - Result Builder

/// Builder for concise tool registration in session configuration.
@resultBuilder
public enum ToolSetBuilder {
    public static func buildBlock(_ components: [any Tool]...) -> [any Tool] {
        components.flatMap { $0 }
    }

    public static func buildExpression<T: Tool>(_ expression: T) -> [any Tool] {
        [expression]
    }

    public static func buildExpression(_ expression: [any Tool]) -> [any Tool] {
        expression
    }

    public static func buildOptional(_ component: [any Tool]?) -> [any Tool] {
        component ?? []
    }

    public static func buildEither(first component: [any Tool]) -> [any Tool] {
        component
    }

    public static func buildEither(second component: [any Tool]) -> [any Tool] {
        component
    }

    public static func buildArray(_ components: [[any Tool]]) -> [any Tool] {
        components.flatMap { $0 }
    }
}

// MARK: - Provider

/// Minimal provider wrapper built from concrete Conduit providers.
public struct Provider: Sendable {
    fileprivate let makeSession: @Sendable (Model, Session.Options) throws -> Session

    private init(
        makeSession: @escaping @Sendable (Model, Session.Options) throws -> Session
    ) {
        self.makeSession = makeSession
    }

    #if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
    /// Facade options for OpenAI-compatible providers.
    public struct OpenAIOptions: Sendable, Hashable {
        public enum APIStyle: Sendable, Hashable, Codable {
            case chat
            case responses
        }

        public var timeout: TimeInterval
        public var maxRetries: Int
        public var headers: [String: String]
        public var organizationID: String?
        public var api: APIStyle

        public init(
            timeout: TimeInterval = 60,
            maxRetries: Int = 3,
            headers: [String: String] = [:],
            organizationID: String? = nil,
            api: APIStyle = .chat
        ) {
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.headers = headers
            self.organizationID = organizationID
            self.api = api
        }
    }
    #endif

    #if CONDUIT_TRAIT_ANTHROPIC
    /// Facade options for Anthropic providers.
    public struct AnthropicOptions: Sendable, Hashable {
        public var baseURL: URL
        public var apiVersion: String
        public var timeout: TimeInterval
        public var maxRetries: Int
        public var supportsStreaming: Bool
        public var supportsVision: Bool
        public var supportsExtendedThinking: Bool
        public var thinkingBudgetTokens: Int?

        public init(
            baseURL: URL = URL(string: "https://api.anthropic.com")!,
            apiVersion: String = "2023-06-01",
            timeout: TimeInterval = 60,
            maxRetries: Int = 3,
            supportsStreaming: Bool = true,
            supportsVision: Bool = true,
            supportsExtendedThinking: Bool = true,
            thinkingBudgetTokens: Int? = nil
        ) {
            self.baseURL = baseURL
            self.apiVersion = apiVersion
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.supportsStreaming = supportsStreaming
            self.supportsVision = supportsVision
            self.supportsExtendedThinking = supportsExtendedThinking
            self.thinkingBudgetTokens = thinkingBudgetTokens
        }
    }
    #endif

    #if CONDUIT_TRAIT_MLX
    /// Facade options for MLX local inference.
    public struct MLXOptions: Sendable, Hashable {
        public var memoryLimit: ByteCount?
        public var useMemoryMapping: Bool
        public var kvCacheLimit: Int?
        public var prefillStepSize: Int
        public var kvQuantizationBits: Int?
        public var runtimePolicy: ProviderRuntimePolicy

        public init(
            memoryLimit: ByteCount? = nil,
            useMemoryMapping: Bool = true,
            kvCacheLimit: Int? = nil,
            prefillStepSize: Int = 512,
            kvQuantizationBits: Int? = nil,
            runtimePolicy: ProviderRuntimePolicy = .default
        ) {
            self.memoryLimit = memoryLimit
            self.useMemoryMapping = useMemoryMapping
            self.kvCacheLimit = kvCacheLimit
            self.prefillStepSize = prefillStepSize
            self.kvQuantizationBits = kvQuantizationBits
            self.runtimePolicy = runtimePolicy
        }
    }
    #endif

    /// Facade options for HuggingFace providers.
    public struct HuggingFaceOptions: Sendable, Hashable {
        public var baseURL: URL
        public var timeout: TimeInterval
        public var maxRetries: Int
        public var retryBaseDelay: TimeInterval

        public init(
            baseURL: URL = URL(string: "https://api-inference.huggingface.co")!,
            timeout: TimeInterval = 60,
            maxRetries: Int = 3,
            retryBaseDelay: TimeInterval = 1.0
        ) {
            self.baseURL = baseURL
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.retryBaseDelay = retryBaseDelay
        }
    }

    /// Creates a custom provider wrapper for maximum extensibility.
    ///
    /// - Parameters:
    ///   - provider: Any concrete provider that supports text generation.
    ///   - mapModel: Maps facade `Model` into the provider's concrete model ID type.
    ///   - prepare: Optional provider-specific preparation hook (e.g. local warmup).
    ///   - release: Optional provider-specific resource release hook.
    public static func custom<P: AIProvider & TextGenerator>(
        _ provider: P,
        mapModel: @escaping @Sendable (Model) throws -> P.ModelID,
        prepare: (@Sendable (P.ModelID) async throws -> Void)? = nil,
        release: (@Sendable () async -> Void)? = nil
    ) -> Self {
        let factory: @Sendable (Model, Session.Options) throws -> Session = { (model: Model, options: Session.Options) throws -> Session in
            let mapped = try mapModel(model)
            let prepareHook: (@Sendable () async throws -> Void)?
            if let prepare {
                prepareHook = { try await prepare(mapped) }
            } else {
                prepareHook = nil
            }
            return Session.build(
                provider: provider,
                model: mapped,
                options: options,
                prepare: prepareHook,
                release: release
            )
        }

        return Provider(makeSession: factory)
    }
}

// MARK: Provider Factories

extension Provider {
    #if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
    public static func openAI(
        apiKey: String,
        configure: (inout OpenAIOptions) -> Void = { _ in }
    ) -> Self {
        var options = OpenAIOptions()
        configure(&options)

        var configuration = OpenAIConfiguration.openAI(apiKey: apiKey)
        configuration.timeout = max(0, options.timeout)
        configuration.maxRetries = max(0, options.maxRetries)
        configuration.defaultHeaders = options.headers
        configuration.organizationID = options.organizationID
        configuration.apiVariant = options.api == .responses ? .responses : .chatCompletions
        let provider = OpenAIProvider(configuration: configuration)

        return .custom(provider) { model in
            .openAI(model.id)
        }
    }

    public static func openRouter(
        apiKey: String,
        configure: (inout OpenAIOptions) -> Void = { _ in }
    ) -> Self {
        var options = OpenAIOptions()
        configure(&options)

        var configuration = OpenAIConfiguration.openRouter(apiKey: apiKey)
        configuration.timeout = max(0, options.timeout)
        configuration.maxRetries = max(0, options.maxRetries)
        configuration.defaultHeaders = options.headers
        configuration.organizationID = options.organizationID
        configuration.apiVariant = options.api == .responses ? .responses : .chatCompletions
        let provider = OpenAIProvider(configuration: configuration)

        return .custom(provider) { model in
            .openAI(model.id)
        }
    }
    #endif

    #if CONDUIT_TRAIT_ANTHROPIC
    public static func anthropic(
        apiKey: String,
        configure: (inout AnthropicOptions) -> Void = { _ in }
    ) -> Self {
        var options = AnthropicOptions()
        configure(&options)

        var configuration = AnthropicConfiguration.standard(apiKey: apiKey)
        configuration.baseURL = options.baseURL
        configuration.apiVersion = options.apiVersion
        configuration.timeout = max(0, options.timeout)
        configuration.maxRetries = max(0, options.maxRetries)
        configuration.supportsStreaming = options.supportsStreaming
        configuration.supportsVision = options.supportsVision
        configuration.supportsExtendedThinking = options.supportsExtendedThinking
        configuration.thinkingConfig = options.thinkingBudgetTokens.map {
            ThinkingConfiguration(enabled: true, budgetTokens: max(0, $0))
        }
        let provider = AnthropicProvider(configuration: configuration)

        return .custom(provider) { model in
            .anthropic(model.id)
        }
    }
    #endif

    #if CONDUIT_TRAIT_MLX
    public static func mlx(
        configure: (inout MLXOptions) -> Void = { _ in }
    ) -> Self {
        var options = MLXOptions()
        configure(&options)

        var configuration = MLXConfiguration(
            memoryLimit: options.memoryLimit,
            useMemoryMapping: options.useMemoryMapping,
            kvCacheLimit: options.kvCacheLimit,
            prefillStepSize: options.prefillStepSize,
            useQuantizedKVCache: options.kvQuantizationBits != nil,
            kvQuantizationBits: options.kvQuantizationBits ?? 4,
            runtimePolicy: options.runtimePolicy
        )
        let provider = MLXProvider(configuration: configuration)

        return .custom(
            provider,
            mapModel: { model in
                switch model.family {
                case .mlx, .custom:
                    return .mlx(model.id)
                case .mlxLocal:
                    return .mlxLocal(model.id)
                default:
                    throw AIError.invalidInput("MLX provider requires .mlx(...) or .mlxLocal(...) models")
                }
            },
            prepare: { modelID in
                try await provider.prepare(model: modelID)
            },
            release: {
                await provider.releaseResources()
            }
        )
    }
    #endif

    public static func huggingFace(
        token: String? = nil,
        configure: (inout HuggingFaceOptions) -> Void = { _ in }
    ) -> Self {
        var options = HuggingFaceOptions()
        configure(&options)

        var configuration = HFConfiguration.default
        if let token {
            configuration = configuration.token(.static(token))
        }
        configuration.baseURL = options.baseURL
        configuration.timeout = max(0, options.timeout)
        configuration.maxRetries = max(0, options.maxRetries)
        configuration.retryBaseDelay = max(0, options.retryBaseDelay)
        let provider = HuggingFaceProvider(configuration: configuration)

        return .custom(provider) { model in
            guard model.family == .huggingFace || model.family == .custom else {
                throw AIError.invalidInput("HuggingFace provider requires .huggingFace(...) models")
            }
            return .huggingFace(model.id)
        }
    }

    #if CONDUIT_TRAIT_KIMI && CONDUIT_TRAIT_OPENAI
    public static func kimi(apiKey: String) -> Self {
        let provider = KimiProvider(apiKey: apiKey)

        return .custom(provider) { model in
            guard model.family == .kimi || model.family == .custom else {
                throw AIError.invalidInput("Kimi provider requires .kimi(...) models")
            }
            return .kimi(model.id)
        }
    }
    #endif

    #if CONDUIT_TRAIT_MINIMAX && CONDUIT_TRAIT_OPENAI
    public static func miniMax(apiKey: String? = nil) -> Self {
        let provider = MiniMaxProvider(apiKey: apiKey)

        return .custom(provider) { model in
            guard model.family == .miniMax || model.family == .custom else {
                throw AIError.invalidInput("MiniMax provider requires .miniMax(...) models")
            }
            return .miniMax(model.id)
        }
    }
    #endif
}

// MARK: - Conduit

/// Top-level concise entry point.
public struct Conduit: Sendable {
    public let provider: Provider

    public init(_ provider: Provider) {
        self.provider = provider
    }

    /// Creates a stateful session with optional closure-based configuration.
    public func session(
        model: Model,
        configure: (inout Session.Options) -> Void = { _ in }
    ) throws -> Session {
        var options = Session.Options()
        configure(&options)
        return try provider.makeSession(model, options)
    }
}

// MARK: - Session

/// Minimal, stateful conversational interface.
public struct Session: Sendable {
    public struct Options: Sendable {
        public var run: RunOptions
        fileprivate var tools: [any Tool]
        fileprivate var toolRetryPolicy: ToolExecutor.RetryPolicy
        fileprivate var maxToolRounds: Int

        public init(run: RunOptions = .default) {
            self.run = run
            self.tools = []
            self.toolRetryPolicy = .none
            self.maxToolRounds = 8
        }

        /// Mutate run options using a closure for concise composition.
        public mutating func run(_ update: (inout RunOptions) -> Void) {
            update(&run)
        }

        /// Register tools via result-builder closure.
        public mutating func tools(@ToolSetBuilder _ build: () -> [any Tool]) {
            self.tools = build()
        }

        public mutating func toolRetry(_ policy: ToolExecutor.RetryPolicy) {
            self.toolRetryPolicy = policy
        }

        public mutating func maxToolRounds(_ value: Int) {
            self.maxToolRounds = max(0, value)
        }
    }

    /// Typed output wrapper for `run(_:as:)`.
    public struct Output<Value: Sendable>: Sendable {
        public let text: String
        public let value: Value
    }

    private let runText: @Sendable (String) async throws -> String
    private let streamText: @Sendable (String) -> AsyncThrowingStream<String, Error>
    private let cancelGeneration: @Sendable () async -> Void
    private let prepareHook: (@Sendable () async throws -> Void)?
    private let releaseHook: (@Sendable () async -> Void)?

    private init(
        runText: @escaping @Sendable (String) async throws -> String,
        streamText: @escaping @Sendable (String) -> AsyncThrowingStream<String, Error>,
        cancelGeneration: @escaping @Sendable () async -> Void,
        prepareHook: (@Sendable () async throws -> Void)?,
        releaseHook: (@Sendable () async -> Void)?
    ) {
        self.runText = runText
        self.streamText = streamText
        self.cancelGeneration = cancelGeneration
        self.prepareHook = prepareHook
        self.releaseHook = releaseHook
    }

    @inline(__always)
    public func run(_ prompt: String) async throws -> String {
        try await runText(prompt)
    }

    /// Runs a prompt and decodes the textual response into a typed value.
    @inline(__always)
    public func run<T: Decodable & Sendable>(
        _ prompt: String,
        as type: T.Type = T.self,
        decoder: JSONDecoder = .init()
    ) async throws -> Output<T> {
        let text = try await runText(prompt)

        do {
            let value = try decoder.decode(T.self, from: Data(text.utf8))
            return Output(text: text, value: value)
        } catch {
            throw AIError.invalidInput(
                "Failed to decode response as \(String(describing: T.self)): \(error.localizedDescription)"
            )
        }
    }

    /// Streams text with opaque sequence typing for concise call sites.
    @inline(__always)
    public func stream(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        streamText(prompt)
    }

    @inline(__always)
    public func cancel() async {
        await cancelGeneration()
    }

    /// Prepares the session for low-latency interaction when supported.
    ///
    /// This is a no-op for providers that don't expose preparation hooks.
    @inline(__always)
    public func prepare() async throws {
        try await prepareHook?()
    }

    /// Releases provider-managed resources when supported.
    ///
    /// This is a no-op for providers that don't expose release hooks.
    @inline(__always)
    public func releaseResources() async {
        await releaseHook?()
    }
}

extension Session {
    fileprivate static func build<P: AIProvider & TextGenerator>(
        provider: P,
        model: P.ModelID,
        options: Options,
        prepare: (@Sendable () async throws -> Void)? = nil,
        release: (@Sendable () async -> Void)? = nil
    ) -> Session {
        let session = ChatSession(provider: provider, model: model, config: options.run)

        if !options.tools.isEmpty {
            session.toolExecutor = ToolExecutor(tools: options.tools)
            session.toolCallRetryPolicy = options.toolRetryPolicy
            session.maxToolCallRounds = options.maxToolRounds
        }

        return Session(
            runText: { prompt in
                try await session.send(prompt)
            },
            streamText: { prompt in
                session.stream(prompt)
            },
            cancelGeneration: {
                await session.cancel()
            },
            prepareHook: prepare,
            releaseHook: release
        )
    }
}
