// ImageGenerator.swift
// SwiftAI
//
// Protocol for generating images from text prompts.

import Foundation

// MARK: - ImageGenerator Protocol

/// A protocol that defines image generation capabilities for AI providers.
///
/// Conforming types can generate images from text prompts using diffusion models
/// or other text-to-image architectures. This protocol supports both cloud-based
/// and local on-device image generation.
///
/// ## Overview
///
/// The `ImageGenerator` protocol provides a unified interface for text-to-image
/// generation across different AI providers (HuggingFace cloud API, MLX local models).
/// It supports customizable generation parameters, negative prompts for guiding
/// what to avoid, and optional progress callbacks for local generation.
///
/// ## Usage
///
/// ### Simple Image Generation
///
/// ```swift
/// let provider = HuggingFaceProvider(apiKey: "hf_...")
/// let image = try await provider.generateImage(
///     prompt: "A serene Japanese garden at sunset"
/// )
///
/// // Display in SwiftUI
/// image.image
///
/// // Save to disk
/// try image.save(to: URL.documentsDirectory.appending(path: "garden.png"))
/// ```
///
/// ### Generation with Configuration
///
/// ```swift
/// let provider = MLXImageProvider()
/// let image = try await provider.generateImage(
///     prompt: "A cyberpunk cityscape with neon lights",
///     config: .highQuality.size(width: 1024, height: 768)
/// )
/// ```
///
/// ### Using Negative Prompts
///
/// Negative prompts help guide the model away from unwanted elements:
///
/// ```swift
/// let image = try await provider.generateImage(
///     prompt: "A professional portrait photograph",
///     negativePrompt: "blurry, low quality, distorted, cartoon",
///     config: .highQuality
/// )
/// ```
///
/// ### Progress Tracking (Local Models)
///
/// For local generation with MLX, track progress through the diffusion steps:
///
/// ```swift
/// let provider = MLXImageProvider()
/// let image = try await provider.generateImage(
///     prompt: "An oil painting of a mountain landscape",
///     config: .highQuality
/// ) { progress in
///     await MainActor.run {
///         progressView.progress = progress.fractionComplete
///         statusLabel.text = "Step \(progress.currentStep)/\(progress.totalSteps)"
///     }
/// }
/// ```
///
/// ### Cancellation
///
/// Long-running image generation can be cancelled:
///
/// ```swift
/// let task = Task {
///     try await provider.generateImage(
///         prompt: "A detailed fantasy map",
///         config: .highQuality
///     )
/// }
///
/// // Later, cancel if needed
/// task.cancel()
/// // Or use the explicit method
/// await provider.cancelGeneration()
/// ```
///
/// ## Thread Safety
///
/// Implementations of this protocol must be `Sendable` and thread-safe.
/// All methods can be called concurrently from different tasks. Progress
/// callbacks must also be `@Sendable` to safely cross isolation boundaries.
///
/// ## Error Handling
///
/// All generation methods throw `AIError` when:
/// - The model is not available or fails to load
/// - Network requests fail (for cloud providers)
/// - The prompt is empty or invalid
/// - Rate limits are exceeded (for cloud providers)
/// - Memory is insufficient for the requested dimensions (for local providers)
/// - The task is cancelled
///
/// ## Provider Implementations
///
/// Different providers offer different capabilities:
///
/// | Provider | Progress | Negative Prompt | Local |
/// |----------|----------|-----------------|-------|
/// | HuggingFace | Limited | Yes | No |
/// | MLXImageProvider | Full | Yes | Yes |
///
/// ## Performance Considerations
///
/// - Image generation is computationally intensive; expect 5-30 seconds per image
/// - Higher step counts produce better quality but take proportionally longer
/// - Larger dimensions require more memory; 1024x1024 needs approximately 8GB RAM
/// - Cloud providers may have rate limits; implement appropriate retry logic
///
/// - SeeAlso: `GeneratedImage`, `ImageGenerationConfig`, `ImageGenerationProgress`
public protocol ImageGenerator: Sendable {

    // MARK: - Required Methods

    /// Generates an image from a text prompt.
    ///
    /// This is the primary image generation method with full control over all
    /// parameters including negative prompts and progress tracking.
    ///
    /// ## Behavior
    ///
    /// 1. Validates the prompt is non-empty
    /// 2. Loads the diffusion model (if not already loaded)
    /// 3. Encodes the text prompt and negative prompt
    /// 4. Runs the denoising/diffusion process
    /// 5. Decodes the latent representation to pixel space
    /// 6. Returns the generated image with metadata
    ///
    /// ## Diffusion Process
    ///
    /// For diffusion models (Stable Diffusion, SDXL, etc.), generation works by:
    /// 1. Starting from random noise
    /// 2. Iteratively denoising guided by the text prompt
    /// 3. Optionally steering away from the negative prompt
    /// 4. Producing a clean image after all steps complete
    ///
    /// The `onProgress` callback is invoked after each denoising step,
    /// allowing real-time progress tracking for local generation.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXImageProvider()
    ///
    /// let image = try await provider.generateImage(
    ///     prompt: "A majestic eagle soaring over snow-capped mountains",
    ///     negativePrompt: "blurry, low resolution, watermark",
    ///     config: ImageGenerationConfig(
    ///         width: 1024,
    ///         height: 768,
    ///         steps: 30,
    ///         guidanceScale: 7.5
    ///     )
    /// ) { progress in
    ///     print("Progress: \(progress.percentComplete)%")
    /// }
    ///
    /// // Save the result
    /// try image.save(to: URL.documentsDirectory.appending(path: "eagle.png"))
    /// ```
    ///
    /// ## Prompt Engineering Tips
    ///
    /// - Be specific and descriptive: "A golden retriever puppy playing in autumn leaves"
    /// - Include style keywords: "digital art", "oil painting", "photograph"
    /// - Specify lighting: "dramatic lighting", "soft natural light", "neon glow"
    /// - Use negative prompts to exclude common artifacts: "blurry, distorted, watermark"
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image. Must be non-empty.
    ///     More detailed prompts generally produce better results.
    ///   - negativePrompt: Optional text describing what to avoid in the image.
    ///     Common values include "blurry", "low quality", "distorted".
    ///     Pass `nil` to use model defaults.
    ///   - config: Image generation configuration controlling dimensions,
    ///     quality, and generation parameters. Use presets like `.default`,
    ///     `.highQuality`, or customize with fluent builders.
    ///   - onProgress: Optional callback invoked during generation with
    ///     progress updates. Must be `@Sendable` for thread safety.
    ///     Cloud providers may not invoke this callback. Pass `nil`
    ///     if progress tracking is not needed.
    ///
    /// - Returns: A `GeneratedImage` containing the image data with methods
    ///   for display, saving, and format conversion.
    ///
    /// - Throws: `AIError` if generation fails. Common errors include:
    ///   - `.invalidInput`: Empty or invalid prompt
    ///   - `.modelNotFound`: Requested model is not available
    ///   - `.modelNotLoaded`: Model needs to be loaded first
    ///   - `.outOfMemory`: Insufficient memory for requested dimensions
    ///   - `.networkError`: Network issues (cloud providers)
    ///   - `.rateLimited`: API rate limit exceeded (cloud providers)
    ///   - `.cancelled`: Generation was cancelled
    func generateImage(
        prompt: String,
        negativePrompt: String?,
        config: ImageGenerationConfig,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)?
    ) async throws -> GeneratedImage

    /// Cancels any ongoing image generation.
    ///
    /// Attempts to immediately stop any in-progress image generation operation.
    /// This is useful when:
    /// - The user wants to abort a long-running generation
    /// - You need to free GPU/memory resources urgently
    /// - The application is moving to the background
    ///
    /// ## Behavior
    ///
    /// Calling this method:
    /// 1. Signals the provider to stop generating
    /// 2. Releases any intermediate computation results
    /// 3. Frees GPU memory used for generation
    /// 4. Returns immediately (non-blocking)
    ///
    /// If no generation is in progress, this method has no effect.
    ///
    /// ## Example
    ///
    /// ```swift
    /// actor ImageController {
    ///     let provider: MLXImageProvider
    ///     var currentTask: Task<GeneratedImage, Error>?
    ///
    ///     func startGeneration(prompt: String) {
    ///         currentTask = Task {
    ///             try await provider.generateImage(prompt: prompt)
    ///         }
    ///     }
    ///
    ///     func stopGeneration() async {
    ///         currentTask?.cancel()
    ///         await provider.cancelGeneration()
    ///         currentTask = nil
    ///     }
    /// }
    /// ```
    ///
    /// - Note: After calling this method, any pending `generateImage()` call
    ///   will throw `AIError.cancelled` or `CancellationError`.
    func cancelGeneration() async

    /// Whether this provider is currently available for generation.
    ///
    /// Returns `true` if the provider is ready to generate images.
    /// Check this property before starting generation to provide
    /// appropriate UI feedback.
    ///
    /// A provider might be unavailable if:
    /// - Required models are not downloaded (local providers)
    /// - The device doesn't meet hardware requirements (local providers)
    /// - Network connectivity is unavailable (cloud providers)
    /// - API credentials are missing or invalid (cloud providers)
    /// - Another generation is already in progress
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXImageProvider()
    ///
    /// if await provider.isAvailable {
    ///     let image = try await provider.generateImage(
    ///         prompt: "A beautiful landscape"
    ///     )
    /// } else {
    ///     print("Image generation is not available")
    /// }
    /// ```
    ///
    /// - Note: This property is `async` because checking availability
    ///   may require querying system state or network resources.
    var isAvailable: Bool { get async }
}

// MARK: - Default Implementations

extension ImageGenerator {

    /// Generates an image from a text prompt with default configuration.
    ///
    /// This is the simplest form of image generation, using the model's
    /// default parameters. Suitable for quick prototyping and testing.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = HuggingFaceProvider(apiKey: "hf_...")
    /// let image = try await provider.generateImage(
    ///     prompt: "A colorful abstract painting"
    /// )
    /// ```
    ///
    /// - Parameter prompt: Text description of the desired image.
    /// - Returns: The generated image.
    /// - Throws: `AIError` if generation fails.
    public func generateImage(
        prompt: String
    ) async throws -> GeneratedImage {
        try await generateImage(
            prompt: prompt,
            negativePrompt: nil,
            config: .default,
            onProgress: nil
        )
    }

    /// Generates an image with configuration but no negative prompt or progress.
    ///
    /// Use this when you need custom dimensions or quality settings
    /// but don't need negative prompts or progress tracking.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXImageProvider()
    /// let image = try await provider.generateImage(
    ///     prompt: "A futuristic city skyline",
    ///     config: .landscape.steps(40)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image.
    ///   - config: Image generation configuration.
    /// - Returns: The generated image.
    /// - Throws: `AIError` if generation fails.
    public func generateImage(
        prompt: String,
        config: ImageGenerationConfig
    ) async throws -> GeneratedImage {
        try await generateImage(
            prompt: prompt,
            negativePrompt: nil,
            config: config,
            onProgress: nil
        )
    }

    /// Generates an image with progress tracking but no negative prompt.
    ///
    /// Use this for local generation when you want to display
    /// a progress indicator to the user.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXImageProvider()
    /// let image = try await provider.generateImage(
    ///     prompt: "A detailed fantasy castle",
    ///     config: .highQuality
    /// ) { progress in
    ///     await MainActor.run {
    ///         self.progressBar.progress = progress.fractionComplete
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image.
    ///   - config: Image generation configuration.
    ///   - onProgress: Callback invoked with progress updates.
    /// - Returns: The generated image.
    /// - Throws: `AIError` if generation fails.
    public func generateImage(
        prompt: String,
        config: ImageGenerationConfig,
        onProgress: @escaping @Sendable (ImageGenerationProgress) -> Void
    ) async throws -> GeneratedImage {
        try await generateImage(
            prompt: prompt,
            negativePrompt: nil,
            config: config,
            onProgress: onProgress
        )
    }

    /// Generates an image with a negative prompt but no progress tracking.
    ///
    /// Use this when you need to exclude certain elements from the
    /// generated image but don't need progress updates.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = HuggingFaceProvider(apiKey: "hf_...")
    /// let image = try await provider.generateImage(
    ///     prompt: "A professional headshot photograph",
    ///     negativePrompt: "cartoon, anime, illustration, painting",
    ///     config: .square1024
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: Text description of the desired image.
    ///   - negativePrompt: Text describing what to avoid.
    ///   - config: Image generation configuration.
    /// - Returns: The generated image.
    /// - Throws: `AIError` if generation fails.
    public func generateImage(
        prompt: String,
        negativePrompt: String,
        config: ImageGenerationConfig
    ) async throws -> GeneratedImage {
        try await generateImage(
            prompt: prompt,
            negativePrompt: negativePrompt,
            config: config,
            onProgress: nil
        )
    }
}

// MARK: - Batch Generation

extension ImageGenerator {

    /// Generates multiple images from an array of prompts.
    ///
    /// Processes prompts sequentially, returning results in the same order.
    /// If any generation fails, the entire batch fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let prompts = [
    ///     "A sunset over the ocean",
    ///     "A snowy mountain peak",
    ///     "A dense tropical forest"
    /// ]
    ///
    /// let images = try await provider.generateImages(
    ///     prompts: prompts,
    ///     config: .default
    /// )
    ///
    /// for (index, image) in images.enumerated() {
    ///     try image.save(to: directory.appending(path: "image_\(index).png"))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prompts: Array of text prompts to generate images from.
    ///   - config: Configuration applied to all generations.
    /// - Returns: Array of generated images in the same order as prompts.
    /// - Throws: `AIError` if any generation fails.
    public func generateImages(
        prompts: [String],
        config: ImageGenerationConfig = .default
    ) async throws -> [GeneratedImage] {
        var results: [GeneratedImage] = []
        results.reserveCapacity(prompts.count)

        for prompt in prompts {
            try Task.checkCancellation()
            let image = try await generateImage(
                prompt: prompt,
                negativePrompt: nil,
                config: config,
                onProgress: nil
            )
            results.append(image)
        }

        return results
    }
}
