// ImageGenerationConfig.swift
// SwiftAI

import Foundation
import os.log

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

    /// Logger for validation warnings.
    private static let logger = Logger(
        subsystem: "com.swiftai.framework",
        category: "ImageGenerationConfig"
    )

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

    // MARK: - DALL-E Properties

    /// DALL-E image size.
    ///
    /// Only used by OpenAI DALL-E models. MLX providers use width/height instead.
    /// Overrides width/height for DALL-E providers.
    public let dalleSize: DALLEImageSize?

    /// DALL-E 3 quality setting.
    ///
    /// Only applicable to DALL-E 3. Ignored for DALL-E 2 and local models.
    public let dalleQuality: DALLEQuality?

    /// DALL-E 3 style setting.
    ///
    /// Only applicable to DALL-E 3. Ignored for DALL-E 2 and local models.
    public let dalleStyle: DALLEStyle?

    /// Creates an image generation configuration.
    ///
    /// - Parameters:
    ///   - width: Image width in pixels (nil for model default).
    ///   - height: Image height in pixels (nil for model default).
    ///   - steps: Number of inference steps (nil for model default).
    ///   - guidanceScale: Prompt guidance scale (nil for model default).
    ///   - dalleSize: DALL-E image size (nil for default).
    ///   - dalleQuality: DALL-E 3 quality setting (nil for default).
    ///   - dalleStyle: DALL-E 3 style setting (nil for default).
    public init(
        width: Int? = nil,
        height: Int? = nil,
        steps: Int? = nil,
        guidanceScale: Float? = nil,
        dalleSize: DALLEImageSize? = nil,
        dalleQuality: DALLEQuality? = nil,
        dalleStyle: DALLEStyle? = nil
    ) {
        self.width = width
        self.height = height
        self.steps = steps
        self.guidanceScale = guidanceScale
        self.dalleSize = dalleSize
        self.dalleQuality = dalleQuality
        self.dalleStyle = dalleStyle
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

    // MARK: - DALL-E Presets

    /// DALL-E 3 high quality preset.
    ///
    /// Uses HD quality with vivid style for detailed, dramatic images.
    /// Best for final output and professional use.
    public static let dalleHD = ImageGenerationConfig(
        dalleSize: .large1024,
        dalleQuality: .hd,
        dalleStyle: .vivid
    )

    /// DALL-E 3 natural style preset.
    ///
    /// Uses standard quality with natural style for photorealistic images.
    /// Best for product photos, documentation, and realistic scenes.
    public static let dalleNatural = ImageGenerationConfig(
        dalleSize: .large1024,
        dalleQuality: .standard,
        dalleStyle: .natural
    )

    /// DALL-E 3 landscape preset.
    ///
    /// Wide format (1792×1024) suitable for landscapes, scenes, and horizontal compositions.
    public static let dalleLandscape = ImageGenerationConfig(
        dalleSize: .landscape1792x1024
    )

    /// DALL-E 3 portrait preset.
    ///
    /// Tall format (1024×1792) suitable for portraits and vertical compositions.
    public static let dallePortrait = ImageGenerationConfig(
        dalleSize: .portrait1024x1792
    )

    // MARK: - Fluent Builders

    /// Sets the image width.
    ///
    /// - Parameter value: Width in pixels (must be divisible by 8 and greater than 0).
    /// - Returns: A new configuration with the updated width.
    /// - Warning: If the value is not divisible by 8, a runtime warning is printed.
    ///   Most diffusion models require dimensions divisible by 8.
    public func width(_ value: Int) -> ImageGenerationConfig {
        validateDimension(value, name: "width")
        return ImageGenerationConfig(
            width: value,
            height: self.height,
            steps: self.steps,
            guidanceScale: self.guidanceScale,
            dalleSize: self.dalleSize,
            dalleQuality: self.dalleQuality,
            dalleStyle: self.dalleStyle
        )
    }

    /// Sets the image height.
    ///
    /// - Parameter value: Height in pixels (must be divisible by 8 and greater than 0).
    /// - Returns: A new configuration with the updated height.
    /// - Warning: If the value is not divisible by 8, a runtime warning is printed.
    ///   Most diffusion models require dimensions divisible by 8.
    public func height(_ value: Int) -> ImageGenerationConfig {
        validateDimension(value, name: "height")
        return ImageGenerationConfig(
            width: self.width,
            height: value,
            steps: self.steps,
            guidanceScale: self.guidanceScale,
            dalleSize: self.dalleSize,
            dalleQuality: self.dalleQuality,
            dalleStyle: self.dalleStyle
        )
    }

    /// Sets the image dimensions.
    ///
    /// - Parameters:
    ///   - width: Width in pixels (must be divisible by 8 and greater than 0).
    ///   - height: Height in pixels (must be divisible by 8 and greater than 0).
    /// - Returns: A new configuration with the updated dimensions.
    /// - Warning: If values are not divisible by 8, runtime warnings are printed.
    ///   Most diffusion models require dimensions divisible by 8.
    public func size(width: Int, height: Int) -> ImageGenerationConfig {
        validateDimension(width, name: "width")
        validateDimension(height, name: "height")
        return ImageGenerationConfig(
            width: width,
            height: height,
            steps: self.steps,
            guidanceScale: self.guidanceScale,
            dalleSize: self.dalleSize,
            dalleQuality: self.dalleQuality,
            dalleStyle: self.dalleStyle
        )
    }

    /// Sets the number of inference steps.
    ///
    /// Higher values produce more detailed images but take longer.
    ///
    /// - Parameter value: Number of steps (must be between 1 and 150, typically 20-50).
    /// - Returns: A new configuration with the updated steps.
    /// - Warning: If the value is outside the recommended range, a runtime warning is printed.
    public func steps(_ value: Int) -> ImageGenerationConfig {
        validateSteps(value)
        return ImageGenerationConfig(
            width: self.width,
            height: self.height,
            steps: value,
            guidanceScale: self.guidanceScale,
            dalleSize: self.dalleSize,
            dalleQuality: self.dalleQuality,
            dalleStyle: self.dalleStyle
        )
    }

    /// Sets the guidance scale.
    ///
    /// Controls how closely the model follows the text prompt.
    /// Higher values make the model follow the prompt more literally.
    ///
    /// - Parameter value: Guidance scale (must be between 0.0 and 30.0, typically 5.0-15.0).
    /// - Returns: A new configuration with the updated guidance scale.
    /// - Warning: If the value is outside the recommended range, a runtime warning is printed.
    public func guidanceScale(_ value: Float) -> ImageGenerationConfig {
        validateGuidanceScale(value)
        return ImageGenerationConfig(
            width: self.width,
            height: self.height,
            steps: self.steps,
            guidanceScale: value,
            dalleSize: self.dalleSize,
            dalleQuality: self.dalleQuality,
            dalleStyle: self.dalleStyle
        )
    }

    // MARK: - DALL-E Fluent Builders

    /// Sets the DALL-E image size.
    ///
    /// - Parameter size: The image size for DALL-E generation.
    /// - Returns: A new configuration with the updated size.
    /// - Note: Overrides width/height for DALL-E providers.
    public func dalleSize(_ size: DALLEImageSize) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: self.width,
            height: self.height,
            steps: self.steps,
            guidanceScale: self.guidanceScale,
            dalleSize: size,
            dalleQuality: self.dalleQuality,
            dalleStyle: self.dalleStyle
        )
    }

    /// Sets the DALL-E 3 quality.
    ///
    /// - Parameter quality: The quality level for DALL-E 3 generation.
    /// - Returns: A new configuration with the updated quality.
    /// - Note: Only applicable to DALL-E 3. Ignored for DALL-E 2 and local models.
    public func dalleQuality(_ quality: DALLEQuality) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: self.width,
            height: self.height,
            steps: self.steps,
            guidanceScale: self.guidanceScale,
            dalleSize: self.dalleSize,
            dalleQuality: quality,
            dalleStyle: self.dalleStyle
        )
    }

    /// Sets the DALL-E 3 style.
    ///
    /// - Parameter style: The style for DALL-E 3 generation.
    /// - Returns: A new configuration with the updated style.
    /// - Note: Only applicable to DALL-E 3. Ignored for DALL-E 2 and local models.
    public func dalleStyle(_ style: DALLEStyle) -> ImageGenerationConfig {
        ImageGenerationConfig(
            width: self.width,
            height: self.height,
            steps: self.steps,
            guidanceScale: self.guidanceScale,
            dalleSize: self.dalleSize,
            dalleQuality: self.dalleQuality,
            dalleStyle: style
        )
    }

    // MARK: - Internal

    /// Whether any parameters are set (non-nil).
    internal var hasParameters: Bool {
        width != nil || height != nil || steps != nil || guidanceScale != nil ||
        dalleSize != nil || dalleQuality != nil || dalleStyle != nil
    }

    // MARK: - Validation

    /// Validates image dimension (width/height).
    private func validateDimension(_ value: Int, name: String) {
        if value <= 0 {
            Self.logger.warning("ImageGenerationConfig: \(name) must be greater than 0 (got \(value))")
        } else if value % 8 != 0 {
            // Note: OSLog requires a single string literal, can't use + concatenation
            Self.logger.warning(
                "ImageGenerationConfig: \(name) should be divisible by 8 (got \(value))"
            )
        }
    }

    /// Validates inference steps.
    private func validateSteps(_ value: Int) {
        if value < 1 {
            Self.logger.warning("ImageGenerationConfig: steps must be at least 1 (got \(value))")
        } else if value > 150 {
            Self.logger.warning("ImageGenerationConfig: steps above 150 may be excessive and slow (got \(value))")
        }
    }

    /// Validates guidance scale.
    private func validateGuidanceScale(_ value: Float) {
        if value < 0.0 {
            Self.logger.warning(
                "ImageGenerationConfig: guidanceScale must be non-negative (got \(value))"
            )
        } else if value > 30.0 {
            Self.logger.warning(
                "ImageGenerationConfig: guidanceScale above 30.0 may produce poor results (got \(value))"
            )
        }
    }
}
