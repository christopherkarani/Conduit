// OpenAIModelID.swift
// SwiftAI
//
// Model identifiers for OpenAI-compatible providers.

import Foundation

// MARK: - OpenAIModelID

/// A model identifier for OpenAI-compatible APIs.
///
/// `OpenAIModelID` provides type-safe model identification across different
/// OpenAI-compatible backends. Each backend may use different naming conventions:
///
/// - **OpenAI**: `gpt-4o`, `gpt-3.5-turbo`, `dall-e-3`
/// - **OpenRouter**: `openai/gpt-4-turbo`, `anthropic/claude-3-opus`
/// - **Ollama**: `llama3.2`, `llama3.2:3b`, `codellama:7b-instruct`
/// - **Azure**: Uses deployment names, not model names
///
/// ## Usage
///
/// ### Using Static Properties
/// ```swift
/// let response = try await provider.generate(
///     "Hello",
///     model: .gpt4o
/// )
/// ```
///
/// ### Custom Model String
/// ```swift
/// let response = try await provider.generate(
///     "Hello",
///     model: OpenAIModelID("gpt-4-0125-preview")
/// )
/// ```
///
/// ### OpenRouter Format
/// ```swift
/// let response = try await provider.generate(
///     "Hello",
///     model: .openRouter("anthropic/claude-3-opus")
/// )
/// ```
///
/// ### Ollama Format
/// ```swift
/// let response = try await provider.generate(
///     "Hello",
///     model: .ollama("llama3.2:3b")
/// )
/// ```
///
/// ## Model Naming Conventions
///
/// This struct uses a pass-through approach where the model string is sent
/// directly to the API. This means:
/// - Use `gpt-4o` for OpenAI
/// - Use `openai/gpt-4o` for OpenRouter (if not using their alias)
/// - Use `llama3.2:3b` for Ollama
/// - Use the deployment name for Azure
///
/// The static properties provide common models with correct naming.
public struct OpenAIModelID: ModelIdentifying {

    // MARK: - Properties

    /// The raw model identifier string.
    ///
    /// This string is sent directly to the API in the `model` field.
    public let rawValue: String

    /// The provider type for OpenAI-compatible models.
    ///
    /// All OpenAI-compatible models use `.openAI` for routing purposes,
    /// though the actual backend may vary.
    public var provider: ProviderType {
        .openAI
    }

    /// Human-readable display name for the model.
    ///
    /// Extracts the model name from provider-prefixed formats:
    /// - `openai/gpt-4-turbo` -> `gpt-4-turbo`
    /// - `gpt-4o` -> `gpt-4o`
    /// - `llama3.2:3b` -> `llama3.2:3b`
    public var displayName: String {
        rawValue.components(separatedBy: "/").last ?? rawValue
    }

    // MARK: - Initialization

    /// Creates a model identifier from a raw string.
    ///
    /// - Parameter rawValue: The model identifier string.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a model identifier from a raw string.
    ///
    /// - Parameter rawValue: The model identifier string.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        "[OpenAI-Compatible] \(rawValue)"
    }
}

// MARK: - OpenAI Models

extension OpenAIModelID {

    // MARK: GPT-4 Series

    /// GPT-4o - Latest multimodal flagship model.
    ///
    /// High intelligence for complex tasks. Supports text, images, and audio.
    /// Context: 128K tokens
    public static let gpt4o = OpenAIModelID("gpt-4o")

    /// GPT-4o Mini - Affordable, intelligent small model.
    ///
    /// Fast and cost-effective for simpler tasks.
    /// Context: 128K tokens
    public static let gpt4oMini = OpenAIModelID("gpt-4o-mini")

    /// GPT-4 Turbo - Previous flagship with vision.
    ///
    /// High capability with vision and function calling.
    /// Context: 128K tokens
    public static let gpt4Turbo = OpenAIModelID("gpt-4-turbo")

    /// GPT-4 - Original GPT-4 model.
    ///
    /// Broad general knowledge and reasoning.
    /// Context: 8K tokens
    public static let gpt4 = OpenAIModelID("gpt-4")

    // MARK: GPT-3.5 Series

    /// GPT-3.5 Turbo - Fast, cost-effective model.
    ///
    /// Good for simple tasks, coding, and Q&A.
    /// Context: 16K tokens
    public static let gpt35Turbo = OpenAIModelID("gpt-3.5-turbo")

    // MARK: Reasoning Models

    /// o1 - High reasoning model.
    ///
    /// Designed for complex reasoning tasks.
    /// Context: 128K tokens
    public static let o1 = OpenAIModelID("o1")

    /// o1 Mini - Fast reasoning model.
    ///
    /// Faster reasoning for simpler tasks.
    /// Context: 128K tokens
    public static let o1Mini = OpenAIModelID("o1-mini")

    /// o3 Mini - Latest mini reasoning model.
    ///
    /// Advanced reasoning with faster inference.
    /// Context: 128K tokens
    public static let o3Mini = OpenAIModelID("o3-mini")

    // MARK: Embedding Models

    /// Text Embedding 3 Small - Efficient embeddings.
    ///
    /// 1536 dimensions, optimized for speed.
    public static let textEmbedding3Small = OpenAIModelID("text-embedding-3-small")

    /// Text Embedding 3 Large - High-quality embeddings.
    ///
    /// 3072 dimensions, optimized for quality.
    public static let textEmbedding3Large = OpenAIModelID("text-embedding-3-large")

    /// Ada v2 - Legacy embedding model.
    ///
    /// 1536 dimensions.
    public static let textEmbeddingAda002 = OpenAIModelID("text-embedding-ada-002")

    // MARK: Image Models

    /// DALL-E 3 - Latest image generation model.
    ///
    /// High quality, supports 1024x1024, 1024x1792, 1792x1024.
    public static let dallE3 = OpenAIModelID("dall-e-3")

    /// DALL-E 2 - Previous image generation model.
    ///
    /// Supports up to 1024x1024.
    public static let dallE2 = OpenAIModelID("dall-e-2")

    // MARK: Audio Models

    /// Whisper 1 - Speech recognition model.
    ///
    /// Supports transcription and translation.
    public static let whisper1 = OpenAIModelID("whisper-1")

    /// TTS 1 - Text-to-speech model.
    ///
    /// Standard quality, faster.
    public static let tts1 = OpenAIModelID("tts-1")

    /// TTS 1 HD - High-definition text-to-speech.
    ///
    /// Higher quality audio.
    public static let tts1HD = OpenAIModelID("tts-1-hd")
}

// MARK: - OpenRouter Helpers

extension OpenAIModelID {

    /// Creates a model ID for OpenRouter with explicit provider prefix.
    ///
    /// OpenRouter uses `provider/model` format for routing:
    /// - `openai/gpt-4-turbo`
    /// - `anthropic/claude-3-opus`
    /// - `google/gemini-pro`
    ///
    /// ## Usage
    /// ```swift
    /// let model = OpenAIModelID.openRouter("anthropic/claude-3-opus")
    /// ```
    ///
    /// - Parameter model: The full model identifier including provider prefix.
    /// - Returns: A model ID for use with OpenRouter.
    public static func openRouter(_ model: String) -> OpenAIModelID {
        OpenAIModelID(model)
    }

    // MARK: Common OpenRouter Models

    /// Claude 3 Opus via OpenRouter.
    public static let claudeOpus = OpenAIModelID("anthropic/claude-3-opus")

    /// Claude 3 Sonnet via OpenRouter.
    public static let claudeSonnet = OpenAIModelID("anthropic/claude-3-sonnet")

    /// Claude 3 Haiku via OpenRouter.
    public static let claudeHaiku = OpenAIModelID("anthropic/claude-3-haiku")

    /// Gemini Pro via OpenRouter.
    public static let geminiPro = OpenAIModelID("google/gemini-pro")

    /// Gemini Pro 1.5 via OpenRouter.
    public static let geminiPro15 = OpenAIModelID("google/gemini-pro-1.5")

    /// Mixtral 8x7B via OpenRouter.
    public static let mixtral8x7B = OpenAIModelID("mistralai/mixtral-8x7b-instruct")

    /// Llama 3.1 70B via OpenRouter.
    public static let llama31B70B = OpenAIModelID("meta-llama/llama-3.1-70b-instruct")

    /// Llama 3.1 8B via OpenRouter.
    public static let llama31B8B = OpenAIModelID("meta-llama/llama-3.1-8b-instruct")
}

// MARK: - Ollama Helpers

extension OpenAIModelID {

    /// Creates a model ID for Ollama local models.
    ///
    /// Ollama uses `model:tag` format:
    /// - `llama3.2` (uses default tag)
    /// - `llama3.2:3b`
    /// - `codellama:7b-instruct`
    ///
    /// ## Usage
    /// ```swift
    /// let model = OpenAIModelID.ollama("llama3.2:3b")
    /// ```
    ///
    /// - Parameter model: The Ollama model name with optional tag.
    /// - Returns: A model ID for use with Ollama.
    public static func ollama(_ model: String) -> OpenAIModelID {
        OpenAIModelID(model)
    }

    // MARK: Common Ollama Models

    /// Llama 3.2 (latest, default size).
    public static let ollamaLlama32 = OpenAIModelID("llama3.2")

    /// Llama 3.2 3B parameter version.
    public static let ollamaLlama32B3B = OpenAIModelID("llama3.2:3b")

    /// Llama 3.2 1B parameter version.
    public static let ollamaLlama32B1B = OpenAIModelID("llama3.2:1b")

    /// Mistral 7B.
    public static let ollamaMistral = OpenAIModelID("mistral")

    /// CodeLlama 7B.
    public static let ollamaCodeLlama = OpenAIModelID("codellama")

    /// Phi-3.
    public static let ollamaPhi3 = OpenAIModelID("phi3")

    /// Gemma 2.
    public static let ollamaGemma2 = OpenAIModelID("gemma2")

    /// Qwen 2.5.
    public static let ollamaQwen25 = OpenAIModelID("qwen2.5")

    /// DeepSeek Coder.
    public static let ollamaDeepseekCoder = OpenAIModelID("deepseek-coder")

    /// Nomic Embed - Embedding model for Ollama.
    public static let ollamaNomicEmbed = OpenAIModelID("nomic-embed-text")
}

// MARK: - Azure Helpers

extension OpenAIModelID {

    /// Creates a model ID for Azure OpenAI deployments.
    ///
    /// Azure OpenAI uses deployment names instead of model names.
    /// The deployment maps to a specific model version.
    ///
    /// ## Usage
    /// ```swift
    /// let model = OpenAIModelID.azure(deployment: "my-gpt4-deployment")
    /// ```
    ///
    /// - Parameter deployment: The Azure deployment name.
    /// - Returns: A model ID for use with Azure OpenAI.
    public static func azure(deployment: String) -> OpenAIModelID {
        OpenAIModelID(deployment)
    }
}

// MARK: - ExpressibleByStringLiteral

extension OpenAIModelID: ExpressibleByStringLiteral {

    /// Creates a model ID from a string literal.
    ///
    /// ## Usage
    /// ```swift
    /// let model: OpenAIModelID = "gpt-4o"
    /// ```
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}

// MARK: - Codable

extension OpenAIModelID: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
