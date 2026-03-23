// ModelIdentifier.swift
// Conduit

import Foundation

// MARK: - ModelIdentifier

/// Identifies a model and its inference provider.
///
/// Conduit requires explicit model selection—there is no automatic
/// provider detection. This ensures developers understand exactly
/// where inference will occur.
///
/// ## Usage
/// ```swift
/// // Local MLX model
/// let localModel: ModelIdentifier = .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
///
/// // Local llama.cpp GGUF model
/// let ggufModel: ModelIdentifier = .llama("/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf")
///
/// // Local compiled Core ML model
/// let coremlModel: ModelIdentifier = .coreml("/models/StatefulMistral7BInstructInt4.mlmodelc")
///
/// // Cloud HuggingFace model
/// let cloudModel: ModelIdentifier = .huggingFace("meta-llama/Llama-3.1-70B-Instruct")
///
/// // Apple Foundation Models
/// let appleModel: ModelIdentifier = .foundationModels
/// ```
///
/// ## Codable Representation
///
/// ModelIdentifier encodes to JSON with the following structure:
/// - MLX models: `{"type": "mlx", "id": "mlx-community/model-name"}`
/// - llama.cpp models: `{"type": "llama", "id": "/path/to/model.gguf"}`
/// - Core ML models: `{"type": "coreml", "id": "/path/to/model.mlmodelc"}`
/// - HuggingFace models: `{"type": "huggingFace", "id": "org/model-name"}`
/// - Foundation models: `{"type": "foundationModels"}` (no id field)
///
/// ## Protocol Conformances
/// - `ModelIdentifying`: Provides raw value, display name, and provider type
/// - `Codable`: Custom JSON encoding/decoding
/// - `Hashable`: Inherited from ModelIdentifying
/// - `Sendable`: Thread-safe across concurrency boundaries
/// - `CustomStringConvertible`: Human-readable description
public enum ModelIdentifier: ModelIdentifying, Codable {

    /// A model to be run via OpenAI-compatible APIs.
    ///
    /// Includes OpenAI, OpenRouter, and Ollama model strings.
    /// - Parameter id: Provider-specific model identifier.
    case openAI(String)

    /// A model to be run via Anthropic Claude APIs.
    ///
    /// - Parameter id: Anthropic model identifier.
    case anthropic(String)

    /// A model to be run locally via MLX on Apple Silicon.
    ///
    /// - Parameter id: The HuggingFace repository ID (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit")
    case mlx(String)

    /// A local MLX model loaded directly from a filesystem path.
    ///
    /// This allows loading MLX models from local directories without requiring
    /// HuggingFace Hub download. The path should point to a directory containing:
    /// - config.json (model configuration)
    /// - *.safetensors files (model weights)
    /// - tokenizer.json or tokenizer_config.json (tokenizer files)
    ///
    /// - Parameter path: Absolute path to the local model directory.
    ///
    /// ## Example
    /// ```swift
    /// let localModel: ModelIdentifier = .mlxLocal("/Users/me/models/Qwen3-8B-MLX-bf16")
    /// ```
    case mlxLocal(String)

    /// A local GGUF model to be run directly with llama.cpp.
    ///
    /// - Parameter path: Absolute or relative path to the `.gguf` model file.
    case llama(String)

    /// A local compiled Core ML model to run on-device.
    ///
    /// - Parameter path: Absolute or relative path to the compiled `.mlmodelc` directory.
    case coreml(String)

    /// A model to be run via HuggingFace Inference API.
    ///
    /// - Parameter id: The HuggingFace model ID (e.g., "meta-llama/Llama-3.1-70B-Instruct")
    case huggingFace(String)

    /// Apple's on-device Foundation Models (iOS 26+).
    ///
    /// This uses Apple's system language model. No model ID is needed
    /// as Apple manages the model automatically.
    case foundationModels

    /// Moonshot Kimi API models (cloud).
    ///
    /// Kimi models feature 256K context windows and strong reasoning.
    /// - Parameter id: The Kimi model ID (e.g., "kimi-k2-5")
    case kimi(String)

    /// MiniMax API models (cloud).
    ///
    /// - Parameter id: The MiniMax model ID (e.g., "MiniMax-M2.7")
    case miniMax(String)

    // MARK: - ModelIdentifying

    /// The raw string identifier for this model.
    ///
    /// - For MLX and HuggingFace models: Returns the repository ID string.
    /// - For MLX Local models: Returns the local filesystem path.
    /// - For Foundation Models: Returns "apple-foundation-models".
    public var rawValue: String {
        switch self {
        case .openAI(let id):
            return id
        case .anthropic(let id):
            return id
        case .mlx(let id):
            return id
        case .mlxLocal(let path):
            return path
        case .llama(let path):
            return path
        case .coreml(let path):
            return path
        case .huggingFace(let id):
            return id
        case .foundationModels:
            return "apple-foundation-models"
        case .kimi(let id):
            return id
        case .miniMax(let id):
            return id
        }
    }

    /// Human-readable display name for the model.
    ///
    /// Extracts the last path component from repository IDs for brevity.
    /// - For MLX and HuggingFace models: Returns the model name (last path component).
    /// - For MLX Local, llama.cpp, and CoreML models: Returns the directory/file name.
    /// - For Foundation Models: Returns "Apple Intelligence".
    public var displayName: String {
        switch self {
        case .openAI(let id):
            return id.components(separatedBy: "/").last ?? id
        case .anthropic(let id):
            return id.components(separatedBy: "/").last ?? id
        case .mlx(let id):
            return id.components(separatedBy: "/").last ?? id
        case .mlxLocal(let path):
            let directoryName = URL(fileURLWithPath: path).lastPathComponent
            return directoryName.isEmpty ? path : directoryName
        case .llama(let path):
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            return fileName.isEmpty ? path : fileName
        case .coreml(let path):
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            return fileName.isEmpty ? path : fileName
        case .huggingFace(let id):
            return id.components(separatedBy: "/").last ?? id
        case .foundationModels:
            return "Apple Intelligence"
        case .kimi(let id):
            return id
        case .miniMax(let id):
            return id
        }
    }

    /// The provider this model belongs to.
    ///
    /// - Returns: The appropriate `ProviderType` case for this model.
    public var provider: ProviderType {
        switch self {
        case .openAI:
            return .openAI
        case .anthropic:
            return .anthropic
        case .mlx:
            return .mlx
        case .mlxLocal:
            return .mlx
        case .llama:
            return .llama
        case .coreml:
            return .coreml
        case .huggingFace:
            return .huggingFace
        case .foundationModels:
            return .foundationModels
        case .kimi:
            return .kimi
        case .miniMax:
            return .minimax
        }
    }

    // MARK: - CustomStringConvertible

    /// A textual representation of this model identifier.
    ///
    /// Format: `"[Provider Name] model-id"`
    ///
    /// ## Examples
    /// - `"[MLX (Local)] mlx-community/Llama-3.2-1B-Instruct-4bit"`
    /// - `"[llama.cpp (Local)] /models/Llama-3.2-3B-Instruct-Q4_K_M.gguf"`
    /// - `"[HuggingFace (Cloud)] meta-llama/Llama-3.1-70B-Instruct"`
    /// - `"[Apple Foundation Models] apple-foundation-models"`
    public var description: String {
        "[\(provider.displayName)] \(rawValue)"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    private enum ModelType: String, Codable {
        case openAI
        case anthropic
        case mlx
        case mlxLocal
        case llama
        case coreml
        case huggingFace
        case foundationModels
        case kimi
        case miniMax
    }

    /// Decodes a ModelIdentifier from a JSON decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the data is malformed.
    ///
    /// ## Expected JSON Structure
    /// - MLX: `{"type": "mlx", "id": "model-id"}`
    /// - MLX Local: `{"type": "mlxLocal", "id": "/path/to/model"}`
    /// - llama.cpp: `{"type": "llama", "id": "/path/to/model.gguf"}`
    /// - Core ML: `{"type": "coreml", "id": "/path/to/model.mlmodelc"}`
    /// - HuggingFace: `{"type": "huggingFace", "id": "model-id"}`
    /// - Foundation Models: `{"type": "foundationModels"}` (no id field required)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ModelType.self, forKey: .type)

        switch type {
        case .openAI:
            let id = try container.decode(String.self, forKey: .id)
            self = .openAI(id)

        case .anthropic:
            let id = try container.decode(String.self, forKey: .id)
            self = .anthropic(id)

        case .mlx:
            let id = try container.decode(String.self, forKey: .id)
            self = .mlx(id)

        case .mlxLocal:
            let path = try container.decode(String.self, forKey: .id)
            self = .mlxLocal(path)

        case .llama:
            let path = try container.decode(String.self, forKey: .id)
            self = .llama(path)

        case .coreml:
            let path = try container.decode(String.self, forKey: .id)
            self = .coreml(path)

        case .huggingFace:
            let id = try container.decode(String.self, forKey: .id)
            self = .huggingFace(id)

        case .foundationModels:
            self = .foundationModels

        case .kimi:
            let id = try container.decode(String.self, forKey: .id)
            self = .kimi(id)

        case .miniMax:
            let id = try container.decode(String.self, forKey: .id)
            self = .miniMax(id)
        }
    }

    /// Encodes this ModelIdentifier to a JSON encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    ///
    /// ## Generated JSON Structure
    /// - MLX: `{"type": "mlx", "id": "model-id"}`
    /// - MLX Local: `{"type": "mlxLocal", "id": "/path/to/model"}`
    /// - llama.cpp: `{"type": "llama", "id": "/path/to/model.gguf"}`
    /// - Core ML: `{"type": "coreml", "id": "/path/to/model.mlmodelc"}`
    /// - HuggingFace: `{"type": "huggingFace", "id": "model-id"}`
    /// - Foundation Models: `{"type": "foundationModels"}` (no id field)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .openAI(let id):
            try container.encode(ModelType.openAI, forKey: .type)
            try container.encode(id, forKey: .id)

        case .anthropic(let id):
            try container.encode(ModelType.anthropic, forKey: .type)
            try container.encode(id, forKey: .id)

        case .mlx(let id):
            try container.encode(ModelType.mlx, forKey: .type)
            try container.encode(id, forKey: .id)

        case .mlxLocal(let path):
            try container.encode(ModelType.mlxLocal, forKey: .type)
            try container.encode(path, forKey: .id)

        case .llama(let path):
            try container.encode(ModelType.llama, forKey: .type)
            try container.encode(path, forKey: .id)

        case .coreml(let path):
            try container.encode(ModelType.coreml, forKey: .type)
            try container.encode(path, forKey: .id)

        case .huggingFace(let id):
            try container.encode(ModelType.huggingFace, forKey: .type)
            try container.encode(id, forKey: .id)

        case .foundationModels:
            try container.encode(ModelType.foundationModels, forKey: .type)

        case .kimi(let id):
            try container.encode(ModelType.kimi, forKey: .type)
            try container.encode(id, forKey: .id)

        case .miniMax(let id):
            try container.encode(ModelType.miniMax, forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}

// MARK: - Convenience Extensions

extension ModelIdentifier {

    /// Whether this model requires network connectivity.
    ///
    /// Delegates to the provider's `requiresNetwork` property.
    /// - MLX, llama.cpp, and Foundation Models: `false` (offline capable)
    /// - HuggingFace: `true` (requires internet connection)
    public var requiresNetwork: Bool {
        provider.requiresNetwork
    }

    /// Whether this model runs locally without network access.
    ///
    /// Inverse of `requiresNetwork`.
    /// - MLX, llama.cpp, and Foundation Models: `true` (local inference)
    /// - HuggingFace: `false` (cloud inference)
    public var isLocal: Bool {
        !requiresNetwork
    }
}

// MARK: - Model Registry

/// Registry of commonly used models with convenient static accessors.
///
/// Using registry constants ensures correct model IDs and makes
/// code more readable.
///
/// ## Usage
/// ```swift
/// let response = try await provider.generate(
///     "Hello!",
///     model: .llama3_2_1b,
///     config: .default
/// )
/// ```
public extension ModelIdentifier {

    // MARK: - MLX Local Models (Recommended)

    /// Llama 3.2 1B (4-bit quantized) - Fast, lightweight
    ///
    /// Ideal for: Quick responses, low memory usage (~800MB RAM)
    static let llama3_2_1b = ModelIdentifier.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")

    /// Llama 3.2 3B (4-bit quantized) - Balanced performance
    ///
    /// Ideal for: General purpose use, good quality/speed tradeoff (~2GB RAM)
    static let llama3_2_3b = ModelIdentifier.mlx("mlx-community/Llama-3.2-3B-Instruct-4bit")

    /// Phi-3 Mini (4-bit quantized) - Microsoft's efficient model
    ///
    /// Ideal for: Code generation, technical content (~2.5GB RAM)
    static let phi3Mini = ModelIdentifier.mlx("mlx-community/Phi-3-mini-4k-instruct-4bit")

    /// Phi-4 (4-bit quantized) - Latest Phi model
    ///
    /// Ideal for: Latest capabilities from Microsoft's Phi series (~8GB RAM)
    static let phi4 = ModelIdentifier.mlx("mlx-community/phi-4-4bit")

    /// Qwen 2.5 3B (4-bit quantized)
    ///
    /// Ideal for: Multilingual support, instruction following (~2GB RAM)
    static let qwen2_5_3b = ModelIdentifier.mlx("mlx-community/Qwen2.5-3B-Instruct-4bit")

    /// Mistral 7B (4-bit quantized)
    ///
    /// Ideal for: High quality responses, larger context window (~4GB RAM)
    static let mistral7B = ModelIdentifier.mlx("mlx-community/Mistral-7B-Instruct-v0.3-4bit")

    /// Gemma 2 2B (4-bit quantized)
    ///
    /// Ideal for: Google's efficient model, good instruction following (~1.5GB RAM)
    static let gemma2_2b = ModelIdentifier.mlx("mlx-community/gemma-2-2b-it-4bit")

    // MARK: - MLX Embedding Models

    /// BGE Small - Fast embeddings
    ///
    /// Ideal for: Quick similarity search, low memory usage (384 dimensions)
    static let bgeSmall = ModelIdentifier.mlx("mlx-community/bge-small-en-v1.5")

    /// BGE Large - Higher quality embeddings
    ///
    /// Ideal for: High-quality semantic search, RAG applications (1024 dimensions)
    static let bgeLarge = ModelIdentifier.mlx("mlx-community/bge-large-en-v1.5")

    /// Nomic Embed - Good balance
    ///
    /// Ideal for: General-purpose embeddings, balanced quality/speed (768 dimensions)
    static let nomicEmbed = ModelIdentifier.mlx("mlx-community/nomic-embed-text-v1.5")

    // MARK: - Local MLX Models

    /// Creates a local MLX model identifier from a filesystem path.
    ///
    /// Use this to load MLX models directly from local directories without
    /// requiring HuggingFace Hub download.
    ///
    /// - Parameter path: Absolute path to the local model directory.
    /// - Returns: A `ModelIdentifier` configured for local MLX loading.
    ///
    /// ## Example
    /// ```swift
    /// let localModel = ModelIdentifier.mlxLocal(path: "/Users/me/models/Qwen3-8B-MLX-bf16")
    /// ```
    static func mlxLocal(path: String) -> ModelIdentifier {
        .mlxLocal(path)
    }

    // MARK: - HuggingFace Cloud Models

    /// Llama 3.1 70B - High capability, cloud only
    ///
    /// Ideal for: Complex reasoning, highest quality responses (requires API key)
    static let llama3_1_70B = ModelIdentifier.huggingFace("meta-llama/Llama-3.1-70B-Instruct")

    /// Llama 3.1 8B - Balanced cloud option
    ///
    /// Ideal for: Cost-effective cloud inference, good quality (requires API key)
    static let llama3_1_8B = ModelIdentifier.huggingFace("meta-llama/Llama-3.1-8B-Instruct")

    /// Mixtral 8x7B - MoE architecture
    ///
    /// Ideal for: Mixture-of-Experts efficiency, strong performance (requires API key)
    static let mixtral8x7B = ModelIdentifier.huggingFace("mistralai/Mixtral-8x7B-Instruct-v0.1")

    /// DeepSeek R1 - Reasoning focused
    ///
    /// Ideal for: Complex reasoning tasks, chain-of-thought (requires API key)
    static let deepseekR1 = ModelIdentifier.huggingFace("deepseek-ai/DeepSeek-R1")

    /// Whisper Large V3 - Speech recognition
    ///
    /// Ideal for: Audio transcription, supports 99 languages (requires API key)
    static let whisperLargeV3 = ModelIdentifier.huggingFace("openai/whisper-large-v3")

    // MARK: - Apple Foundation Models

    /// Apple's on-device Foundation Model
    ///
    /// Ideal for: Privacy-sensitive apps, system integration (iOS 26+, no API key needed)
    static let apple = ModelIdentifier.foundationModels

    // MARK: - Kimi Cloud Models

    /// Kimi K2.5 - Latest flagship with advanced reasoning
    ///
    /// Ideal for: Complex reasoning, coding, long context (256K tokens, requires API key)
    static let kimiK2_5 = ModelIdentifier.kimi("kimi-k2-5")

    /// Kimi K2 - General-purpose model
    ///
    /// Ideal for: General tasks, good performance (256K tokens, requires API key)
    static let kimiK2 = ModelIdentifier.kimi("kimi-k2")

    /// Kimi K1.5 - Long context specialist
    ///
    /// Ideal for: Document analysis, summarization (256K tokens, requires API key)
    static let kimiK1_5 = ModelIdentifier.kimi("kimi-k1-5")
}

// MARK: - Legacy Compatibility

public extension ModelIdentifier {

    // MARK: OpenAI Latest Models

    static let gpt5_4 = ModelIdentifier.openAI("gpt-5.4")
    static let gpt5_4Mini = ModelIdentifier.openAI("gpt-5.4-mini")
    static let gpt5_2 = ModelIdentifier.openAI("gpt-5.2")
    static let gpt5_2ChatLatest = ModelIdentifier.openAI("gpt-5.2-chat-latest")
    static let gpt5_2Codex = ModelIdentifier.openAI("gpt-5.2-codex")
    static let gpt5_2Pro = ModelIdentifier.openAI("gpt-5.2-pro")
    static let gpt5_1 = ModelIdentifier.openAI("gpt-5.1")
    static let gpt5_1Codex = ModelIdentifier.openAI("gpt-5.1-codex")
    static let gpt5_1CodexMax = ModelIdentifier.openAI("gpt-5.1-codex-max")
    static let gpt5 = ModelIdentifier.openAI("gpt-5")
    static let gpt5Mini = ModelIdentifier.openAI("gpt-5-mini")
    static let gpt5Nano = ModelIdentifier.openAI("gpt-5-nano")

    // MARK: OpenAI-Compatible Legacy Names

    static let gpt4o = ModelIdentifier.openAI("gpt-4o")
    static let gpt4oMini = ModelIdentifier.openAI("gpt-4o-mini")
    static let gpt4Turbo = ModelIdentifier.openAI("gpt-4-turbo")
    static let gpt4 = ModelIdentifier.openAI("gpt-4")
    static let gpt35Turbo = ModelIdentifier.openAI("gpt-3.5-turbo")
    static let o1 = ModelIdentifier.openAI("o1")
    static let o1Mini = ModelIdentifier.openAI("o1-mini")
    static let o3Mini = ModelIdentifier.openAI("o3-mini")
    static let textEmbedding3Small = ModelIdentifier.openAI("text-embedding-3-small")
    static let textEmbedding3Large = ModelIdentifier.openAI("text-embedding-3-large")
    static let textEmbeddingAda002 = ModelIdentifier.openAI("text-embedding-ada-002")
    static let dallE3 = ModelIdentifier.openAI("dall-e-3")
    static let dallE2 = ModelIdentifier.openAI("dall-e-2")
    static let whisper1 = ModelIdentifier.openAI("whisper-1")
    static let tts1 = ModelIdentifier.openAI("tts-1")
    static let tts1HD = ModelIdentifier.openAI("tts-1-hd")

    static func openRouter(_ model: String) -> ModelIdentifier {
        .openAI(model)
    }

    static let claudeOpus = ModelIdentifier.openAI("anthropic/claude-3-opus")
    static let claudeSonnet = ModelIdentifier.openAI("anthropic/claude-3-sonnet")
    static let claudeHaiku = ModelIdentifier.openAI("anthropic/claude-3-haiku")
    static let geminiPro = ModelIdentifier.openAI("google/gemini-pro")
    static let geminiPro15 = ModelIdentifier.openAI("google/gemini-pro-1.5")
    static let llama31B70B = ModelIdentifier.openAI("meta-llama/llama-3.1-70b-instruct")
    static let llama31B8B = ModelIdentifier.openAI("meta-llama/llama-3.1-8b-instruct")

    static func ollama(_ model: String) -> ModelIdentifier {
        .openAI(model)
    }

    static let ollamaLlama32 = ModelIdentifier.openAI("llama3.2")
    static let ollamaLlama32B3B = ModelIdentifier.openAI("llama3.2:3b")
    static let ollamaLlama32B1B = ModelIdentifier.openAI("llama3.2:1b")
    static let ollamaMistral = ModelIdentifier.openAI("mistral")
    static let ollamaCodeLlama = ModelIdentifier.openAI("codellama")
    static let ollamaPhi3 = ModelIdentifier.openAI("phi3")
    static let ollamaGemma2 = ModelIdentifier.openAI("gemma2")
    static let ollamaQwen25 = ModelIdentifier.openAI("qwen2.5")
    static let ollamaDeepseekCoder = ModelIdentifier.openAI("deepseek-coder")
    static let ollamaNomicEmbed = ModelIdentifier.openAI("nomic-embed-text")

    static func azure(deployment: String) -> ModelIdentifier {
        .openAI(deployment)
    }

    // MARK: Anthropic Legacy Names

    static let claudeOpus46 = ModelIdentifier.anthropic("claude-opus-4-6")
    static let claudeSonnet46 = ModelIdentifier.anthropic("claude-sonnet-4-6")
    static let claudeOpus45 = ModelIdentifier.anthropic("claude-opus-4-5-20251101")
    static let claudeSonnet45 = ModelIdentifier.anthropic("claude-sonnet-4-5-20250929")
    static let claude35Sonnet = ModelIdentifier.anthropic("claude-3-5-sonnet-20241022")
    static let claude3Opus = ModelIdentifier.anthropic("claude-3-opus-20240229")
    static let claude3Sonnet = ModelIdentifier.anthropic("claude-3-sonnet-20240229")
    static let claude3Haiku = ModelIdentifier.anthropic("claude-3-haiku-20240307")
    static let claudeOpus4 = ModelIdentifier.anthropic("claude-opus-4-20250514")
    static let claudeOpus41 = ModelIdentifier.anthropic("claude-opus-4-1-20250805")
    static let claudeSonnet4 = ModelIdentifier.anthropic("claude-sonnet-4-20250514")
    static let claude37Sonnet = ModelIdentifier.anthropic("claude-3-7-sonnet-20250219")
    static let claudeHaiku45 = ModelIdentifier.anthropic("claude-haiku-4-5-20251001")
    static let claude35Haiku = ModelIdentifier.anthropic("claude-3-5-haiku-20241022")

    // MARK: Anthropic Latest Aliases

    static let claudeOpus4Latest = ModelIdentifier.anthropic("claude-opus-4-6")
    static let claudeSonnet4Latest = ModelIdentifier.anthropic("claude-sonnet-4-6")
    static let claudeSonnet37Latest = ModelIdentifier.anthropic("claude-3-7-sonnet-20250219")
    static let claudeSonnet35Latest = ModelIdentifier.anthropic("claude-3-5-sonnet-20241022")
    static let claudeHaiku35Latest = ModelIdentifier.anthropic("claude-3-5-haiku-20241022")

    // MARK: MiniMax Legacy Names

    static let minimaxM2 = ModelIdentifier.miniMax("MiniMax-M2")
    static let minimaxM2_1 = ModelIdentifier.miniMax("MiniMax-M2.1")
    static let minimaxM2_5 = ModelIdentifier.miniMax("MiniMax-M2.5")
    static let minimaxM2_5Highspeed = ModelIdentifier.miniMax("MiniMax-M2.5-highspeed")
    static let minimaxM2_7 = ModelIdentifier.miniMax("MiniMax-M2.7")
    static let minimaxM2_7Highspeed = ModelIdentifier.miniMax("MiniMax-M2.7-highspeed")
    static let minimaxM2_1Lightning = ModelIdentifier.miniMax("MiniMax-M2.1-lightning")

    // MARK: Kimi Latest Aliases

    static let kimiLatest = ModelIdentifier.kimi("kimi-latest")
    static let kimiThinkingPreview = ModelIdentifier.kimi("kimi-thinking-preview")
    static let kimiK2Preview = ModelIdentifier.kimi("kimi-k2-0711-preview")
    static let kimiK2_0905Preview = ModelIdentifier.kimi("kimi-k2-0905-preview")
    static let kimiK2TurboPreview = ModelIdentifier.kimi("kimi-k2-turbo-preview")
    static let kimiK2ThinkingTurbo = ModelIdentifier.kimi("kimi-k2-thinking-turbo")
}
