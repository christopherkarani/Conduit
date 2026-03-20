// ProviderRuntimeCapabilities.swift
// Conduit
//
// Typed runtime capability, policy, and diagnostics contracts for provider-level
// feature gating (Membrane v2 post-v1 features).

import Foundation

// MARK: - Runtime Feature Identity

/// Runtime features owned by provider/runtime implementations.
///
/// These features are intentionally below orchestration concerns.
public enum ProviderRuntimeFeature: String, Sendable, Codable, CaseIterable {
    case kvQuantization = "kv_quantization"
    case attentionSinks = "attention_sinks"
    case kvSwap = "kv_swap"
    case incrementalPrefill = "incremental_prefill"
    case speculativeScheduling = "speculative_scheduling"
}

// MARK: - Capability Contracts

/// Capability details for a single runtime feature.
public struct ProviderRuntimeFeatureCapability: Sendable, Hashable, Codable {
    /// Whether this runtime feature is available on the provider/runtime path.
    public var isSupported: Bool

    /// Optional supported quantization bit-depths (for quantization features).
    public var supportedBits: [Int]

    /// Optional max sink tokens (for attention sinks).
    public var maxSinkTokens: Int?

    /// Optional max draft stream count (for speculative scheduling).
    public var maxDraftStreams: Int?

    /// Optional max draft ahead token window (for speculative scheduling).
    public var maxDraftAheadTokens: Int?

    /// Optional max incremental prefill token span.
    public var maxIncrementalPrefillTokens: Int?

    /// Whether verifier rollback semantics are supported.
    public var supportsVerifierRollback: Bool

    /// Reason for unavailability when `isSupported` is false.
    public var reasonUnavailable: String?

    public init(
        isSupported: Bool,
        supportedBits: [Int] = [],
        maxSinkTokens: Int? = nil,
        maxDraftStreams: Int? = nil,
        maxDraftAheadTokens: Int? = nil,
        maxIncrementalPrefillTokens: Int? = nil,
        supportsVerifierRollback: Bool = false,
        reasonUnavailable: String? = nil
    ) {
        self.isSupported = isSupported
        self.supportedBits = supportedBits
        self.maxSinkTokens = maxSinkTokens
        self.maxDraftStreams = maxDraftStreams
        self.maxDraftAheadTokens = maxDraftAheadTokens
        self.maxIncrementalPrefillTokens = maxIncrementalPrefillTokens
        self.supportsVerifierRollback = supportsVerifierRollback
        self.reasonUnavailable = reasonUnavailable
    }
}

/// Aggregated runtime capabilities for provider/runtime-owned features.
public struct ProviderRuntimeCapabilities: Sendable, Hashable, Codable {
    private var capabilities: [ProviderRuntimeFeature: ProviderRuntimeFeatureCapability]

    /// Access capabilities via subscript.
    public subscript(feature: ProviderRuntimeFeature) -> ProviderRuntimeFeatureCapability {
        get { capabilities[feature] ?? ProviderRuntimeFeatureCapability(isSupported: false) }
        set { capabilities[feature] = newValue }
    }

    /// Creates runtime capabilities from a dictionary.
    public init(capabilities: [ProviderRuntimeFeature: ProviderRuntimeFeatureCapability] = [:]) {
        self.capabilities = capabilities
    }

    /// Creates runtime capabilities with individual feature capabilities.
    public init(
        kvQuantization: ProviderRuntimeFeatureCapability,
        attentionSinks: ProviderRuntimeFeatureCapability,
        kvSwap: ProviderRuntimeFeatureCapability,
        incrementalPrefill: ProviderRuntimeFeatureCapability,
        speculativeScheduling: ProviderRuntimeFeatureCapability
    ) {
        self.capabilities = [
            .kvQuantization: kvQuantization,
            .attentionSinks: attentionSinks,
            .kvSwap: kvSwap,
            .incrementalPrefill: incrementalPrefill,
            .speculativeScheduling: speculativeScheduling
        ]
    }

    /// Returns the capability for a specific feature.
    @available(*, deprecated, renamed: "subscript")
    public func capability(for feature: ProviderRuntimeFeature) -> ProviderRuntimeFeatureCapability {
        self[feature]
    }

    /// KV quantization capability.
    @available(*, deprecated, renamed: "subscript")
    public var kvQuantization: ProviderRuntimeFeatureCapability {
        get { self[.kvQuantization] }
        set { self[.kvQuantization] = newValue }
    }

    /// Attention sinks capability.
    @available(*, deprecated, renamed: "subscript")
    public var attentionSinks: ProviderRuntimeFeatureCapability {
        get { self[.attentionSinks] }
        set { self[.attentionSinks] = newValue }
    }

    /// KV swap capability.
    @available(*, deprecated, renamed: "subscript")
    public var kvSwap: ProviderRuntimeFeatureCapability {
        get { self[.kvSwap] }
        set { self[.kvSwap] = newValue }
    }

    /// Incremental prefill capability.
    @available(*, deprecated, renamed: "subscript")
    public var incrementalPrefill: ProviderRuntimeFeatureCapability {
        get { self[.incrementalPrefill] }
        set { self[.incrementalPrefill] = newValue }
    }

    /// Speculative scheduling capability.
    @available(*, deprecated, renamed: "subscript")
    public var speculativeScheduling: ProviderRuntimeFeatureCapability {
        get { self[.speculativeScheduling] }
        set { self[.speculativeScheduling] = newValue }
    }
}

// MARK: - Runtime Policy (flags + model allowlists)

/// Per-feature policy flags.
public struct ProviderRuntimeFeatureFlags: Sendable, Hashable, Codable {
    private var flags: [ProviderRuntimeFeature: Bool]

    /// Access flags via subscript.
    public subscript(feature: ProviderRuntimeFeature) -> Bool {
        get { flags[feature] ?? true }
        set { flags[feature] = newValue }
    }

    /// Creates feature flags from a dictionary.
    public init(flags: [ProviderRuntimeFeature: Bool] = [:]) {
        self.flags = flags
    }

    /// Creates feature flags with individual feature settings.
    public init(
        kvQuantization: Bool = true,
        attentionSinks: Bool = true,
        kvSwap: Bool = true,
        incrementalPrefill: Bool = true,
        speculativeScheduling: Bool = true
    ) {
        self.flags = [
            .kvQuantization: kvQuantization,
            .attentionSinks: attentionSinks,
            .kvSwap: kvSwap,
            .incrementalPrefill: incrementalPrefill,
            .speculativeScheduling: speculativeScheduling
        ]
    }

    /// Returns whether a feature is enabled.
    @available(*, deprecated, renamed: "subscript")
    public func isEnabled(_ feature: ProviderRuntimeFeature) -> Bool {
        self[feature]
    }

    /// KV quantization flag.
    @available(*, deprecated, renamed: "subscript")
    public var kvQuantization: Bool {
        get { self[.kvQuantization] }
        set { self[.kvQuantization] = newValue }
    }

    /// Attention sinks flag.
    @available(*, deprecated, renamed: "subscript")
    public var attentionSinks: Bool {
        get { self[.attentionSinks] }
        set { self[.attentionSinks] = newValue }
    }

    /// KV swap flag.
    @available(*, deprecated, renamed: "subscript")
    public var kvSwap: Bool {
        get { self[.kvSwap] }
        set { self[.kvSwap] = newValue }
    }

    /// Incremental prefill flag.
    @available(*, deprecated, renamed: "subscript")
    public var incrementalPrefill: Bool {
        get { self[.incrementalPrefill] }
        set { self[.incrementalPrefill] = newValue }
    }

    /// Speculative scheduling flag.
    @available(*, deprecated, renamed: "subscript")
    public var speculativeScheduling: Bool {
        get { self[.speculativeScheduling] }
        set { self[.speculativeScheduling] = newValue }
    }
}

/// Per-feature model allowlists.
///
/// Empty allowlist means "no restriction".
public struct ProviderRuntimeModelAllowlist: Sendable, Hashable, Codable {
    private var allowlists: [ProviderRuntimeFeature: Set<String>]

    /// Access allowlists via subscript.
    public subscript(feature: ProviderRuntimeFeature) -> Set<String> {
        get { allowlists[feature] ?? [] }
        set { allowlists[feature] = newValue }
    }

    /// Creates model allowlists from a dictionary.
    public init(allowlists: [ProviderRuntimeFeature: Set<String>] = [:]) {
        self.allowlists = allowlists
    }

    /// Creates model allowlists with individual feature allowlists.
    public init(
        kvQuantizationModels: Set<String> = [],
        attentionSinkModels: Set<String> = [],
        kvSwapModels: Set<String> = [],
        incrementalPrefillModels: Set<String> = [],
        speculativeSchedulingModels: Set<String> = []
    ) {
        self.allowlists = [
            .kvQuantization: kvQuantizationModels,
            .attentionSinks: attentionSinkModels,
            .kvSwap: kvSwapModels,
            .incrementalPrefill: incrementalPrefillModels,
            .speculativeScheduling: speculativeSchedulingModels
        ]
    }

    /// Returns whether a model is allowed for a feature.
    @available(*, deprecated, renamed: "subscript")
    public func isModelAllowed(feature: ProviderRuntimeFeature, modelID: String) -> Bool {
        let allowlist = self[feature]
        return allowlist.isEmpty || allowlist.contains(modelID)
    }

    /// KV quantization model allowlist.
    @available(*, deprecated, renamed: "subscript")
    public var kvQuantizationModels: Set<String> {
        get { self[.kvQuantization] }
        set { self[.kvQuantization] = newValue }
    }

    /// Attention sinks model allowlist.
    @available(*, deprecated, renamed: "subscript")
    public var attentionSinkModels: Set<String> {
        get { self[.attentionSinks] }
        set { self[.attentionSinks] = newValue }
    }

    /// KV swap model allowlist.
    @available(*, deprecated, renamed: "subscript")
    public var kvSwapModels: Set<String> {
        get { self[.kvSwap] }
        set { self[.kvSwap] = newValue }
    }

    /// Incremental prefill model allowlist.
    @available(*, deprecated, renamed: "subscript")
    public var incrementalPrefillModels: Set<String> {
        get { self[.incrementalPrefill] }
        set { self[.incrementalPrefill] = newValue }
    }

    /// Speculative scheduling model allowlist.
    @available(*, deprecated, renamed: "subscript")
    public var speculativeSchedulingModels: Set<String> {
        get { self[.speculativeScheduling] }
        set { self[.speculativeScheduling] = newValue }
    }
}

/// Runtime policy gate combining feature flags and model allowlists.
public struct ProviderRuntimePolicy: Sendable, Hashable, Codable {
    public static let `default` = ProviderRuntimePolicy()

    public var featureFlags: ProviderRuntimeFeatureFlags
    public var modelAllowlist: ProviderRuntimeModelAllowlist

    public init(
        featureFlags: ProviderRuntimeFeatureFlags = .init(),
        modelAllowlist: ProviderRuntimeModelAllowlist = .init()
    ) {
        self.featureFlags = featureFlags
        self.modelAllowlist = modelAllowlist
    }

    /// Returns whether a feature is enabled.
    public func isEnabled(feature: ProviderRuntimeFeature) -> Bool {
        featureFlags[feature]
    }

    /// Returns whether a model is allowed for a feature.
    public func isModelAllowed(feature: ProviderRuntimeFeature, modelID: String) -> Bool {
        let allowlist = modelAllowlist[feature]
        return allowlist.isEmpty || allowlist.contains(modelID)
    }

    /// Applies per-request runtime policy overrides.
    ///
    /// Unset override fields preserve the existing policy values.
    public func applying(overrides: ProviderRuntimePolicyOverride?) -> ProviderRuntimePolicy {
        guard let overrides else { return self }
        return ProviderRuntimePolicy(
            featureFlags: featureFlags.applying(overrides: overrides.featureFlags),
            modelAllowlist: modelAllowlist.applying(overrides: overrides.modelAllowlist)
        )
    }
}

// MARK: - Runtime Policy Overrides

/// Optional per-request feature-flag overrides.
///
/// `nil` fields preserve provider-level policy defaults.
public struct ProviderRuntimeFeatureFlagOverride: Sendable, Hashable, Codable {
    private var overrides: [ProviderRuntimeFeature: Bool]

    /// Access overrides via subscript.
    public subscript(feature: ProviderRuntimeFeature) -> Bool? {
        get { overrides[feature] }
        set { overrides[feature] = newValue }
    }

    /// Creates feature flag overrides from a dictionary.
    public init(overrides: [ProviderRuntimeFeature: Bool?] = [:]) {
        self.overrides = overrides.compactMapValues { $0 }
    }

    /// Creates feature flag overrides with individual feature settings.
    public init(
        kvQuantization: Bool? = nil,
        attentionSinks: Bool? = nil,
        kvSwap: Bool? = nil,
        incrementalPrefill: Bool? = nil,
        speculativeScheduling: Bool? = nil
    ) {
        self.overrides = [:]
        self.overrides[.kvQuantization] = kvQuantization
        self.overrides[.attentionSinks] = attentionSinks
        self.overrides[.kvSwap] = kvSwap
        self.overrides[.incrementalPrefill] = incrementalPrefill
        self.overrides[.speculativeScheduling] = speculativeScheduling
    }

    /// KV quantization override.
    @available(*, deprecated, renamed: "subscript")
    public var kvQuantization: Bool? {
        get { self[.kvQuantization] }
        set { self[.kvQuantization] = newValue }
    }

    /// Attention sinks override.
    @available(*, deprecated, renamed: "subscript")
    public var attentionSinks: Bool? {
        get { self[.attentionSinks] }
        set { self[.attentionSinks] = newValue }
    }

    /// KV swap override.
    @available(*, deprecated, renamed: "subscript")
    public var kvSwap: Bool? {
        get { self[.kvSwap] }
        set { self[.kvSwap] = newValue }
    }

    /// Incremental prefill override.
    @available(*, deprecated, renamed: "subscript")
    public var incrementalPrefill: Bool? {
        get { self[.incrementalPrefill] }
        set { self[.incrementalPrefill] = newValue }
    }

    /// Speculative scheduling override.
    @available(*, deprecated, renamed: "subscript")
    public var speculativeScheduling: Bool? {
        get { self[.speculativeScheduling] }
        set { self[.speculativeScheduling] = newValue }
    }
}

/// Optional per-request model-allowlist overrides.
///
/// `nil` fields preserve provider-level allowlists.
public struct ProviderRuntimeModelAllowlistOverride: Sendable, Hashable, Codable {
    private var overrides: [ProviderRuntimeFeature: Set<String>?]

    /// Access overrides via subscript.
    public subscript(feature: ProviderRuntimeFeature) -> Set<String>? {
        get { overrides[feature] ?? nil }
        set { overrides[feature] = newValue }
    }

    /// Creates model allowlist overrides from a dictionary.
    public init(overrides: [ProviderRuntimeFeature: Set<String>?] = [:]) {
        self.overrides = overrides
    }

    /// Creates model allowlist overrides with individual feature settings.
    public init(
        kvQuantizationModels: Set<String>? = nil,
        attentionSinkModels: Set<String>? = nil,
        kvSwapModels: Set<String>? = nil,
        incrementalPrefillModels: Set<String>? = nil,
        speculativeSchedulingModels: Set<String>? = nil
    ) {
        self.overrides = [:]
        self.overrides[.kvQuantization] = kvQuantizationModels
        self.overrides[.attentionSinks] = attentionSinkModels
        self.overrides[.kvSwap] = kvSwapModels
        self.overrides[.incrementalPrefill] = incrementalPrefillModels
        self.overrides[.speculativeScheduling] = speculativeSchedulingModels
    }

    /// KV quantization models override.
    @available(*, deprecated, renamed: "subscript")
    public var kvQuantizationModels: Set<String>? {
        get { self[.kvQuantization] }
        set { self[.kvQuantization] = newValue }
    }

    /// Attention sinks models override.
    @available(*, deprecated, renamed: "subscript")
    public var attentionSinkModels: Set<String>? {
        get { self[.attentionSinks] }
        set { self[.attentionSinks] = newValue }
    }

    /// KV swap models override.
    @available(*, deprecated, renamed: "subscript")
    public var kvSwapModels: Set<String>? {
        get { self[.kvSwap] }
        set { self[.kvSwap] = newValue }
    }

    /// Incremental prefill models override.
    @available(*, deprecated, renamed: "subscript")
    public var incrementalPrefillModels: Set<String>? {
        get { self[.incrementalPrefill] }
        set { self[.incrementalPrefill] = newValue }
    }

    /// Speculative scheduling models override.
    @available(*, deprecated, renamed: "subscript")
    public var speculativeSchedulingModels: Set<String>? {
        get { self[.speculativeScheduling] }
        set { self[.speculativeScheduling] = newValue }
    }
}

/// Optional per-request policy overrides combining flags and allowlists.
public struct ProviderRuntimePolicyOverride: Sendable, Hashable, Codable {
    public var featureFlags: ProviderRuntimeFeatureFlagOverride
    public var modelAllowlist: ProviderRuntimeModelAllowlistOverride

    public init(
        featureFlags: ProviderRuntimeFeatureFlagOverride = .init(),
        modelAllowlist: ProviderRuntimeModelAllowlistOverride = .init()
    ) {
        self.featureFlags = featureFlags
        self.modelAllowlist = modelAllowlist
    }
}

// MARK: - Per-request Runtime Feature Configuration

private extension ProviderRuntimeFeatureFlags {
    func applying(overrides: ProviderRuntimeFeatureFlagOverride) -> ProviderRuntimeFeatureFlags {
        var flags = self
        for feature in ProviderRuntimeFeature.allCases {
            if let override = overrides[feature] {
                flags[feature] = override
            }
        }
        return flags
    }
}

private extension ProviderRuntimeModelAllowlist {
    func applying(overrides: ProviderRuntimeModelAllowlistOverride) -> ProviderRuntimeModelAllowlist {
        var allowlists = self
        for feature in ProviderRuntimeFeature.allCases {
            if let override = overrides[feature] {
                allowlists[feature] = override
            }
        }
        return allowlists
    }
}

/// Per-request runtime feature controls.
///
/// `enabled == nil` means "no request override".
public struct ProviderRuntimeFeatureConfiguration: Sendable, Hashable, Codable {
    public struct KVQuantization: Sendable, Hashable, Codable {
        public var enabled: Bool?
        public var bits: Int?

        public init(enabled: Bool? = nil, bits: Int? = nil) {
            self.enabled = enabled
            self.bits = bits
        }
    }

    public struct AttentionSinks: Sendable, Hashable, Codable {
        public var enabled: Bool?
        public var sinkTokenCount: Int?

        public init(enabled: Bool? = nil, sinkTokenCount: Int? = nil) {
            self.enabled = enabled
            self.sinkTokenCount = sinkTokenCount
        }
    }

    public struct KVSwap: Sendable, Hashable, Codable {
        public var enabled: Bool?
        public var ioBudgetMBPerSecond: Int?

        public init(enabled: Bool? = nil, ioBudgetMBPerSecond: Int? = nil) {
            self.enabled = enabled
            self.ioBudgetMBPerSecond = ioBudgetMBPerSecond
        }
    }

    public struct IncrementalPrefill: Sendable, Hashable, Codable {
        public var enabled: Bool?
        public var maxPrefixTokens: Int?

        public init(enabled: Bool? = nil, maxPrefixTokens: Int? = nil) {
            self.enabled = enabled
            self.maxPrefixTokens = maxPrefixTokens
        }
    }

    public struct SpeculativeScheduling: Sendable, Hashable, Codable {
        public var enabled: Bool?
        public var draftStreamCount: Int?
        public var draftAheadTokens: Int?
        public var verificationBatchTokens: Int?
        public var rollbackTokenBudgetPerTurn: Int?
        public var autoDisableDivergenceRate: Double?

        public init(
            enabled: Bool? = nil,
            draftStreamCount: Int? = nil,
            draftAheadTokens: Int? = nil,
            verificationBatchTokens: Int? = nil,
            rollbackTokenBudgetPerTurn: Int? = nil,
            autoDisableDivergenceRate: Double? = nil
        ) {
            self.enabled = enabled
            self.draftStreamCount = draftStreamCount
            self.draftAheadTokens = draftAheadTokens
            self.verificationBatchTokens = verificationBatchTokens
            self.rollbackTokenBudgetPerTurn = rollbackTokenBudgetPerTurn
            self.autoDisableDivergenceRate = autoDisableDivergenceRate
        }
    }

    public var kvQuantization: KVQuantization
    public var attentionSinks: AttentionSinks
    public var kvSwap: KVSwap
    public var incrementalPrefill: IncrementalPrefill
    public var speculativeScheduling: SpeculativeScheduling

    public init(
        kvQuantization: KVQuantization = .init(),
        attentionSinks: AttentionSinks = .init(),
        kvSwap: KVSwap = .init(),
        incrementalPrefill: IncrementalPrefill = .init(),
        speculativeScheduling: SpeculativeScheduling = .init()
    ) {
        self.kvQuantization = kvQuantization
        self.attentionSinks = attentionSinks
        self.kvSwap = kvSwap
        self.incrementalPrefill = incrementalPrefill
        self.speculativeScheduling = speculativeScheduling
    }
}

// MARK: - Diagnostics

/// Runtime diagnostics event kind.
public enum ProviderRuntimeDiagnosticsEventKind: String, Sendable, Codable {
    case capabilitySelected = "capability_selected"
    case capabilityDenied = "capability_denied"
    case fallbackUsed = "fallback_used"
    case autoDisabled = "auto_disabled"
}

/// Structured runtime diagnostics event for observability and conformance logs.
public struct ProviderRuntimeDiagnosticsEvent: Sendable, Equatable, Codable {
    public var timestamp: Date
    public var feature: ProviderRuntimeFeature
    public var kind: ProviderRuntimeDiagnosticsEventKind
    public var modelID: String
    public var reason: String?
    public var details: [String: String]

    public init(
        timestamp: Date = Date(),
        feature: ProviderRuntimeFeature,
        kind: ProviderRuntimeDiagnosticsEventKind,
        modelID: String,
        reason: String? = nil,
        details: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.feature = feature
        self.kind = kind
        self.modelID = modelID
        self.reason = reason
        self.details = details
    }
}
