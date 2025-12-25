// OpenAICapabilities.swift
// SwiftAI
//
// Capability flags for OpenAI-compatible providers.

import Foundation

// MARK: - OpenAICapabilities

/// Capability flags for OpenAI-compatible providers.
///
/// Different OpenAI-compatible backends support different features.
/// Use this type to check what operations are available before
/// attempting them.
///
/// ## Usage
///
/// ### Checking Capabilities
/// ```swift
/// let provider = OpenAIProvider(endpoint: .openRouter, apiKey: "...")
/// let caps = await provider.capabilities
///
/// if caps.contains(.imageGeneration) {
///     let image = try await provider.generateImage(prompt: "A cat")
/// } else {
///     print("Image generation not supported")
/// }
/// ```
///
/// ### Multiple Capability Check
/// ```swift
/// let required: OpenAICapabilities = [.streaming, .functionCalling]
/// if caps.isSuperset(of: required) {
///     // Both streaming and function calling available
/// }
/// ```
///
/// ## Backend Capabilities
///
/// | Capability | OpenAI | OpenRouter | Ollama | Azure |
/// |------------|--------|------------|--------|-------|
/// | textGeneration | Yes | Yes | Yes | Yes |
/// | streaming | Yes | Yes | Yes | Yes |
/// | embeddings | Yes | Yes | Yes | Depends |
/// | imageGeneration | Yes | No | No | Depends |
/// | transcription | Yes | No | No | Depends |
/// | functionCalling | Yes | Yes | Some | Depends |
/// | jsonMode | Yes | Yes | Some | Yes |
/// | vision | Yes | Some | Some | Depends |
public struct OpenAICapabilities: OptionSet, Sendable, Hashable {

    // MARK: - RawValue

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // MARK: - Capability Flags

    /// Text generation (chat completions).
    ///
    /// Supported by all OpenAI-compatible backends.
    public static let textGeneration = OpenAICapabilities(rawValue: 1 << 0)

    /// Streaming text generation.
    ///
    /// Server-sent events (SSE) streaming of responses.
    /// Supported by all major backends.
    public static let streaming = OpenAICapabilities(rawValue: 1 << 1)

    /// Text embeddings.
    ///
    /// Vector embeddings for semantic search and similarity.
    /// Requires embedding-capable models.
    public static let embeddings = OpenAICapabilities(rawValue: 1 << 2)

    /// Image generation (DALL-E).
    ///
    /// Text-to-image generation.
    /// Only supported by OpenAI and some Azure deployments.
    public static let imageGeneration = OpenAICapabilities(rawValue: 1 << 3)

    /// Audio transcription (Whisper).
    ///
    /// Speech-to-text transcription.
    /// Only supported by OpenAI and some Azure deployments.
    public static let transcription = OpenAICapabilities(rawValue: 1 << 4)

    /// Function/tool calling.
    ///
    /// Structured function calling with JSON schemas.
    /// Supported by most modern backends.
    public static let functionCalling = OpenAICapabilities(rawValue: 1 << 5)

    /// JSON mode.
    ///
    /// Forces model to output valid JSON.
    /// Supported by most modern backends.
    public static let jsonMode = OpenAICapabilities(rawValue: 1 << 6)

    /// Vision/multimodal input.
    ///
    /// Ability to process images in prompts.
    /// Requires vision-capable models.
    public static let vision = OpenAICapabilities(rawValue: 1 << 7)

    /// Text-to-speech (TTS).
    ///
    /// Audio generation from text.
    /// Only supported by OpenAI.
    public static let textToSpeech = OpenAICapabilities(rawValue: 1 << 8)

    /// Parallel function calling.
    ///
    /// Multiple function calls in a single response.
    /// Supported by newer models.
    public static let parallelFunctionCalling = OpenAICapabilities(rawValue: 1 << 9)

    /// Structured outputs (response format schemas).
    ///
    /// JSON schema-based output validation.
    /// Supported by GPT-4o and newer.
    public static let structuredOutputs = OpenAICapabilities(rawValue: 1 << 10)

    // MARK: - Preset Capability Sets

    /// Full OpenAI capabilities.
    ///
    /// All features available through the official OpenAI API.
    public static let openAI: OpenAICapabilities = [
        .textGeneration,
        .streaming,
        .embeddings,
        .imageGeneration,
        .transcription,
        .functionCalling,
        .jsonMode,
        .vision,
        .textToSpeech,
        .parallelFunctionCalling,
        .structuredOutputs
    ]

    /// OpenRouter capabilities.
    ///
    /// Text-focused features available through OpenRouter.
    public static let openRouter: OpenAICapabilities = [
        .textGeneration,
        .streaming,
        .embeddings,
        .functionCalling,
        .jsonMode,
        .vision  // Some models
    ]

    /// Ollama capabilities.
    ///
    /// Core text and embedding features for local inference.
    public static let ollama: OpenAICapabilities = [
        .textGeneration,
        .streaming,
        .embeddings,
        .vision  // Some models like llava
    ]

    /// Minimal text-only capabilities.
    ///
    /// The baseline that all backends should support.
    public static let textOnly: OpenAICapabilities = [
        .textGeneration,
        .streaming
    ]

    /// All available capabilities.
    public static let all: OpenAICapabilities = [
        .textGeneration,
        .streaming,
        .embeddings,
        .imageGeneration,
        .transcription,
        .functionCalling,
        .jsonMode,
        .vision,
        .textToSpeech,
        .parallelFunctionCalling,
        .structuredOutputs
    ]

    // MARK: - Capability Descriptions

    /// Human-readable descriptions of contained capabilities.
    public var descriptions: [String] {
        var result: [String] = []

        if contains(.textGeneration) { result.append("Text Generation") }
        if contains(.streaming) { result.append("Streaming") }
        if contains(.embeddings) { result.append("Embeddings") }
        if contains(.imageGeneration) { result.append("Image Generation") }
        if contains(.transcription) { result.append("Transcription") }
        if contains(.functionCalling) { result.append("Function Calling") }
        if contains(.jsonMode) { result.append("JSON Mode") }
        if contains(.vision) { result.append("Vision") }
        if contains(.textToSpeech) { result.append("Text-to-Speech") }
        if contains(.parallelFunctionCalling) { result.append("Parallel Function Calling") }
        if contains(.structuredOutputs) { result.append("Structured Outputs") }

        return result
    }
}

// MARK: - CustomStringConvertible

extension OpenAICapabilities: CustomStringConvertible {
    public var description: String {
        let caps = descriptions
        guard !caps.isEmpty else {
            return "OpenAICapabilities(none)"
        }
        return "OpenAICapabilities(\(caps.joined(separator: ", ")))"
    }
}

// MARK: - Capability Checking

extension OpenAICapabilities {

    /// Checks if a specific capability is supported.
    ///
    /// - Parameter capability: The capability to check.
    /// - Returns: `true` if the capability is supported.
    public func supports(_ capability: OpenAICapabilities) -> Bool {
        contains(capability)
    }

    /// Checks if all specified capabilities are supported.
    ///
    /// - Parameter capabilities: The capabilities to check.
    /// - Returns: `true` if all capabilities are supported.
    public func supportsAll(_ capabilities: OpenAICapabilities) -> Bool {
        isSuperset(of: capabilities)
    }

    /// Checks if any of the specified capabilities are supported.
    ///
    /// - Parameter capabilities: The capabilities to check.
    /// - Returns: `true` if any capability is supported.
    public func supportsAny(_ capabilities: OpenAICapabilities) -> Bool {
        !intersection(capabilities).isEmpty
    }

    /// Returns capabilities that are missing.
    ///
    /// - Parameter required: The required capabilities.
    /// - Returns: The capabilities that are not supported.
    public func missing(from required: OpenAICapabilities) -> OpenAICapabilities {
        required.subtracting(self)
    }
}

// MARK: - Endpoint Capabilities

extension OpenAIEndpoint {

    /// Default capabilities for this endpoint.
    ///
    /// This provides a baseline of expected capabilities.
    /// Actual capabilities may vary based on model and configuration.
    public var defaultCapabilities: OpenAICapabilities {
        switch self {
        case .openAI:
            return .openAI
        case .openRouter:
            return .openRouter
        case .ollama:
            return .ollama
        case .azure:
            // Azure capabilities depend on deployment
            return [.textGeneration, .streaming, .functionCalling, .jsonMode]
        case .custom:
            // Assume basic text capabilities for unknown endpoints
            return .textOnly
        }
    }
}
