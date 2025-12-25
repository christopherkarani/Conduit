// AzureConfiguration.swift
// SwiftAI
//
// Azure OpenAI-specific configuration.

import Foundation

// MARK: - AzureConfiguration

/// Configuration for Azure OpenAI Service.
///
/// Azure OpenAI provides enterprise-grade access to OpenAI models
/// through Microsoft Azure. This configuration handles Azure-specific
/// requirements like API versions and content filtering.
///
/// ## Usage
///
/// ### Basic Configuration
/// ```swift
/// let config = AzureConfiguration(
///     resource: "my-company-openai",
///     deployment: "gpt4-deployment"
/// )
/// ```
///
/// ### With Custom API Version
/// ```swift
/// let config = AzureConfiguration(
///     resource: "my-company-openai",
///     deployment: "gpt4-deployment",
///     apiVersion: "2024-02-15-preview"
/// )
/// ```
///
/// ### With Content Filtering
/// ```swift
/// let config = AzureConfiguration(
///     resource: "my-company-openai",
///     deployment: "gpt4-deployment"
/// ).withContentFiltering(.strict)
/// ```
///
/// ## Azure URL Format
///
/// Azure OpenAI URLs follow this pattern:
/// ```
/// https://{resource}.openai.azure.com/openai/deployments/{deployment}/{operation}?api-version={version}
/// ```
///
/// ## Authentication
///
/// Azure OpenAI supports two authentication methods:
/// 1. API Key in `api-key` header
/// 2. Azure AD token in `Authorization` header
public struct AzureConfiguration: Sendable, Hashable {

    // MARK: - Properties

    /// Your Azure OpenAI resource name.
    ///
    /// This is the name you chose when creating the Azure OpenAI resource.
    /// It appears in the URL: `{resource}.openai.azure.com`
    public let resource: String

    /// The deployment name for the model.
    ///
    /// In Azure, you deploy a specific model version to a deployment.
    /// The deployment name is used in API calls instead of the model name.
    public let deployment: String

    /// The Azure OpenAI API version.
    ///
    /// Azure uses dated API versions. Use the latest stable version
    /// unless you need specific preview features.
    ///
    /// Default: `"2024-02-15-preview"`
    public var apiVersion: String

    /// Content filtering configuration.
    ///
    /// Azure OpenAI includes content filtering by default.
    /// Use this to configure the filtering behavior.
    public var contentFiltering: ContentFilteringMode

    /// Enable streaming for chat completions.
    ///
    /// Default: `true`
    public var enableStreaming: Bool

    /// Custom Azure region override.
    ///
    /// By default, the region is determined by your resource.
    /// Set this to override for regional routing.
    public var region: String?

    // MARK: - Initialization

    /// Creates an Azure OpenAI configuration.
    ///
    /// - Parameters:
    ///   - resource: Your Azure OpenAI resource name.
    ///   - deployment: The deployment name for the model.
    ///   - apiVersion: API version string. Default: `"2024-02-15-preview"`
    ///   - contentFiltering: Content filtering mode. Default: `.default`
    ///   - enableStreaming: Enable streaming. Default: `true`
    ///   - region: Optional region override. Default: `nil`
    public init(
        resource: String,
        deployment: String,
        apiVersion: String = "2024-02-15-preview",
        contentFiltering: ContentFilteringMode = .default,
        enableStreaming: Bool = true,
        region: String? = nil
    ) {
        self.resource = resource
        self.deployment = deployment
        self.apiVersion = apiVersion
        self.contentFiltering = contentFiltering
        self.enableStreaming = enableStreaming
        self.region = region
    }

    // MARK: - URL Generation

    /// The base URL for this Azure OpenAI resource.
    public var baseURL: URL {
        URL(string: "https://\(resource).openai.azure.com/openai")!
    }

    /// The chat completions endpoint URL.
    public var chatCompletionsURL: URL {
        baseURL
            .appendingPathComponent("deployments")
            .appendingPathComponent(deployment)
            .appendingPathComponent("chat/completions")
            .appending(queryItems: [URLQueryItem(name: "api-version", value: apiVersion)])
    }

    /// The embeddings endpoint URL.
    public var embeddingsURL: URL {
        baseURL
            .appendingPathComponent("deployments")
            .appendingPathComponent(deployment)
            .appendingPathComponent("embeddings")
            .appending(queryItems: [URLQueryItem(name: "api-version", value: apiVersion)])
    }

    /// The images generations endpoint URL.
    public var imagesGenerationsURL: URL {
        baseURL
            .appendingPathComponent("deployments")
            .appendingPathComponent(deployment)
            .appendingPathComponent("images/generations")
            .appending(queryItems: [URLQueryItem(name: "api-version", value: apiVersion)])
    }
}

// MARK: - ContentFilteringMode

/// Content filtering modes for Azure OpenAI.
///
/// Azure OpenAI includes content filtering to prevent harmful outputs.
/// These modes control the filtering behavior.
public enum ContentFilteringMode: String, Sendable, Hashable, Codable {

    /// Default content filtering (Azure's standard settings).
    case `default`

    /// Strict content filtering (more aggressive blocking).
    case strict

    /// Reduced content filtering (requires approval from Microsoft).
    case reduced

    /// No content filtering (requires special approval).
    case none

    /// Human-readable description.
    public var description: String {
        switch self {
        case .default:
            return "Default filtering"
        case .strict:
            return "Strict filtering"
        case .reduced:
            return "Reduced filtering"
        case .none:
            return "No filtering"
        }
    }
}

// MARK: - Fluent API

extension AzureConfiguration {

    /// Returns a copy with the specified API version.
    ///
    /// - Parameter version: The Azure OpenAI API version.
    /// - Returns: A new configuration with the updated version.
    public func apiVersion(_ version: String) -> AzureConfiguration {
        var copy = self
        copy.apiVersion = version
        return copy
    }

    /// Returns a copy with the specified content filtering mode.
    ///
    /// - Parameter mode: The content filtering mode.
    /// - Returns: A new configuration with the updated mode.
    public func contentFiltering(_ mode: ContentFilteringMode) -> AzureConfiguration {
        var copy = self
        copy.contentFiltering = mode
        return copy
    }

    /// Returns a copy with strict content filtering.
    ///
    /// - Returns: A new configuration with strict filtering.
    public func withStrictFiltering() -> AzureConfiguration {
        contentFiltering(.strict)
    }

    /// Returns a copy with streaming enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable streaming.
    /// - Returns: A new configuration with the updated setting.
    public func streaming(_ enabled: Bool) -> AzureConfiguration {
        var copy = self
        copy.enableStreaming = enabled
        return copy
    }

    /// Returns a copy with the specified region.
    ///
    /// - Parameter region: The Azure region.
    /// - Returns: A new configuration with the updated region.
    public func region(_ region: String) -> AzureConfiguration {
        var copy = self
        copy.region = region
        return copy
    }
}

// MARK: - Codable

extension AzureConfiguration: Codable {}

// MARK: - Common API Versions

extension AzureConfiguration {

    /// Known Azure OpenAI API versions.
    public enum APIVersion {

        /// Latest stable version (2024-02-15-preview).
        public static let latestStable = "2024-02-15-preview"

        /// GA version (2024-02-01).
        public static let ga2024 = "2024-02-01"

        /// Legacy version (2023-05-15).
        public static let legacy = "2023-05-15"
    }
}
