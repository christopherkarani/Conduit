// OllamaConfiguration.swift
// Conduit
//
// Ollama-specific configuration for local inference.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation

// MARK: - OllamaConfiguration

/// Configuration for Ollama local inference server.
///
/// Ollama runs LLMs locally and provides an OpenAI-compatible API.
/// This configuration controls Ollama-specific features like model
/// management and server health checks.
///
/// ## Usage
///
/// ### Default Configuration
/// ```swift
/// let config = OllamaConfiguration.default
/// ```
///
/// ### Custom Keep-Alive
/// ```swift
/// let config = OllamaConfiguration(keepAlive: "10m")
/// ```
///
/// ### With Model Pull Settings
/// ```swift
/// let config = OllamaConfiguration()
///     .pullOnMissing(true)
///     .keepAlive("30m")
/// ```
///
/// ## Keep-Alive Format
///
/// The `keepAlive` parameter controls how long models stay loaded:
/// - `"5m"` - 5 minutes
/// - `"1h"` - 1 hour
/// - `"0"` - Unload immediately after request
/// - `"-1"` - Keep loaded indefinitely
public struct OllamaConfiguration: Sendable, Hashable {

    // MARK: - Properties

    /// How long to keep the model loaded in memory.
    ///
    /// Format: Number followed by unit (s, m, h)
    /// - `"5m"` - 5 minutes
    /// - `"1h"` - 1 hour
    /// - `"0"` - Unload immediately
    /// - `"-1"` - Keep indefinitely
    ///
    /// Default: `"5m"` (Ollama default)
    public var keepAlive: String?

    /// Automatically pull models that aren't available.
    ///
    /// When `true`, if a requested model isn't available locally,
    /// the provider will attempt to pull it from the Ollama registry.
    ///
    /// Default: `false`
    public var pullOnMissing: Bool

    /// Number of parallel requests to allow.
    ///
    /// Controls concurrent model loading. Higher values use more memory.
    /// Set to `nil` to use Ollama's default.
    public var numParallel: Int?

    /// Number of GPU layers to use.
    ///
    /// Controls how many layers are offloaded to GPU.
    /// Set to `nil` for auto-detection.
    /// Set to `0` to force CPU-only.
    public var numGPU: Int?

    /// Main GPU to use for computation.
    ///
    /// For multi-GPU systems, specifies which GPU to use.
    /// Set to `nil` for auto-selection.
    public var mainGPU: Int?

    /// Enable low VRAM mode.
    ///
    /// When `true`, uses less GPU memory at the cost of speed.
    /// Useful for GPUs with limited memory.
    ///
    /// Default: `false`
    public var lowVRAM: Bool

    /// Context window size.
    ///
    /// Sets the number of tokens the model can use for context.
    /// Larger values use more memory.
    /// Set to `nil` to use model's default.
    public var numCtx: Int?

    /// Enable health checks before requests.
    ///
    /// When `true`, verifies the Ollama server is running before
    /// making requests. Adds slight latency but catches issues early.
    ///
    /// Default: `true`
    public var healthCheck: Bool

    /// Timeout for health check requests (in seconds).
    ///
    /// Default: 5.0
    public var healthCheckTimeout: TimeInterval

    // MARK: - Initialization

    /// Creates an Ollama configuration.
    ///
    /// - Parameters:
    ///   - keepAlive: How long to keep model loaded. Default: `nil` (use Ollama default)
    ///   - pullOnMissing: Auto-pull missing models. Default: `false`
    ///   - numParallel: Parallel request count. Default: `nil`
    ///   - numGPU: GPU layers count. Default: `nil`
    ///   - mainGPU: Main GPU index. Default: `nil`
    ///   - lowVRAM: Enable low VRAM mode. Default: `false`
    ///   - numCtx: Context window size. Default: `nil`
    ///   - healthCheck: Enable health checks. Default: `true`
    ///   - healthCheckTimeout: Health check timeout. Default: 5.0
    public init(
        keepAlive: String? = nil,
        pullOnMissing: Bool = false,
        numParallel: Int? = nil,
        numGPU: Int? = nil,
        mainGPU: Int? = nil,
        lowVRAM: Bool = false,
        numCtx: Int? = nil,
        healthCheck: Bool = true,
        healthCheckTimeout: TimeInterval = 5.0
    ) {
        self.keepAlive = keepAlive
        self.pullOnMissing = pullOnMissing
        self.numParallel = numParallel
        self.numGPU = numGPU
        self.mainGPU = mainGPU
        self.lowVRAM = lowVRAM
        self.numCtx = numCtx
        self.healthCheck = healthCheck
        self.healthCheckTimeout = healthCheckTimeout
    }

    // MARK: - Static Presets

    /// Default Ollama configuration.
    ///
    /// Uses Ollama's default settings with health checks enabled.
    public static let `default` = OllamaConfiguration()

    /// Configuration for memory-constrained systems.
    ///
    /// Uses low VRAM mode and shorter keep-alive.
    public static let lowMemory = OllamaConfiguration(
        keepAlive: "1m",
        lowVRAM: true
    )

    /// Configuration for interactive use.
    ///
    /// Keeps models loaded longer for faster subsequent requests.
    public static let interactive = OllamaConfiguration(
        keepAlive: "30m",
        healthCheck: true
    )

    /// Configuration for batch processing.
    ///
    /// Unloads models immediately after use.
    public static let batch = OllamaConfiguration(
        keepAlive: "0",
        healthCheck: false
    )

    /// Configuration for always-on server.
    ///
    /// Keeps models loaded indefinitely.
    public static let alwaysOn = OllamaConfiguration(
        keepAlive: "-1",
        healthCheck: true
    )

    // MARK: - Options Generation

    /// Generates Ollama-specific options for the request body.
    ///
    /// - Returns: Dictionary of Ollama options.
    public func options() -> [String: Any] {
        var opts: [String: Any] = [:]

        if let numGPU = numGPU {
            opts["num_gpu"] = numGPU
        }

        if let mainGPU = mainGPU {
            opts["main_gpu"] = mainGPU
        }

        if lowVRAM {
            opts["low_vram"] = true
        }

        if let numCtx = numCtx {
            opts["num_ctx"] = numCtx
        }

        return opts
    }
}

// MARK: - Fluent API

extension OllamaConfiguration {

    /// Returns a copy with the specified keep-alive duration.
    ///
    /// - Parameter duration: Keep-alive duration (e.g., "5m", "1h", "0", "-1").
    /// - Returns: A new configuration with the updated value.
    public func keepAlive(_ duration: String) -> OllamaConfiguration {
        var copy = self
        copy.keepAlive = duration
        return copy
    }

    /// Returns a copy with pull-on-missing enabled or disabled.
    ///
    /// - Parameter enabled: Whether to auto-pull missing models.
    /// - Returns: A new configuration with the updated value.
    public func pullOnMissing(_ enabled: Bool) -> OllamaConfiguration {
        var copy = self
        copy.pullOnMissing = enabled
        return copy
    }

    /// Returns a copy with the specified parallel request count.
    ///
    /// - Parameter count: Number of parallel requests.
    /// - Returns: A new configuration with the updated value.
    public func numParallel(_ count: Int) -> OllamaConfiguration {
        var copy = self
        copy.numParallel = count
        return copy
    }

    /// Returns a copy with the specified GPU layer count.
    ///
    /// - Parameter count: Number of GPU layers.
    /// - Returns: A new configuration with the updated value.
    public func numGPU(_ count: Int) -> OllamaConfiguration {
        var copy = self
        copy.numGPU = count
        return copy
    }

    /// Returns a copy with CPU-only mode enabled.
    ///
    /// - Returns: A new configuration with numGPU set to 0.
    public func cpuOnly() -> OllamaConfiguration {
        var copy = self
        copy.numGPU = 0
        return copy
    }

    /// Returns a copy with low VRAM mode enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable low VRAM mode.
    /// - Returns: A new configuration with the updated value.
    public func lowVRAM(_ enabled: Bool) -> OllamaConfiguration {
        var copy = self
        copy.lowVRAM = enabled
        return copy
    }

    /// Returns a copy with the specified context window size.
    ///
    /// - Parameter size: Context window size in tokens.
    /// - Returns: A new configuration with the updated value.
    public func contextSize(_ size: Int) -> OllamaConfiguration {
        var copy = self
        copy.numCtx = size
        return copy
    }

    /// Returns a copy with health checks enabled or disabled.
    ///
    /// - Parameter enabled: Whether to enable health checks.
    /// - Returns: A new configuration with the updated value.
    public func healthCheck(_ enabled: Bool) -> OllamaConfiguration {
        var copy = self
        copy.healthCheck = enabled
        return copy
    }
}

// MARK: - Codable

extension OllamaConfiguration: Codable {}

// MARK: - Model Status

/// Status of an Ollama model.
public enum OllamaModelStatus: Sendable, Hashable {

    /// Model is available and ready to use.
    case available

    /// Model is currently being pulled (downloading).
    case pulling(progress: Double)

    /// Model is not available locally.
    case notAvailable

    /// Model status could not be determined.
    case unknown
}

// MARK: - Server Status

/// Status of the Ollama server.
public enum OllamaServerStatus: Sendable, Hashable {

    /// Server is running and responsive.
    case running

    /// Server is not responding.
    case notResponding

    /// Server returned an error.
    case error(String)

    /// Server status is unknown.
    case unknown
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
