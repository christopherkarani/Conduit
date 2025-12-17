// ModelSize.swift
// SwiftAI

import Foundation

/// Model size categories based on RAM requirements.
///
/// Used to categorize models by their memory footprint and match them
/// with device capabilities. Helps users select appropriate models
/// for their hardware.
///
/// ## Size Guidelines
/// | Size | RAM | Example Models |
/// |------|-----|----------------|
/// | tiny | < 500MB | Small embeddings |
/// | small | 500MB - 2GB | Llama 3.2 1B |
/// | medium | 2GB - 8GB | Llama 3.2 3B |
/// | large | 8GB - 32GB | Mistral 7B |
/// | xlarge | > 32GB | Llama 70B |
///
/// ## Usage
/// ```swift
/// // Check if a device can run a model size
/// let availableRAM = ProcessInfo.processInfo.physicalMemory
/// let recommendedSize = ModelSize.forAvailableRAM(Int64(availableRAM))
/// print("Recommended: \(recommendedSize.displayName)")
///
/// // Compare model sizes
/// if ModelSize.small < ModelSize.large {
///     print("Small models require less RAM")
/// }
/// ```
///
/// ## Device Capability Matching
/// The framework uses `ModelSize` to recommend models based on device
/// capabilities. When selecting a model, consider:
/// - Available system RAM (leave headroom for OS and other apps)
/// - Current memory pressure
/// - Concurrent model usage requirements
///
/// - Note: RAM estimates include both model weights and inference overhead.
public enum ModelSize: String, Sendable, CaseIterable, Codable {
    /// Tiny models (< 500MB RAM)
    ///
    /// Suitable for:
    /// - Small embedding models
    /// - Quantized tiny models
    /// - Low-resource devices
    /// - Devices with < 4GB RAM
    case tiny

    /// Small models (500MB - 2GB RAM)
    ///
    /// Suitable for:
    /// - Llama 3.2 1B (quantized)
    /// - Small instruction-tuned models
    /// - Entry-level devices
    /// - Devices with 4-8GB RAM
    case small

    /// Medium models (2GB - 8GB RAM)
    ///
    /// Suitable for:
    /// - Llama 3.2 3B
    /// - Mid-range instruction models
    /// - Standard devices
    /// - Devices with 8-16GB RAM
    case medium

    /// Large models (8GB - 32GB RAM)
    ///
    /// Suitable for:
    /// - Mistral 7B
    /// - Llama 3 8B
    /// - High-end consumer devices
    /// - Devices with 16-32GB RAM
    case large

    /// Extra large models (> 32GB RAM)
    ///
    /// Suitable for:
    /// - Llama 70B
    /// - Large multi-modal models
    /// - Professional workstations
    /// - Devices with 64GB+ RAM
    case xlarge

    /// Approximate RAM required for this model size.
    ///
    /// These are conservative estimates that account for model weights
    /// plus inference overhead (KV cache, activations, etc.).
    ///
    /// - Returns: A `ByteCount` representing the approximate RAM requirement.
    ///
    /// ## Implementation Notes
    /// The values returned are the midpoint of each size range, providing
    /// a reasonable estimate for planning purposes. Actual requirements
    /// vary based on:
    /// - Quantization level (4-bit vs 8-bit vs FP16)
    /// - Context length
    /// - Batch size
    /// - KV cache configuration
    public var approximateRAM: ByteCount {
        switch self {
        case .tiny:
            return .megabytes(512)
        case .small:
            return .gigabytes(2)
        case .medium:
            return .gigabytes(8)
        case .large:
            return .gigabytes(16)
        case .xlarge:
            return .gigabytes(32)
        }
    }

    /// Human-readable description of this model size.
    ///
    /// Includes both the size category name and the RAM range,
    /// suitable for display in UI.
    ///
    /// - Returns: A formatted string like "Small (500MB - 2GB)".
    public var displayName: String {
        switch self {
        case .tiny:
            return "Tiny (< 500MB)"
        case .small:
            return "Small (500MB - 2GB)"
        case .medium:
            return "Medium (2GB - 8GB)"
        case .large:
            return "Large (8GB - 32GB)"
        case .xlarge:
            return "Extra Large (> 32GB)"
        }
    }

    /// Minimum RAM in bytes required for this model size.
    ///
    /// Defines the lower bound of the RAM range for this size category.
    /// Used for device capability matching and comparisons.
    ///
    /// - Returns: The minimum RAM in bytes as an `Int64`.
    public var minimumRAMBytes: Int64 {
        switch self {
        case .tiny:
            return 0
        case .small:
            return 500_000_000  // 500 MB
        case .medium:
            return 2_000_000_000  // 2 GB
        case .large:
            return 8_000_000_000  // 8 GB
        case .xlarge:
            return 32_000_000_000  // 32 GB
        }
    }

    /// Returns the appropriate model size for a given available RAM.
    ///
    /// Automatically selects the largest model size that can safely fit
    /// in the available RAM, leaving 20% headroom for system overhead.
    ///
    /// - Parameter availableRAM: Available RAM in bytes.
    /// - Returns: The largest model size that can fit in the available RAM.
    ///
    /// ## Usage
    /// ```swift
    /// let physicalRAM = Int64(ProcessInfo.processInfo.physicalMemory)
    /// let recommended = ModelSize.forAvailableRAM(physicalRAM)
    /// print("Your device can run \(recommended) models")
    /// ```
    ///
    /// ## Implementation Notes
    /// This method applies a 0.8 multiplier to leave headroom for:
    /// - Operating system memory requirements
    /// - Other running applications
    /// - Memory fragmentation
    /// - Inference overhead (KV cache, activations)
    ///
    /// On memory-constrained devices, consider using smaller models
    /// than recommended to avoid memory pressure.
    public static func forAvailableRAM(_ availableRAM: Int64) -> ModelSize {
        // Leave some headroom (use 80% of available)
        let usableRAM = Int64(Double(availableRAM) * 0.8)

        if usableRAM >= 32_000_000_000 {
            return .xlarge
        } else if usableRAM >= 8_000_000_000 {
            return .large
        } else if usableRAM >= 2_000_000_000 {
            return .medium
        } else if usableRAM >= 500_000_000 {
            return .small
        } else {
            return .tiny
        }
    }
}

// MARK: - CustomStringConvertible

extension ModelSize: CustomStringConvertible {
    /// A textual representation of this model size.
    ///
    /// Returns the same value as `displayName` for consistent
    /// string formatting.
    public var description: String {
        displayName
    }
}

// MARK: - Comparable

extension ModelSize: Comparable {
    /// Compares two model sizes based on their RAM requirements.
    ///
    /// Allows sorting and filtering model sizes by resource requirements.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side model size.
    ///   - rhs: The right-hand side model size.
    /// - Returns: `true` if `lhs` requires less RAM than `rhs`.
    ///
    /// ## Usage
    /// ```swift
    /// let sizes = ModelSize.allCases.sorted()
    /// // [.tiny, .small, .medium, .large, .xlarge]
    ///
    /// if ModelSize.small < ModelSize.large {
    ///     print("Small models are less demanding")
    /// }
    /// ```
    public static func < (lhs: ModelSize, rhs: ModelSize) -> Bool {
        lhs.minimumRAMBytes < rhs.minimumRAMBytes
    }
}
