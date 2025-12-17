// DeviceCapabilities.swift
// SwiftAI

import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Device hardware capabilities relevant to AI inference.
///
/// Detects and reports device specifications that affect model selection
/// and inference performance, including RAM, chip type, and framework support.
///
/// ## Usage
/// ```swift
/// let capabilities = DeviceCapabilities.current()
/// print("Total RAM: \(capabilities.totalRAM)")
/// print("Supports MLX: \(capabilities.supportsMLX)")
/// print("Recommended size: \(capabilities.recommendedModelSize())")
/// ```
public struct DeviceCapabilities: Sendable, Hashable {

    /// Total system RAM in bytes.
    public let totalRAM: Int64

    /// Currently available RAM in bytes (approximate).
    public let availableRAM: Int64

    /// Chip/CPU type description (e.g., "Apple M2", "Apple A17 Pro").
    public let chipType: String?

    /// Number of Neural Engine cores (if detectable).
    public let neuralEngineCores: Int?

    /// Whether the device supports MLX inference (Apple Silicon).
    public let supportsMLX: Bool

    /// Whether the device supports Apple Foundation Models (iOS 26+).
    public let supportsFoundationModels: Bool

    // MARK: - Initialization

    /// Creates a device capabilities instance.
    public init(
        totalRAM: Int64,
        availableRAM: Int64,
        chipType: String? = nil,
        neuralEngineCores: Int? = nil,
        supportsMLX: Bool,
        supportsFoundationModels: Bool
    ) {
        self.totalRAM = totalRAM
        self.availableRAM = availableRAM
        self.chipType = chipType
        self.neuralEngineCores = neuralEngineCores
        self.supportsMLX = supportsMLX
        self.supportsFoundationModels = supportsFoundationModels
    }

    // MARK: - Current Device Detection

    /// Detects and returns the current device's capabilities.
    ///
    /// This method queries the system for hardware information including:
    /// - Total and available RAM
    /// - Chip type (on Apple platforms)
    /// - Neural Engine cores
    /// - Framework support (MLX, Foundation Models)
    ///
    /// - Returns: A `DeviceCapabilities` instance for the current device.
    public static func current() -> DeviceCapabilities {
        let totalRAM = Int64(ProcessInfo.processInfo.physicalMemory)
        let availableRAM = Self.getAvailableMemory()
        let chipType = Self.getChipType()
        let isAppleSilicon = Self.isAppleSilicon()

        return DeviceCapabilities(
            totalRAM: totalRAM,
            availableRAM: availableRAM,
            chipType: chipType,
            neuralEngineCores: Self.getNeuralEngineCores(chipType: chipType),
            supportsMLX: isAppleSilicon,
            supportsFoundationModels: Self.checkFoundationModelsSupport()
        )
    }

    // MARK: - Model Recommendations

    /// Returns the recommended model size based on available RAM.
    ///
    /// Accounts for system overhead by using only ~80% of available RAM.
    ///
    /// - Returns: The largest `ModelSize` suitable for this device.
    public func recommendedModelSize() -> ModelSize {
        ModelSize.forAvailableRAM(availableRAM)
    }

    /// Checks if the device can run a model of the given size.
    ///
    /// - Parameter size: The model size to check.
    /// - Returns: `true` if the device has enough resources.
    public func canRunModel(ofSize size: ModelSize) -> Bool {
        availableRAM >= size.minimumRAMBytes
    }

    // MARK: - Formatted Output

    /// Total RAM as a formatted string.
    public var formattedTotalRAM: String {
        ByteCountFormatter.string(fromByteCount: totalRAM, countStyle: .memory)
    }

    /// Available RAM as a formatted string.
    public var formattedAvailableRAM: String {
        ByteCountFormatter.string(fromByteCount: availableRAM, countStyle: .memory)
    }
}

// MARK: - Private Detection Methods

extension DeviceCapabilities {

    private static func getAvailableMemory() -> Int64 {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        // Use os_proc_available_memory on iOS platforms
        return Int64(os_proc_available_memory())
        #elseif os(macOS)
        // Use vm_statistics on macOS
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            // Use getpagesize() which is thread-safe and avoids concurrency warnings
            let pageSize = Int64(getpagesize())
            return Int64(stats.free_count) * pageSize + Int64(stats.inactive_count) * pageSize
        }

        // Fallback: estimate as half of total
        return Int64(ProcessInfo.processInfo.physicalMemory) / 2
        #else
        // Other platforms: estimate as half of total
        return Int64(ProcessInfo.processInfo.physicalMemory) / 2
        #endif
    }

    private static func getChipType() -> String? {
        #if os(macOS) || os(iOS)
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)

        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
            // Convert to UInt8 array and decode, truncating at null terminator
            let uint8Buffer = buffer.map { UInt8(bitPattern: $0) }
            if let nullIndex = uint8Buffer.firstIndex(of: 0) {
                return String(decoding: uint8Buffer[..<nullIndex], as: UTF8.self)
            }
            return String(decoding: uint8Buffer, as: UTF8.self)
        }
        return nil
        #else
        return nil
        #endif
    }

    private static func isAppleSilicon() -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    private static func getNeuralEngineCores(chipType: String?) -> Int? {
        guard let chip = chipType?.lowercased() else { return nil }

        // Neural Engine cores by Apple chip generation
        // M-series Macs
        if chip.contains("m4") { return 16 }
        if chip.contains("m3") { return 16 }
        if chip.contains("m2") { return 16 }
        if chip.contains("m1") { return 16 }

        // A-series iOS
        if chip.contains("a17") { return 16 }
        if chip.contains("a16") { return 16 }
        if chip.contains("a15") { return 16 }
        if chip.contains("a14") { return 16 }
        if chip.contains("a13") { return 8 }
        if chip.contains("a12") { return 8 }

        return nil
    }

    private static func checkFoundationModelsSupport() -> Bool {
        #if os(iOS) || os(macOS) || os(visionOS)
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return true
        }
        #endif
        return false
    }
}

// MARK: - CustomStringConvertible

extension DeviceCapabilities: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        parts.append("RAM: \(formattedTotalRAM) total, \(formattedAvailableRAM) available")
        if let chip = chipType {
            parts.append("Chip: \(chip)")
        }
        if let cores = neuralEngineCores {
            parts.append("Neural Engine: \(cores) cores")
        }
        parts.append("MLX: \(supportsMLX ? "✓" : "✗")")
        parts.append("Foundation Models: \(supportsFoundationModels ? "✓" : "✗")")
        return parts.joined(separator: ", ")
    }
}
