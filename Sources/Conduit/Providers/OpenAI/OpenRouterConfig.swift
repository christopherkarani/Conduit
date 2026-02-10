// OpenRouterConfig.swift
// Conduit
//
// OpenRouter-specific configuration for routing and fallbacks.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation

// MARK: - OpenRouterRoutingConfig

/// Configuration for OpenRouter's model routing features.
///
/// OpenRouter is an aggregator that provides access to multiple AI providers
/// through a single API. This configuration controls which providers to use,
/// fallback behavior, and routing preferences.
///
/// ## Usage
///
/// ### Basic Routing
/// ```swift
/// let config = OpenRouterRoutingConfig(
///     providers: [.anthropic, .openai],
///     fallbacks: true
/// )
/// ```
///
/// ### Latency-Based Routing
/// ```swift
/// let config = OpenRouterRoutingConfig(
///     routeByLatency: true,
///     fallbacks: true
/// )
/// ```
///
/// ### Provider Requirements for JSON
/// ```swift
/// let config = OpenRouterRoutingConfig(
///     providers: [.openai, .anthropic],
///     requireProvidersForJSON: true
/// )
/// ```
///
/// ## Headers
///
/// The configuration adds these headers to OpenRouter requests:
/// - `HTTP-Referer`: Your site URL (for rankings)
/// - `X-Title`: Your app name (for rankings)
/// - Provider routing headers
///
/// ## Model Format
///
/// OpenRouter uses `provider/model` format:
/// - `openai/gpt-4-turbo`
/// - `anthropic/claude-3-opus`
/// - `google/gemini-pro`
public struct OpenRouterRoutingConfig: Sendable, Hashable {

    // MARK: - Properties

    /// Preferred providers for routing, in priority order.
    ///
    /// When specified, OpenRouter will attempt to route requests
    /// to these providers first, falling back to others if needed.
    ///
    /// - Note: Set to `nil` to use OpenRouter's default routing.
    public var providers: [OpenRouterProvider]?

    /// Enable automatic fallbacks on provider failure.
    ///
    /// When `true`, if the primary provider fails, OpenRouter will
    /// automatically retry with another provider.
    ///
    /// Default: `true`
    public var fallbacks: Bool

    /// Route requests based on latency.
    ///
    /// When `true`, OpenRouter will prefer providers with lower latency.
    ///
    /// Default: `false`
    public var routeByLatency: Bool

    /// Require specified providers for JSON mode.
    ///
    /// When `true`, requests using JSON mode will only be routed
    /// to providers in the `providers` list.
    ///
    /// Default: `false`
    public var requireProvidersForJSON: Bool

    /// Your site URL for OpenRouter rankings.
    ///
    /// OpenRouter tracks usage by site for their leaderboards.
    /// This is sent in the `HTTP-Referer` header.
    public var siteURL: URL?

    /// Your app name for OpenRouter rankings.
    ///
    /// This is sent in the `X-Title` header.
    public var appName: String?

    /// Custom route tag for grouping requests.
    ///
    /// - Important: OpenRouter's request API does not currently support arbitrary tagging.
    ///   This property is retained for backward compatibility but is not sent in requests
    ///   unless it matches a valid `data_collection` value ("allow" or "deny").
    public var routeTag: String?

    /// Controls whether OpenRouter and upstream providers may store prompts/completions.
    ///
    /// This maps to OpenRouter's `provider.data_collection` field.
    public var dataCollection: OpenRouterDataCollection?

    // MARK: - Initialization

    /// Creates an OpenRouter routing configuration.
    ///
    /// - Parameters:
    ///   - providers: Preferred providers in priority order. Default: `nil` (auto-route)
    ///   - fallbacks: Enable automatic fallbacks. Default: `true`
    ///   - routeByLatency: Prefer lower-latency providers. Default: `false`
    ///   - requireProvidersForJSON: Require specified providers for JSON mode. Default: `false`
    ///   - siteURL: Your site URL for rankings. Default: `nil`
    ///   - appName: Your app name for rankings. Default: `nil`
    ///   - routeTag: Custom route tag. Default: `nil`
    ///   - dataCollection: Data collection policy. Default: `nil`
    public init(
        providers: [OpenRouterProvider]? = nil,
        fallbacks: Bool = true,
        routeByLatency: Bool = false,
        requireProvidersForJSON: Bool = false,
        siteURL: URL? = nil,
        appName: String? = nil,
        routeTag: String? = nil,
        dataCollection: OpenRouterDataCollection? = nil
    ) {
        self.providers = providers
        self.fallbacks = fallbacks
        self.routeByLatency = routeByLatency
        self.requireProvidersForJSON = requireProvidersForJSON
        self.siteURL = siteURL
        self.appName = appName
        self.routeTag = routeTag
        self.dataCollection = dataCollection
    }

    // MARK: - Static Presets

    /// Default routing configuration.
    ///
    /// Uses OpenRouter's default routing with fallbacks enabled.
    public static let `default` = OpenRouterRoutingConfig()

    /// Prefer OpenAI providers.
    ///
    /// Routes to OpenAI first, with fallbacks enabled.
    public static let preferOpenAI = OpenRouterRoutingConfig(
        providers: [.openai],
        fallbacks: true
    )

    /// Prefer Anthropic providers.
    ///
    /// Routes to Anthropic first, with fallbacks enabled.
    public static let preferAnthropic = OpenRouterRoutingConfig(
        providers: [.anthropic],
        fallbacks: true
    )

    /// Latency-optimized routing.
    ///
    /// Routes to the fastest available provider.
    public static let fastestProvider = OpenRouterRoutingConfig(
        fallbacks: true,
        routeByLatency: true
    )

    // MARK: - Header Generation

    /// Generates HTTP headers for this configuration.
    ///
    /// - Returns: Dictionary of header names to values.
    public func headers() -> [String: String] {
        var headers: [String: String] = [:]

        // Site identification
        if let siteURL = siteURL {
            headers["HTTP-Referer"] = siteURL.absoluteString
        }

        if let appName = appName {
            headers["X-Title"] = appName
        }

        return headers
    }

    /// Generates provider routing value for the request body.
    ///
    /// This is included in the chat completion request to control routing.
    ///
    /// - Returns: The provider routing configuration, or `nil` if using defaults.
    public func providerRouting() -> [String: Any]? {
        var routing: [String: Any] = [:]

        if let providers = providers, !providers.isEmpty {
            // OpenRouter expects provider slugs (e.g., "anthropic", "openai").
            routing["order"] = providers.map(\.slug)
        }

        if !fallbacks {
            routing["allow_fallbacks"] = false
        }

        if routeByLatency {
            // OpenRouter provider routing supports `sort: "latency"`.
            routing["sort"] = "latency"
        }

        if requireProvidersForJSON {
            routing["require_parameters"] = true
        }

        if let dataCollection = dataCollection {
            routing["data_collection"] = dataCollection.rawValue
        } else if let legacy = routeTag?.lowercased(), OpenRouterDataCollection(rawValue: legacy) != nil {
            // Backward compatible: treat old `routeTag` as `data_collection` only when valid.
            routing["data_collection"] = legacy
        }

        return routing.isEmpty ? nil : routing
    }
}

// MARK: - OpenRouterProvider

/// Providers available through OpenRouter.
///
/// OpenRouter aggregates many AI providers. Use these to specify
/// routing preferences.
public enum OpenRouterProvider: String, Sendable, Hashable, CaseIterable {

    /// OpenAI (GPT-4, etc.)
    case openai = "OpenAI"

    /// Anthropic (Claude)
    case anthropic = "Anthropic"

    /// Google (Gemini)
    case google = "Google"

    /// Google AI Studio
    case googleAIStudio = "Google AI Studio"

    /// Together AI
    case together = "Together"

    /// Fireworks AI
    case fireworks = "Fireworks"

    /// Perplexity
    case perplexity = "Perplexity"

    /// Mistral AI
    case mistral = "Mistral"

    /// Groq
    case groq = "Groq"

    /// DeepSeek
    case deepseek = "DeepSeek"

    /// Cohere
    case cohere = "Cohere"

    /// AI21 Labs
    case ai21 = "AI21"

    /// Amazon Bedrock
    case bedrock = "Amazon Bedrock"

    /// Azure
    case azure = "Azure"

    /// Provider slug used by OpenRouter's routing API (e.g., `provider.order`).
    public var slug: String {
        switch self {
        case .openai:
            return "openai"
        case .anthropic:
            return "anthropic"
        case .google:
            return "google"
        case .googleAIStudio:
            return "google-ai-studio"
        case .together:
            return "together"
        case .fireworks:
            return "fireworks"
        case .perplexity:
            return "perplexity"
        case .mistral:
            return "mistral"
        case .groq:
            return "groq"
        case .deepseek:
            return "deepseek"
        case .cohere:
            return "cohere"
        case .ai21:
            return "ai21"
        case .bedrock:
            return "bedrock"
        case .azure:
            return "azure"
        }
    }

    /// Human-readable display name.
    public var displayName: String {
        rawValue
    }
}

// MARK: - OpenRouterDataCollection

/// Controls whether providers may store prompts/completions.
///
/// Maps to OpenRouter's `provider.data_collection` field.
public enum OpenRouterDataCollection: String, Sendable, Hashable, CaseIterable {
    /// Providers may store prompts/completions.
    case allow
    /// Providers must not store prompts/completions.
    case deny
}

// MARK: - Fluent API

extension OpenRouterRoutingConfig {

    /// Returns a copy with the specified providers.
    ///
    /// - Parameter providers: Preferred providers in priority order.
    /// - Returns: A new configuration with the updated providers.
    public func providers(_ providers: [OpenRouterProvider]) -> OpenRouterRoutingConfig {
        var copy = self
        copy.providers = providers
        return copy
    }

    /// Returns a copy with fallbacks enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable fallbacks.
    /// - Returns: A new configuration with the updated setting.
    public func fallbacks(_ enabled: Bool) -> OpenRouterRoutingConfig {
        var copy = self
        copy.fallbacks = enabled
        return copy
    }

    /// Returns a copy with latency-based routing enabled or disabled.
    ///
    /// - Parameter enabled: Whether to route by latency.
    /// - Returns: A new configuration with the updated setting.
    public func routeByLatency(_ enabled: Bool) -> OpenRouterRoutingConfig {
        var copy = self
        copy.routeByLatency = enabled
        return copy
    }

    /// Returns a copy with the specified site URL.
    ///
    /// - Parameter url: Your site URL for OpenRouter rankings.
    /// - Returns: A new configuration with the updated URL.
    public func siteURL(_ url: URL) -> OpenRouterRoutingConfig {
        var copy = self
        copy.siteURL = url
        return copy
    }

    /// Returns a copy with the specified app name.
    ///
    /// - Parameter name: Your app name for OpenRouter rankings.
    /// - Returns: A new configuration with the updated name.
    public func appName(_ name: String) -> OpenRouterRoutingConfig {
        var copy = self
        copy.appName = name
        return copy
    }

    /// Returns a copy with the specified route tag.
    ///
    /// - Parameter tag: Custom route tag for grouping requests.
    /// - Returns: A new configuration with the updated tag.
    public func routeTag(_ tag: String) -> OpenRouterRoutingConfig {
        var copy = self
        copy.routeTag = tag
        return copy
    }

    /// Returns a copy with the specified data collection policy.
    ///
    /// - Parameter policy: Whether providers may store prompts/completions.
    /// - Returns: A new configuration with the updated policy.
    public func dataCollection(_ policy: OpenRouterDataCollection) -> OpenRouterRoutingConfig {
        var copy = self
        copy.dataCollection = policy
        return copy
    }
}

// MARK: - Codable

extension OpenRouterRoutingConfig: Codable {}
extension OpenRouterProvider: Codable {}
extension OpenRouterDataCollection: Codable {}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
