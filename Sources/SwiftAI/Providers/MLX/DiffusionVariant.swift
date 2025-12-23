// DiffusionVariant.swift
// SwiftAI

import Foundation

/// Supported diffusion model variants for local image generation.
///
/// Each variant represents a different model architecture with specific
/// characteristics for quality, speed, and memory usage.
///
/// ## Choosing a Variant
///
/// | Variant | Size | Steps | Speed | Quality | Best For |
/// |---------|------|-------|-------|---------|----------|
/// | `.sdxlTurbo` | ~6.5GB | 4 | Fast | Excellent | General use |
/// | `.sd15` | ~2GB | 20 | Slow | Good | Memory-constrained devices |
/// | `.flux` | ~4GB | 4 | Fast | Very Good | Balance of speed/quality |
///
/// ## Usage
///
/// ```swift
/// let provider = MLXImageProvider()
/// try await provider.loadModel(from: modelPath, variant: .sdxlTurbo)
/// ```
public enum DiffusionVariant: String, Sendable, CaseIterable, Codable {

    /// SDXL Turbo - Fast, high-quality 1024×1024 images.
    ///
    /// - Size: ~6.5GB
    /// - Steps: 4 (very fast)
    /// - Quality: Excellent
    /// - Resolution: 1024×1024
    case sdxlTurbo = "sdxl-turbo"

    /// Stable Diffusion 1.5 (4-bit quantized).
    ///
    /// - Size: ~2GB
    /// - Steps: 20
    /// - Quality: Good
    /// - Resolution: 512×512
    case sd15 = "sd-1.5"

    /// Flux Schnell (4-bit quantized).
    ///
    /// - Size: ~4GB
    /// - Steps: 4
    /// - Quality: Very Good
    /// - Resolution: 1024×1024
    case flux = "flux"

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .sdxlTurbo: return "SDXL Turbo"
        case .sd15: return "Stable Diffusion 1.5"
        case .flux: return "Flux Schnell"
        }
    }

    /// Default number of inference steps for this variant.
    ///
    /// Using fewer steps is faster but may reduce quality.
    /// Using more steps may improve quality at the cost of speed.
    public var defaultSteps: Int {
        switch self {
        case .sdxlTurbo: return 4
        case .sd15: return 20
        case .flux: return 4
        }
    }

    /// Approximate model size in gibibytes (1 GiB = 1024^3 bytes).
    public var sizeGiB: Double {
        switch self {
        case .sdxlTurbo: return 6.5
        case .sd15: return 2.0
        case .flux: return 4.0
        }
    }

    /// Approximate model size in bytes.
    public var sizeBytes: Int64 {
        Int64(sizeGiB * 1_073_741_824) // 1 GiB = 1024^3 bytes
    }

    /// Formatted size string (e.g., "6.5 GiB").
    public var formattedSize: String {
        String(format: "%.1f GiB", sizeGiB)
    }

    /// Recommended output resolution for this variant.
    public var defaultResolution: (width: Int, height: Int) {
        switch self {
        case .sdxlTurbo: return (1024, 1024)
        case .sd15: return (512, 512)
        case .flux: return (1024, 1024)
        }
    }

    /// Default guidance scale for this variant.
    ///
    /// Higher values make the model follow the prompt more closely
    /// but may reduce creativity.
    public var defaultGuidanceScale: Double {
        switch self {
        case .sdxlTurbo: return 0.0  // Turbo doesn't use guidance
        case .sd15: return 7.5
        case .flux: return 3.5
        }
    }

    /// Minimum RAM required to load this model.
    public var minimumMemoryGB: Double {
        switch self {
        case .sdxlTurbo: return 8.0
        case .sd15: return 4.0
        case .flux: return 6.0
        }
    }

    /// Brief description of the model.
    public var modelDescription: String {
        switch self {
        case .sdxlTurbo:
            return "Fast, high-quality 1024×1024 images in just 4 steps"
        case .sd15:
            return "Classic SD 1.5, quantized for memory efficiency"
        case .flux:
            return "Fast Flux variant, 4 steps for quick generation"
        }
    }
}

// MARK: - Identifiable

extension DiffusionVariant: Identifiable {
    public var id: String { rawValue }
}

// MARK: - CustomStringConvertible

extension DiffusionVariant: CustomStringConvertible {
    public var description: String {
        "\(displayName) (\(formattedSize), \(defaultSteps) steps)"
    }
}

// MARK: - Deprecated

extension DiffusionVariant {
    /// Approximate model size in gibibytes.
    /// - Note: Renamed to `sizeGiB` for clarity (1 GiB = 1024^3 bytes).
    @available(*, deprecated, renamed: "sizeGiB")
    public var sizeGB: Double { sizeGiB }
}
