// DALLEStyle.swift
// SwiftAI
//
// Style settings for DALL-E 3 image generation.

import Foundation

/// Style setting for DALL-E 3 image generation.
///
/// Controls the artistic style of generated images. Only applicable to DALL-E 3.
/// DALL-E 2 does not support style settings.
///
/// ## Comparison
///
/// - **Vivid**: Hyper-real, dramatic images with enhanced colors and contrast
/// - **Natural**: More subdued, natural-looking images closer to photographs
///
/// ## Usage
///
/// ```swift
/// // Dramatic, artistic style
/// let config = ImageGenerationConfig()
///     .dalleStyle(.vivid)
///
/// // Photorealistic style
/// let config = ImageGenerationConfig()
///     .dalleStyle(.natural)
/// ```
public enum DALLEStyle: String, Sendable, Hashable, Codable, CaseIterable {
    /// Vivid style - hyper-real and dramatic.
    ///
    /// Produces images with:
    /// - Enhanced colors and saturation
    /// - Dramatic lighting and contrast
    /// - Artistic, stylized appearance
    /// - More creative interpretation of prompts
    ///
    /// Best for: Artistic images, illustrations, creative content.
    case vivid

    /// Natural style - realistic and subtle.
    ///
    /// Produces images with:
    /// - Natural color palette
    /// - Balanced lighting
    /// - Photorealistic appearance
    /// - Closer adherence to real-world appearance
    ///
    /// Best for: Product photos, documentation, realistic scenes.
    case natural

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .vivid: return "Vivid"
        case .natural: return "Natural"
        }
    }
}
