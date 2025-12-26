// MLXImageProvider.swift
// SwiftAI
//
// Local on-device image generation using MLX StableDiffusion.

import Foundation
import Hub
@preconcurrency import MLX
import StableDiffusion

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Local on-device image generation using MLX StableDiffusion.
///
/// Generates images entirely on-device using Apple Silicon's Neural Engine
/// and GPU. Supports SDXL Turbo, Stable Diffusion 1.5, and Flux models.
///
/// ## Features
///
/// - **Privacy**: All processing happens on-device
/// - **Offline**: Works without internet connection
/// - **Progress**: Step-by-step progress callbacks
/// - **Cancellation**: Cancel mid-generation
///
/// ## Requirements
///
/// - Apple Silicon (M-series Mac or A14+ iPhone/iPad)
/// - 6GB+ RAM (8GB+ recommended for SDXL)
/// - Downloaded model weights
///
/// ## Usage
///
/// ```swift
/// let provider = MLXImageProvider()
///
/// // Load a model
/// try await provider.loadModel(from: modelPath, variant: .sdxlTurbo)
///
/// // Generate with progress
/// let image = try await provider.generateImage(
///     prompt: "A cat wearing a top hat, digital art",
///     config: .default
/// ) { progress in
///     print("Step \(progress.currentStep)/\(progress.totalSteps)")
/// }
/// ```
///
/// ## Performance
///
/// Generation time depends on:
/// - Model variant (SDXL Turbo: ~5s, SD 1.5: ~15s)
/// - Image dimensions (larger = slower)
/// - Number of steps (more = slower but better quality)
/// - Device (M3 > M2 > M1 > A-series)
///
/// ## Memory Management
///
/// The provider automatically manages GPU memory based on device RAM:
/// - ≤8GB RAM: Conservative mode (3GB GPU limit)
/// - >8GB RAM: Normal mode (more cache)
///
/// Call `unloadModel()` when finished to free memory.
public actor MLXImageProvider: ImageGenerator {

    // MARK: - Properties

    /// The loaded StableDiffusion model container.
    private var modelContainer: ModelContainer<TextToImageGenerator>?

    /// The identifier of the currently loaded model.
    private var currentModelId: String?

    /// The variant of the currently loaded model.
    private var currentVariant: DiffusionVariant?

    /// Flag indicating if generation should be cancelled.
    private var isCancelled = false

    /// Minimum device RAM required for image generation (6GB).
    private let minimumMemoryRequired: UInt64 = 6 * 1024 * 1024 * 1024

    /// LRU cache for loaded diffusion models.
    private let modelCache: ModelLRUCache

    // MARK: - Initialization

    /// Creates a new MLX image provider.
    ///
    /// The provider starts unloaded. Call `loadModel(from:variant:)` before
    /// generating images.
    ///
    /// - Parameter cacheCapacity: Maximum number of models to keep in cache
    ///   (default 2). Each cached model consumes 2-8GB of RAM. Ensure your
    ///   device has sufficient memory before increasing capacity.
    public init(cacheCapacity: Int = 2) {
        self.modelCache = ModelLRUCache(capacity: cacheCapacity)
    }

    // MARK: - ImageGenerator Conformance

    /// Whether the provider is available for image generation.
    ///
    /// Returns `true` if:
    /// - Running on Apple Silicon (arm64)
    /// - Device has at least 6GB RAM
    /// - A model is loaded
    public var isAvailable: Bool {
        get async {
            #if !arch(arm64)
            return false
            #else
            let hasMemory = ProcessInfo.processInfo.physicalMemory >= minimumMemoryRequired
            let hasModel = modelContainer != nil
            return hasMemory && hasModel
            #endif
        }
    }

    /// Generates an image from a text prompt.
    ///
    /// This method performs multi-stage diffusion generation:
    /// 1. Validates platform and memory requirements
    /// 2. Validates input prompt and dimensions
    /// 3. Generates latents through iterative denoising
    /// 4. Decodes latents to pixel space
    /// 5. Converts to PNG format
    ///
    /// ## Progress Reporting
    ///
    /// The `onProgress` callback is invoked after each diffusion step,
    /// allowing you to display real-time progress to the user.
    ///
    /// ## Cancellation
    ///
    /// Call `cancelGeneration()` from another task to stop generation.
    /// The method will throw `AIError.cancelled` if cancelled.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let image = try await provider.generateImage(
    ///     prompt: "A serene mountain landscape at sunset",
    ///     negativePrompt: "blurry, low quality",
    ///     config: .highQuality
    /// ) { progress in
    ///     await MainActor.run {
    ///         progressView.progress = progress.fractionComplete
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image (must be non-empty).
    ///   - negativePrompt: Optional text describing what to avoid.
    ///   - config: Image generation configuration (dimensions, steps, guidance).
    ///   - onProgress: Optional callback for progress updates.
    ///
    /// - Returns: The generated image as PNG data.
    ///
    /// - Throws:
    ///   - `AIError.unsupportedPlatform` if not on Apple Silicon or insufficient RAM
    ///   - `AIError.modelNotLoaded` if no model is loaded
    ///   - `AIError.invalidInput` if prompt is empty or dimensions are invalid
    ///   - `AIError.cancelled` if generation was cancelled
    ///   - `AIError.generationFailed` if the diffusion process fails
    public func generateImage(
        prompt: String,
        negativePrompt: String? = nil,
        config: ImageGenerationConfig = .default,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)? = nil
    ) async throws -> GeneratedImage {
        // 1. Check for task cancellation at start
        try Task.checkCancellation()

        // 2. Platform validation
        #if !arch(arm64)
        throw AIError.unsupportedPlatform("MLX image generation requires Apple Silicon")
        #else

        // 3. Memory validation
        guard ProcessInfo.processInfo.physicalMemory >= minimumMemoryRequired else {
            throw AIError.unsupportedPlatform("Requires 6GB+ RAM for image generation")
        }

        // 4. Model validation
        guard let container = modelContainer, let variant = currentVariant else {
            throw AIError.modelNotLoaded("No diffusion model loaded. Call loadModel() first.")
        }

        // 5. Prompt validation
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AIError.invalidInput("Prompt cannot be empty")
        }

        // 6. Determine generation parameters
        let steps = config.steps ?? variant.defaultSteps
        let guidance = config.guidanceScale ?? Float(variant.defaultGuidanceScale)
        let width = config.width ?? variant.defaultResolution.width
        let height = config.height ?? variant.defaultResolution.height

        // 7. Dimension validation (diffusion models require dimensions divisible by 8)
        guard width % 8 == 0 else {
            throw AIError.invalidInput("Width must be divisible by 8, got \(width)")
        }
        guard height % 8 == 0 else {
            throw AIError.invalidInput("Height must be divisible by 8, got \(height)")
        }

        // 8. Reset cancellation flag
        isCancelled = false
        let startTime = Date()

        // Calculate latent size (image size / 8 for VAE encoding)
        let latentWidth = width / 8
        let latentHeight = height / 8

        // 9. Create evaluation parameters
        let evaluateParams = EvaluateParameters(
            cfgWeight: guidance,
            steps: steps,
            imageCount: 1,
            decodingBatchSize: 1,
            latentSize: [latentHeight, latentWidth],
            seed: UInt64.random(in: 0...UInt64.max),
            prompt: trimmedPrompt,
            negativePrompt: negativePrompt ?? ""
        )

        do {
            // 10. Generate latents with progress tracking
            // Capture cancellation state before entering Sendable closure
            let wasCancelled = isCancelled

            let (finalLatent, totalSteps) = try await container.perform { generator in
                // Ensure cleanup happens on all exit paths (cancellation, error, success)
                defer {
                    // Clean up GPU resources if cancelled or errored
                    if Task.isCancelled || wasCancelled {
                        #if arch(arm64)
                        MLX.GPU.clearCache()
                        #endif
                    }
                }

                // Ensure model is loaded
                generator.ensureLoaded()

                // Generate latents through denoising iterations
                var latentIterator = generator.generateLatents(parameters: evaluateParams)
                var finalLatent: MLXArray?
                var currentStep = 0
                let totalSteps = latentIterator.underestimatedCount

                while let latent = latentIterator.next() {
                    currentStep += 1
                    finalLatent = latent

                    // Report progress
                    let elapsed = Date().timeIntervalSince(startTime)
                    let progress = ImageGenerationProgress(
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                        elapsedTime: elapsed
                    )
                    onProgress?(progress)

                    // Evaluate to prevent graph buildup
                    eval(latent)
                }

                guard let latent = finalLatent else {
                    throw AIError.generationFailed(
                        underlying: SendableError(
                            localizedDescription: "No latent generated"
                        )
                    )
                }

                // Return evaluated latent and total steps
                return (latent, totalSteps)
            }

            // 11. Check for cancellation after expensive latent generation
            try Task.checkCancellation()
            if isCancelled {
                cleanupGPUResources()
                throw AIError.cancelled
            }

            // 12. Decode the latent to an image
            let decoded = try await container.perform { generator in
                let decoder = generator.detachedDecoder()
                let result = decoder(finalLatent)
                eval(result)
                return result
            }

            // 13. Check for cancellation after decoding
            try Task.checkCancellation()
            if isCancelled {
                cleanupGPUResources()
                throw AIError.cancelled
            }

            // 14. Convert MLXArray to PNG data
            let pngData = try convertToPNG(decoded, width: width, height: height)

            // 15. Report completion
            let totalTime = Date().timeIntervalSince(startTime)
            let completionProgress = ImageGenerationProgress.completed(
                totalSteps: totalSteps,
                elapsedTime: totalTime
            )
            onProgress?(completionProgress)

            return GeneratedImage(data: pngData, format: .png)

        } catch is CancellationError {
            cleanupGPUResources()
            throw AIError.cancelled
        } catch let error as AIError {
            if case .cancelled = error {
                cleanupGPUResources()
            }
            throw error
        } catch {
            if isCancelled {
                cleanupGPUResources()
                throw AIError.cancelled
            }
            throw AIError.generationFailed(underlying: SendableError(error))
        }
        #endif
    }

    /// Cancels any ongoing image generation.
    ///
    /// Sets the cancellation flag which will be checked during the next
    /// progress callback. The `generateImage()` method will throw
    /// `AIError.cancelled` once cancellation is detected.
    ///
    /// This method returns immediately and does not wait for generation
    /// to actually stop.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let task = Task {
    ///     try await provider.generateImage(
    ///         prompt: "A detailed fantasy landscape"
    ///     )
    /// }
    ///
    /// // Cancel after 5 seconds
    /// try? await Task.sleep(for: .seconds(5))
    /// await provider.cancelGeneration()
    /// ```
    public func cancelGeneration() async {
        isCancelled = true
    }

    // MARK: - Model Management

    /// Loads a diffusion model from a local directory.
    ///
    /// The model directory should contain all required files for the
    /// specified variant:
    /// - UNet weights
    /// - Text encoder weights
    /// - VAE weights
    /// - Tokenizer configuration
    /// - Diffusion configuration
    ///
    /// ## Model Caching
    ///
    /// Models are automatically cached after loading. If the same model is
    /// loaded again, it will be retrieved from cache instead of being
    /// loaded from disk, significantly improving performance.
    ///
    /// ## Model Sources
    ///
    /// Download MLX-optimized models from HuggingFace Hub:
    /// - `mlx-community/stable-diffusion-xl-turbo-4bit`
    /// - `mlx-community/stable-diffusion-v1-5-4bit`
    /// - `mlx-community/flux-schnell-4bit`
    ///
    /// ## Memory Requirements
    ///
    /// Ensure your device has sufficient RAM for the variant:
    /// - SDXL Turbo: 8GB+
    /// - SD 1.5: 4GB+
    /// - Flux: 6GB+
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXImageProvider()
    /// let modelPath = URL.documentsDirectory.appending(path: "models/sdxl-turbo")
    /// try await provider.loadModel(from: modelPath, variant: .sdxlTurbo)
    /// ```
    ///
    /// - Parameters:
    ///   - path: Local directory containing the model files.
    ///   - variant: The diffusion model variant to load.
    ///
    /// - Throws:
    ///   - `AIError.unsupportedModel` if the variant is not natively supported
    ///   - `AIError.fileError` if model files cannot be read
    ///   - `AIError.insufficientMemory` if device lacks required RAM
    ///   - `AIError.generationFailed` if model loading fails
    public func loadModel(from path: URL, variant: DiffusionVariant) async throws {
        // Check if variant is natively supported
        guard variant.isNativelySupported else {
            throw AIError.unsupportedModel(
                variant: variant.displayName,
                reason: variant.unsupportedReason ?? "Not supported"
            )
        }

        let modelId = path.lastPathComponent

        // Check if model is already cached
        if let cachedContainer = await modelCache.get(modelId: modelId, variant: variant) {
            // Use cached model
            modelContainer = cachedContainer
            currentModelId = modelId
            currentVariant = variant
            return
        }

        // Check memory requirements
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let requiredMemory = UInt64(variant.minimumMemoryGB * 1_073_741_824)

        guard physicalMemory >= requiredMemory else {
            throw AIError.insufficientMemory(
                required: ByteCount(Int64(requiredMemory)),
                available: ByteCount(Int64(physicalMemory))
            )
        }

        do {
            // Validate OS version requirements
            try validateOSVersion()

            // Validate model files exist and are complete
            try validateModelFiles(at: path)

            // Map variant to StableDiffusionConfiguration preset

            let sdConfig: StableDiffusionConfiguration
            switch variant {
            case .sdxlTurbo:
                sdConfig = .presetSDXLTurbo
            case .sd15:
                // SD 1.5 is not natively supported by mlx-swift-examples StableDiffusion library
                // The library only provides presets for SDXL Turbo and SD 2.1
                throw AIError.unsupportedPlatform(
                    "Stable Diffusion 1.5 is not currently supported. " +
                    "Please use SDXL Turbo (.sdxlTurbo) instead."
                )
            case .flux:
                // Flux is not natively supported by mlx-swift-examples StableDiffusion library
                // The library only provides presets for SDXL Turbo and SD 2.1
                throw AIError.unsupportedPlatform(
                    "Flux is not currently supported by the MLX StableDiffusion library. " +
                    "Please use SDXL Turbo (.sdxlTurbo) instead."
                )
            }


            // Configure GPU memory limits during model loading (optimization)
            configureMemoryLimits()

            // Create model container for text-to-image generation
            let container = try ModelContainer<TextToImageGenerator>.createTextToImageGenerator(
                configuration: sdConfig,
                loadConfiguration: LoadConfiguration()
            )

            // Enable memory conservation for lower-memory devices
            if physicalMemory <= 8 * 1024 * 1024 * 1024 {
                await container.setConserveMemory(true)
            }

            // Cache the model
            await modelCache.put(modelId: modelId, variant: variant, container: container)

            modelContainer = container
            currentModelId = modelId
            currentVariant = variant

        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }
    }

    /// Unloads the current model to free memory.
    ///
    /// By default, the model is kept in the cache for faster reloading.
    /// Set `clearCache` to `true` to completely remove it from cache and
    /// free all associated memory.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Generate images
    /// let image1 = try await provider.generateImage(prompt: "...")
    /// let image2 = try await provider.generateImage(prompt: "...")
    ///
    /// // Unload but keep in cache for fast reloading
    /// await provider.unloadModel()
    ///
    /// // Unload and remove from cache to free all memory
    /// await provider.unloadModel(clearCache: true)
    /// ```
    ///
    /// - Parameter clearCache: If `true`, removes the model from cache and
    ///   clears GPU resources. If `false` (default), keeps the model in cache
    ///   for faster reloading.
    public func unloadModel(clearCache: Bool = false) async {
        // If clearCache is true, remove from cache
        if clearCache, let modelId = currentModelId, let variant = currentVariant {
            await modelCache.remove(modelId: modelId, variant: variant)
        }

        modelContainer = nil
        currentModelId = nil
        currentVariant = nil

        // Clear GPU cache
        #if arch(arm64)
        MLX.GPU.clearCache()
        #endif
    }

    /// The identifier of the currently loaded model.
    ///
    /// Returns `nil` if no model is loaded.
    public var loadedModelId: String? {
        currentModelId
    }

    /// The variant of the currently loaded model.
    ///
    /// Returns `nil` if no model is loaded.
    public var loadedVariant: DiffusionVariant? {
        currentVariant
    }

    // MARK: - Private Helpers

    /// Configures GPU memory limits based on device RAM.
    ///
    /// For devices with ≤8GB RAM, uses conservative settings:
    /// - 1MB cache limit
    /// - 3GB GPU memory limit
    ///
    /// For devices with >8GB RAM, uses standard settings:
    /// - 256MB cache limit
    /// - No explicit GPU memory limit
    ///
    /// This method should be called once during model loading, not on every generation.
    private func configureMemoryLimits() {
        #if arch(arm64)
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        if physicalMemory <= 8 * 1024 * 1024 * 1024 {
            // Low memory device (≤8GB)
            MLX.GPU.set(cacheLimit: 1 * 1024 * 1024)           // 1MB cache
            MLX.GPU.set(memoryLimit: 3 * 1024 * 1024 * 1024)   // 3GB limit
        } else {
            // High memory device (>8GB)
            MLX.GPU.set(cacheLimit: 256 * 1024 * 1024)         // 256MB cache
        }
        #endif
    }

    /// Cleans up GPU resources after cancellation or error.
    ///
    /// This method clears the GPU cache to release any intermediate tensors
    /// that were allocated during generation. This is especially important
    /// when generation is cancelled to avoid memory leaks.
    private func cleanupGPUResources() {
        #if arch(arm64)
        MLX.GPU.clearCache()
        #endif
    }

    /// Validates that the OS version meets minimum requirements for MLX.
    ///
    /// MLX image generation requires:
    /// - macOS 14.0+ (Sonoma)
    /// - iOS 17.0+
    /// - visionOS 1.0+
    ///
    /// - Throws: `AIError.unsupportedPlatform` if OS version is too old.
    private nonisolated func validateOSVersion() throws {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            // OS version is supported
        } else {
            throw AIError.unsupportedPlatform(
                "MLX image generation requires macOS 14.0 (Sonoma) or later"
            )
        }
        #elseif os(iOS)
        if #available(iOS 17.0, *) {
            // OS version is supported
        } else {
            throw AIError.unsupportedPlatform(
                "MLX image generation requires iOS 17.0 or later"
            )
        }
        #elseif os(visionOS)
        if #available(visionOS 1.0, *) {
            // OS version is supported
        } else {
            throw AIError.unsupportedPlatform(
                "MLX image generation requires visionOS 1.0 or later"
            )
        }
        #else
        throw AIError.unsupportedPlatform(
            "MLX image generation is only supported on macOS, iOS, and visionOS"
        )
        #endif
    }

    /// Validates that model files are present and complete.
    ///
    /// Checks for essential model files in the directory:
    /// - At least one `.safetensors` file (model weights)
    /// - Configuration files (`.json`)
    /// - Tokenizer files
    ///
    /// - Parameter path: The model directory path.
    /// - Throws: `AIError.fileError` if required files are missing.
    private nonisolated func validateModelFiles(at path: URL) throws {
        let fileManager = FileManager.default

        // Check directory exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AIError.fileError(
                underlying: SendableError(
                    localizedDescription: "Model directory does not exist at path: \(path.path)"
                )
            )
        }

        // Get directory contents
        let contents: [String]
        do {
            contents = try fileManager.contentsOfDirectory(atPath: path.path)
        } catch {
            throw AIError.fileError(
                underlying: SendableError(
                    localizedDescription: "Cannot read model directory at path \(path.path): \(error.localizedDescription)"
                )
            )
        }

        // Verify at least one .safetensors file exists
        let hasSafetensors = contents.contains { $0.hasSuffix(".safetensors") }
        guard hasSafetensors else {
            throw AIError.fileError(
                underlying: SendableError(
                    localizedDescription: "Model directory at path \(path.path) is missing .safetensors weight files. " +
                    "Please ensure the model is fully downloaded."
                )
            )
        }

        // Verify at least one .json configuration file exists
        let hasConfig = contents.contains { $0.hasSuffix(".json") }
        guard hasConfig else {
            throw AIError.fileError(
                underlying: SendableError(
                    localizedDescription: "Model directory at path \(path.path) is missing .json configuration files. " +
                    "Please ensure the model is fully downloaded."
                )
            )
        }

        // Check for tokenizer files (tokenizer.json or tokenizer_config.json)
        let hasTokenizer = contents.contains {
            $0.contains("tokenizer") && ($0.hasSuffix(".json") || $0.hasSuffix(".model"))
        }
        guard hasTokenizer else {
            throw AIError.fileError(
                underlying: SendableError(
                    localizedDescription: "Model directory at path \(path.path) is missing tokenizer files. " +
                    "Please ensure the model is fully downloaded."
                )
            )
        }
    }

    /// Converts an MLXArray to PNG data.
    ///
    /// The array is expected to be in RGB format with shape [height, width, 3]
    /// and values in the range [0.0, 1.0] (normalized).
    ///
    /// - Parameters:
    ///   - array: The MLX array containing normalized image data.
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    ///
    /// - Returns: PNG-encoded image data.
    ///
    /// - Throws: `AIError.generationFailed` if conversion fails.
    private func convertToPNG(_ array: MLXArray, width: Int, height: Int) throws -> Data {
        // Convert from [0.0, 1.0] to [0, 255] and extract as UInt8 data
        let scaledArray = array * 255.0
        let uint8Array = scaledArray.asType(UInt8.self)
        eval(uint8Array)

        // Get raw data from MLXArray
        // The array should be in [height, width, 3] format for RGB
        let mlxData = uint8Array.asData()
        let data = mlxData.data

        // Create CGImage from raw bytes
        guard let provider = CGDataProvider(data: data as CFData) else {
            throw AIError.generationFailed(
                underlying: SendableError(
                    localizedDescription: "Failed to create image data provider"
                )
            )
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: width * 3,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw AIError.generationFailed(
                underlying: SendableError(
                    localizedDescription: "Failed to create CGImage"
                )
            )
        }

        // Convert to PNG data using platform-specific APIs
        #if os(iOS) || os(visionOS)
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else {
            throw AIError.generationFailed(
                underlying: SendableError(
                    localizedDescription: "Failed to encode PNG"
                )
            )
        }
        return pngData

        #elseif os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw AIError.generationFailed(
                underlying: SendableError(
                    localizedDescription: "Failed to encode PNG"
                )
            )
        }
        return pngData

        #else
        throw AIError.unsupportedPlatform("Image encoding not supported on this platform")
        #endif
    }
}
