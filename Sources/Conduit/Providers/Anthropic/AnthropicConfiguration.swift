// AnthropicConfiguration.swift
// Conduit
//
// Main configuration for Anthropic Claude API.

#if CONDUIT_TRAIT_ANTHROPIC
import Foundation

// MARK: - AnthropicConfiguration

/// Configuration for Anthropic Claude API.
///
/// `AnthropicConfiguration` provides unified configuration for the Anthropic
/// Claude API with support for authentication, timeouts, retries, and
/// advanced features.
///
/// ## Progressive Disclosure
///
/// ### Level 1: Simple (One-liner)
/// ```swift
/// // Just works with API key
/// let provider = AnthropicProvider(apiKey: "sk-ant-...")
/// ```
///
/// ### Level 2: Standard (Named Configuration)
/// ```swift
/// // Standard configuration with API key
/// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
/// let provider = AnthropicProvider(configuration: config)
/// ```
///
/// ### Level 3: Expert (Full Control)
/// ```swift
/// let config = try AnthropicConfiguration(
///     authentication: .apiKey("sk-ant-..."),
///     timeout: 120,
///     maxRetries: 5,
///     supportsExtendedThinking: true
/// )
/// let provider = AnthropicProvider(configuration: config)
/// ```
///
/// ## Thread Safety
///
/// `AnthropicConfiguration` is `Sendable` and safe to share across
/// concurrent tasks. All contained types are also `Sendable`.
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct AnthropicConfiguration: Sendable, Hashable, Codable {

    // MARK: - Core Settings

    /// Authentication configuration.
    ///
    /// Determines how API requests are authenticated.
    /// Default: `.auto` (checks ANTHROPIC_API_KEY environment variable)
    public var authentication: AnthropicAuthentication

    /// The base URL for the Anthropic API.
    ///
    /// Default: `https://api.anthropic.com`
    public var baseURL: URL

    /// The API version to use.
    ///
    /// Anthropic uses versioned API endpoints. Specify the version
    /// in the `anthropic-version` header.
    /// Default: `"2023-06-01"`
    public var apiVersion: String

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

    // MARK: - Feature Flags

    /// Whether the provider supports streaming responses.
    ///
    /// Anthropic supports Server-Sent Events (SSE) for streaming.
    /// Default: `true`
    public var supportsStreaming: Bool

    /// Whether the provider supports vision (image) inputs.
    ///
    /// Claude 3+ models support vision capabilities.
    /// Default: `true`
    public var supportsVision: Bool

    /// Whether the provider supports extended thinking mode.
    ///
    /// Extended thinking allows the model to reason longer before responding.
    /// Available on select models.
    /// Default: `true`
    public var supportsExtendedThinking: Bool

    /// Configuration for extended thinking mode.
    ///
    /// When set, enables extended thinking where Claude spends more time
    /// reasoning before responding. This is an opt-in premium feature.
    ///
    /// Set to `nil` to disable extended thinking (default).
    ///
    /// ## Usage
    /// ```swift
    /// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
    ///     .extendedThinking(.standard)
    /// ```
    public var thinkingConfig: ThinkingConfiguration?

    // MARK: - Initialization

    /// Creates an Anthropic configuration with the specified settings.
    ///
    /// - Parameters:
    ///   - authentication: Authentication configuration. Default: `.auto`
    ///   - baseURL: The API base URL. Default: `https://api.anthropic.com`
    ///   - apiVersion: The API version. Default: `"2023-06-01"`
    ///   - timeout: Request timeout in seconds. Default: 60.0
    ///   - maxRetries: Maximum retry attempts. Default: 3
    ///   - supportsStreaming: Enable streaming support. Default: `true`
    ///   - supportsVision: Enable vision support. Default: `true`
    ///   - supportsExtendedThinking: Enable extended thinking. Default: `true`
    ///
    /// - Throws: `AIError.invalidInput` if the base URL does not use HTTPS
    ///   (localhost URLs are exempt for development purposes).
    public init(
        authentication: AnthropicAuthentication = .auto,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        apiVersion: String = "2023-06-01",
        timeout: TimeInterval = 60.0,
        maxRetries: Int = 3,
        supportsStreaming: Bool = true,
        supportsVision: Bool = true,
        supportsExtendedThinking: Bool = true
    ) throws {
        try Self.validateSecureURL(baseURL)
        self.authentication = authentication
        self.baseURL = baseURL
        self.apiVersion = apiVersion
        self.timeout = max(0, timeout)
        self.maxRetries = max(0, maxRetries)
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
        self.supportsExtendedThinking = supportsExtendedThinking
    }

    // MARK: - URL Validation

    /// Validates that a URL uses HTTPS for security.
    ///
    /// All API requests should use HTTPS to protect API keys and data in transit.
    /// Localhost URLs are exempt for development and testing purposes.
    ///
    /// - Parameter url: The URL to validate.
    /// - Throws: `AIError.invalidInput` if the URL does not use HTTPS
    ///   and is not a localhost address.
    private static func validateSecureURL(_ url: URL) throws {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased() ?? ""

        // Allow localhost for development
        let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"

        guard scheme == "https" || isLocalhost else {
            throw AIError.invalidInput(
                "Base URL must use HTTPS for security. Got: \(url.absoluteString)"
            )
        }
    }

    // MARK: - Static Factories

    /// Standard configuration with an API key.
    ///
    /// Creates a configuration with default settings and the provided API key.
    ///
    /// - Parameter apiKey: Your Anthropic API key (starts with "sk-ant-").
    /// - Returns: A standard configuration with the specified API key.
    public static func standard(apiKey: String) -> AnthropicConfiguration {
        let config: AnthropicConfiguration
        do {
            config = try AnthropicConfiguration(
                authentication: .apiKey(apiKey)
            )
        } catch {
            preconditionFailure(
                "Failed to create AnthropicConfiguration with default URL: \(error)",
                file: #file,
                line: #line
            )
        }
        return config
    }

    // MARK: - Request Building

    /// Builds HTTP headers for a request.
    ///
    /// Combines authentication, API version, and content type headers.
    ///
    /// - Returns: Dictionary of header names to values.
    public func buildHeaders() -> [String: String] {
        var headers: [String: String] = [
            "Content-Type": "application/json",
            "anthropic-version": apiVersion
        ]

        // Add authentication if available
        if let apiKey = authentication.apiKey {
            headers["X-Api-Key"] = apiKey
        }

        return headers
    }

    // MARK: - Computed Properties

    /// Whether authentication is properly configured.
    ///
    /// Returns `true` if the authentication has a valid API key.
    public var hasValidAuthentication: Bool {
        authentication.isValid
    }
}

// MARK: - Fluent API

extension AnthropicConfiguration {

    /// Returns a copy with the specified authentication.
    ///
    /// - Parameter auth: The authentication configuration.
    /// - Returns: A new configuration with the updated authentication.
    public func authentication(_ auth: AnthropicAuthentication) -> AnthropicConfiguration {
        var copy = self
        copy.authentication = auth
        return copy
    }

    /// Returns a copy with the specified API key.
    ///
    /// - Parameter apiKey: The API key.
    /// - Returns: A new configuration with the updated API key.
    public func apiKey(_ apiKey: String) -> AnthropicConfiguration {
        var copy = self
        copy.authentication = .apiKey(apiKey)
        return copy
    }

    /// Returns a copy with the specified base URL.
    ///
    /// - Parameter url: The base URL. Must use HTTPS (localhost exempt for development).
    /// - Returns: A new configuration with the updated URL.
    /// - Throws: `AIError.invalidInput` if the URL does not use HTTPS.
    public func baseURL(_ url: URL) throws -> AnthropicConfiguration {
        try Self.validateSecureURL(url)
        var copy = self
        copy.baseURL = url
        return copy
    }

    /// Returns a copy with the specified API version.
    ///
    /// - Parameter version: The API version string.
    /// - Returns: A new configuration with the updated version.
    public func apiVersion(_ version: String) -> AnthropicConfiguration {
        var copy = self
        copy.apiVersion = version
        return copy
    }

    /// Returns a copy with the specified timeout.
    ///
    /// - Parameter seconds: Request timeout in seconds.
    /// - Returns: A new configuration with the updated timeout.
    public func timeout(_ seconds: TimeInterval) -> AnthropicConfiguration {
        var copy = self
        copy.timeout = max(0, seconds)
        return copy
    }

    /// Returns a copy with the specified maximum retries.
    ///
    /// - Parameter count: Maximum retry attempts.
    /// - Returns: A new configuration with the updated retry count.
    public func maxRetries(_ count: Int) -> AnthropicConfiguration {
        var copy = self
        copy.maxRetries = max(0, count)
        return copy
    }

    /// Returns a copy with streaming support enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable streaming.
    /// - Returns: A new configuration with the updated setting.
    public func streaming(_ enabled: Bool) -> AnthropicConfiguration {
        var copy = self
        copy.supportsStreaming = enabled
        return copy
    }

    /// Returns a copy with vision support enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable vision.
    /// - Returns: A new configuration with the updated setting.
    public func vision(_ enabled: Bool) -> AnthropicConfiguration {
        var copy = self
        copy.supportsVision = enabled
        return copy
    }

    /// Returns a copy with extended thinking enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable extended thinking.
    /// - Returns: A new configuration with the updated setting.
    public func extendedThinking(_ enabled: Bool) -> AnthropicConfiguration {
        var copy = self
        copy.supportsExtendedThinking = enabled
        return copy
    }

    /// Returns a copy with the specified extended thinking configuration.
    ///
    /// Extended thinking allows Claude to spend more time reasoning before
    /// responding. This is an opt-in premium feature available on select models.
    ///
    /// ## Usage
    /// ```swift
    /// // Use standard thinking (1024 tokens budget)
    /// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
    ///     .extendedThinking(.standard)
    ///
    /// // Custom thinking budget
    /// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
    ///     .extendedThinking(ThinkingConfiguration(enabled: true, budgetTokens: 2048))
    ///
    /// // Disable thinking
    /// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
    ///     .extendedThinking(nil)
    /// ```
    ///
    /// - Parameter config: The thinking configuration, or `nil` to disable.
    /// - Returns: A new configuration with updated thinking settings.
    public func extendedThinking(_ config: ThinkingConfiguration?) -> AnthropicConfiguration {
        var copy = self
        copy.thinkingConfig = config
        return copy
    }
}

// MARK: - ThinkingConfiguration

/// Configuration for extended thinking mode.
///
/// Extended thinking allows Claude to spend more time reasoning before responding.
/// This feature is available on select models and is opt-in.
///
/// When enabled, Claude will use an internal "thinking" process before generating
/// the final response. The thinking process consumes tokens from the budget but
/// is not visible in the final output.
///
/// ## Usage
/// ```swift
/// // Standard configuration (1024 tokens)
/// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
///     .extendedThinking(.standard)
///
/// // Custom budget
/// let thinking = ThinkingConfiguration(enabled: true, budgetTokens: 2048)
/// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
///     .extendedThinking(thinking)
///
/// let result = try await provider.generate(
///     messages: messages,
///     model: .claudeOpus45,
///     config: .default
/// )
/// ```
///
/// ## Performance Considerations
///
/// - **Latency**: Higher budgets increase response time
/// - **Cost**: Thinking tokens are billed at the same rate as output tokens
/// - **Quality**: Larger budgets allow deeper reasoning for complex tasks
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
/// - `Codable`: Full JSON encoding/decoding support
public struct ThinkingConfiguration: Sendable, Hashable, Codable {

    // MARK: - Properties

    /// Whether extended thinking is enabled.
    ///
    /// When `true`, Claude will perform internal reasoning before responding.
    /// When `false`, thinking is disabled (default behavior).
    public let enabled: Bool

    /// Maximum tokens allocated for thinking process.
    ///
    /// This budget controls how much the model can "think" before responding.
    /// Higher budgets allow deeper reasoning but increase latency and cost.
    ///
    /// The thinking process is internal and not visible in the final response.
    /// Only the assistant's response text is returned to the user.
    ///
    /// ## Recommended Budgets
    /// - **Simple tasks**: 512-1024 tokens
    /// - **Standard tasks**: 1024-2048 tokens
    /// - **Complex reasoning**: 2048-4096 tokens
    ///
    /// Default: 1024
    public let budgetTokens: Int

    // MARK: - Static Factories

    /// Standard thinking configuration.
    ///
    /// Provides a balanced configuration suitable for most use cases.
    ///
    /// - **Enabled**: `true`
    /// - **Budget**: 1024 tokens
    ///
    /// ## Usage
    /// ```swift
    /// let config = AnthropicConfiguration.standard(apiKey: "sk-ant-...")
    ///     .extendedThinking(.standard)
    /// ```
    public static let standard = ThinkingConfiguration(
        enabled: true,
        budgetTokens: 1024
    )

    // MARK: - Initialization

    /// Creates a thinking configuration.
    ///
    /// - Parameters:
    ///   - enabled: Whether to enable thinking. Default: `true`
    ///   - budgetTokens: Token budget for thinking. Must be non-negative. Default: 1024
    ///
    /// - Note: The budget is validated to ensure it's not negative.
    ///   Negative values are clamped to 0.
    public init(enabled: Bool = true, budgetTokens: Int = 1024) {
        self.enabled = enabled
        self.budgetTokens = max(0, budgetTokens)
    }
}

#endif // CONDUIT_TRAIT_ANTHROPIC
