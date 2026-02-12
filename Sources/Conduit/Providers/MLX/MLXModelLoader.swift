// MLXModelLoader.swift
// Conduit
//
// NOTE: This entire file requires MLX trait - Metal GPU and Apple Silicon only.

#if canImport(MLX)

#if CONDUIT_TRAIT_MLX
import Foundation
@preconcurrency import MLX
@preconcurrency import MLXLMCommon
@preconcurrency import MLXLLM
@preconcurrency import MLXVLM
// Note: Tokenizer protocol is re-exported through MLXLMCommon

/// Internal actor for loading and managing MLX model instances.
///
/// Manages model lifecycle including loading, caching in memory, and LRU eviction.
/// Only one model is kept loaded at a time by default to conserve memory.
///
/// ## Overview
///
/// `MLXModelLoader` is an internal actor that handles the low-level details of loading
/// and managing MLX model instances. It integrates with `ModelManager` for downloading
/// and caching model files, and provides LRU eviction when memory is constrained.
///
/// ## Architecture
///
/// ```
/// MLXProvider → MLXModelLoader → ModelManager
///                    ↓
///           LLMModelFactory (mlx-swift-lm)
/// ```
///
/// ## LRU Eviction
///
/// By default, only one model is kept loaded in memory at a time. When a different model
/// is requested, the previous model is automatically unloaded. This can be configured
/// via the `maxLoadedModels` parameter.
///
/// ## Thread Safety
///
/// As an actor, `MLXModelLoader` provides automatic thread safety for all operations.
/// All model loading and access tracking is serialized through the actor's executor.
///
/// - Note: This is an internal implementation detail of the MLX provider and should
///   not be used directly by application code.
internal actor MLXModelLoader {

    // MARK: - Properties

    /// The MLX configuration for this loader.
    let configuration: MLXConfiguration

    /// Maximum number of models to keep loaded in memory (LRU).
    ///
    /// When this limit is reached, the least recently used model is evicted
    /// before loading a new one.
    ///
    /// - Note: This is now managed by MLXModelCache.
    let maxLoadedModels: Int

    // MARK: - Initialization

    /// Creates a model loader with the specified configuration.
    ///
    /// - Parameters:
    ///   - configuration: The MLX configuration for model loading. Defaults to `.default`.
    ///   - maxLoadedModels: Maximum models to keep in memory. Defaults to 1.
    init(configuration: MLXConfiguration = .default, maxLoadedModels: Int = 1) {
        self.configuration = configuration
        self.maxLoadedModels = max(1, maxLoadedModels)
    }

    // MARK: - Model Loading

    #if arch(arm64)
    /// Loads a model and returns its container.
    ///
    /// If the model is already loaded in memory, returns the cached container
    /// immediately. Otherwise, downloads the model (if needed) and loads it
    /// into memory.
    ///
    /// This method automatically detects VLM capabilities and routes to the
    /// appropriate factory (VLMModelFactory for vision models, LLMModelFactory
    /// for text-only models).
    ///
    /// - Parameter identifier: The model identifier to load.
    /// - Returns: The loaded model container.
    /// - Throws: `AIError` if loading fails.
    ///
    /// ## Error Cases
    /// - `AIError.invalidInput` if identifier is not an MLX model
    /// - `AIError.modelNotCached` if download fails
    /// - `AIError.generationFailed` if model loading fails
    func loadModel(identifier: ModelIdentifier) async throws -> ModelContainer {
        // Validate it's an MLX model
        guard case .mlx(let modelId) = identifier else {
            throw AIError.invalidInput("MLXModelLoader only supports .mlx() model identifiers")
        }

        applyRuntimeConfiguration()

        // Check cache first
        if let cached = await MLXModelCache.shared.get(modelId) {
            // Set as current model
            await MLXModelCache.shared.setCurrentModel(modelId)
            return cached.container
        }

        // Detect model capabilities using VLMDetector
        let capabilities = await VLMDetector.shared.detectCapabilities(identifier)

        // Create MLX configuration using model ID
        // mlx-swift-lm handles downloading and caching internally via HuggingFace Hub
        let modelConfig = ModelConfiguration(id: modelId)

        // Load the model using the appropriate factory based on capabilities
        do {
            let container: ModelContainer

            if capabilities.supportsVision {
                // Route to VLMModelFactory for vision-capable models
                container = try await VLMModelFactory.shared.loadContainer(
                    configuration: modelConfig,
                    progressHandler: { progress in
                        // Progress tracking for model weight loading
                        // Could expose this via a callback in the future
                    }
                )
            } else {
                // Route to LLMModelFactory for text-only models
                container = try await LLMModelFactory.shared.loadContainer(
                    configuration: modelConfig,
                    progressHandler: { progress in
                        // Progress tracking for model weight loading
                        // Could expose this via a callback in the future
                    }
                )
            }

            // Estimate model size (rough estimate based on model name or default to 2GB)
            let estimatedSize = estimateModelSize(modelId: modelId)

            // Cache the loaded model with its capabilities
            let cachedModel = MLXModelCache.CachedModel(
                container: container,
                capabilities: capabilities,
                weightsSize: estimatedSize
            )
            await MLXModelCache.shared.set(cachedModel, forKey: modelId)
            await MLXModelCache.shared.setCurrentModel(modelId)

            // Mark as accessed in ModelManager for LRU tracking
            await ModelManager.shared.markAccessed(identifier)

            return container

        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }
    }
    #endif

    /// Applies global MLX runtime settings from the loader configuration.
    ///
    /// MLX GPU memory limits are global process-level settings, so this is
    /// applied opportunistically before model loading.
    private func applyRuntimeConfiguration() {
        if let memoryLimit = configuration.memoryLimit {
            MLX.GPU.set(memoryLimit: Int(clamping: memoryLimit.bytes))
        }
    }

    /// Unloads a specific model from memory.
    ///
    /// Removes the model from the in-memory cache. The model files remain
    /// on disk and can be reloaded later.
    ///
    /// - Parameter identifier: The model to unload.
    func unloadModel(identifier: ModelIdentifier) async {
        guard case .mlx(let modelId) = identifier else { return }
        await MLXModelCache.shared.remove(modelId)
    }

    /// Unloads all models from memory.
    ///
    /// Clears the in-memory cache of all loaded models. Model files remain
    /// on disk and can be reloaded later.
    func unloadAllModels() async {
        await MLXModelCache.shared.removeAll()
    }

    /// Checks if a model is currently loaded in memory.
    ///
    /// - Parameter identifier: The model to check.
    /// - Returns: `true` if the model is loaded, `false` otherwise.
    func isLoaded(_ identifier: ModelIdentifier) async -> Bool {
        guard case .mlx(let modelId) = identifier else { return false }
        return await MLXModelCache.shared.contains(modelId)
    }

    /// Returns the capabilities of a loaded model.
    ///
    /// If the model is not currently loaded, this returns `nil`.
    /// To get capabilities without loading, use `VLMDetector.shared.detectCapabilities()`.
    ///
    /// - Parameter identifier: The model to query.
    /// - Returns: The model's capabilities if loaded, `nil` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// let identifier = ModelIdentifier.mlx("mlx-community/llava-1.5-7b-4bit")
    /// if let capabilities = await modelLoader.getCapabilities(identifier) {
    ///     if capabilities.supportsVision {
    ///         print("VLM detected: \(capabilities.architectureType?.rawValue ?? "unknown")")
    ///     }
    /// }
    /// ```
    func getCapabilities(_ identifier: ModelIdentifier) async -> ModelCapabilities? {
        guard case .mlx(let modelId) = identifier else { return nil }
        if let cached = await MLXModelCache.shared.get(modelId) {
            return cached.capabilities
        }
        return nil
    }

    // MARK: - Tokenizer Access

    #if arch(arm64)
    /// Encodes text to tokens using the model's tokenizer.
    ///
    /// - Parameters:
    ///   - text: The text to encode.
    ///   - identifier: The model whose tokenizer to use.
    /// - Returns: Array of token IDs.
    /// - Throws: `AIError` if encoding fails.
    func encode(text: String, for identifier: ModelIdentifier) async throws -> [Int] {
        let container = try await loadModel(identifier: identifier)
        return await container.perform { context in
            context.tokenizer.encode(text: text)
        }
    }

    /// Decodes tokens to text using the model's tokenizer.
    ///
    /// - Parameters:
    ///   - tokens: The token IDs to decode.
    ///   - identifier: The model whose tokenizer to use.
    /// - Returns: Decoded text string.
    /// - Throws: `AIError` if decoding fails.
    func decode(tokens: [Int], for identifier: ModelIdentifier) async throws -> String {
        let container = try await loadModel(identifier: identifier)
        return await container.perform { context in
            context.tokenizer.decode(tokens: tokens)
        }
    }
    #endif

    // MARK: - Private Helpers

    #if arch(arm64)
    /// Estimates model size based on model ID heuristics.
    ///
    /// This is a rough estimate based on common model naming patterns.
    /// For more accurate sizes, the actual weights file would need to be inspected.
    ///
    /// - Parameter modelId: The model identifier (repository ID).
    /// - Returns: Estimated model size in bytes.
    private func estimateModelSize(modelId: String) -> ByteCount {
        let lowercased = modelId.lowercased()

        // Check for size indicators in the model name
        if lowercased.contains("1b") || lowercased.contains("1.5b") {
            return .gigabytes(1)
        } else if lowercased.contains("3b") {
            return .gigabytes(2)
        } else if lowercased.contains("7b") {
            return .gigabytes(4)
        } else if lowercased.contains("13b") {
            return .gigabytes(8)
        } else if lowercased.contains("30b") || lowercased.contains("33b") {
            return .gigabytes(16)
        } else if lowercased.contains("70b") {
            return .gigabytes(32)
        }

        // Check for quantization indicators
        if lowercased.contains("4bit") || lowercased.contains("q4") {
            // 4-bit quantized models are roughly 1/4 size
            return .gigabytes(2)
        } else if lowercased.contains("8bit") || lowercased.contains("q8") {
            return .gigabytes(4)
        }

        // Default fallback
        return .gigabytes(2)
    }
    #endif

    /// Resolves the local file path for a model, downloading if necessary.
    ///
    /// - Parameter identifier: The model to resolve.
    /// - Returns: The local file URL for the model.
    /// - Throws: `AIError.modelNotCached` if download fails.
    private func resolveModelPath(for identifier: ModelIdentifier) async throws -> URL {
        // Check if already cached
        if await ModelManager.shared.isCached(identifier) {
            if let path = await ModelManager.shared.localPath(for: identifier) {
                return path
            }
        }

        // Not cached - download it
        do {
            return try await ModelManager.shared.download(identifier, progress: nil)
        } catch {
            throw AIError.modelNotCached(identifier)
        }
    }
}

// MARK: - Non-arm64 Stubs

#if !arch(arm64)
extension MLXModelLoader {
    /// Stub for non-Apple Silicon - always throws.
    ///
    /// MLX requires Apple Silicon (arm64) architecture. On other platforms,
    /// this method throws `AIError.providerUnavailable`.
    ///
    /// - Parameter identifier: The model identifier (ignored).
    /// - Throws: `AIError.providerUnavailable` with reason `.deviceNotSupported`.
    func loadModel(identifier: ModelIdentifier) async throws -> Never {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }

    /// Stub for non-Apple Silicon - always throws.
    ///
    /// MLX requires Apple Silicon (arm64) architecture. On other platforms,
    /// this method throws `AIError.providerUnavailable`.
    ///
    /// - Parameter identifier: The model identifier (ignored).
    /// - Throws: `AIError.providerUnavailable` with reason `.deviceNotSupported`.
    func tokenizer(for identifier: ModelIdentifier) async throws -> Never {
        throw AIError.providerUnavailable(reason: .deviceNotSupported)
    }
}
#endif // !arch(arm64)

#endif // canImport(MLX)

#endif // CONDUIT_TRAIT_MLX
