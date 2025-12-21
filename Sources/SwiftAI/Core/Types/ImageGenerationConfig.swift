// ImageGenerationConfig.swift
// SwiftAI

import Foundation

/// Configuration for text-to-image generation.
///
/// Controls image dimensions, quality, and generation parameters for diffusion models.
/// Use presets for common configurations or build custom settings with fluent modifiers.
///
/// ## Usage
///
/// ```swift
/// // Use default settings
/// let result = try await provider.textToImage(
///     "A sunset over mountains",
///     model: .huggingFace("stabilityai/stable-diffusion-3")
/// )
///
/// // Use a preset
/// let result = try await provider.textToImage(
///     "A portrait in oil painting style",
///     model: .huggingFace("stabilityai/stable-diffusion-xl-base-1.0"),
///     config: .highQuality
/// )
///
/// // Customize with fluent builders
/// let result = try await provider.textToImage(
///     "A cat wearing a top hat",
///     model: .huggingFace("stabilityai/stable-diffusion-3"),
///     config: .default.width(1024).height(768).steps(30)
/// )
/// ```
///
/// ## Presets
///
/// | Preset | Description |
/// |--------|-------------|
/// | `.default` | Model defaults (fastest) |
/// | `.highQuality` | 50 steps, guidance 7.5 |
/// | `.fast` | 20 steps (quick previews) |
/// | `.square512` | 512x512 pixels |
/// | `.square1024` | 1024x1024 pixels |
///
/// ## Parameters
///
/// - **Width/Height**: Image dimensions in pixels. Common values: 512, 768, 1024.
///   Must be divisible by 8 for most diffusion models.
/// - **Steps**: Number of denoising iterations (20-50 typical). Higher = better quality, slower.
/// - **Guidance Scale**: How closely to follow the prompt (5.0-15.0 typical).
///   Higher = more literal interpretation, lower = more creative freedom.
public struct ImageGenerationConfig: Sendable, Hashable {

    /// The desired image width in pixels.
    ///
    /// Should be divisible by 8 for most diffusion models.
    /// Common values: 512, 768, 1024.
    public let width: Int?

    /// The desired image height in pixels.
    ///
    /// Should be divisible by 8 for most diffusion models.
    /// Common values: 512, 768, 1024.
    public let height: Int?

    /// The number of inference/denoising steps.
    ///
    /// Higher values produce more detailed images but take longer.
    /// Typical range: 20-50. Default varies by model (usually 25-30).
    public let steps: Int?

    /// Guidance scale for prompt adherence.
    ///
    /// Controls how closely the model follows the text prompt.
    /// - Lower values (5-7): More creative, may deviate from prompt
    /// - Higher values (10-15): More literal, closely follows prompt
    /// - Typical default: 7.5
    public let guidanceScale: Float?

    /// Creates an image generation configuration.
    ///
    /// - Parameters:
    ///   - width: Image width in pixels (nil for model default).
    ///   - height: Image height in pixels (nil for model default).
    ///   - steps: Number of inference steps (nil for model default).
    ///   - guidanceScale: Prompt guidance scale (nil for model default).
    public init(
        width: Int? = nil,
        height: Int? = nil,
        steps: Int? = nil,
        guidanceScale: Float? = nil
    ) {
        self.width = width
        self.height = height
        self.steps = steps
        self.guidanceScale = guidanceScale
    }

    // MARK: - Presets

    /// Default configuration using model defaults.
    ///
    /// Fastest option - lets the model choose optimal parameters.
    public static let `default` = ImageGenerationConfig()

    /// High quality preset with more inference steps.
    ///
    /// Uses 50 steps and guidance scale of 7.5 for detailed, prompt-accurate results.
    /// Takes longer but produces better quality images.
    public static let highQuality = ImageGenerationConfig(steps: 50, guidanceScale: 7.5)

    /// Fast preset with fewer steps for quick previews.
    ///
    /// Uses 20 steps for rapid generation. Good for iteration and testing prompts.
    public static let fast = ImageGenerationConfig(steps: 20)

    /// Square image preset (512x512).
    ///
    /// Standard resolution, fast generation. Good for thumbnails and previews.
    public static let square512 = ImageGenerationConfig(width: 512, height: 512)

    /// Large square image preset (1024x1024).
    ///
    /// High resolution square format. Good for final output and detailed images.
    public static let square1024 = ImageGenerationConfig(width: 1024, height: 1024)

    /// Landscape preset (1024x768).
    ///
    /// Wide format suitable for landscapes, scenes, and horizontal compositions.
    public static let landscape = ImageGenerationConfig(width: 1024, height: 768)

    /// Portrait preset (768x1024).
    ///
    /// Tall format suitable for portraits, characters, and vertical compositions.
    public static let portrait = ImageGenerationConfig(width: 768, height: 1024)

    // MARK: - Fluent Builders

    /// Sets the image width.
    ///
    /// - Parameter value: Width in pixels (should be divisible by 8).
    /// - Returns: A new configuration with the updated width.
    public func width(_ value: Int) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: value,
            height: self.height,
            steps: self.steps,
            guidanceScale: self.guidanceScale
        )
    }

    /// Sets the image height.
    ///
    /// - Parameter value: Height in pixels (should be divisible by 8).
    /// - Returns: A new configuration with the updated height.
    public func height(_ value: Int) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: self.width,
            height: value,
            steps: self.steps,
            guidanceScale: self.guidanceScale
        )
    }

    /// Sets the image dimensions.
    ///
    /// - Parameters:
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    /// - Returns: A new configuration with the updated dimensions.
    public func size(width: Int, height: Int) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: width,
            height: height,
            steps: self.steps,
            guidanceScale: self.guidanceScale
        )
    }

    /// Sets the number of inference steps.
    ///
    /// Higher values produce more detailed images but take longer.
    ///
    /// - Parameter value: Number of steps (typically 20-50).
    /// - Returns: A new configuration with the updated steps.
    public func steps(_ value: Int) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: self.width,
            height: self.height,
            steps: value,
            guidanceScale: self.guidanceScale
        )
    }

    /// Sets the guidance scale.
    ///
    /// Controls how closely the model follows the text prompt.
    /// Higher values make the model follow the prompt more literally.
    ///
    /// - Parameter value: Guidance scale (typically 5.0-15.0).
    /// - Returns: A new configuration with the updated guidance scale.
    public func guidanceScale(_ value: Float) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: self.width,
            height: self.height,
            steps: self.steps,
            guidanceScale: value
        )
    }

    // MARK: - Internal

    /// Whether any parameters are set (non-nil).
    internal var hasParameters: Bool {
        width != nil || height != nil || steps != nil || guidanceScale != nil
    }
}
