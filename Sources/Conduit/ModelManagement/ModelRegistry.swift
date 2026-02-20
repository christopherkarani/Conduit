// ModelRegistry.swift
// Conduit

import Foundation

// MARK: - ModelCapability

/// Capabilities that a model can provide.
///
/// Models may support one or more capabilities, such as text generation,
/// embeddings, or transcription. Capabilities help filter and discover
/// models suitable for specific tasks.
///
/// ## Usage
/// ```swift
/// // Find all models with embedding capability
/// let embeddingModels = ModelRegistry.models(with: .embeddings)
///
/// // Check if a model supports code generation
/// if model.capabilities.contains(.codeGeneration) {
///     // Use for code tasks
/// }
/// ```
public enum ModelCapability: String, Sendable, Codable, CaseIterable {
    /// Text generation capability (chat, completion).
    case textGeneration

    /// Generate embeddings for semantic search and RAG.
    case embeddings

    /// Audio transcription (speech-to-text).
    case transcription

    /// Specialized code generation and understanding.
    case codeGeneration

    /// Advanced reasoning and chain-of-thought.
    case reasoning

    /// Multimodal understanding (text + images).
    case multimodal

    /// Human-readable display name for this capability.
    ///
    /// Suitable for UI display and user-facing messages.
    ///
    /// ## Examples
    /// - `textGeneration` → "Text Generation"
    /// - `codeGeneration` → "Code Generation"
    /// - `embeddings` → "Embeddings"
    public var displayName: String {
        switch self {
        case .textGeneration:
            return "Text Generation"
        case .embeddings:
            return "Embeddings"
        case .transcription:
            return "Transcription"
        case .codeGeneration:
            return "Code Generation"
        case .reasoning:
            return "Reasoning"
        case .multimodal:
            return "Multimodal"
        }
    }
}

// MARK: - ModelInfo

/// Comprehensive information about an available model.
///
/// Describes a model's characteristics, capabilities, and metadata.
/// This enhanced version includes size categorization, capability flags,
/// and recommendation status.
///
/// ## Usage
/// ```swift
/// let model = ModelRegistry.info(for: .llama3_2_1b)!
/// print("\(model.name): \(model.size.displayName), \(model.contextWindow) tokens")
///
/// if model.isRecommended {
///     print("Recommended for general use")
/// }
///
/// if let params = model.parameters {
///     print("Model size: \(params)")
/// }
/// ```
public struct ModelInfo: Sendable, Identifiable, Hashable {
    /// The model's unique identifier.
    ///
    /// This is the ModelIdentifier that can be used with providers
    /// for inference operations.
    public let identifier: ModelIdentifier

    /// Unique identifier conforming to `Identifiable`.
    ///
    /// Returns the raw string value from the identifier.
    public var id: String { identifier.rawValue }

    /// Human-readable name for the model.
    ///
    /// Example: "Llama 3.2 1B"
    public let name: String

    /// Detailed description of the model's characteristics and use cases.
    ///
    /// Example: "Fast and efficient model ideal for quick responses"
    public let description: String

    /// Size category based on memory requirements.
    ///
    /// Indicates approximate RAM usage during inference.
    public let size: ModelSize

    /// Actual disk space required to store the model files.
    ///
    /// This is the download size for local models. Cloud models
    /// may have `nil` disk size as they don't require local storage.
    public let diskSize: ByteCount?

    /// Maximum context window size in tokens.
    ///
    /// Represents the maximum number of tokens the model can process
    /// in a single request (prompt + completion).
    ///
    /// Example: 8192 for Llama 3.2, 128000 for Llama 3.1
    public let contextWindow: Int

    /// Set of capabilities this model supports.
    ///
    /// Models may support one or more capabilities such as text generation,
    /// embeddings, or transcription.
    public let capabilities: Set<ModelCapability>

    /// Whether this model is recommended for general use.
    ///
    /// Recommended models have been tested and verified for quality,
    /// performance, and reliability.
    public let isRecommended: Bool

    /// Model parameter count as a string.
    ///
    /// Examples: "1B", "7B", "70B" for billion-parameter models.
    /// May be `nil` for models where parameter count is not relevant
    /// or not publicly disclosed.
    public let parameters: String?

    /// Quantization level applied to the model.
    ///
    /// Examples: "4-bit", "8-bit", "fp16", "fp32".
    /// Local models often use 4-bit quantization for efficiency.
    /// May be `nil` for cloud models or full-precision models.
    public let quantization: String?

    /// Creates a new ModelInfo instance.
    ///
    /// - Parameters:
    ///   - identifier: The model's unique identifier
    ///   - name: Human-readable name
    ///   - description: Detailed description
    ///   - size: Size category based on memory requirements
    ///   - diskSize: Actual disk space required (optional)
    ///   - contextWindow: Maximum context window in tokens
    ///   - capabilities: Set of supported capabilities
    ///   - isRecommended: Whether this model is recommended
    ///   - parameters: Parameter count string (optional)
    ///   - quantization: Quantization level (optional)
    public init(
        identifier: ModelIdentifier,
        name: String,
        description: String,
        size: ModelSize,
        diskSize: ByteCount? = nil,
        contextWindow: Int,
        capabilities: Set<ModelCapability>,
        isRecommended: Bool = false,
        parameters: String? = nil,
        quantization: String? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.description = description
        self.size = size
        self.diskSize = diskSize
        self.contextWindow = contextWindow
        self.capabilities = capabilities
        self.isRecommended = isRecommended
        self.parameters = parameters
        self.quantization = quantization
    }

    // MARK: - Hashable

    /// Hashes the model using only its identifier.
    ///
    /// Two ModelInfo instances with the same identifier are considered
    /// equal regardless of other properties, consistent with Identifiable.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    // MARK: - Equatable

    /// Compares models by their identifier only.
    ///
    /// Two ModelInfo instances are equal if they have the same identifier,
    /// regardless of other properties.
    public static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

// MARK: - ModelRegistry

/// Central registry of all known models across all providers.
///
/// ModelRegistry provides a static catalog of pre-configured models
/// with comprehensive metadata. Use this to discover models, filter
/// by capabilities, or look up model information.
///
/// ## Usage
/// ```swift
/// // Get all available models
/// let allModels = ModelRegistry.allModels
///
/// // Find a specific model
/// if let model = ModelRegistry.info(for: .llama3_2_1b) {
///     print("\(model.name): \(model.description)")
/// }
///
/// // Filter by provider
/// let mlxModels = ModelRegistry.models(for: .mlx)
///
/// // Filter by capability
/// let embeddingModels = ModelRegistry.models(with: .embeddings)
///
/// // Get recommended models only
/// let recommended = ModelRegistry.recommendedModels()
/// ```
public enum ModelRegistry {

    // MARK: - All Models

    /// Complete catalog of all known models across all providers.
    ///
    /// This array contains 19 pre-configured models:
    /// - 7 MLX text generation models
    /// - 3 MLX embedding models
    /// - 5 HuggingFace cloud models
    /// - 1 Apple Foundation Model
    /// - 3 Kimi cloud models
    ///
    /// Models are organized by provider and capability for easy discovery.
    public static let allModels: [ModelInfo] = [

        // MARK: MLX Text Generation Models (7)

        ModelInfo(
            identifier: .llama3_2_1b,
            name: "Llama 3.2 1B",
            description: "Fast and efficient model ideal for quick responses and low memory usage",
            size: .small,
            diskSize: .megabytes(800),
            contextWindow: 8192,
            capabilities: [.textGeneration],
            isRecommended: true,
            parameters: "1B",
            quantization: "4-bit"
        ),

        ModelInfo(
            identifier: .llama3_2_3b,
            name: "Llama 3.2 3B",
            description: "Balanced model offering good quality and reasonable speed",
            size: .small,
            diskSize: .gigabytes(2),
            contextWindow: 8192,
            capabilities: [.textGeneration],
            isRecommended: true,
            parameters: "3B",
            quantization: "4-bit"
        ),

        ModelInfo(
            identifier: .phi3Mini,
            name: "Phi-3 Mini",
            description: "Microsoft's efficient model with strong code generation capabilities",
            size: .small,
            diskSize: .megabytes(2500),
            contextWindow: 4096,
            capabilities: [.textGeneration, .codeGeneration, .reasoning],
            isRecommended: false,
            parameters: "3.8B",
            quantization: "4-bit"
        ),

        ModelInfo(
            identifier: .phi4,
            name: "Phi-4",
            description: "Latest Phi model with enhanced reasoning and instruction following",
            size: .medium,
            diskSize: .gigabytes(8),
            contextWindow: 16384,
            capabilities: [.textGeneration, .codeGeneration, .reasoning],
            isRecommended: true,
            parameters: "14B",
            quantization: "4-bit"
        ),

        ModelInfo(
            identifier: .qwen2_5_3b,
            name: "Qwen 2.5 3B",
            description: "Multilingual model with strong instruction following and large context window",
            size: .small,
            diskSize: .gigabytes(2),
            contextWindow: 32768,
            capabilities: [.textGeneration],
            isRecommended: false,
            parameters: "3B",
            quantization: "4-bit"
        ),

        ModelInfo(
            identifier: .mistral7B,
            name: "Mistral 7B",
            description: "High-quality model with excellent reasoning and large context window",
            size: .medium,
            diskSize: .gigabytes(4),
            contextWindow: 32768,
            capabilities: [.textGeneration],
            isRecommended: false,
            parameters: "7B",
            quantization: "4-bit"
        ),

        ModelInfo(
            identifier: .gemma2_2b,
            name: "Gemma 2 2B",
            description: "Google's efficient model with strong instruction following capabilities",
            size: .small,
            diskSize: .megabytes(1500),
            contextWindow: 8192,
            capabilities: [.textGeneration],
            isRecommended: false,
            parameters: "2B",
            quantization: "4-bit"
        ),

        // MARK: MLX Embedding Models (3)

        ModelInfo(
            identifier: .bgeSmall,
            name: "BGE Small",
            description: "Fast embedding model ideal for quick similarity search with low memory usage",
            size: .small,
            diskSize: .megabytes(100),
            contextWindow: 512,
            capabilities: [.embeddings],
            isRecommended: true,
            parameters: "33M",
            quantization: nil
        ),

        ModelInfo(
            identifier: .bgeLarge,
            name: "BGE Large",
            description: "High-quality embedding model for semantic search and RAG applications",
            size: .small,
            diskSize: .megabytes(400),
            contextWindow: 512,
            capabilities: [.embeddings],
            isRecommended: false,
            parameters: "335M",
            quantization: nil
        ),

        ModelInfo(
            identifier: .nomicEmbed,
            name: "Nomic Embed",
            description: "Balanced embedding model with large context window, ideal for document embeddings",
            size: .small,
            diskSize: .megabytes(250),
            contextWindow: 8192,
            capabilities: [.embeddings],
            isRecommended: false,
            parameters: "137M",
            quantization: nil
        ),

        // MARK: HuggingFace Cloud Models (5)

        ModelInfo(
            identifier: .llama3_1_70B,
            name: "Llama 3.1 70B",
            description: "Powerful cloud model with exceptional reasoning and massive context window",
            size: .xlarge,
            diskSize: nil,
            contextWindow: 128000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning],
            isRecommended: true,
            parameters: "70B",
            quantization: nil
        ),

        ModelInfo(
            identifier: .llama3_1_8B,
            name: "Llama 3.1 8B",
            description: "Balanced cloud model offering good quality with massive context window",
            size: .medium,
            diskSize: nil,
            contextWindow: 128000,
            capabilities: [.textGeneration],
            isRecommended: false,
            parameters: "8B",
            quantization: nil
        ),

        ModelInfo(
            identifier: .mixtral8x7B,
            name: "Mixtral 8x7B",
            description: "Mixture-of-Experts model offering efficient high-quality inference",
            size: .large,
            diskSize: nil,
            contextWindow: 32768,
            capabilities: [.textGeneration],
            isRecommended: false,
            parameters: "8x7B",
            quantization: nil
        ),

        ModelInfo(
            identifier: .deepseekR1,
            name: "DeepSeek R1",
            description: "Advanced reasoning model with explicit chain-of-thought capabilities",
            size: .xlarge,
            diskSize: nil,
            contextWindow: 64000,
            capabilities: [.textGeneration, .reasoning],
            isRecommended: false,
            parameters: "671B",
            quantization: nil
        ),

        ModelInfo(
            identifier: .whisperLargeV3,
            name: "Whisper Large V3",
            description: "State-of-the-art speech recognition model supporting 99 languages",
            size: .large,
            diskSize: nil,
            contextWindow: 0, // N/A for transcription models
            capabilities: [.transcription],
            isRecommended: true,
            parameters: "1.55B",
            quantization: nil
        ),

        // MARK: Apple Foundation Models (1)

        ModelInfo(
            identifier: .apple,
            name: "Apple Intelligence",
            description: "Apple's on-device foundation model with system integration (iOS 26+)",
            size: .medium,
            diskSize: nil,
            contextWindow: 4096,
            capabilities: [.textGeneration],
            isRecommended: true,
            parameters: nil,
            quantization: nil
        ),

        // MARK: Kimi Cloud Models (3)

        ModelInfo(
            identifier: .kimiK2_5,
            name: "Kimi K2.5",
            description: "Moonshot's flagship model with advanced reasoning and 256K context window",
            size: .large,
            diskSize: nil,
            contextWindow: 256000,
            capabilities: [.textGeneration, .codeGeneration, .reasoning],
            isRecommended: true,
            parameters: nil,
            quantization: nil
        ),

        ModelInfo(
            identifier: .kimiK2,
            name: "Kimi K2",
            description: "General-purpose model with strong performance across diverse tasks",
            size: .large,
            diskSize: nil,
            contextWindow: 256000,
            capabilities: [.textGeneration, .codeGeneration],
            isRecommended: false,
            parameters: nil,
            quantization: nil
        ),

        ModelInfo(
            identifier: .kimiK1_5,
            name: "Kimi K1.5",
            description: "Long context specialist optimized for document analysis and summarization",
            size: .large,
            diskSize: nil,
            contextWindow: 256000,
            capabilities: [.textGeneration, .reasoning],
            isRecommended: false,
            parameters: nil,
            quantization: nil
        )
    ]

    // MARK: - Lookup Methods

    /// Look up model information by identifier.
    ///
    /// Returns the ModelInfo for a given identifier, or `nil` if
    /// the model is not in the registry.
    ///
    /// ## Usage
    /// ```swift
    /// if let model = ModelRegistry.info(for: .llama3_2_1b) {
    ///     print("Found: \(model.name)")
    ///     print("Size: \(model.size.displayName)")
    ///     print("Context: \(model.contextWindow) tokens")
    /// }
    /// ```
    ///
    /// - Parameter identifier: The model identifier to look up
    /// - Returns: ModelInfo if found, `nil` otherwise
    public static func info(for identifier: ModelIdentifier) -> ModelInfo? {
        allModels.first { $0.identifier == identifier }
    }

    // MARK: - Filter Methods

    /// Get all models for a specific provider.
    ///
    /// Filters the model catalog by provider type (MLX, HuggingFace, or
    /// Apple Foundation Models).
    ///
    /// ## Usage
    /// ```swift
    /// // Get all local MLX models
    /// let mlxModels = ModelRegistry.models(for: .mlx)
    ///
    /// // Get all cloud models
    /// let cloudModels = ModelRegistry.models(for: .huggingFace)
    /// ```
    ///
    /// - Parameter provider: The provider type to filter by
    /// - Returns: Array of models belonging to the specified provider
    public static func models(for provider: ProviderType) -> [ModelInfo] {
        allModels.filter { $0.identifier.provider == provider }
    }

    /// Get all models supporting a specific capability.
    ///
    /// Filters models by their supported capabilities. Models may support
    /// multiple capabilities.
    ///
    /// ## Usage
    /// ```swift
    /// // Find all embedding models
    /// let embeddingModels = ModelRegistry.models(with: .embeddings)
    ///
    /// // Find all models with reasoning capability
    /// let reasoningModels = ModelRegistry.models(with: .reasoning)
    /// ```
    ///
    /// - Parameter capability: The capability to filter by
    /// - Returns: Array of models supporting the specified capability
    public static func models(with capability: ModelCapability) -> [ModelInfo] {
        allModels.filter { $0.capabilities.contains(capability) }
    }

    /// Get all recommended models.
    ///
    /// Recommended models have been tested and verified for quality,
    /// performance, and reliability. These are good starting points
    /// for most applications.
    ///
    /// ## Usage
    /// ```swift
    /// let recommended = ModelRegistry.recommendedModels()
    /// for model in recommended {
    ///     print("\(model.name): \(model.description)")
    /// }
    /// ```
    ///
    /// - Returns: Array of recommended models
    public static func recommendedModels() -> [ModelInfo] {
        allModels.filter { $0.isRecommended }
    }

    /// Get all models that run locally without network access.
    ///
    /// Local models include MLX models and Apple Foundation Models.
    /// These models can operate offline and provide privacy benefits.
    ///
    /// ## Usage
    /// ```swift
    /// let localModels = ModelRegistry.localModels()
    /// print("Found \(localModels.count) local models")
    /// ```
    ///
    /// - Returns: Array of models that run locally
    public static func localModels() -> [ModelInfo] {
        allModels.filter { !$0.identifier.requiresNetwork }
    }

    /// Get all cloud-based models requiring network access.
    ///
    /// Cloud models include all HuggingFace inference API models.
    /// These models require an internet connection and API key.
    ///
    /// ## Usage
    /// ```swift
    /// let cloudModels = ModelRegistry.cloudModels()
    /// print("Found \(cloudModels.count) cloud models")
    /// ```
    ///
    /// - Returns: Array of cloud models
    public static func cloudModels() -> [ModelInfo] {
        allModels.filter { $0.identifier.requiresNetwork }
    }
}
