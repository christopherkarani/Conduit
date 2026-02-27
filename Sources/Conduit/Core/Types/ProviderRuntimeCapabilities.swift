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
    public var kvQuantization: ProviderRuntimeFeatureCapability
    public var attentionSinks: ProviderRuntimeFeatureCapability
    public var kvSwap: ProviderRuntimeFeatureCapability
    public var incrementalPrefill: ProviderRuntimeFeatureCapability
    public var speculativeScheduling: ProviderRuntimeFeatureCapability

    public init(
        kvQuantization: ProviderRuntimeFeatureCapability,
        attentionSinks: ProviderRuntimeFeatureCapability,
        kvSwap: ProviderRuntimeFeatureCapability,
        incrementalPrefill: ProviderRuntimeFeatureCapability,
        speculativeScheduling: ProviderRuntimeFeatureCapability
    ) {
        self.kvQuantization = kvQuantization
        self.attentionSinks = attentionSinks
        self.kvSwap = kvSwap
        self.incrementalPrefill = incrementalPrefill
        self.speculativeScheduling = speculativeScheduling
    }

    public func capability(for feature: ProviderRuntimeFeature) -> ProviderRuntimeFeatureCapability {
        switch feature {
        case .kvQuantization:
            kvQuantization
        case .attentionSinks:
            attentionSinks
        case .kvSwap:
            kvSwap
        case .incrementalPrefill:
            incrementalPrefill
        case .speculativeScheduling:
            speculativeScheduling
        }
    }
}

// MARK: - Runtime Policy (flags + model allowlists)

/// Per-feature policy flags.
public struct ProviderRuntimeFeatureFlags: Sendable, Hashable, Codable {
    public var kvQuantization: Bool
    public var attentionSinks: Bool
    public var kvSwap: Bool
    public var incrementalPrefill: Bool
    public var speculativeScheduling: Bool

    public init(
        kvQuantization: Bool = true,
        attentionSinks: Bool = true,
        kvSwap: Bool = true,
        incrementalPrefill: Bool = true,
        speculativeScheduling: Bool = true
    ) {
        self.kvQuantization = kvQuantization
        self.attentionSinks = attentionSinks
        self.kvSwap = kvSwap
        self.incrementalPrefill = incrementalPrefill
        self.speculativeScheduling = speculativeScheduling
    }

    public func isEnabled(_ feature: ProviderRuntimeFeature) -> Bool {
        switch feature {
        case .kvQuantization:
            kvQuantization
        case .attentionSinks:
            attentionSinks
        case .kvSwap:
            kvSwap
        case .incrementalPrefill:
            incrementalPrefill
        case .speculativeScheduling:
            speculativeScheduling
        }
    }
}

/// Per-feature model allowlists.
///
/// Empty allowlist means "no restriction".
public struct ProviderRuntimeModelAllowlist: Sendable, Hashable, Codable {
    public var kvQuantizationModels: Set<String>
    public var attentionSinkModels: Set<String>
    public var kvSwapModels: Set<String>
    public var incrementalPrefillModels: Set<String>
    public var speculativeSchedulingModels: Set<String>

    public init(
        kvQuantizationModels: Set<String> = [],
        attentionSinkModels: Set<String> = [],
        kvSwapModels: Set<String> = [],
        incrementalPrefillModels: Set<String> = [],
        speculativeSchedulingModels: Set<String> = []
    ) {
        self.kvQuantizationModels = kvQuantizationModels
        self.attentionSinkModels = attentionSinkModels
        self.kvSwapModels = kvSwapModels
        self.incrementalPrefillModels = incrementalPrefillModels
        self.speculativeSchedulingModels = speculativeSchedulingModels
    }

    public func isModelAllowed(feature: ProviderRuntimeFeature, modelID: String) -> Bool {
        let allowlist: Set<String> = switch feature {
        case .kvQuantization:
            kvQuantizationModels
        case .attentionSinks:
            attentionSinkModels
        case .kvSwap:
            kvSwapModels
        case .incrementalPrefill:
            incrementalPrefillModels
        case .speculativeScheduling:
            speculativeSchedulingModels
        }

        return allowlist.isEmpty || allowlist.contains(modelID)
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

    public func isEnabled(feature: ProviderRuntimeFeature) -> Bool {
        featureFlags.isEnabled(feature)
    }

    public func isModelAllowed(feature: ProviderRuntimeFeature, modelID: String) -> Bool {
        modelAllowlist.isModelAllowed(feature: feature, modelID: modelID)
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

/// Optional per-request feature-flag overrides.
///
/// `nil` fields preserve provider-level policy defaults.
public struct ProviderRuntimeFeatureFlagOverride: Sendable, Hashable, Codable {
    public var kvQuantization: Bool?
    public var attentionSinks: Bool?
    public var kvSwap: Bool?
    public var incrementalPrefill: Bool?
    public var speculativeScheduling: Bool?

    public init(
        kvQuantization: Bool? = nil,
        attentionSinks: Bool? = nil,
        kvSwap: Bool? = nil,
        incrementalPrefill: Bool? = nil,
        speculativeScheduling: Bool? = nil
    ) {
        self.kvQuantization = kvQuantization
        self.attentionSinks = attentionSinks
        self.kvSwap = kvSwap
        self.incrementalPrefill = incrementalPrefill
        self.speculativeScheduling = speculativeScheduling
    }
}

/// Optional per-request model-allowlist overrides.
///
/// `nil` fields preserve provider-level allowlists.
public struct ProviderRuntimeModelAllowlistOverride: Sendable, Hashable, Codable {
    public var kvQuantizationModels: Set<String>?
    public var attentionSinkModels: Set<String>?
    public var kvSwapModels: Set<String>?
    public var incrementalPrefillModels: Set<String>?
    public var speculativeSchedulingModels: Set<String>?

    public init(
        kvQuantizationModels: Set<String>? = nil,
        attentionSinkModels: Set<String>? = nil,
        kvSwapModels: Set<String>? = nil,
        incrementalPrefillModels: Set<String>? = nil,
        speculativeSchedulingModels: Set<String>? = nil
    ) {
        self.kvQuantizationModels = kvQuantizationModels
        self.attentionSinkModels = attentionSinkModels
        self.kvSwapModels = kvSwapModels
        self.incrementalPrefillModels = incrementalPrefillModels
        self.speculativeSchedulingModels = speculativeSchedulingModels
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
        ProviderRuntimeFeatureFlags(
            kvQuantization: overrides.kvQuantization ?? kvQuantization,
            attentionSinks: overrides.attentionSinks ?? attentionSinks,
            kvSwap: overrides.kvSwap ?? kvSwap,
            incrementalPrefill: overrides.incrementalPrefill ?? incrementalPrefill,
            speculativeScheduling: overrides.speculativeScheduling ?? speculativeScheduling
        )
    }
}

private extension ProviderRuntimeModelAllowlist {
    func applying(overrides: ProviderRuntimeModelAllowlistOverride) -> ProviderRuntimeModelAllowlist {
        ProviderRuntimeModelAllowlist(
            kvQuantizationModels: overrides.kvQuantizationModels ?? kvQuantizationModels,
            attentionSinkModels: overrides.attentionSinkModels ?? attentionSinkModels,
            kvSwapModels: overrides.kvSwapModels ?? kvSwapModels,
            incrementalPrefillModels: overrides.incrementalPrefillModels ?? incrementalPrefillModels,
            speculativeSchedulingModels: overrides.speculativeSchedulingModels ?? speculativeSchedulingModels
        )
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
