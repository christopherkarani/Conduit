//
//  MLXCompatibilityChecker.swift
//  SwiftAI
//
//  Multi-tier validation service for determining MLX model compatibility.
//  Uses HuggingFace metadata to validate models before download/usage.
//

import Foundation

// MARK: - MLXCompatibilityChecker

/// Actor-based service for validating MLX model compatibility using multi-tier detection.
///
/// Provides comprehensive validation across three confidence tiers:
/// - **Tier 1 (High)**: Explicit MLX tags in HuggingFace metadata
/// - **Tier 2 (Medium)**: Model name contains "mlx" AND has required files
/// - **Tier 3 (Medium)**: Trusted `mlx-community/` prefix AND has required files
///
/// ## Usage
/// ```swift
/// let checker = MLXCompatibilityChecker.shared
///
/// // Check a model identifier
/// let result = await checker.checkCompatibility(.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit"))
/// switch result {
/// case .compatible(let confidence):
///     print("Compatible with \(confidence) confidence")
/// case .incompatible(let reasons):
///     print("Incompatible: \(reasons)")
/// case .unknown(let error):
///     print("Unable to verify: \(error?.localizedDescription ?? "unknown")")
/// }
///
/// // Convenience boolean check
/// if await checker.isCompatible(.mlx("mlx-community/Qwen2.5-3B-Instruct-4bit")) {
///     // Proceed with download
/// }
/// ```
///
/// ## Validation Strategy
///
/// ### Tier 1: Explicit MLX Tags (High Confidence)
/// Searches for explicit MLX tags in model metadata:
/// - `mlx`
/// - `apple-mlx`
/// - `library:mlx`
///
/// ### Tier 2: Name-Based Detection (Medium Confidence)
/// Model repository ID contains "mlx" (case-insensitive) AND:
/// - Has `config.json`
/// - Has `.safetensors` weight files
/// - Has tokenizer files
/// - Architecture is supported by MLX
///
/// ### Tier 3: Trusted Repository Fallback (Medium Confidence)
/// Repository ID starts with `mlx-community/` AND:
/// - Has required files (same as Tier 2)
/// - Architecture is supported by MLX
///
/// ### Network Failure Fallback
/// On network errors, trusted `mlx-community/` models return `.compatible(.medium)`
/// to allow offline usage scenarios.
///
/// ## Required Files
///
/// All tiers (except Tier 1) validate the presence of:
/// - **config.json**: Model configuration
/// - **Weights**: Files ending in `.safetensors`
/// - **Tokenizer**: Any of:
///   - `tokenizer.json`
///   - `tokenizer.model`
///   - `spiece.model`
///   - `vocab.json`
///   - `vocab.txt`
///   - `merges.txt`
///
/// ## Supported Architectures
///
/// The following model architectures are validated as MLX-compatible:
/// - Language Models: llama, mistral, mixtral, qwen, qwen2, phi, phi3, gemma, gemma2
/// - Code Models: starcoder, codellama
/// - Extended Models: deepseek, yi, internlm, baichuan, chatglm, falcon, mpt
/// - Vision-Language Models: llava, llava_next, qwen2_vl, pixtral, paligemma
///
public actor MLXCompatibilityChecker {

    // MARK: - Singleton

    /// Shared singleton instance.
    public static let shared = MLXCompatibilityChecker()

    // MARK: - Private Initialization

    private init() {}

    // MARK: - Public Methods

    /// Checks if a model is compatible with MLX using multi-tier validation.
    ///
    /// Performs comprehensive validation across three tiers (explicit tags, name-based, trusted repos)
    /// and falls back to trusted repository detection on network errors.
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: A `CompatibilityResult` indicating compatibility, incompatibility, or unknown status.
    ///
    /// ## Example
    /// ```swift
    /// let result = await MLXCompatibilityChecker.shared.checkCompatibility(.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit"))
    /// switch result {
    /// case .compatible(let confidence):
    ///     print("Compatible with \(confidence) confidence")
    /// case .incompatible(let reasons):
    ///     print("Incompatible: \(reasons.map { $0.description }.joined(separator: ", "))")
    /// case .unknown(let error):
    ///     print("Unable to verify compatibility")
    /// }
    /// ```
    public func checkCompatibility(_ model: ModelIdentifier) async -> CompatibilityResult {
        guard case .mlx(let repoId) = model else {
            // Non-MLX models are not checked for MLX compatibility - return unknown
            // (they're not "incompatible", they're just not MLX models)
            return .unknown(nil)
        }

        return await checkCompatibility(repoId: repoId)
    }

    /// Checks if a repository is compatible with MLX using multi-tier validation.
    ///
    /// Performs comprehensive validation across three tiers and falls back to
    /// trusted repository detection on network errors.
    ///
    /// - Parameter repoId: The HuggingFace repository ID (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit").
    /// - Returns: A `CompatibilityResult` indicating compatibility, incompatibility, or unknown status.
    ///
    /// ## Example
    /// ```swift
    /// let result = await MLXCompatibilityChecker.shared.checkCompatibility(repoId: "mlx-community/Qwen2.5-3B-Instruct-4bit")
    /// if case .compatible(let confidence) = result {
    ///     print("Compatible with \(confidence) confidence")
    /// }
    /// ```
    public func checkCompatibility(repoId: String) async -> CompatibilityResult {
        // Fetch metadata from HuggingFace
        let metadata = await HFMetadataService.shared.fetchRepoMetadata(repoId: repoId)

        // Handle network failure for trusted repositories
        if metadata == nil {
            // Trust mlx-community repos on network failure
            if repoId.lowercased().hasPrefix("mlx-community/") {
                return .compatible(confidence: .medium)
            }
            return .unknown(nil)
        }

        guard let meta = metadata else {
            return .unknown(nil)
        }

        // Tier 1: Check for explicit MLX tags (high confidence)
        if hasExplicitMLXTags(meta.tags) {
            return .compatible(confidence: .high)
        }

        // Tier 2: Name-based detection (medium confidence)
        let repoNameContainsMLX = repoId.lowercased().contains("mlx")
        if repoNameContainsMLX {
            if let result = validateRequiredFiles(meta) {
                return result
            }
        }

        // Tier 3: Trust mlx-community prefix with file validation (medium confidence)
        if repoId.lowercased().hasPrefix("mlx-community/") {
            if let result = validateRequiredFiles(meta) {
                return result
            }
        }

        // No tier matched - not compatible
        return .incompatible(reasons: [.notMLXOptimized])
    }

    /// Convenience method to check if a model is compatible (returns boolean).
    ///
    /// Returns `true` if the model is compatible with any confidence level,
    /// or if it's an `mlx-community/` model and verification failed (offline trust).
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: `true` if compatible, `false` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// if await MLXCompatibilityChecker.shared.isCompatible(.mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")) {
    ///     print("Model is compatible")
    /// }
    /// ```
    public func isCompatible(_ model: ModelIdentifier) async -> Bool {
        let result = await checkCompatibility(model)
        switch result {
        case .compatible:
            return true
        case .incompatible, .unknown:
            return false
        }
    }

    // MARK: - Private Validation Methods

    /// Checks if tags contain explicit MLX indicators.
    ///
    /// Searches for:
    /// - `mlx` (exact match, case-insensitive)
    /// - `apple-mlx` (exact match, case-insensitive)
    /// - `library:mlx` (prefix match, case-insensitive)
    ///
    /// - Parameter tags: Array of tags from HuggingFace metadata.
    /// - Returns: `true` if explicit MLX tags are found.
    private func hasExplicitMLXTags(_ tags: [String]) -> Bool {
        let lowerTags = tags.map { $0.lowercased() }

        // Check for exact matches
        if lowerTags.contains("mlx") || lowerTags.contains("apple-mlx") {
            return true
        }

        // Check for library:mlx prefix
        if lowerTags.contains(where: { $0.hasPrefix("library:mlx") }) {
            return true
        }

        return false
    }

    /// Validates required files and supported architecture.
    ///
    /// Checks for:
    /// - `config.json` (required)
    /// - `.safetensors` weight files (required)
    /// - Tokenizer files (required, any of: tokenizer.json, tokenizer.model, etc.)
    /// - Supported architecture (extracted from config.json or tags)
    ///
    /// - Parameter metadata: Repository metadata from HuggingFace.
    /// - Returns: `CompatibilityResult` or `nil` if validation fails.
    private func validateRequiredFiles(_ metadata: HFMetadataService.RepoMetadata) -> CompatibilityResult? {
        var reasons: [IncompatibilityReason] = []

        // Check for config.json
        let hasConfig = metadata.files.contains { $0.path == "config.json" }
        if !hasConfig {
            reasons.append(.missingConfigJSON)
        }

        // Check for safetensors weights
        let hasWeights = metadata.files.contains { $0.path.hasSuffix(".safetensors") }
        if !hasWeights {
            reasons.append(.missingWeights)
        }

        // Check for tokenizer files
        let tokenizerFiles = [
            "tokenizer.json",
            "tokenizer.model",
            "spiece.model",
            "vocab.json",
            "vocab.txt",
            "merges.txt"
        ]
        let hasTokenizer = metadata.files.contains { file in
            tokenizerFiles.contains(file.path)
        }
        if !hasTokenizer {
            reasons.append(.missingTokenizer)
        }

        // Check architecture support if model_type is available
        if let modelType = metadata.modelType {
            let archSupported = Self.supportedArchitectures.contains(modelType.lowercased())
            if !archSupported {
                reasons.append(.unsupportedArchitecture(modelType))
            }
        }

        // If any incompatibility reasons exist, return incompatible
        if !reasons.isEmpty {
            return .incompatible(reasons: reasons)
        }

        // All checks passed - compatible with medium confidence
        return .compatible(confidence: .medium)
    }

    // MARK: - Supported Architectures

    /// Set of MLX-supported model architectures.
    ///
    /// This list is based on MLX Swift's supported architectures as of December 2024.
    /// Architectures are stored in lowercase for case-insensitive comparison.
    private static let supportedArchitectures: Set<String> = [
        // Core language models
        "llama", "mistral", "mixtral", "qwen", "qwen2",
        "phi", "phi3", "gemma", "gemma2",

        // Code generation models
        "starcoder", "codellama",

        // Extended support
        "deepseek", "yi", "internlm", "baichuan",
        "chatglm", "falcon", "mpt",

        // Vision-language models
        "llava", "llava_next", "qwen2_vl", "pixtral", "paligemma"
    ]
}

// MARK: - CompatibilityResult

/// Result of MLX compatibility validation.
///
/// Provides detailed information about compatibility status including
/// confidence levels for compatible models and specific reasons for incompatibility.
public enum CompatibilityResult: Sendable {

    /// Model is compatible with MLX.
    ///
    /// - Parameter confidence: The confidence level of the compatibility determination.
    case compatible(confidence: Confidence)

    /// Model is incompatible with MLX.
    ///
    /// - Parameter reasons: Array of specific incompatibility reasons.
    case incompatible(reasons: [IncompatibilityReason])

    /// Unable to determine compatibility.
    ///
    /// - Parameter error: Optional error that caused the determination failure.
    case unknown(Error?)

    /// Confidence level for compatibility determination.
    public enum Confidence: Sendable {

        /// High confidence - Model has explicit MLX tags.
        ///
        /// The model's HuggingFace metadata contains explicit MLX tags
        /// such as "mlx", "apple-mlx", or "library:mlx".
        case high

        /// Medium confidence - Name suggests MLX or from trusted source.
        ///
        /// The model's name contains "mlx" or it's from the `mlx-community`
        /// organization, and all required files are present.
        case medium

        /// Low confidence - Only basic requirements met.
        ///
        /// The model has the required files and supported architecture,
        /// but lacks explicit MLX indicators.
        case low
    }
}

// MARK: - IncompatibilityReason

/// Specific reasons why a model is incompatible with MLX.
///
/// Provides detailed information about what's missing or unsupported
/// in a model that prevents MLX compatibility.
public enum IncompatibilityReason: Sendable, CustomStringConvertible {

    /// Model is missing required `config.json` file.
    case missingConfigJSON

    /// Model is missing required `.safetensors` weight files.
    case missingWeights

    /// Model is missing required tokenizer files.
    ///
    /// Expected at least one of: tokenizer.json, tokenizer.model,
    /// spiece.model, vocab.json, vocab.txt, or merges.txt.
    case missingTokenizer

    /// Model uses an unsupported architecture.
    ///
    /// - Parameter architecture: The unsupported architecture name.
    case unsupportedArchitecture(String)

    /// Model is not optimized for MLX.
    ///
    /// No MLX indicators found in tags, name, or repository prefix.
    case notMLXOptimized

    /// Model format is unknown or unrecognized.
    case unknownFormat

    /// Human-readable description of the incompatibility reason.
    public var description: String {
        switch self {
        case .missingConfigJSON:
            return "Missing required config.json file"
        case .missingWeights:
            return "Missing required .safetensors weight files"
        case .missingTokenizer:
            return "Missing required tokenizer files"
        case .unsupportedArchitecture(let arch):
            return "Unsupported architecture: \(arch)"
        case .notMLXOptimized:
            return "Model is not optimized for MLX"
        case .unknownFormat:
            return "Unknown or unrecognized model format"
        }
    }
}
