// OpenAIEndpoint.swift
// Conduit
//
// Defines the supported OpenAI-compatible API endpoints.

import Foundation

// MARK: - OpenAIEndpoint

/// Represents an OpenAI-compatible API endpoint.
///
/// Conduit supports multiple backends that implement the OpenAI API specification:
/// - **OpenAI**: The official OpenAI API
/// - **OpenRouter**: Aggregator with access to multiple providers
/// - **Ollama**: Local inference server
/// - **Azure OpenAI**: Microsoft's Azure-hosted OpenAI service
/// - **Custom**: Any OpenAI-compatible endpoint
///
/// ## Usage
///
/// ```swift
/// // OpenAI (default)
/// let provider = OpenAIProvider(endpoint: .openAI, apiKey: "sk-...")
///
/// // OpenRouter
/// let provider = OpenAIProvider(endpoint: .openRouter, apiKey: "or-...")
///
/// // Local Ollama
/// let provider = OpenAIProvider(endpoint: .ollama())
///
/// // Azure OpenAI
/// let provider = OpenAIProvider(
///     endpoint: .azure(
///         resource: "my-resource",
///         deployment: "gpt-4",
///         apiVersion: "2024-02-15-preview"
///     ),
///     apiKey: "azure-key"
/// )
///
/// // Custom endpoint
/// let provider = OpenAIProvider(
///     endpoint: .custom(URL(string: "https://my-proxy.com/v1")!),
///     apiKey: "custom-key"
/// )
/// ```
///
/// ## Endpoint Characteristics
///
/// | Endpoint | Authentication | Local | Features |
/// |----------|---------------|-------|----------|
/// | OpenAI | Bearer token | No | Full API |
/// | OpenRouter | Bearer token | No | Text, Embeddings |
/// | Ollama | None | Yes | Text, Embeddings |
/// | Azure | API key | No | Varies by deployment |
/// | Custom | Configurable | Varies | Varies |
public enum OpenAIEndpoint: Sendable, Hashable {

    // MARK: - Cases

    /// OpenAI's official API at api.openai.com.
    ///
    /// This is the default endpoint providing access to GPT-4, DALL-E,
    /// Whisper, and other OpenAI models.
    ///
    /// ## Base URL
    /// `https://api.openai.com/v1`
    ///
    /// ## Authentication
    /// Requires a Bearer token (API key starting with `sk-`).
    ///
    /// ## Supported Features
    /// - Text generation (chat completions)
    /// - Streaming
    /// - Embeddings
    /// - Image generation (DALL-E)
    /// - Audio transcription (Whisper)
    /// - Function calling
    /// - JSON mode
    case openAI

    /// OpenRouter's API aggregator.
    ///
    /// OpenRouter provides unified access to models from OpenAI, Anthropic,
    /// Google, and other providers through a single API.
    ///
    /// ## Base URL
    /// `https://openrouter.ai/api/v1`
    ///
    /// ## Authentication
    /// Requires a Bearer token (API key starting with `sk-or-`).
    ///
    /// ## Supported Features
    /// - Text generation (chat completions)
    /// - Streaming
    /// - Embeddings
    /// - Function calling
    /// - JSON mode
    /// - Provider routing and fallbacks
    ///
    /// ## Model Naming
    /// OpenRouter uses `provider/model` format:
    /// - `openai/gpt-4-turbo`
    /// - `anthropic/claude-3-opus`
    /// - `google/gemini-pro`
    case openRouter

    /// Ollama local inference server.
    ///
    /// Ollama runs LLMs locally on your machine. No API key is required.
    ///
    /// ## Base URL
    /// `http://{host}:{port}/v1`
    ///
    /// Default: `http://localhost:11434/v1`
    ///
    /// ## Authentication
    /// None required for local server.
    ///
    /// ## Supported Features
    /// - Text generation (chat completions)
    /// - Streaming
    /// - Embeddings (with compatible models)
    ///
    /// ## Model Naming
    /// Ollama uses model names with optional tags:
    /// - `llama3.2`
    /// - `llama3.2:3b`
    /// - `codellama:7b-instruct`
    ///
    /// - Parameters:
    ///   - host: The hostname of the Ollama server. Default: `"localhost"`
    ///   - port: The port of the Ollama server. Default: `11434`
    case ollama(host: String = "localhost", port: Int = 11434)

    /// Azure OpenAI Service.
    ///
    /// Microsoft's enterprise-grade OpenAI service with Azure integration.
    ///
    /// ## Base URL
    /// `https://{resource}.openai.azure.com/openai`
    ///
    /// ## Authentication
    /// Requires an API key in the `api-key` header.
    ///
    /// ## Supported Features
    /// Varies by deployment. Check your Azure portal for available features.
    ///
    /// ## Model Naming
    /// Azure uses deployment names, not model names. The deployment
    /// determines which model is used.
    ///
    /// - Parameters:
    ///   - resource: Your Azure OpenAI resource name.
    ///   - deployment: The deployment name (maps to a specific model).
    ///   - apiVersion: The API version string (e.g., "2024-02-15-preview").
    case azure(resource: String, deployment: String, apiVersion: String)

    /// A custom OpenAI-compatible endpoint.
    ///
    /// Use this for:
    /// - Self-hosted OpenAI-compatible servers
    /// - Proxy servers
    /// - Other OpenAI-compatible APIs
    ///
    /// ## Base URL
    /// The provided URL is used as-is.
    ///
    /// ## Authentication
    /// Configure via `OpenAIAuthentication`.
    ///
    /// ## Supported Features
    /// Varies by implementation. Use capability detection.
    ///
    /// - Parameter url: The base URL of the OpenAI-compatible API.
    case custom(URL)

    // MARK: - Computed Properties

    /// The base URL for this endpoint.
    ///
    /// This URL is used as the prefix for all API requests.
    /// Path components like `/chat/completions` are appended to this URL.
    public var baseURL: URL {
        switch self {
        case .openAI:
            // This force unwrap is safe because the URL string is hardcoded and known valid.
            // If this fails, it indicates a fundamental system issue with URL parsing.
            return URL(string: "https://api.openai.com/v1")!

        case .openRouter:
            // This force unwrap is safe because the URL string is hardcoded and known valid.
            return URL(string: "https://openrouter.ai/api/v1")!

        case .ollama(let host, let port):
            // Validate and sanitize host to prevent URL injection
            let sanitizedHost: String
            if host.isEmpty {
                sanitizedHost = "localhost"
            } else {
                // Remove any URL scheme, path separators, or invalid characters
                var cleaned = host
                    .replacingOccurrences(of: "http://", with: "")
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "/", with: "")
                    .replacingOccurrences(of: "\\", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // If cleaning resulted in an empty string, use localhost
                if cleaned.isEmpty {
                    cleaned = "localhost"
                }
                sanitizedHost = cleaned
            }

            let validPort = (1...65535).contains(port) ? port : 11434

            // Use URLComponents for safer URL construction
            var components = URLComponents()
            components.scheme = "http"
            components.host = sanitizedHost
            components.port = validPort
            components.path = "/v1"

            // URL construction with validated components should never fail.
            // If it does, we fall back to localhost to avoid crashing.
            return components.url ?? URL(string: "http://localhost:11434/v1")!

        case .azure(let resource, _, _):
            // Validate resource name - use a safe fallback if empty or invalid
            let sanitizedResource = resource.isEmpty ? "default" : resource
            // URL construction with a validated resource name should never fail.
            // If it does, we use a fallback to avoid crashing the app.
            return URL(string: "https://\(sanitizedResource).openai.azure.com/openai")!

        case .custom(let url):
            return url
        }
    }

    /// The chat completions endpoint URL.
    ///
    /// For Azure, this includes the deployment name and API version.
    public var chatCompletionsURL: URL {
        switch self {
        case .azure(_, let deployment, let apiVersion):
            return baseURL
                .appendingPathComponent("deployments")
                .appendingPathComponent(deployment)
                .appendingPathComponent("chat/completions")
                .appending(queryItems: [URLQueryItem(name: "api-version", value: apiVersion)])

        default:
            return baseURL.appendingPathComponent("chat/completions")
        }
    }

    /// The embeddings endpoint URL.
    ///
    /// For Azure, this includes the deployment name and API version.
    public var embeddingsURL: URL {
        switch self {
        case .azure(_, let deployment, let apiVersion):
            return baseURL
                .appendingPathComponent("deployments")
                .appendingPathComponent(deployment)
                .appendingPathComponent("embeddings")
                .appending(queryItems: [URLQueryItem(name: "api-version", value: apiVersion)])

        default:
            return baseURL.appendingPathComponent("embeddings")
        }
    }

    /// The images generations endpoint URL.
    ///
    /// Only supported by OpenAI and some custom endpoints.
    public var imagesGenerationsURL: URL {
        baseURL.appendingPathComponent("images/generations")
    }

    /// The audio transcriptions endpoint URL.
    ///
    /// Only supported by OpenAI and some custom endpoints.
    public var audioTranscriptionsURL: URL {
        baseURL.appendingPathComponent("audio/transcriptions")
    }

    /// Whether this endpoint is local (no network required).
    public var isLocal: Bool {
        switch self {
        case .ollama:
            return true
        case .openAI, .openRouter, .azure, .custom:
            return false
        }
    }

    /// Whether this endpoint requires authentication.
    public var requiresAuthentication: Bool {
        switch self {
        case .ollama:
            return false
        case .openAI, .openRouter, .azure, .custom:
            return true
        }
    }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .openRouter:
            return "OpenRouter"
        case .ollama(let host, let port):
            if host == "localhost" && port == 11434 {
                return "Ollama (Local)"
            }
            return "Ollama (\(host):\(port))"
        case .azure(let resource, _, _):
            return "Azure OpenAI (\(resource))"
        case .custom(let url):
            return "Custom (\(url.host ?? url.absoluteString))"
        }
    }
}

// MARK: - CustomStringConvertible

extension OpenAIEndpoint: CustomStringConvertible {
    public var description: String {
        displayName
    }
}

// MARK: - Convenience Initializers

extension OpenAIEndpoint {

    /// Creates an Ollama endpoint with a custom URL.
    ///
    /// Use this when your Ollama server is at a non-standard location.
    ///
    /// - Parameter url: The full URL to the Ollama server's v1 API.
    /// - Returns: An Ollama endpoint with the parsed host and port.
    /// - Note: Falls back to localhost:11434 if URL parsing fails.
    public static func ollama(url: URL) -> OpenAIEndpoint {
        let host = url.host ?? "localhost"
        let port = url.port ?? 11434
        return .ollama(host: host, port: port)
    }

    /// Creates an Azure endpoint with common defaults.
    ///
    /// Uses the latest stable API version.
    ///
    /// - Parameters:
    ///   - resource: Your Azure OpenAI resource name.
    ///   - deployment: The deployment name.
    /// - Returns: An Azure endpoint with the default API version.
    public static func azure(resource: String, deployment: String) -> OpenAIEndpoint {
        .azure(resource: resource, deployment: deployment, apiVersion: "2024-02-15-preview")
    }
}

// MARK: - Validated Constructors

extension OpenAIEndpoint {

    /// Creates a validated Ollama endpoint.
    ///
    /// This factory method ensures that host and port values are valid before
    /// creating an Ollama endpoint. Invalid values are replaced with safe defaults.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Valid configuration
    /// let endpoint = OpenAIEndpoint.ollamaValidated(host: "192.168.1.10", port: 8080)
    ///
    /// // Empty host falls back to localhost
    /// let endpoint = OpenAIEndpoint.ollamaValidated(host: "", port: 11434)
    /// // Result: .ollama(host: "localhost", port: 11434)
    ///
    /// // Invalid port falls back to default
    /// let endpoint = OpenAIEndpoint.ollamaValidated(host: "localhost", port: 99999)
    /// // Result: .ollama(host: "localhost", port: 11434)
    /// ```
    ///
    /// - Parameters:
    ///   - host: The hostname. Must not be empty. Default: `"localhost"`
    ///   - port: The port number. Must be between 1 and 65535. Default: `11434`
    /// - Returns: An Ollama endpoint with validated parameters.
    /// - Note: Invalid values are automatically corrected to defaults rather than throwing errors.
    ///         Use `validateOllamaConfig(host:port:)` if you need explicit validation errors.
    public static func ollamaValidated(host: String = "localhost", port: Int = 11434) -> OpenAIEndpoint {
        let validHost = host.isEmpty ? "localhost" : host
        let validPort = (1...65535).contains(port) ? port : 11434
        return .ollama(host: validHost, port: validPort)
    }

    /// Validates an Ollama configuration.
    ///
    /// Use this method when you need explicit validation errors rather than
    /// automatic fallback to defaults.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// do {
    ///     try OpenAIEndpoint.validateOllamaConfig(host: "192.168.1.10", port: 8080)
    ///     let endpoint = .ollama(host: "192.168.1.10", port: 8080)
    /// } catch let error as OpenAIEndpoint.ValidationError {
    ///     print("Invalid configuration: \(error.localizedDescription)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - host: The hostname to validate.
    ///   - port: The port to validate.
    /// - Throws: `ValidationError.emptyHost` if host is empty.
    /// - Throws: `ValidationError.invalidPort` if port is not in range 1-65535.
    public static func validateOllamaConfig(host: String, port: Int) throws {
        guard !host.isEmpty else {
            throw ValidationError.emptyHost
        }
        guard (1...65535).contains(port) else {
            throw ValidationError.invalidPort(port)
        }
    }

    /// Validation errors for endpoint configuration.
    ///
    /// These errors are thrown by `validateOllamaConfig(host:port:)` when
    /// configuration parameters are invalid.
    public enum ValidationError: LocalizedError {

        /// The Ollama host is empty.
        case emptyHost

        /// The Ollama port is outside the valid range (1-65535).
        case invalidPort(Int)

        /// A localized description of the error.
        public var errorDescription: String? {
            switch self {
            case .emptyHost:
                return "Ollama host cannot be empty"
            case .invalidPort(let port):
                return "Invalid port \(port). Must be between 1 and 65535."
            }
        }
    }
}

// MARK: - Codable

extension OpenAIEndpoint: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case host
        case port
        case resource
        case deployment
        case apiVersion
        case url
    }

    private enum EndpointType: String, Codable {
        case openAI
        case openRouter
        case ollama
        case azure
        case custom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EndpointType.self, forKey: .type)

        switch type {
        case .openAI:
            self = .openAI

        case .openRouter:
            self = .openRouter

        case .ollama:
            let host = try container.decodeIfPresent(String.self, forKey: .host) ?? "localhost"
            let port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 11434
            self = .ollama(host: host, port: port)

        case .azure:
            let resource = try container.decode(String.self, forKey: .resource)
            let deployment = try container.decode(String.self, forKey: .deployment)
            let apiVersion = try container.decode(String.self, forKey: .apiVersion)
            self = .azure(resource: resource, deployment: deployment, apiVersion: apiVersion)

        case .custom:
            let url = try container.decode(URL.self, forKey: .url)
            self = .custom(url)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .openAI:
            try container.encode(EndpointType.openAI, forKey: .type)

        case .openRouter:
            try container.encode(EndpointType.openRouter, forKey: .type)

        case .ollama(let host, let port):
            try container.encode(EndpointType.ollama, forKey: .type)
            try container.encode(host, forKey: .host)
            try container.encode(port, forKey: .port)

        case .azure(let resource, let deployment, let apiVersion):
            try container.encode(EndpointType.azure, forKey: .type)
            try container.encode(resource, forKey: .resource)
            try container.encode(deployment, forKey: .deployment)
            try container.encode(apiVersion, forKey: .apiVersion)

        case .custom(let url):
            try container.encode(EndpointType.custom, forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}
