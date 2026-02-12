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

    /// A model to be run locally via MLX on Apple Silicon.
    ///
    /// - Parameter id: The HuggingFace repository ID (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit")
    case mlx(String)

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

    // MARK: - ModelIdentifying

    /// The raw string identifier for this model.
    ///
    /// - For MLX and HuggingFace models: Returns the repository ID string.
    /// - For Foundation Models: Returns "apple-foundation-models".
    public var rawValue: String {
        switch self {
        case .mlx(let id):
            return id
        case .llama(let path):
            return path
        case .coreml(let path):
            return path
        case .huggingFace(let id):
            return id
        case .foundationModels:
            return "apple-foundation-models"
        }
    }

    /// Human-readable display name for the model.
    ///
    /// Extracts the last path component from repository IDs for brevity.
    /// - For MLX and HuggingFace models: Returns the model name (last path component).
    /// - For Foundation Models: Returns "Apple Intelligence".
    public var displayName: String {
        switch self {
        case .mlx(let id):
            return id.components(separatedBy: "/").last ?? id
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
        }
    }

    /// The provider this model belongs to.
    ///
    /// - Returns: The appropriate `ProviderType` case for this model.
    public var provider: ProviderType {
        switch self {
        case .mlx:
            return .mlx
        case .llama:
            return .llama
        case .coreml:
            return .coreml
        case .huggingFace:
            return .huggingFace
        case .foundationModels:
            return .foundationModels
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
        case mlx
        case llama
        case coreml
        case huggingFace
        case foundationModels
    }

    /// Decodes a ModelIdentifier from a JSON decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the data is malformed.
    ///
    /// ## Expected JSON Structure
    /// - MLX: `{"type": "mlx", "id": "model-id"}`
    /// - llama.cpp: `{"type": "llama", "id": "/path/to/model.gguf"}`
    /// - Core ML: `{"type": "coreml", "id": "/path/to/model.mlmodelc"}`
    /// - HuggingFace: `{"type": "huggingFace", "id": "model-id"}`
    /// - Foundation Models: `{"type": "foundationModels"}` (no id field required)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ModelType.self, forKey: .type)

        switch type {
        case .mlx:
            let id = try container.decode(String.self, forKey: .id)
            self = .mlx(id)

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
        }
    }

    /// Encodes this ModelIdentifier to a JSON encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `EncodingError` if encoding fails.
    ///
    /// ## Generated JSON Structure
    /// - MLX: `{"type": "mlx", "id": "model-id"}`
    /// - llama.cpp: `{"type": "llama", "id": "/path/to/model.gguf"}`
    /// - Core ML: `{"type": "coreml", "id": "/path/to/model.mlmodelc"}`
    /// - HuggingFace: `{"type": "huggingFace", "id": "model-id"}`
    /// - Foundation Models: `{"type": "foundationModels"}` (no id field)
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .mlx(let id):
            try container.encode(ModelType.mlx, forKey: .type)
            try container.encode(id, forKey: .id)

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
}
