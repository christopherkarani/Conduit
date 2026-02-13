// ForwardDeclarations.swift
// Conduit
//
// This file contains minimal type stubs that protocols depend on,
// allowing Phase 2 protocols to compile before Phases 3-9 implement full types.
//
// Each stub is marked with a comment indicating which phase will implement it fully.

import Foundation

// MARK: - ModelIdentifying Protocol (Complete Implementation)

/// A type that uniquely identifies a model.
///
/// Model identifiers are used throughout Conduit to specify which
/// model should be used for inference. Each provider has its own
/// identifier type that conforms to this protocol.
///
/// ## Conformance Requirements
/// - Must be `Hashable` for use in collections and caching
/// - Must be `Sendable` for Swift 6.2 concurrency
/// - Must provide a raw string value and display name
///
/// ## Example
/// ```swift
/// public struct MyModelID: ModelIdentifying {
///     public let rawValue: String
///     public var displayName: String { rawValue }
///     public var provider: ProviderType { .mlx }
/// }
/// ```
public protocol ModelIdentifying: Hashable, Sendable, CustomStringConvertible {
    /// The raw string identifier (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit")
    var rawValue: String { get }

    /// Human-readable display name for the model.
    var displayName: String { get }

    /// The provider this model belongs to.
    var provider: ProviderType { get }
}

// MARK: - ProviderType Enum (Complete Implementation)

/// The type of inference provider.
///
/// Conduit supports three inference providers, each with different
/// characteristics and use cases.
public enum ProviderType: String, Sendable, Codable, CaseIterable {
    /// MLX local inference on Apple Silicon.
    ///
    /// Runs entirely on-device using Apple's MLX framework.
    /// Best for: Privacy-sensitive applications, offline use, Apple Silicon Macs.
    case mlx

    /// Core ML local inference.
    ///
    /// Runs compiled `.mlmodelc` language models on-device via swift-transformers.
    /// Best for: Fully local Core ML model deployments.
    case coreml

    /// llama.cpp local inference.
    ///
    /// Runs GGUF models locally via llama.cpp through LlamaSwift.
    /// Best for: Cross-model local GGUF inference, offline portability.
    case llama

    /// HuggingFace Inference API (cloud).
    ///
    /// Connects to HuggingFace's hosted inference endpoints.
    /// Best for: Access to large models, when local hardware is insufficient.
    case huggingFace

    /// Apple Foundation Models (iOS 26+).
    ///
    /// Uses Apple's built-in on-device language model.
    /// Best for: System integration, Apple Intelligence features.
    case foundationModels

    /// OpenAI API (cloud).
    ///
    /// Connects to OpenAI's hosted inference endpoints.
    /// Best for: Access to GPT-4, DALL-E, Whisper models.
    case openAI

    /// OpenRouter API aggregator (cloud).
    ///
    /// Routes requests to multiple providers via unified API.
    /// Best for: Access to 400+ models, provider fallbacks.
    case openRouter

    /// Ollama local inference server.
    ///
    /// Runs models locally via HTTP server.
    /// Best for: Cross-platform local inference, model sharing.
    case ollama

    /// Anthropic API (cloud).
    ///
    /// Connects to Anthropic's hosted Claude models.
    /// Best for: Access to Claude 3/4 models, advanced reasoning.
    case anthropic

    /// Moonshot Kimi API (cloud).
    ///
    /// Connects to Moonshot's Kimi models with 256K context.
    /// Best for: Long context tasks, reasoning, coding.
    case kimi

    /// Azure OpenAI Service (cloud).
    ///
    /// Microsoft's enterprise OpenAI deployment.
    /// Best for: Enterprise compliance, Azure integration.
    case azure

    /// Human-readable name for display purposes.
    public var displayName: String {
        switch self {
        case .mlx:
            return "MLX (Local)"
        case .coreml:
            return "Core ML (Local)"
        case .llama:
            return "llama.cpp (Local)"
        case .huggingFace:
            return "HuggingFace (Cloud)"
        case .foundationModels:
            return "Apple Foundation Models"
        case .openAI:
            return "OpenAI"
        case .openRouter:
            return "OpenRouter"
        case .ollama:
            return "Ollama (Local)"
        case .anthropic:
            return "Anthropic"
        case .kimi:
            return "Kimi"
        case .azure:
            return "Azure OpenAI"
        }
    }

    /// Whether this provider requires network connectivity.
    ///
    /// Cloud providers require network access, while local providers
    /// can operate offline.
    public var requiresNetwork: Bool {
        switch self {
        case .mlx, .coreml, .llama, .foundationModels, .ollama:
            return false
        case .huggingFace, .openAI, .openRouter, .anthropic, .kimi, .azure:
            return true
        }
    }
}

// MARK: - Message (Phase 4: Message Types - COMPLETE)
// Full implementation in Message.swift

// MARK: - GenerateConfig (Phase 5: Generation Configuration - COMPLETE)
// Full implementation in GenerateConfig.swift

// MARK: - TranscriptionConfig, TranscriptionResult, TranscriptionSegment, TranscriptionWord (Phase 5 - COMPLETE)
// Full implementation in TranscriptionResult.swift

// MARK: - GenerationResult (Phase 6 - COMPLETE)
// Full implementation in GenerationResult.swift

// MARK: - GenerationChunk (Phase 6 - COMPLETE)
// Full implementation in GenerationChunk.swift

// MARK: - EmbeddingResult (Phase 6 - COMPLETE)
// Full implementation in EmbeddingResult.swift

// MARK: - ProviderAvailability Stub (Phase 7: Provider Availability)

/// Detailed availability information for a provider.
///
/// Contains information about whether a provider is available
/// and the reason if it is not.
///
/// - Note: This is a minimal stub. Full implementation in Phase 7.
public struct ProviderAvailability: Sendable {
    /// Whether the provider is available for inference.
    public let isAvailable: Bool

    /// Reason if unavailable.
    public let unavailableReason: UnavailabilityReason?

    /// Device capabilities (CPU, GPU, memory, etc.).
    public let capabilities: DeviceCapabilities?

    /// Recommended model size based on device capabilities.
    public let recommendedModelSize: ModelSize?

    /// Creates a provider availability status.
    public init(
        isAvailable: Bool,
        unavailableReason: UnavailabilityReason? = nil,
        capabilities: DeviceCapabilities? = nil,
        recommendedModelSize: ModelSize? = nil
    ) {
        self.isAvailable = isAvailable
        self.unavailableReason = unavailableReason
        self.capabilities = capabilities
        self.recommendedModelSize = recommendedModelSize
    }

    /// Indicates the provider is available.
    public static let available = ProviderAvailability(
        isAvailable: true,
        capabilities: DeviceCapabilities.current(),
        recommendedModelSize: DeviceCapabilities.current().recommendedModelSize()
    )

    /// Creates an unavailable status with the given reason.
    public static func unavailable(_ reason: UnavailabilityReason) -> ProviderAvailability {
        ProviderAvailability(
            isAvailable: false,
            unavailableReason: reason,
            capabilities: DeviceCapabilities.current()
        )
    }
}

// MARK: - UnavailabilityReason Stub (Phase 7: Provider Availability)

/// Reason why a provider is unavailable.
///
/// Provides detailed information about why inference cannot
/// be performed with a particular provider.
///
/// - Note: This is a minimal stub. Full implementation in Phase 7.
public enum UnavailabilityReason: Sendable, Equatable, CustomStringConvertible {
    /// Device doesn't meet requirements.
    case deviceNotSupported

    /// Required OS version not met.
    case osVersionNotMet(required: String)

    /// Apple Intelligence not enabled on device.
    case appleIntelligenceDisabled

    /// Model is still downloading.
    case modelDownloading(progress: Double)

    /// Model is not downloaded.
    case modelNotDownloaded

    /// No network connectivity (for cloud providers).
    case noNetwork

    /// API key is missing or invalid.
    case apiKeyMissing

    /// Insufficient memory available for inference.
    case insufficientMemory(required: ByteCount, available: ByteCount)

    /// Unknown or custom reason.
    case unknown(String)

    public var description: String {
        switch self {
        case .deviceNotSupported:
            return "Device not supported"
        case .osVersionNotMet(let required):
            return "Requires \(required) or later"
        case .appleIntelligenceDisabled:
            return "Apple Intelligence is not enabled"
        case .modelDownloading(let progress):
            return "Model downloading (\(Int(progress * 100))%)"
        case .modelNotDownloaded:
            return "Model not downloaded"
        case .noNetwork:
            return "No network connection"
        case .apiKeyMissing:
            return "API key not configured"
        case .insufficientMemory(let required, let available):
            return "Insufficient memory: need \(required.formatted), have \(available.formatted)"
        case .unknown(let reason):
            return reason
        }
    }
}

// MARK: - ByteCount Stub (Phase 8: Token Counting / Phase 9: Model Management)

/// Represents a byte count with formatting utilities.
///
/// Used for representing file sizes, memory limits, and
/// cache sizes throughout the framework.
///
/// - Note: This is a minimal stub. Full implementation in Phase 9.
public struct ByteCount: Sendable, Hashable, Comparable, Codable {
    /// The raw byte count.
    public let bytes: Int64

    /// Creates a byte count.
    public init(_ bytes: Int64) {
        self.bytes = bytes
    }

    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.bytes < rhs.bytes
    }

    /// Formatted string representation (e.g., "4.2 GB").
    public var formatted: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Creates a byte count from megabytes.
    public static func megabytes(_ mb: Int) -> ByteCount {
        ByteCount(Int64(mb) * 1_000_000)
    }

    /// Creates a byte count from gigabytes.
    public static func gigabytes(_ gb: Int) -> ByteCount {
        ByteCount(Int64(gb) * 1_000_000_000)
    }
}

// MARK: - TokenCount (Phase 8: Token Counting - COMPLETE)
// Full implementation in TokenCount.swift

// MARK: - CachedModelInfo Stub (Phase 9: Model Management)

/// Information about a cached model on the local device.
///
/// Describes a model that has been downloaded and is available
/// for local inference. This type provides metadata about the cached
/// model including its location, size, and access history.
///
/// ## Usage
/// ```swift
/// let modelManager = try await MLXModelManager()
/// let cachedModels = try await modelManager.listCachedModels()
///
/// for model in cachedModels {
///     print("Model: \(model.identifier.displayName)")
///     print("Size: \(model.size.formatted)")
///     print("Downloaded: \(model.downloadedAt)")
/// }
/// ```
///
/// - Note: This is a minimal stub. Full implementation in Phase 9.
public struct CachedModelInfo: Sendable, Identifiable, Codable {
    /// The model identifier.
    ///
    /// This uniquely identifies which model is cached and includes
    /// provider-specific information.
    public let identifier: ModelIdentifier

    /// Local path to the model files.
    ///
    /// This directory contains all model artifacts including weights,
    /// configuration files, and tokenizer data.
    public let path: URL

    /// Size of the model on disk.
    ///
    /// Total size of all model files in the cache directory.
    public let size: ByteCount

    /// When the model was downloaded.
    ///
    /// Timestamp of the initial download completion.
    public let downloadedAt: Date

    /// When the model was last accessed.
    ///
    /// Updated whenever the model is loaded for inference.
    /// Used for cache eviction policies.
    public let lastAccessedAt: Date

    /// The model revision/version identifier.
    ///
    /// For HuggingFace models, this corresponds to the git commit SHA.
    /// For MLX models, this may be a version tag or commit reference.
    /// Can be `nil` for models without version tracking.
    public let revision: String?

    /// Unique identifier for Identifiable conformance.
    ///
    /// Derived from the model identifier's raw value.
    public var id: String { identifier.rawValue }

    /// Creates cached model information.
    ///
    /// - Parameters:
    ///   - identifier: The model identifier.
    ///   - path: Local path to the model files.
    ///   - size: Size of the model on disk.
    ///   - downloadedAt: When the model was downloaded.
    ///   - lastAccessedAt: When the model was last accessed.
    ///   - revision: Optional revision/version identifier.
    public init(
        identifier: ModelIdentifier,
        path: URL,
        size: ByteCount,
        downloadedAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        revision: String? = nil
    ) {
        self.identifier = identifier
        self.path = path
        self.size = size
        self.downloadedAt = downloadedAt
        self.lastAccessedAt = lastAccessedAt
        self.revision = revision
    }

    // MARK: - Codable
    //
    // ModelIdentifier is already Codable, so we can directly encode/decode it.
    // Swift will synthesize the Codable implementation automatically since
    // all stored properties are Codable (ModelIdentifier, URL, ByteCount, Date, String?).
}

// MARK: - DownloadProgress, DownloadState, DownloadTask (Phase 9 - COMPLETE)
// Full implementation in ModelManagement/DownloadProgress.swift
