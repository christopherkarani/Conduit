// WarmupConfig.swift
// Conduit

import Foundation

// MARK: - WarmupConfig

/// Configuration for model warmup behavior in ChatSession.
///
/// Model warmup performs a minimal generation pass to pre-compile Metal shaders
/// and initialize the model's attention cache. This trades startup time for
/// improved first-message latency.
///
/// ## Performance Impact
///
/// - **Without warmup**: First message has ~2-4 second overhead (shader compilation)
/// - **With warmup**: First message latency is ~100-300ms (normal generation speed)
/// - **Warmup duration**: Typically 1-2 seconds during initialization
///
/// ## When to Use
///
/// **Use `.eager` warmup when:**
/// - The model is known at initialization time
/// - First-message latency is critical for user experience
/// - You're willing to pay the cost upfront during session creation
/// - Example: Chat interface where the user expects immediate responses
///
/// **Use `.default` (no warmup) when:**
/// - The model might change before first use
/// - Initialization speed is more important than first-message speed
/// - The session might be created but not immediately used
/// - Example: Pre-creating sessions for potential future conversations
///
/// ## Usage
///
/// ### Eager Warmup (Recommended for Active Chats)
///
/// ```swift
/// // Warmup automatically on init
/// let session = try await ChatSession(
///     provider: provider,
///     model: .llama3_2_1b,
///     warmup: .eager
/// )
/// // First message will be fast (~100-300ms)
/// ```
///
/// ### Default (No Warmup)
///
/// ```swift
/// // No warmup overhead during init
/// let session = ChatSession(
///     provider: provider,
///     model: .llama3_2_1b,
///     warmup: .default
/// )
/// // First message will include warmup time (~2-4s)
/// ```
///
/// ### Custom Warmup
///
/// ```swift
/// let customWarmup = WarmupConfig(
///     warmupOnInit: true,
///     prefillChars: 100,  // Larger cache warmup
///     warmupTokens: 10    // More tokens generated
/// )
/// let session = try await ChatSession(
///     provider: provider,
///     model: .llama3_2_1b,
///     warmup: customWarmup
/// )
/// ```
///
/// ## Properties
///
/// - `warmupOnInit`: If `true`, performs warmup during session initialization.
/// - `prefillChars`: Number of characters in the warmup prompt. Controls the
///   size of the attention cache that gets warmed up. Default: 50.
/// - `warmupTokens`: Number of tokens to generate during warmup. Higher values
///   warm up longer generation sequences but take longer. Default: 5.
///
/// ## Static Presets
///
/// - `.default`: No automatic warmup (`warmupOnInit: false`)
/// - `.eager`: Automatic warmup with default parameters (`warmupOnInit: true`)
public struct WarmupConfig: Sendable {
    /// Whether to perform warmup during session initialization.
    ///
    /// If `true`, the session initializer will call the provider's `warmUp()`
    /// method automatically. This trades initialization time for improved
    /// first-message latency.
    public var warmupOnInit: Bool

    /// Number of characters in the warmup prompt.
    ///
    /// Controls the size of the attention cache that gets warmed up. Larger
    /// values warm up the cache for longer prompts but take slightly longer.
    ///
    /// Default: 50 characters
    public var prefillChars: Int

    /// Number of tokens to generate during warmup.
    ///
    /// Higher values provide better warmup for longer generation sequences
    /// but increase warmup duration.
    ///
    /// Default: 5 tokens
    public var warmupTokens: Int

    /// Creates a custom warmup configuration.
    ///
    /// - Parameters:
    ///   - warmupOnInit: Whether to warmup on session init. Default: `false`.
    ///   - prefillChars: Number of warmup prompt characters. Default: `50`.
    ///   - warmupTokens: Number of tokens to generate. Default: `5`.
    public init(
        warmupOnInit: Bool = false,
        prefillChars: Int = 50,
        warmupTokens: Int = 5
    ) {
        self.warmupOnInit = warmupOnInit
        self.prefillChars = prefillChars
        self.warmupTokens = warmupTokens
    }

    /// Default configuration with no automatic warmup.
    ///
    /// First message will include warmup overhead (~2-4s), but session
    /// initialization is fast.
    public static let `default` = WarmupConfig(warmupOnInit: false)

    /// Eager warmup configuration.
    ///
    /// Performs warmup during session initialization. First message will be
    /// fast (~100-300ms), but session creation takes longer (~1-2s).
    public static let eager = WarmupConfig(warmupOnInit: true)
}
