# SwiftAI Image Generation Enhancement Proposal

## Overview

This document proposes adding **local on-device image generation** to SwiftAI alongside the existing cloud-based HuggingFace implementation. This enables:

- **Cloud Generation**: Via HuggingFace Inference API (existing)
- **Local Generation**: Via MLX StableDiffusion on Apple Silicon (new)

Users can choose based on their needs:
| Use Case | Recommended Provider |
|----------|---------------------|
| No API key available | Local (MLXImageProvider) |
| Privacy-focused / Offline | Local (MLXImageProvider) |
| No storage for models | Cloud (HuggingFaceProvider) |
| Access to latest models | Cloud (HuggingFaceProvider) |

---

## Table of Contents

1. [Package Dependencies](#1-package-dependencies)
2. [New Protocol: ImageGenerator](#2-new-protocol-imagegenerator)
3. [New Provider: MLXImageProvider](#3-new-provider-mlximageprovider)
4. [Model Management](#4-model-management)
5. [HuggingFaceProvider Conformance](#5-huggingfaceprovider-conformance)
6. [Usage Examples](#6-usage-examples)
7. [Device Requirements](#7-device-requirements)
8. [File Summary](#8-file-summary)

---

## 1. Package Dependencies

### File: `Package.swift`

Add the `mlx-swift-examples` package which contains the StableDiffusion library:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftAI",
            targets: ["SwiftAI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.0"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.4.0"),
        // NEW: Add mlx-swift-examples for StableDiffusion
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SwiftAI",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                // NEW: StableDiffusion library
                .product(name: "StableDiffusion", package: "mlx-swift-examples"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SwiftAITests",
            dependencies: ["SwiftAI"]
        ),
    ]
)
```

---

## 2. New Protocol: ImageGenerator

### File: `Sources/SwiftAI/ImageGeneration/ImageGenerator.swift`

A unified protocol for image generation that both cloud and local providers conform to:

```swift
// ImageGenerator.swift
// SwiftAI

import Foundation

/// Protocol for text-to-image generation providers.
///
/// Implementations include:
/// - `HuggingFaceProvider`: Cloud-based generation via HuggingFace Inference API
/// - `MLXImageProvider`: Local on-device generation via MLX StableDiffusion
///
/// ## Usage
///
/// ```swift
/// // Using any ImageGenerator
/// func generateArt(with generator: some ImageGenerator) async throws -> GeneratedImage {
///     return try await generator.generateImage(
///         prompt: "A beautiful sunset",
///         config: .highQuality,
///         onProgress: { progress in
///             print("Progress: \(Int(progress.fractionComplete * 100))%")
///         }
///     )
/// }
/// ```
public protocol ImageGenerator: Sendable {

    /// Generates an image from a text prompt.
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image.
    ///   - negativePrompt: Optional text describing what to avoid in the image.
    ///   - config: Image generation configuration (dimensions, steps, guidance).
    ///   - onProgress: Optional callback for progress updates (local generation only).
    /// - Returns: The generated image with metadata.
    /// - Throws: `AIError` if generation fails.
    func generateImage(
        prompt: String,
        negativePrompt: String?,
        config: ImageGenerationConfig,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)?
    ) async throws -> GeneratedImage

    /// Cancels any ongoing image generation.
    ///
    /// For local generation, this stops the diffusion process at the next step.
    /// For cloud generation, this cancels the network request.
    func cancelGeneration() async

    /// Whether this provider is currently available for generation.
    ///
    /// For cloud providers, checks API token availability.
    /// For local providers, checks device compatibility and loaded model.
    var isAvailable: Bool { get async }
}

// MARK: - Default Implementation

extension ImageGenerator {
    /// Generates an image with default parameters.
    public func generateImage(
        prompt: String,
        config: ImageGenerationConfig = .default
    ) async throws -> GeneratedImage {
        try await generateImage(
            prompt: prompt,
            negativePrompt: nil,
            config: config,
            onProgress: nil
        )
    }

    /// Generates an image with progress tracking.
    public func generateImage(
        prompt: String,
        config: ImageGenerationConfig = .default,
        onProgress: @escaping @Sendable (ImageGenerationProgress) -> Void
    ) async throws -> GeneratedImage {
        try await generateImage(
            prompt: prompt,
            negativePrompt: nil,
            config: config,
            onProgress: onProgress
        )
    }
}
```

### File: `Sources/SwiftAI/ImageGeneration/ImageGenerationProgress.swift`

```swift
// ImageGenerationProgress.swift
// SwiftAI

import Foundation

/// Progress information during image generation.
///
/// Local diffusion models report step-by-step progress. Cloud providers
/// may not provide granular progress updates.
///
/// ## Usage
///
/// ```swift
/// let image = try await provider.generateImage(
///     prompt: "A mountain landscape",
///     onProgress: { progress in
///         print("Step \(progress.currentStep)/\(progress.totalSteps)")
///         print("ETA: \(progress.formattedETA)")
///         updateProgressBar(progress.fractionComplete)
///     }
/// )
/// ```
public struct ImageGenerationProgress: Sendable, Equatable {

    /// The current step in the diffusion process.
    public let currentStep: Int

    /// Total number of steps for this generation.
    public let totalSteps: Int

    /// Time elapsed since generation started.
    public let elapsedTime: TimeInterval

    /// Estimated time remaining (calculated from elapsed time and progress).
    public let estimatedTimeRemaining: TimeInterval?

    /// Fraction of generation complete (0.0 to 1.0).
    public var fractionComplete: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    /// Percentage complete (0 to 100).
    public var percentComplete: Int {
        Int(fractionComplete * 100)
    }

    /// Formatted ETA string (e.g., "~5s remaining").
    public var formattedETA: String {
        guard let eta = estimatedTimeRemaining, eta > 0 else {
            return "Calculating..."
        }
        if eta < 60 {
            return "~\(Int(eta))s remaining"
        } else {
            return "~\(Int(eta / 60))m \(Int(eta.truncatingRemainder(dividingBy: 60)))s remaining"
        }
    }

    /// Creates a new progress instance.
    public init(
        currentStep: Int,
        totalSteps: Int,
        elapsedTime: TimeInterval,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.elapsedTime = elapsedTime

        // Calculate ETA if not provided
        if let eta = estimatedTimeRemaining {
            self.estimatedTimeRemaining = eta
        } else if currentStep > 0 {
            let avgTimePerStep = elapsedTime / Double(currentStep)
            self.estimatedTimeRemaining = avgTimePerStep * Double(totalSteps - currentStep)
        } else {
            self.estimatedTimeRemaining = nil
        }
    }
}
```

---

## 3. New Provider: MLXImageProvider

### File: `Sources/SwiftAI/Providers/MLX/MLXImageProvider.swift`

```swift
// MLXImageProvider.swift
// SwiftAI

import Foundation
import MLX
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
/// try await provider.loadModel(
///     from: modelPath,
///     variant: .sdxlTurbo
/// )
///
/// // Generate with progress
/// let image = try await provider.generateImage(
///     prompt: "A cat wearing a top hat, oil painting",
///     config: .default,
///     onProgress: { progress in
///         print("Step \(progress.currentStep)/\(progress.totalSteps)")
///     }
/// )
///
/// // Display or save
/// if let uiImage = image.uiImage {
///     // Use the image
/// }
/// try image.save(to: outputURL)
/// ```
///
/// ## Supported Models
///
/// | Model | Size | Steps | Quality |
/// |-------|------|-------|---------|
/// | SDXL Turbo | ~6.5GB | 4 | Excellent |
/// | SD 1.5 (4-bit) | ~2GB | 20 | Good |
/// | Flux Schnell (4-bit) | ~4GB | 4 | Very Good |
public actor MLXImageProvider: ImageGenerator {

    // MARK: - Properties

    /// The loaded model container.
    private var modelContainer: ModelContainer<TextToImageGenerator>?

    /// Currently loaded model identifier.
    private var currentModelId: String?

    /// Current model variant.
    private var currentVariant: DiffusionVariant?

    /// Cancellation flag.
    private var isCancelled = false

    /// Minimum memory required (6GB).
    private let minimumMemoryRequired: UInt64 = 6 * 1024 * 1024 * 1024

    // MARK: - Initialization

    /// Creates a new MLX image provider.
    public init() {}

    // MARK: - ImageGenerator Conformance

    /// Whether local generation is available.
    ///
    /// Returns `true` if:
    /// - Device has Apple Silicon (arm64)
    /// - Device has at least 6GB RAM
    /// - A model is loaded
    public var isAvailable: Bool {
        get async {
            #if arch(arm64)
            let hasMemory = ProcessInfo.processInfo.physicalMemory >= minimumMemoryRequired
            let hasModel = modelContainer != nil
            return hasMemory && hasModel
            #else
            return false
            #endif
        }
    }

    /// Generates an image from a text prompt using the loaded diffusion model.
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image.
    ///   - negativePrompt: Optional text describing what to avoid.
    ///   - config: Generation configuration.
    ///   - onProgress: Optional progress callback.
    /// - Returns: The generated image.
    /// - Throws: `AIError` if generation fails.
    public func generateImage(
        prompt: String,
        negativePrompt: String?,
        config: ImageGenerationConfig,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)?
    ) async throws -> GeneratedImage {

        // Validate device
        #if !arch(arm64)
        throw AIError.unsupportedPlatform("MLX image generation requires Apple Silicon")
        #endif

        // Validate memory
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        guard availableMemory >= minimumMemoryRequired else {
            throw AIError.insufficientResources(
                "Requires 6GB+ RAM, device has \(availableMemory / 1_000_000_000)GB"
            )
        }

        // Validate model is loaded
        guard let container = modelContainer else {
            throw AIError.modelNotLoaded("No diffusion model loaded. Call loadModel() first.")
        }

        // Reset state
        isCancelled = false
        let startTime = Date()

        // Configure memory limits
        configureMemoryLimits()

        // Determine generation parameters
        let steps = config.steps ?? currentVariant?.defaultSteps ?? 20
        let guidance = config.guidanceScale ?? 7.5

        // Generate using two-stage pattern for memory efficiency
        let imageData = try await container.performTwoStage { generator in
            // Stage 1: Generate latents
            try await generator.ensureLoaded()

            let parameters = EvaluateParameters(
                prompt: prompt,
                negativePrompt: negativePrompt ?? "",
                seed: UInt64.random(in: 0...UInt64.max),
                steps: steps,
                guidanceScale: guidance
            )

            let latents = generator.generateLatents(parameters: parameters)
            return (generator.detachedDecoder(), latents)

        } second: { [weak self] decoder, latents in
            // Stage 2: Decode latents with progress
            guard let self = self else {
                throw AIError.cancelled
            }

            var lastLatent: MLXArray?
            let totalSteps = latents.underestimatedCount

            for (step, xt) in latents.enumerated() {
                // Check cancellation
                if await self.isCancelled {
                    throw AIError.cancelled
                }

                // Evaluate step
                eval(xt)
                lastLatent = xt

                // Report progress
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = ImageGenerationProgress(
                    currentStep: step + 1,
                    totalSteps: totalSteps,
                    elapsedTime: elapsed
                )
                onProgress?(progress)
            }

            // Decode final latent to image
            guard let finalLatent = lastLatent else {
                throw AIError.generationFailed("No latent generated")
            }

            var raster = decoder(finalLatent[0])
            raster = (raster * 255).asType(.uint8).squeezed()
            eval(raster)

            return raster
        }

        // Convert MLXArray to Data
        let pngData = try mlxArrayToPNGData(imageData, config: config)

        return GeneratedImage(data: pngData, format: .png)
    }

    /// Cancels ongoing generation.
    public func cancelGeneration() async {
        isCancelled = true
    }

    // MARK: - Model Management

    /// Loads a diffusion model from a local directory.
    ///
    /// The directory should contain model weights downloaded from HuggingFace.
    ///
    /// - Parameters:
    ///   - path: Path to the model directory.
    ///   - variant: The type of diffusion model.
    /// - Throws: `AIError` if model cannot be loaded.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let modelPath = URL.documentsDirectory
    ///     .appending(path: "models/sdxl-turbo")
    ///
    /// try await provider.loadModel(
    ///     from: modelPath,
    ///     variant: .sdxlTurbo
    /// )
    /// ```
    public func loadModel(from path: URL, variant: DiffusionVariant) async throws {
        // Unload existing model
        await unloadModel()

        // Get configuration for variant
        let configuration: StableDiffusionConfiguration = switch variant {
        case .sdxlTurbo:
            .presetSDXLTurbo
        case .sd15:
            .presetSD15
        case .flux:
            .presetFlux
        }

        // Load configuration
        let loadConfig = LoadConfiguration(modelDirectory: path)

        // Create model container
        do {
            modelContainer = try await ModelContainer<TextToImageGenerator>
                .createTextToImageGenerator(
                    configuration: configuration,
                    loadConfiguration: loadConfig
                )
        } catch {
            throw AIError.modelLoadFailed(underlying: error)
        }

        // Configure memory conservation
        let shouldConserve = ProcessInfo.processInfo.physicalMemory <= 8 * 1024 * 1024 * 1024
        await modelContainer?.setConserveMemory(shouldConserve)

        currentModelId = path.lastPathComponent
        currentVariant = variant
    }

    /// Unloads the current model to free memory.
    public func unloadModel() async {
        modelContainer = nil
        currentModelId = nil
        currentVariant = nil
    }

    /// The currently loaded model identifier.
    public var loadedModelId: String? {
        currentModelId
    }

    /// The currently loaded model variant.
    public var loadedVariant: DiffusionVariant? {
        currentVariant
    }

    // MARK: - Private Helpers

    /// Configures GPU memory limits based on device capabilities.
    private func configureMemoryLimits() {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        if physicalMemory <= 8 * 1024 * 1024 * 1024 {
            // Low memory device (≤8GB)
            GPU.set(cacheLimit: 1 * 1024 * 1024)           // 1MB cache
            GPU.set(memoryLimit: 3 * 1024 * 1024 * 1024)   // 3GB limit
        } else {
            // High memory device (>8GB)
            GPU.set(cacheLimit: 256 * 1024 * 1024)         // 256MB cache
            // No memory limit for high-memory devices
        }
    }

    /// Converts MLXArray raster data to PNG Data.
    private func mlxArrayToPNGData(_ array: MLXArray, config: ImageGenerationConfig) throws -> Data {
        let width = config.width ?? 512
        let height = config.height ?? 512

        // Get raw bytes
        let rawData = array.asData(noCopy: true)

        // Create CGImage
        guard let provider = CGDataProvider(data: rawData as CFData) else {
            throw AIError.generationFailed("Failed to create image data provider")
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else {
            throw AIError.generationFailed("Failed to create CGImage")
        }

        // Convert to PNG data
        #if os(iOS) || os(visionOS)
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else {
            throw AIError.generationFailed("Failed to encode PNG")
        }
        return pngData
        #elseif os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AIError.generationFailed("Failed to encode PNG")
        }
        return pngData
        #else
        throw AIError.unsupportedPlatform("Image encoding not supported on this platform")
        #endif
    }
}
```

### File: `Sources/SwiftAI/Providers/MLX/DiffusionVariant.swift`

```swift
// DiffusionVariant.swift
// SwiftAI

import Foundation

/// Supported diffusion model variants for local image generation.
public enum DiffusionVariant: String, Sendable, CaseIterable, Codable {

    /// SDXL Turbo - Fast, high-quality 1024x1024 images.
    ///
    /// - Size: ~6.5GB
    /// - Steps: 4 (very fast)
    /// - Quality: Excellent
    case sdxlTurbo = "sdxl-turbo"

    /// Stable Diffusion 1.5 (4-bit quantized).
    ///
    /// - Size: ~2GB
    /// - Steps: 20
    /// - Quality: Good
    case sd15 = "sd-1.5"

    /// Flux Schnell (4-bit quantized).
    ///
    /// - Size: ~4GB
    /// - Steps: 4
    /// - Quality: Very Good
    case flux = "flux"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .sdxlTurbo: return "SDXL Turbo"
        case .sd15: return "Stable Diffusion 1.5"
        case .flux: return "Flux Schnell"
        }
    }

    /// Default number of inference steps.
    public var defaultSteps: Int {
        switch self {
        case .sdxlTurbo: return 4
        case .sd15: return 20
        case .flux: return 4
        }
    }

    /// Approximate model size in GB.
    public var sizeGB: Double {
        switch self {
        case .sdxlTurbo: return 6.5
        case .sd15: return 2.0
        case .flux: return 4.0
        }
    }

    /// Recommended output resolution.
    public var defaultResolution: (width: Int, height: Int) {
        switch self {
        case .sdxlTurbo: return (1024, 1024)
        case .sd15: return (512, 512)
        case .flux: return (1024, 1024)
        }
    }
}
```

---

## 4. Model Management

### File: `Sources/SwiftAI/ImageGeneration/DiffusionModelRegistry.swift`

```swift
// DiffusionModelRegistry.swift
// SwiftAI

import Foundation

/// Registry for managing diffusion model information and downloads.
///
/// Provides a catalog of available models and tracks which models
/// have been downloaded locally.
///
/// ## Usage
///
/// ```swift
/// let registry = DiffusionModelRegistry.shared
///
/// // List available models
/// for model in DiffusionModelRegistry.availableModels {
///     print("\(model.name): \(model.sizeGB)GB")
/// }
///
/// // Check if downloaded
/// if registry.isDownloaded("mlx-community/sdxl-turbo") {
///     let path = registry.localPath(for: "mlx-community/sdxl-turbo")
/// }
/// ```
public actor DiffusionModelRegistry {

    // MARK: - Singleton

    /// Shared registry instance.
    public static let shared = DiffusionModelRegistry()

    // MARK: - Available Models

    /// Catalog of available diffusion models.
    public static let availableModels: [DiffusionModelInfo] = [
        DiffusionModelInfo(
            id: "mlx-community/sdxl-turbo",
            name: "SDXL Turbo",
            variant: .sdxlTurbo,
            sizeGB: 6.5,
            description: "Fast, high-quality 1024×1024 images in just 4 steps",
            huggingFaceURL: URL(string: "https://huggingface.co/mlx-community/sdxl-turbo")!
        ),
        DiffusionModelInfo(
            id: "mlx-community/stable-diffusion-v1-5-4bit",
            name: "Stable Diffusion 1.5 (4-bit)",
            variant: .sd15,
            sizeGB: 2.0,
            description: "Classic SD 1.5, quantized for efficiency",
            huggingFaceURL: URL(string: "https://huggingface.co/mlx-community/stable-diffusion-v1-5-4bit")!
        ),
        DiffusionModelInfo(
            id: "mlx-community/flux-schnell-4bit",
            name: "Flux Schnell (4-bit)",
            variant: .flux,
            sizeGB: 4.0,
            description: "Fast Flux variant, 4 steps for quick generation",
            huggingFaceURL: URL(string: "https://huggingface.co/mlx-community/flux-schnell-4bit")!
        )
    ]

    // MARK: - Properties

    /// Downloaded models tracked by this registry.
    private var downloadedModels: [String: DownloadedDiffusionModel] = [:]

    /// UserDefaults key for persistence.
    private let storageKey = "swiftai.diffusion.downloaded"

    // MARK: - Initialization

    private init() {
        loadFromStorage()
    }

    // MARK: - Query Methods

    /// Checks if a model is downloaded.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: `true` if the model is downloaded locally.
    public func isDownloaded(_ modelId: String) -> Bool {
        downloadedModels[modelId] != nil
    }

    /// Gets the local path for a downloaded model.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: Local file URL, or `nil` if not downloaded.
    public func localPath(for modelId: String) -> URL? {
        downloadedModels[modelId]?.localPath
    }

    /// Gets information about a downloaded model.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: Downloaded model info, or `nil` if not downloaded.
    public func downloadedModel(for modelId: String) -> DownloadedDiffusionModel? {
        downloadedModels[modelId]
    }

    /// All downloaded models.
    public var allDownloadedModels: [DownloadedDiffusionModel] {
        Array(downloadedModels.values).sorted { $0.downloadedAt > $1.downloadedAt }
    }

    // MARK: - Management Methods

    /// Records a model as downloaded.
    ///
    /// - Parameter model: The downloaded model information.
    public func addDownloaded(_ model: DownloadedDiffusionModel) {
        downloadedModels[model.id] = model
        saveToStorage()
    }

    /// Removes a model from the downloaded list.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Note: This does not delete the files from disk.
    public func removeDownloaded(_ modelId: String) {
        downloadedModels.removeValue(forKey: modelId)
        saveToStorage()
    }

    /// Total size of all downloaded models.
    public var totalDownloadedSize: Int64 {
        downloadedModels.values.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Formatted total size string.
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalDownloadedSize, countStyle: .file)
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let models = try? JSONDecoder().decode([String: DownloadedDiffusionModel].self, from: data) else {
            return
        }
        downloadedModels = models
    }

    private func saveToStorage() {
        guard let data = try? JSONEncoder().encode(downloadedModels) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Model Info Types

/// Information about an available diffusion model.
public struct DiffusionModelInfo: Sendable, Identifiable {

    /// HuggingFace repository ID (e.g., "mlx-community/sdxl-turbo").
    public let id: String

    /// Human-readable model name.
    public let name: String

    /// Model variant type.
    public let variant: DiffusionVariant

    /// Approximate download size in GB.
    public let sizeGB: Double

    /// Brief description of the model.
    public let description: String

    /// URL to the HuggingFace model page.
    public let huggingFaceURL: URL

    /// Formatted size string.
    public var formattedSize: String {
        String(format: "%.1f GB", sizeGB)
    }
}

/// Information about a downloaded diffusion model.
public struct DownloadedDiffusionModel: Sendable, Codable, Identifiable {

    /// HuggingFace repository ID.
    public let id: String

    /// Human-readable model name.
    public let name: String

    /// Model variant type.
    public let variant: DiffusionVariant

    /// Local path to model files.
    public let localPath: URL

    /// When the model was downloaded.
    public let downloadedAt: Date

    /// Size in bytes.
    public let sizeBytes: Int64

    /// Formatted size string.
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    public init(
        id: String,
        name: String,
        variant: DiffusionVariant,
        localPath: URL,
        downloadedAt: Date = Date(),
        sizeBytes: Int64
    ) {
        self.id = id
        self.name = name
        self.variant = variant
        self.localPath = localPath
        self.downloadedAt = downloadedAt
        self.sizeBytes = sizeBytes
    }
}
```

### File: `Sources/SwiftAI/ImageGeneration/DiffusionModelDownloader.swift`

```swift
// DiffusionModelDownloader.swift
// SwiftAI

import Foundation
import Hub

/// Downloads diffusion models from HuggingFace Hub.
///
/// ## Usage
///
/// ```swift
/// let downloader = DiffusionModelDownloader()
///
/// // Download with progress
/// let localPath = try await downloader.download(
///     modelId: "mlx-community/sdxl-turbo",
///     variant: .sdxlTurbo
/// ) { progress in
///     print("Downloaded: \(Int(progress.fractionCompleted * 100))%")
/// }
/// ```
public actor DiffusionModelDownloader {

    // MARK: - Properties

    private let hubApi = HubApi()
    private var activeDownloads: [String: Task<URL, Error>] = [:]
    private let registry = DiffusionModelRegistry.shared

    // MARK: - Initialization

    public init() {}

    // MARK: - Download

    /// Downloads a diffusion model from HuggingFace.
    ///
    /// - Parameters:
    ///   - modelId: HuggingFace repository ID (e.g., "mlx-community/sdxl-turbo").
    ///   - variant: The diffusion model variant.
    ///   - progressHandler: Optional callback for download progress.
    /// - Returns: Local URL where the model was saved.
    /// - Throws: `AIError` if download fails.
    public func download(
        modelId: String,
        variant: DiffusionVariant,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> URL {

        // Check if already downloading
        if let existingTask = activeDownloads[modelId] {
            return try await existingTask.value
        }

        // Check if already downloaded
        if let existingPath = await registry.localPath(for: modelId) {
            return existingPath
        }

        // Create download task
        let task = Task<URL, Error> {
            let localURL = try await hubApi.snapshot(
                from: modelId,
                matching: ["*.safetensors", "*.json", "tokenizer*", "*.txt", "*.model"],
                progressHandler: { progress in
                    progressHandler?(progress)
                }
            )

            // Calculate size
            let size = try FileManager.default
                .allocatedSizeOfDirectory(at: localURL)

            // Register as downloaded
            let downloaded = DownloadedDiffusionModel(
                id: modelId,
                name: variant.displayName,
                variant: variant,
                localPath: localURL,
                sizeBytes: size
            )
            await registry.addDownloaded(downloaded)

            return localURL
        }

        activeDownloads[modelId] = task

        do {
            let result = try await task.value
            activeDownloads.removeValue(forKey: modelId)
            return result
        } catch {
            activeDownloads.removeValue(forKey: modelId)
            throw AIError.downloadFailed(underlying: error)
        }
    }

    /// Cancels an active download.
    ///
    /// - Parameter modelId: The model ID to cancel.
    public func cancelDownload(modelId: String) {
        activeDownloads[modelId]?.cancel()
        activeDownloads.removeValue(forKey: modelId)
    }

    /// Deletes a downloaded model.
    ///
    /// - Parameter modelId: The model ID to delete.
    /// - Throws: Error if file deletion fails.
    public func deleteModel(modelId: String) async throws {
        guard let path = await registry.localPath(for: modelId) else {
            return
        }

        try FileManager.default.removeItem(at: path)
        await registry.removeDownloaded(modelId)
    }
}

// MARK: - FileManager Extension

extension FileManager {
    /// Calculates the allocated size of a directory.
    func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        var size: Int64 = 0
        let enumerator = self.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if resourceValues.isDirectory == false {
                size += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return size
    }
}
```

---

## 5. HuggingFaceProvider Conformance

### File: Update `Sources/SwiftAI/Providers/HuggingFace/HuggingFaceProvider.swift`

Add conformance to `ImageGenerator` protocol:

```swift
// Add this extension to HuggingFaceProvider.swift

// MARK: - ImageGenerator Conformance

extension HuggingFaceProvider: ImageGenerator {

    /// Generates an image using HuggingFace's cloud API.
    ///
    /// This is a convenience wrapper around `textToImage()` that conforms
    /// to the `ImageGenerator` protocol for unified usage.
    ///
    /// - Note: Cloud generation does not provide step-by-step progress.
    ///   The `onProgress` callback is not used.
    public func generateImage(
        prompt: String,
        negativePrompt: String?,
        config: ImageGenerationConfig,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)?
    ) async throws -> GeneratedImage {
        // Note: negativePrompt not supported by current HF text-to-image API
        // Could be added as a future enhancement

        return try await textToImage(
            prompt,
            model: .huggingFace("stabilityai/stable-diffusion-3"),
            config: config
        )
    }

    /// Generates an image with a specific model.
    ///
    /// - Parameters:
    ///   - prompt: Text description of the image.
    ///   - model: HuggingFace model identifier.
    ///   - config: Generation configuration.
    /// - Returns: The generated image.
    public func generateImage(
        prompt: String,
        model: ModelIdentifier,
        config: ImageGenerationConfig = .default
    ) async throws -> GeneratedImage {
        try await textToImage(prompt, model: model, config: config)
    }
}
```

---

## 6. Usage Examples

### Cloud Generation (Existing)

```swift
import SwiftAI

// Create provider
let provider = HuggingFaceProvider()

// Generate image
let image = try await provider.generateImage(
    prompt: "A sunset over mountains, oil painting style",
    config: .highQuality
)

// Display in SwiftUI
if let swiftUIImage = await image.image {
    swiftUIImage.resizable().scaledToFit()
}

// Save to disk
try image.save(to: URL.documentsDirectory.appending(path: "sunset.png"))
```

### Local Generation (New)

```swift
import SwiftAI

// Create provider
let provider = MLXImageProvider()

// Download model (one-time)
let downloader = DiffusionModelDownloader()
let modelPath = try await downloader.download(
    modelId: "mlx-community/sdxl-turbo",
    variant: .sdxlTurbo
) { progress in
    print("Downloading: \(Int(progress.fractionCompleted * 100))%")
}

// Load model
try await provider.loadModel(from: modelPath, variant: .sdxlTurbo)

// Generate with progress
let image = try await provider.generateImage(
    prompt: "A cat wearing a top hat, digital art",
    config: .default
) { progress in
    print("Step \(progress.currentStep)/\(progress.totalSteps)")
}

// Use the image
if let uiImage = image.uiImage {
    imageView.image = uiImage
}
```

### Protocol-Based Usage

```swift
import SwiftAI

/// Works with any ImageGenerator (cloud or local)
func generateArt(
    using generator: some ImageGenerator,
    prompt: String
) async throws -> GeneratedImage {
    try await generator.generateImage(
        prompt: prompt,
        config: .highQuality,
        onProgress: { progress in
            print("Progress: \(progress.percentComplete)%")
        }
    )
}

// Use with cloud
let cloudImage = try await generateArt(
    using: HuggingFaceProvider(),
    prompt: "A beautiful landscape"
)

// Use with local
let localProvider = MLXImageProvider()
try await localProvider.loadModel(from: modelPath, variant: .sdxlTurbo)
let localImage = try await generateArt(
    using: localProvider,
    prompt: "A beautiful landscape"
)
```

---

## 7. Device Requirements

### Local Generation (MLXImageProvider)

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **Chip** | Apple Silicon (A14+) | M1 Pro or better |
| **RAM** | 6GB | 8GB+ |
| **Storage** | 2GB (SD 1.5) | 7GB (SDXL) |
| **iOS** | 17.0+ | 17.0+ |
| **macOS** | 14.0+ | 14.0+ |

### Cloud Generation (HuggingFaceProvider)

| Requirement | Details |
|-------------|---------|
| **Network** | Active internet connection |
| **API Token** | HuggingFace account + token |
| **Platform** | Any (iOS 17+, macOS 14+) |

---

## 8. File Summary

| File | Action | Purpose |
|------|--------|---------|
| `Package.swift` | **Modify** | Add mlx-swift-examples dependency |
| `ImageGenerator.swift` | **Create** | Protocol for image generation |
| `ImageGenerationProgress.swift` | **Create** | Progress tracking type |
| `MLXImageProvider.swift` | **Create** | Local StableDiffusion provider |
| `DiffusionVariant.swift` | **Create** | Model variant enum |
| `DiffusionModelRegistry.swift` | **Create** | Model tracking |
| `DiffusionModelDownloader.swift` | **Create** | HuggingFace downloads |
| `HuggingFaceProvider.swift` | **Modify** | Add ImageGenerator conformance |

### New Directory Structure

```
Sources/SwiftAI/
├── Core/Types/
│   ├── GeneratedImage.swift         (existing)
│   └── ImageGenerationConfig.swift  (existing)
│
├── ImageGeneration/                  (NEW)
│   ├── ImageGenerator.swift
│   ├── ImageGenerationProgress.swift
│   ├── DiffusionModelRegistry.swift
│   └── DiffusionModelDownloader.swift
│
└── Providers/
    ├── HuggingFace/
    │   └── HuggingFaceProvider.swift (modified)
    │
    └── MLX/
        ├── MLXImageProvider.swift    (NEW)
        └── DiffusionVariant.swift    (NEW)
```

---

## Next Steps

1. **Review this proposal** and provide feedback
2. **Create a branch** in SwiftAI repo for these changes
3. **Implement incrementally**:
   - Phase 1: Package dependency + ImageGenerator protocol
   - Phase 2: MLXImageProvider implementation
   - Phase 3: Model management (Registry + Downloader)
   - Phase 4: Tests and documentation
4. **Release** as SwiftAI v1.2.0 or v2.0.0

---

*Document created: December 2024*
*Target: SwiftAI v1.2.0+*
