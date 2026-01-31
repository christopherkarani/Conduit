//
//  VLMDetector.swift
//  Conduit
//
//  Vision Language Model detection service using layered detection strategy.
//  Based on Osaurus ModelManager.swift (lines 1090-1201) and HuggingFaceService.swift (lines 227-248).
//

import Foundation

// MARK: - VLMDetector

/// Detects Vision Language Model (VLM) capabilities using a layered strategy.
///
/// Uses a multi-stage detection approach for maximum accuracy:
/// 1. **Metadata Detection**: Checks HuggingFace tags and pipeline_tag
/// 2. **Config Inspection**: Analyzes config.json for VLM-specific fields
/// 3. **Name Heuristics**: Falls back to model name pattern matching
///
/// ## Usage
/// ```swift
/// let detector = VLMDetector.shared
///
/// // Detect capabilities for a model
/// let capabilities = await detector.detectCapabilities(.mlx("mlx-community/llava-1.5-7b-4bit"))
/// if capabilities.supportsVision {
///     print("VLM detected: \(capabilities.architectureType?.rawValue ?? "unknown")")
/// }
///
/// // Quick VLM check
/// let isVLM = await detector.isVLM(.mlx("mlx-community/pixtral-12b-4bit"))
/// ```
///
/// ## Detection Strategy
///
/// ### Layer 1: Metadata (Highest Confidence)
/// - HuggingFace `pipeline_tag`: "image-to-text", "visual-question-answering", etc.
/// - HuggingFace `tags`: "vision", "multimodal", "vlm", specific architectures
///
/// ### Layer 2: Config.json (High Confidence)
/// - Inspects downloaded model's config.json for VLM-specific fields:
///   - `vision_config`, `image_processor`, `vision_encoder`, etc.
/// - Checks `model_type` against known VLM architectures
///
/// ### Layer 3: Name Heuristics (Medium Confidence)
/// - Pattern matching on model repository ID:
///   - "llava", "pixtral", "vision", "vlm", "paligemma", etc.
///
/// ## Performance
/// - Metadata detection: ~100-300ms (network call)
/// - Config inspection: ~10ms (local file read)
/// - Name heuristics: <1ms (string matching)
///
/// ## Thread Safety
/// `VLMDetector` is an actor ensuring thread-safe access across all methods.
public actor VLMDetector {

    // MARK: - Singleton

    /// Shared singleton instance.
    public static let shared = VLMDetector()

    // MARK: - VLM Config Fields

    /// Config.json fields that indicate a Vision Language Model.
    ///
    /// These fields are typically present in VLM config files but absent in text-only models.
    /// Based on analysis of LLaVA, Qwen2-VL, Pixtral, and other VLM architectures.
    private static let vlmConfigFields: Set<String> = [
        "vision_config",
        "image_processor",
        "vision_encoder",
        "vision_tower",
        "image_encoder",
        "patch_size",
        "num_image_tokens",
        "image_size",
        "vision_feature_layer"
    ]

    // MARK: - VLM Architectures

    /// Known VLM architecture types from model_type field in config.json.
    ///
    /// These strings appear in the `model_type` field of VLM configurations.
    /// Normalized to lowercase with underscores for comparison.
    private static let vlmArchitectures: Set<String> = [
        "llava", "llava_next", "llava-next",
        "qwen2_vl", "qwen2-vl",
        "pixtral",
        "paligemma",
        "idefics", "idefics2", "idefics3",
        "internvl", "internvl2",
        "cogvlm", "cogvlm2",
        "minicpm_v", "minicpm-v",
        "phi3_v", "phi3-v", "phi-3-vision",
        "mllama",
        "florence", "florence2",
        "blip", "blip2"
    ]

    // MARK: - VLM Pipeline Tags

    /// HuggingFace pipeline tags that indicate VLM capabilities.
    ///
    /// These appear in the `pipeline_tag` field of HuggingFace model metadata.
    private let vlmPipelineTags = [
        "image-to-text",
        "visual-question-answering",
        "image-text-to-text",
        "document-question-answering"
    ]

    // MARK: - VLM Tag Indicators

    /// HuggingFace tags that suggest VLM capabilities.
    ///
    /// These are common tags applied to vision-enabled models on HuggingFace.
    private let vlmTagIndicators = [
        "vision", "multimodal", "vlm", "image-text",
        "llava", "vqa", "image-to-text"
    ]

    // MARK: - VLM Name Patterns

    /// Model name patterns that suggest VLM capabilities.
    ///
    /// Used as a fallback when metadata is unavailable.
    private let vlmNamePatterns = [
        "llava", "vision", "vlm", "vl-", "-vl",
        "pixtral", "paligemma", "idefics", "cogvlm",
        "minicpm-v", "phi-3-vision", "mllama", "florence"
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Detects the capabilities of a model using layered detection.
    ///
    /// Uses a multi-stage approach:
    /// 1. Extracts repository ID from ModelIdentifier
    /// 2. Tries metadata detection (HuggingFace API)
    /// 3. Falls back to config.json inspection (if model is downloaded)
    /// 4. Falls back to name heuristics
    ///
    /// - Parameter model: The model identifier to analyze.
    /// - Returns: Detected capabilities including vision support.
    ///
    /// ## Example
    /// ```swift
    /// let caps = await VLMDetector.shared.detectCapabilities(.mlx("mlx-community/llava-1.5-7b-4bit"))
    /// print("Supports vision: \(caps.supportsVision)")
    /// print("Architecture: \(caps.architectureType?.rawValue ?? "unknown")")
    /// ```
    public func detectCapabilities(_ model: ModelIdentifier) async -> ModelCapabilities {
        let repoId = model.rawValue

        // Layer 1: Try metadata detection (highest confidence)
        if let caps = await detectFromMetadata(repoId: repoId) {
            return caps
        }

        // Layer 2: Try config.json inspection (high confidence, if model is downloaded)
        if let caps = await detectFromConfig(repoId: repoId) {
            return caps
        }

        // Layer 3: Fall back to name heuristics (medium confidence)
        return detectFromName(repoId: repoId)
    }

    /// Quick check if a model is a Vision Language Model.
    ///
    /// Convenience method that calls `detectCapabilities` and returns the vision support flag.
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: `true` if the model supports vision input.
    ///
    /// ## Example
    /// ```swift
    /// if await VLMDetector.shared.isVLM(.mlx("mlx-community/pixtral-12b-4bit")) {
    ///     print("This is a vision-capable model")
    /// }
    /// ```
    public func isVLM(_ model: ModelIdentifier) async -> Bool {
        let capabilities = await detectCapabilities(model)
        return capabilities.supportsVision
    }

    // MARK: - Private Detection Methods

    /// Detects capabilities from HuggingFace metadata (tags and pipeline_tag).
    ///
    /// Queries the HuggingFace API to retrieve model metadata including:
    /// - `pipeline_tag`: The model's primary task type
    /// - `tags`: User-applied tags and library tags
    /// - `model_type`: Architecture identifier
    ///
    /// - Parameter repoId: The HuggingFace repository ID.
    /// - Returns: Detected capabilities, or `nil` if metadata is unavailable.
    private func detectFromMetadata(repoId: String) async -> ModelCapabilities? {
        // Use HFMetadataService to fetch model details
        guard let details = await HFMetadataService.shared.fetchModelDetails(repoId: repoId) else {
            return nil
        }

        // Check if metadata indicates VLM
        let isVLM = details.isVLM

        guard isVLM else {
            // Explicitly not a VLM based on metadata
            return ModelCapabilities.textOnly
        }

        // Determine architecture type from model_type or name
        let architectureType = detectArchitectureType(
            modelType: details.modelType,
            repoId: repoId
        )

        return ModelCapabilities(
            supportsVision: true,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            architectureType: architectureType,
            contextWindowSize: nil
        )
    }

    /// Detects capabilities by inspecting config.json from a downloaded model.
    ///
    /// This method only works if the model has been downloaded locally.
    /// It reads the config.json file and looks for VLM-specific fields.
    ///
    /// - Parameter repoId: The HuggingFace repository ID.
    /// - Returns: Detected capabilities, or `nil` if config is unavailable.
    private func detectFromConfig(repoId: String) async -> ModelCapabilities? {
        // Construct path to model directory
        // This assumes models are stored in ~/Library/Application Support/Conduit/models/
        // or a similar location. Adjust based on actual ModelManager storage path.
        guard let modelPath = modelStoragePath(for: repoId) else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            return nil
        }

        let configURL = modelPath.appendingPathComponent("config.json")

        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Check for VLM-specific config fields
        var hasVLMField = false
        for field in Self.vlmConfigFields {
            if config[field] != nil {
                hasVLMField = true
                break
            }
        }

        // Check model_type against known VLM architectures
        var isVLMArchitecture = false
        if let modelType = config["model_type"] as? String {
            let normalized = modelType.lowercased().replacingOccurrences(of: "-", with: "_")
            isVLMArchitecture = Self.vlmArchitectures.contains(normalized)
        }

        let isVLM = hasVLMField || isVLMArchitecture

        guard isVLM else {
            return ModelCapabilities.textOnly
        }

        // Determine architecture type
        let architectureType: ArchitectureType?
        if let modelType = config["model_type"] as? String {
            architectureType = detectArchitectureType(modelType: modelType, repoId: repoId)
        } else {
            architectureType = detectArchitectureType(modelType: nil, repoId: repoId)
        }

        return ModelCapabilities(
            supportsVision: true,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            architectureType: architectureType,
            contextWindowSize: nil
        )
    }

    /// Detects capabilities from model name heuristics (fallback).
    ///
    /// Uses pattern matching on the repository ID to infer VLM capabilities.
    /// This is the least reliable method but provides coverage when metadata
    /// and config files are unavailable.
    ///
    /// - Parameter repoId: The HuggingFace repository ID.
    /// - Returns: Detected capabilities based on name patterns.
    private func detectFromName(repoId: String) -> ModelCapabilities {
        let lower = repoId.lowercased()

        // Check if any VLM pattern matches
        let isVLM = vlmNamePatterns.contains { lower.contains($0) }

        guard isVLM else {
            return ModelCapabilities.textOnly
        }

        // Determine architecture type from name
        let architectureType = detectArchitectureType(modelType: nil, repoId: repoId)

        return ModelCapabilities(
            supportsVision: true,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            architectureType: architectureType,
            contextWindowSize: nil
        )
    }

    // MARK: - Private Helpers

    /// Detects the specific architecture type from model_type field or repository name.
    ///
    /// - Parameters:
    ///   - modelType: The model_type from config.json (if available).
    ///   - repoId: The HuggingFace repository ID.
    /// - Returns: The detected architecture type, or `.vlm` as a fallback.
    private func detectArchitectureType(modelType: String?, repoId: String) -> ArchitectureType {
        let searchString = (modelType ?? repoId).lowercased()

        // Check for specific architectures
        if searchString.contains("llava") {
            return .llava
        } else if searchString.contains("qwen2_vl") || searchString.contains("qwen2-vl") {
            return .qwen2VL
        } else if searchString.contains("pixtral") {
            return .pixtral
        } else if searchString.contains("paligemma") {
            return .paligemma
        } else if searchString.contains("idefics") {
            return .idefics
        } else if searchString.contains("mllama") {
            return .mllama
        } else if searchString.contains("phi3_v") || searchString.contains("phi-3-vision") {
            return .phi3Vision
        } else if searchString.contains("cogvlm") {
            return .cogvlm
        } else if searchString.contains("internvl") {
            return .internvl
        } else if searchString.contains("minicpm-v") || searchString.contains("minicpm_v") {
            return .minicpmV
        } else if searchString.contains("florence") {
            return .florence
        } else if searchString.contains("blip") {
            return .blip
        }

        // Fallback to generic VLM
        return .vlm
    }

    /// Constructs the local storage path for a model.
    ///
    /// This should match the actual storage location used by ModelManager.
    /// Currently assumes models are stored in Application Support directory.
    ///
    /// - Parameter repoId: The HuggingFace repository ID.
    /// - Returns: URL to the model's local directory, or `nil` if Application Support is unavailable.
    private func modelStoragePath(for repoId: String) -> URL? {
        // Get Application Support directory
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        // Construct Conduit models directory
        let conduitDir = appSupport.appendingPathComponent("Conduit", isDirectory: true)
        let modelsDir = conduitDir.appendingPathComponent("models", isDirectory: true)

        // Sanitize repo ID for filesystem (replace / with _)
        let sanitizedRepoId = repoId.replacingOccurrences(of: "/", with: "_")

        return modelsDir.appendingPathComponent(sanitizedRepoId, isDirectory: true)
    }
}
