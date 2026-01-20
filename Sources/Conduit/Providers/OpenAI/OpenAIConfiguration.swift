// OpenAIConfiguration.swift
// Conduit
//
// Main configuration for OpenAI-compatible providers.

import Foundation

// MARK: - OpenAIConfiguration

/// Configuration for OpenAI-compatible API providers.
///
/// `OpenAIConfiguration` provides unified configuration for multiple OpenAI-compatible
/// backends including OpenAI, OpenRouter, Ollama, Azure OpenAI, and custom endpoints.
///
/// ## Progressive Disclosure
///
/// ### Level 1: Simple (One-liner)
/// ```swift
/// // Just works with API key
/// let provider = OpenAIProvider(apiKey: "sk-...")
/// ```
///
/// ### Level 2: Standard (Named Endpoints)
/// ```swift
/// // OpenRouter
/// let provider = OpenAIProvider(
///     endpoint: .openRouter,
///     apiKey: "or-..."
/// )
///
/// // Ollama (no key needed)
/// let provider = OpenAIProvider(endpoint: .ollama())
///
/// // Azure
/// let provider = OpenAIProvider(
///     endpoint: .azure(resource: "my-resource", deployment: "gpt-4"),
///     apiKey: "azure-key"
/// )
/// ```
///
/// ### Level 3: Expert (Full Control)
/// ```swift
/// let config = OpenAIConfiguration(
///     endpoint: .openRouter,
///     authentication: .bearer("or-..."),
///     timeout: 120,
///     retryConfig: .aggressive,
///     openRouterConfig: OpenRouterRoutingConfig(
///         providers: [.anthropic, .openai],
///         fallbacks: true
///     )
/// )
/// let provider = OpenAIProvider(configuration: config)
/// ```
///
/// ## Thread Safety
///
/// `OpenAIConfiguration` is `Sendable` and safe to share across concurrent tasks.
/// All contained types are also `Sendable`.
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct OpenAIConfiguration: Sendable, Hashable {

    // MARK: - Core Settings

    /// The API endpoint to use.
    ///
    /// Determines the base URL and default behavior for requests.
    /// Default: `.openAI`
    public var endpoint: OpenAIEndpoint

    /// Authentication configuration.
    ///
    /// Determines how API requests are authenticated.
    /// Default: `.auto` (checks environment variables)
    public var authentication: OpenAIAuthentication

    // MARK: - Version

    /// The framework version for User-Agent headers.
    /// Update this when releasing new versions.
    private static let frameworkVersion = "0.6.0"

    // MARK: - Network Settings

    /// Request timeout in seconds.
    ///
    /// How long to wait for a response before timing out.
    /// Default: 60.0
    public var timeout: TimeInterval

    /// Maximum number of retry attempts.
    ///
    /// How many times to retry failed requests.
    /// Set to 0 to disable retries.
    /// Default: 3
    public var maxRetries: Int

    /// Retry configuration.
    ///
    /// Controls retry behavior including delays and which errors are retryable.
    /// Default: `.default`
    public var retryConfig: RetryConfiguration

    // MARK: - Request Customization

    /// Default headers to include in all requests.
    ///
    /// These headers are added to every request. Authentication headers
    /// are added separately and will override matching keys.
    public var defaultHeaders: [String: String]

    /// Custom User-Agent string.
    ///
    /// If set, overrides the default User-Agent header.
    public var userAgent: String?

    /// Organization ID for OpenAI requests.
    ///
    /// If set, includes `OpenAI-Organization` header in requests.
    /// Only applicable to OpenAI endpoint.
    public var organizationID: String?

    // MARK: - Backend-Specific Configuration

    /// OpenRouter-specific routing configuration.
    ///
    /// Only used when `endpoint` is `.openRouter`.
    public var openRouterConfig: OpenRouterRoutingConfig?

    /// Azure-specific configuration.
    ///
    /// Only used when `endpoint` is `.azure`.
    /// Note: Azure endpoint already contains resource/deployment info,
    /// this provides additional options.
    public var azureConfig: AzureConfiguration?

    /// Ollama-specific configuration.
    ///
    /// Only used when `endpoint` is `.ollama`.
    public var ollamaConfig: OllamaConfiguration?

    // MARK: - Initialization

    /// Creates an OpenAI configuration with the specified settings.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint. Default: `.openAI`
    ///   - authentication: Authentication configuration. Default: `.auto`
    ///   - timeout: Request timeout in seconds. Default: 60.0
    ///   - maxRetries: Maximum retry attempts. Default: 3
    ///   - retryConfig: Retry behavior configuration. Default: `.default`
    ///   - defaultHeaders: Custom headers for all requests. Default: `[:]`
    ///   - userAgent: Custom User-Agent string. Default: `nil`
    ///   - organizationID: OpenAI organization ID. Default: `nil`
    ///   - openRouterConfig: OpenRouter-specific settings. Default: `nil`
    ///   - azureConfig: Azure-specific settings. Default: `nil`
    ///   - ollamaConfig: Ollama-specific settings. Default: `nil`
    public init(
        endpoint: OpenAIEndpoint = .openAI,
        authentication: OpenAIAuthentication = .auto,
        timeout: TimeInterval = 60.0,
        maxRetries: Int = 3,
        retryConfig: RetryConfiguration = .default,
        defaultHeaders: [String: String] = [:],
        userAgent: String? = nil,
        organizationID: String? = nil,
        openRouterConfig: OpenRouterRoutingConfig? = nil,
        azureConfig: AzureConfiguration? = nil,
        ollamaConfig: OllamaConfiguration? = nil
    ) {
        self.endpoint = endpoint
        self.authentication = authentication
        self.timeout = max(0, timeout)
        self.maxRetries = max(0, maxRetries)
        self.retryConfig = retryConfig
        self.defaultHeaders = defaultHeaders
        self.userAgent = userAgent
        self.organizationID = organizationID
        self.openRouterConfig = openRouterConfig
        self.azureConfig = azureConfig
        self.ollamaConfig = ollamaConfig
    }

    // MARK: - Static Presets

    /// Default OpenAI configuration.
    ///
    /// Uses the official OpenAI API with auto-detected authentication.
    public static let `default` = OpenAIConfiguration()

    /// Configuration for OpenRouter.
    ///
    /// Uses OpenRouter endpoint with auto-detected authentication.
    public static let openRouter = OpenAIConfiguration(
        endpoint: .openRouter,
        authentication: .environment("OPENROUTER_API_KEY"),
        openRouterConfig: .default
    )

    /// Configuration for local Ollama server.
    ///
    /// Uses localhost:11434 with no authentication.
    public static let ollama = OpenAIConfiguration(
        endpoint: .ollama(),
        authentication: .none,
        ollamaConfig: .default
    )

    /// Configuration for long-running requests.
    ///
    /// Extended timeout (120s) for models with slow cold starts.
    public static let longRunning = OpenAIConfiguration(
        timeout: 120.0,
        maxRetries: 5,
        retryConfig: .aggressive
    )

    /// Configuration with retries disabled.
    ///
    /// Fails immediately without retrying.
    public static let noRetry = OpenAIConfiguration(
        maxRetries: 0,
        retryConfig: .none
    )

    // MARK: - Convenience Initializers

    /// Creates a configuration for OpenAI with an API key.
    ///
    /// - Parameter apiKey: Your OpenAI API key.
    /// - Returns: A configuration for OpenAI.
    public static func openAI(apiKey: String) -> OpenAIConfiguration {
        OpenAIConfiguration(
            endpoint: .openAI,
            authentication: .bearer(apiKey)
        )
    }

    /// Creates a configuration for OpenRouter with an API key.
    ///
    /// - Parameter apiKey: Your OpenRouter API key.
    /// - Returns: A configuration for OpenRouter.
    public static func openRouter(apiKey: String) -> OpenAIConfiguration {
        OpenAIConfiguration(
            endpoint: .openRouter,
            authentication: .bearer(apiKey),
            openRouterConfig: .default
        )
    }

    /// Creates a configuration for local Ollama.
    ///
    /// - Parameters:
    ///   - host: The Ollama host. Default: `"localhost"`
    ///   - port: The Ollama port. Default: `11434`
    /// - Returns: A configuration for Ollama.
    public static func ollama(host: String = "localhost", port: Int = 11434) -> OpenAIConfiguration {
        OpenAIConfiguration(
            endpoint: .ollama(host: host, port: port),
            authentication: .none,
            ollamaConfig: .default
        )
    }

    /// Creates a configuration for Azure OpenAI.
    ///
    /// - Parameters:
    ///   - resource: Your Azure OpenAI resource name.
    ///   - deployment: The deployment name.
    ///   - apiKey: Your Azure API key.
    ///   - apiVersion: The API version. Default: latest stable
    /// - Returns: A configuration for Azure OpenAI.
    public static func azure(
        resource: String,
        deployment: String,
        apiKey: String,
        apiVersion: String = "2024-02-15-preview"
    ) -> OpenAIConfiguration {
        OpenAIConfiguration(
            endpoint: .azure(resource: resource, deployment: deployment, apiVersion: apiVersion),
            authentication: .apiKey(apiKey, headerName: "api-key"),
            azureConfig: AzureConfiguration(resource: resource, deployment: deployment, apiVersion: apiVersion)
        )
    }

    /// Creates a configuration for a custom endpoint.
    ///
    /// - Parameters:
    ///   - url: The base URL of the OpenAI-compatible API.
    ///   - apiKey: Optional API key.
    /// - Returns: A configuration for the custom endpoint.
    public static func custom(url: URL, apiKey: String? = nil) -> OpenAIConfiguration {
        let auth: OpenAIAuthentication
        if let key = apiKey {
            auth = .bearer(key)
        } else {
            auth = .auto
        }

        return OpenAIConfiguration(
            endpoint: .custom(url),
            authentication: auth
        )
    }

    // MARK: - Computed Properties

    /// Whether authentication is properly configured.
    ///
    /// Returns `true` if the endpoint doesn't require auth, or if
    /// auth is configured and resolvable.
    public var hasValidAuthentication: Bool {
        if !endpoint.requiresAuthentication {
            return true
        }
        return authentication.isConfigured
    }

    /// The capabilities available for this configuration.
    ///
    /// Returns the default capabilities for the endpoint.
    public var capabilities: OpenAICapabilities {
        endpoint.defaultCapabilities
    }
}

// MARK: - Fluent API

extension OpenAIConfiguration {

    /// Returns a copy with the specified endpoint.
    ///
    /// - Parameter endpoint: The API endpoint.
    /// - Returns: A new configuration with the updated endpoint.
    public func endpoint(_ endpoint: OpenAIEndpoint) -> OpenAIConfiguration {
        var copy = self
        copy.endpoint = endpoint
        return copy
    }

    /// Returns a copy with the specified authentication.
    ///
    /// - Parameter auth: The authentication configuration.
    /// - Returns: A new configuration with the updated authentication.
    public func authentication(_ auth: OpenAIAuthentication) -> OpenAIConfiguration {
        var copy = self
        copy.authentication = auth
        return copy
    }

    /// Returns a copy with the specified API key (bearer token).
    ///
    /// - Parameter apiKey: The API key.
    /// - Returns: A new configuration with bearer authentication.
    public func apiKey(_ apiKey: String) -> OpenAIConfiguration {
        var copy = self
        copy.authentication = .bearer(apiKey)
        return copy
    }

    /// Returns a copy with the specified timeout.
    ///
    /// - Parameter seconds: Request timeout in seconds.
    /// - Returns: A new configuration with the updated timeout.
    public func timeout(_ seconds: TimeInterval) -> OpenAIConfiguration {
        var copy = self
        copy.timeout = max(0, seconds)
        return copy
    }

    /// Returns a copy with the specified maximum retries.
    ///
    /// - Parameter count: Maximum retry attempts.
    /// - Returns: A new configuration with the updated retry count.
    public func maxRetries(_ count: Int) -> OpenAIConfiguration {
        var copy = self
        copy.maxRetries = max(0, count)
        return copy
    }

    /// Returns a copy with the specified retry configuration.
    ///
    /// - Parameter config: The retry configuration.
    /// - Returns: A new configuration with the updated retry settings.
    public func retryConfig(_ config: RetryConfiguration) -> OpenAIConfiguration {
        var copy = self
        copy.retryConfig = config
        return copy
    }

    /// Returns a copy with retries disabled.
    ///
    /// - Returns: A new configuration with maxRetries set to 0.
    public func noRetries() -> OpenAIConfiguration {
        var copy = self
        copy.maxRetries = 0
        return copy
    }

    /// Returns a copy with the specified headers.
    ///
    /// - Parameter headers: Default headers for all requests.
    /// - Returns: A new configuration with the updated headers.
    public func headers(_ headers: [String: String]) -> OpenAIConfiguration {
        var copy = self
        copy.defaultHeaders = headers
        return copy
    }

    /// Returns a copy with an additional header.
    ///
    /// - Parameters:
    ///   - name: The header name.
    ///   - value: The header value.
    /// - Returns: A new configuration with the added header.
    public func header(_ name: String, value: String) -> OpenAIConfiguration {
        var copy = self
        copy.defaultHeaders[name] = value
        return copy
    }

    /// Returns a copy with the specified User-Agent.
    ///
    /// - Parameter userAgent: The User-Agent string.
    /// - Returns: A new configuration with the updated User-Agent.
    public func userAgent(_ userAgent: String) -> OpenAIConfiguration {
        var copy = self
        copy.userAgent = userAgent
        return copy
    }

    /// Returns a copy with the specified organization ID.
    ///
    /// - Parameter orgID: The OpenAI organization ID.
    /// - Returns: A new configuration with the updated organization.
    public func organization(_ orgID: String) -> OpenAIConfiguration {
        var copy = self
        copy.organizationID = orgID
        return copy
    }

    /// Returns a copy with OpenRouter configuration.
    ///
    /// - Parameter config: The OpenRouter routing configuration.
    /// - Returns: A new configuration with OpenRouter settings.
    public func openRouter(_ config: OpenRouterRoutingConfig) -> OpenAIConfiguration {
        var copy = self
        copy.openRouterConfig = config
        return copy
    }

    /// Returns a copy with OpenRouter routing configuration.
    ///
    /// This is an alias for `openRouter(_:)` that provides clearer naming
    /// when chaining with `.openRouter(apiKey:)`.
    ///
    /// ```swift
    /// // Before (confusing):
    /// let config = OpenAIConfiguration.openRouter(apiKey: "...")
    ///     .openRouter(OpenRouterRoutingConfig(...))
    ///
    /// // After (clearer):
    /// let config = OpenAIConfiguration.openRouter(apiKey: "...")
    ///     .routing(.preferAnthropic)
    /// ```
    ///
    /// - Parameter config: The OpenRouter routing configuration.
    /// - Returns: A new configuration with routing settings.
    public func routing(_ config: OpenRouterRoutingConfig) -> OpenAIConfiguration {
        openRouter(config)
    }

    /// Returns a copy configured to prefer specific providers.
    ///
    /// Shorthand for setting provider routing preferences.
    ///
    /// ```swift
    /// let config = OpenAIConfiguration.openRouter(apiKey: "...")
    ///     .preferring(.anthropic, .openai)
    /// ```
    ///
    /// - Parameter providers: Providers to prefer, in priority order.
    /// - Returns: A new configuration with provider preferences.
    public func preferring(_ providers: OpenRouterProvider...) -> OpenAIConfiguration {
        routing(OpenRouterRoutingConfig(providers: providers, fallbacks: true))
    }

    /// Returns a copy with latency-based routing enabled.
    ///
    /// Routes to the fastest available provider.
    ///
    /// ```swift
    /// let config = OpenAIConfiguration.openRouter(apiKey: "...")
    ///     .routeByLatency()
    /// ```
    ///
    /// - Returns: A new configuration with latency routing enabled.
    public func routeByLatency() -> OpenAIConfiguration {
        var copy = self
        if copy.openRouterConfig == nil {
            copy.openRouterConfig = .default
        }
        copy.openRouterConfig?.routeByLatency = true
        return copy
    }

    /// Returns a copy with Ollama configuration.
    ///
    /// - Parameter config: The Ollama configuration.
    /// - Returns: A new configuration with Ollama settings.
    public func ollama(_ config: OllamaConfiguration) -> OpenAIConfiguration {
        var copy = self
        copy.ollamaConfig = config
        return copy
    }

    /// Returns a copy with Azure configuration.
    ///
    /// - Parameter config: The Azure configuration.
    /// - Returns: A new configuration with Azure settings.
    public func azure(_ config: AzureConfiguration) -> OpenAIConfiguration {
        var copy = self
        copy.azureConfig = config
        return copy
    }
}

// MARK: - Request Building

extension OpenAIConfiguration {

    /// Builds HTTP headers for a request.
    ///
    /// Combines default headers, authentication, and backend-specific headers.
    ///
    /// - Returns: Dictionary of header names to values.
    public func buildHeaders() -> [String: String] {
        var headers = defaultHeaders

        // Add authentication
        if let name = authentication.headerName, let value = authentication.headerValue {
            headers[name] = value
        }

        // Add User-Agent
        if let userAgent = userAgent {
            headers["User-Agent"] = userAgent
        } else {
            headers["User-Agent"] = "Conduit/\(Self.frameworkVersion)"
        }

        // Add organization ID for OpenAI
        if let orgID = organizationID, endpoint == .openAI {
            headers["OpenAI-Organization"] = orgID
        }

        // Add OpenRouter headers
        if endpoint == .openRouter, let orConfig = openRouterConfig {
            for (key, value) in orConfig.headers() {
                headers[key] = value
            }
        }

        // Content-Type
        headers["Content-Type"] = "application/json"

        return headers
    }
}

// MARK: - Codable

extension OpenAIConfiguration: Codable {

    private enum CodingKeys: String, CodingKey {
        case endpoint
        case timeout
        case maxRetries
        case retryConfig
        case defaultHeaders
        case userAgent
        case organizationID
        case openRouterConfig
        case ollamaConfig
        // Note: authentication and azureConfig are not encoded for security
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.endpoint = try container.decode(OpenAIEndpoint.self, forKey: .endpoint)
        self.authentication = .auto  // Always use auto for decoded configs
        self.timeout = try container.decode(TimeInterval.self, forKey: .timeout)
        self.maxRetries = try container.decode(Int.self, forKey: .maxRetries)
        self.retryConfig = try container.decode(RetryConfiguration.self, forKey: .retryConfig)
        self.defaultHeaders = try container.decode([String: String].self, forKey: .defaultHeaders)
        self.userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
        self.organizationID = try container.decodeIfPresent(String.self, forKey: .organizationID)
        self.openRouterConfig = try container.decodeIfPresent(OpenRouterRoutingConfig.self, forKey: .openRouterConfig)
        self.azureConfig = nil  // Not encoded
        self.ollamaConfig = try container.decodeIfPresent(OllamaConfiguration.self, forKey: .ollamaConfig)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(endpoint, forKey: .endpoint)
        // authentication is not encoded for security
        try container.encode(timeout, forKey: .timeout)
        try container.encode(maxRetries, forKey: .maxRetries)
        try container.encode(retryConfig, forKey: .retryConfig)
        try container.encode(defaultHeaders, forKey: .defaultHeaders)
        try container.encodeIfPresent(userAgent, forKey: .userAgent)
        try container.encodeIfPresent(organizationID, forKey: .organizationID)
        try container.encodeIfPresent(openRouterConfig, forKey: .openRouterConfig)
        // azureConfig is not encoded for security
        try container.encodeIfPresent(ollamaConfig, forKey: .ollamaConfig)
    }
}
