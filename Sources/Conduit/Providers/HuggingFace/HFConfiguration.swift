// HFConfiguration.swift
// Conduit

import Foundation

/// Configuration options for HuggingFace Inference API.
///
/// `HFConfiguration` controls authentication, network settings, and retry behavior
/// for cloud-based inference via the HuggingFace Inference API.
///
/// ## Usage
/// ```swift
/// // Use defaults with auto token detection
/// let config = HFConfiguration.default
///
/// // Use a preset for long-running models
/// let config = HFConfiguration.longRunning
///
/// // Customize with fluent API
/// let config = HFConfiguration.default
///     .token(.static("hf_..."))
///     .timeout(120)
///     .maxRetries(5)
/// ```
///
/// ## Presets
/// - `default`: Standard configuration with auto token detection
/// - `longRunning`: Longer timeout (120s) for slow models
/// - `endpoint(_:)`: Custom inference endpoint (e.g., private deployment)
///
/// ## Protocol Conformances
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `Hashable`: Can be used in sets and as dictionary keys
struct HFConfiguration: Sendable, Hashable {

    // MARK: - Authentication

    /// Token provider for HuggingFace API authentication.
    ///
    /// Determines how the API token is resolved (environment, static, keychain).
    ///
    /// - Note: Default is `.auto`, which checks environment variables.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.token(.static("hf_..."))
    /// ```
    var tokenProvider: HFTokenProvider

    // MARK: - Network Settings

    /// Base URL for the HuggingFace Inference API.
    ///
    /// Use this to configure custom inference endpoints or private deployments.
    ///
    /// - Note: Default is `https://api-inference.huggingface.co`.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.endpoint(URL(string: "https://custom.example.com")!)
    /// ```
    var baseURL: URL

    /// Request timeout in seconds.
    ///
    /// Controls how long to wait for a response before timing out.
    /// Longer timeouts are needed for large models or cold starts.
    ///
    /// - Note: Default is 60 seconds.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.timeout(120)
    /// ```
    var timeout: TimeInterval

    // MARK: - Retry Settings

    /// Maximum number of retry attempts for failed requests.
    ///
    /// Retries use exponential backoff based on `retryBaseDelay`.
    /// Set to 0 to disable retries.
    ///
    /// - Note: Default is 3 retries.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.maxRetries(5)
    /// ```
    var maxRetries: Int

    /// Base delay for exponential backoff retry strategy (in seconds).
    ///
    /// Actual delay is calculated as: `baseDelay * (2 ^ attemptNumber)`.
    /// For example, with baseDelay=1.0: 1s, 2s, 4s, 8s, etc.
    ///
    /// - Note: Default is 1.0 second.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.retryBaseDelay(0.5)
    /// ```
    var retryBaseDelay: TimeInterval

    // MARK: - Initialization

    /// Creates an HFConfiguration with the specified parameters.
    ///
    /// - Parameters:
    ///   - tokenProvider: Token resolution strategy (default: `.auto`).
    ///   - baseURL: API base URL (default: `https://api-inference.huggingface.co`).
    ///   - timeout: Request timeout in seconds (default: 60).
    ///   - maxRetries: Maximum retry attempts (default: 3).
    ///   - retryBaseDelay: Base delay for exponential backoff (default: 1.0).
    init(
        tokenProvider: HFTokenProvider = .auto,
        baseURL: URL = URL(string: "https://api-inference.huggingface.co")!,
        timeout: TimeInterval = 60,
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 1.0
    ) {
        self.tokenProvider = tokenProvider
        self.baseURL = baseURL
        self.timeout = max(0, timeout) // Ensure non-negative
        self.maxRetries = max(0, maxRetries) // Ensure non-negative
        self.retryBaseDelay = max(0, retryBaseDelay) // Ensure non-negative
    }

    // MARK: - Computed Properties

    /// Whether a token is configured and available.
    ///
    /// Returns `true` if the token provider has a valid token.
    /// Use this to check authentication status before making requests.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default
    /// if config.hasToken {
    ///     let provider = HuggingFaceProvider(configuration: config)
    /// } else {
    ///     print("No HuggingFace token configured")
    /// }
    /// ```
    ///
    /// - Returns: `true` if a token is available, `false` otherwise.
    var hasToken: Bool {
        tokenProvider.isConfigured
    }

    // MARK: - Static Presets

    /// Default configuration with automatic token detection.
    ///
    /// Good for general-purpose inference with standard timeout and retry settings.
    ///
    /// ## Configuration
    /// - tokenProvider: `.auto` (checks `HF_TOKEN` and `HUGGING_FACE_HUB_TOKEN`)
    /// - baseURL: `https://api-inference.huggingface.co`
    /// - timeout: 60 seconds
    /// - maxRetries: 3
    /// - retryBaseDelay: 1.0 second
    static let `default` = HFConfiguration()

    /// Configuration optimized for long-running models.
    ///
    /// Uses longer timeout for models with slow cold starts or heavy computation.
    ///
    /// ## Configuration
    /// - timeout: 120 seconds
    /// - All other settings same as `.default`
    ///
    /// ## Usage
    /// ```swift
    /// let provider = HuggingFaceProvider(configuration: .longRunning)
    /// ```
    static let longRunning = HFConfiguration(
        timeout: 120
    )

    /// Creates a configuration for a custom inference endpoint.
    ///
    /// Use this for private HuggingFace deployments or custom inference servers.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.endpoint(URL(string: "https://custom.example.com")!)
    /// let provider = HuggingFaceProvider(configuration: config)
    /// ```
    ///
    /// - Parameter url: The custom endpoint base URL.
    /// - Returns: A configuration with the specified endpoint.
    static func endpoint(_ url: URL) -> HFConfiguration {
        HFConfiguration(baseURL: url)
    }
}

// MARK: - Fluent API

extension HFConfiguration {

    /// Returns a copy with the specified token provider.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.token(.static("hf_..."))
    /// ```
    ///
    /// - Parameter provider: The token provider to use.
    /// - Returns: A new configuration with the updated token provider.
    func token(_ provider: HFTokenProvider) -> HFConfiguration {
        var copy = self
        copy.tokenProvider = provider
        return copy
    }

    /// Returns a copy with the specified base URL.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.baseURL(URL(string: "https://custom.example.com")!)
    /// ```
    ///
    /// - Parameter url: The API base URL.
    /// - Returns: A new configuration with the updated base URL.
    func baseURL(_ url: URL) -> HFConfiguration {
        var copy = self
        copy.baseURL = url
        return copy
    }

    /// Returns a copy with the specified timeout.
    ///
    /// Timeout is automatically clamped to be non-negative.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.timeout(120)
    /// ```
    ///
    /// - Parameter seconds: Request timeout in seconds.
    /// - Returns: A new configuration with the updated timeout.
    func timeout(_ seconds: TimeInterval) -> HFConfiguration {
        var copy = self
        copy.timeout = max(0, seconds)
        return copy
    }

    /// Returns a copy with the specified maximum retry count.
    ///
    /// Retry count is automatically clamped to be non-negative.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.maxRetries(5)
    /// ```
    ///
    /// - Parameter count: Maximum number of retry attempts.
    /// - Returns: A new configuration with the updated retry count.
    func maxRetries(_ count: Int) -> HFConfiguration {
        var copy = self
        copy.maxRetries = max(0, count)
        return copy
    }

    /// Returns a copy with the specified retry base delay.
    ///
    /// Base delay is automatically clamped to be non-negative.
    ///
    /// ## Usage
    /// ```swift
    /// let config = HFConfiguration.default.retryBaseDelay(0.5)
    /// ```
    ///
    /// - Parameter delay: Base delay in seconds for exponential backoff.
    /// - Returns: A new configuration with the updated base delay.
    func retryBaseDelay(_ delay: TimeInterval) -> HFConfiguration {
        var copy = self
        copy.retryBaseDelay = max(0, delay)
        return copy
    }
}
