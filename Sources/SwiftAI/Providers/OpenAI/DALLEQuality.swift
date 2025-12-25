// DALLEQuality.swift
// SwiftAI
//
// Quality settings for DALL-E 3 image generation.

import Foundation

// MARK: - DALLEQuality

/// Quality setting for DALL-E 3 image generation.
///
/// Controls the level of detail in generated images. Only applicable to DALL-E 3.
/// DALL-E 2 always uses standard quality regardless of this setting.
///
/// ## Pricing Impact
///
/// - **Standard**: $0.04 per 1024×1024 image
/// - **HD**: $0.08 per 1024×1024 image (2x cost for more detail)
///
/// ## Usage
///
/// ```swift
/// let config = ImageGenerationConfig()
///     .dalleQuality(.hd)
/// ```
public enum DALLEQuality: String, Sendable, Hashable, Codable, CaseIterable {

    /// Standard quality - faster generation, lower cost.
    ///
    /// Suitable for most use cases. Provides good detail
    /// at approximately half the cost of HD quality.
    case standard

    /// HD quality - more detail and consistency.
    ///
    /// Produces images with:
    /// - Finer details and textures
    /// - Greater consistency across the image
    /// - Better lighting and shading
    /// - Suitable for professional use
    ///
    /// - Note: Only supported by DALL-E 3. Ignored for DALL-E 2.
    case hd

    // MARK: - Computed Properties

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .hd: return "HD"
        }
    }
}
