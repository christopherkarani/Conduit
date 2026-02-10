// DALLEImageSize.swift
// Conduit
//
// Supported image sizes for DALL-E models.

import Foundation

/// Supported image sizes for DALL-E models.
///
/// DALL-E 2 and DALL-E 3 support different size options.
/// DALL-E 2 supports square images only (256², 512², 1024²).
/// DALL-E 3 supports 1024², and landscape/portrait (1792×1024, 1024×1792).
///
/// ## Usage
///
/// ```swift
/// let config = ImageGenerationConfig()
///     .dalleSize(.landscape1792x1024)
/// ```
public enum DALLEImageSize: String, Sendable, Hashable, Codable, CaseIterable {

    // MARK: - DALL-E 2 Sizes

    /// 256x256 pixels (DALL-E 2 only).
    ///
    /// Small square format, fast generation.
    case small256 = "256x256"

    /// 512x512 pixels (DALL-E 2 only).
    ///
    /// Medium square format.
    case medium512 = "512x512"

    /// 1024x1024 pixels (DALL-E 2 and DALL-E 3).
    ///
    /// Large square format, high quality.
    case large1024 = "1024x1024"

    // MARK: - DALL-E 3 Additional Sizes

    /// 1792x1024 pixels (DALL-E 3 only).
    ///
    /// Wide landscape format.
    case landscape1792x1024 = "1792x1024"

    /// 1024x1792 pixels (DALL-E 3 only).
    ///
    /// Tall portrait format.
    case portrait1024x1792 = "1024x1792"

    // MARK: - Model Compatibility

    /// Whether this size is supported by DALL-E 2.
    ///
    /// DALL-E 2 only supports square formats: 256x256, 512x512, 1024x1024.
    public var supportedByDallE2: Bool {
        switch self {
        case .small256, .medium512, .large1024:
            return true
        case .landscape1792x1024, .portrait1024x1792:
            return false
        }
    }

    /// Whether this size is supported by DALL-E 3.
    ///
    /// DALL-E 3 supports 1024x1024 and non-square formats: 1792x1024, 1024x1792.
    public var supportedByDallE3: Bool {
        switch self {
        case .large1024, .landscape1792x1024, .portrait1024x1792:
            return true
        case .small256, .medium512:
            return false
        }
    }

    // MARK: - Dimensions

    /// The width in pixels.
    public var width: Int {
        switch self {
        case .small256: return 256
        case .medium512: return 512
        case .large1024, .portrait1024x1792: return 1024
        case .landscape1792x1024: return 1792
        }
    }

    /// The height in pixels.
    public var height: Int {
        switch self {
        case .small256: return 256
        case .medium512: return 512
        case .large1024, .landscape1792x1024: return 1024
        case .portrait1024x1792: return 1792
        }
    }

    // MARK: - Display

    /// Human-readable display name.
    ///
    /// Returns the size in "WIDTHxHEIGHT" format.
public var displayName: String {
    rawValue
}
}
