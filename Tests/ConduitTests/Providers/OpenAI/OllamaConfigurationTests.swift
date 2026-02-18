// OllamaConfigurationTests.swift
// Conduit Tests
//
// Tests for OllamaConfiguration, OllamaModelStatus, and OllamaServerStatus.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation
import Testing
@testable import Conduit

@Suite("OllamaConfiguration Tests")
struct OllamaConfigurationTests {

    // MARK: - Default Initialization

    @Test("Default init has expected values")
    func defaultInit() {
        let config = OllamaConfiguration()
        #expect(config.keepAlive == nil)
        #expect(config.pullOnMissing == false)
        #expect(config.numParallel == nil)
        #expect(config.numGPU == nil)
        #expect(config.mainGPU == nil)
        #expect(config.lowVRAM == false)
        #expect(config.numCtx == nil)
        #expect(config.healthCheck == true)
        #expect(config.healthCheckTimeout == 5.0)
    }

    // MARK: - Custom Initialization

    @Test("Custom init preserves all values")
    func customInit() {
        let config = OllamaConfiguration(
            keepAlive: "10m",
            pullOnMissing: true,
            numParallel: 4,
            numGPU: 32,
            mainGPU: 0,
            lowVRAM: true,
            numCtx: 4096,
            healthCheck: false,
            healthCheckTimeout: 10.0
        )
        #expect(config.keepAlive == "10m")
        #expect(config.pullOnMissing == true)
        #expect(config.numParallel == 4)
        #expect(config.numGPU == 32)
        #expect(config.mainGPU == 0)
        #expect(config.lowVRAM == true)
        #expect(config.numCtx == 4096)
        #expect(config.healthCheck == false)
        #expect(config.healthCheckTimeout == 10.0)
    }

    // MARK: - Static Presets

    @Test("Default preset matches default init")
    func defaultPreset() {
        let config = OllamaConfiguration.default
        #expect(config.keepAlive == nil)
        #expect(config.pullOnMissing == false)
        #expect(config.healthCheck == true)
    }

    @Test("lowMemory preset has correct values")
    func lowMemoryPreset() {
        let config = OllamaConfiguration.lowMemory
        #expect(config.keepAlive == "1m")
        #expect(config.lowVRAM == true)
    }

    @Test("interactive preset has longer keep-alive")
    func interactivePreset() {
        let config = OllamaConfiguration.interactive
        #expect(config.keepAlive == "30m")
        #expect(config.healthCheck == true)
    }

    @Test("batch preset unloads immediately and skips health check")
    func batchPreset() {
        let config = OllamaConfiguration.batch
        #expect(config.keepAlive == "0")
        #expect(config.healthCheck == false)
    }

    @Test("alwaysOn preset keeps models loaded indefinitely")
    func alwaysOnPreset() {
        let config = OllamaConfiguration.alwaysOn
        #expect(config.keepAlive == "-1")
        #expect(config.healthCheck == true)
    }

    // MARK: - Options Generation

    @Test("options returns empty dict when no GPU settings")
    func optionsEmpty() {
        let config = OllamaConfiguration()
        let opts = config.options()
        #expect(opts.isEmpty)
    }

    @Test("options includes numGPU when set")
    func optionsIncludesNumGPU() {
        let config = OllamaConfiguration(numGPU: 16)
        let opts = config.options()
        #expect(opts["num_gpu"] as? Int == 16)
    }

    @Test("options includes mainGPU when set")
    func optionsIncludesMainGPU() {
        let config = OllamaConfiguration(mainGPU: 1)
        let opts = config.options()
        #expect(opts["main_gpu"] as? Int == 1)
    }

    @Test("options includes lowVRAM when true")
    func optionsIncludesLowVRAM() {
        let config = OllamaConfiguration(lowVRAM: true)
        let opts = config.options()
        #expect(opts["low_vram"] as? Bool == true)
    }

    @Test("options does not include lowVRAM when false")
    func optionsOmitsLowVRAMWhenFalse() {
        let config = OllamaConfiguration(lowVRAM: false)
        let opts = config.options()
        #expect(opts["low_vram"] == nil)
    }

    @Test("options includes numCtx when set")
    func optionsIncludesNumCtx() {
        let config = OllamaConfiguration(numCtx: 8192)
        let opts = config.options()
        #expect(opts["num_ctx"] as? Int == 8192)
    }

    @Test("options includes all GPU settings when all are set")
    func optionsAllGPUSettings() {
        let config = OllamaConfiguration(
            numGPU: 32,
            mainGPU: 0,
            lowVRAM: true,
            numCtx: 4096
        )
        let opts = config.options()
        #expect(opts["num_gpu"] as? Int == 32)
        #expect(opts["main_gpu"] as? Int == 0)
        #expect(opts["low_vram"] as? Bool == true)
        #expect(opts["num_ctx"] as? Int == 4096)
    }

    // MARK: - Fluent API

    @Test("Fluent keepAlive returns updated copy")
    func fluentKeepAlive() {
        let config = OllamaConfiguration.default.keepAlive("15m")
        #expect(config.keepAlive == "15m")
    }

    @Test("Fluent pullOnMissing returns updated copy")
    func fluentPullOnMissing() {
        let config = OllamaConfiguration.default.pullOnMissing(true)
        #expect(config.pullOnMissing == true)
    }

    @Test("Fluent numParallel returns updated copy")
    func fluentNumParallel() {
        let config = OllamaConfiguration.default.numParallel(8)
        #expect(config.numParallel == 8)
    }

    @Test("Fluent numGPU returns updated copy")
    func fluentNumGPU() {
        let config = OllamaConfiguration.default.numGPU(24)
        #expect(config.numGPU == 24)
    }

    @Test("Fluent cpuOnly sets numGPU to 0")
    func fluentCpuOnly() {
        let config = OllamaConfiguration.default.cpuOnly()
        #expect(config.numGPU == 0)
    }

    @Test("Fluent lowVRAM returns updated copy")
    func fluentLowVRAM() {
        let config = OllamaConfiguration.default.lowVRAM(true)
        #expect(config.lowVRAM == true)
    }

    @Test("Fluent contextSize returns updated copy")
    func fluentContextSize() {
        let config = OllamaConfiguration.default.contextSize(16384)
        #expect(config.numCtx == 16384)
    }

    @Test("Fluent healthCheck returns updated copy")
    func fluentHealthCheck() {
        let config = OllamaConfiguration.default.healthCheck(false)
        #expect(config.healthCheck == false)
    }

    @Test("Fluent API chaining works correctly")
    func fluentChaining() {
        let config = OllamaConfiguration.default
            .keepAlive("10m")
            .pullOnMissing(true)
            .numGPU(16)
            .contextSize(4096)
            .healthCheck(false)

        #expect(config.keepAlive == "10m")
        #expect(config.pullOnMissing == true)
        #expect(config.numGPU == 16)
        #expect(config.numCtx == 4096)
        #expect(config.healthCheck == false)
    }

    // MARK: - Codable

    @Test("OllamaConfiguration round-trips through JSON")
    func codableRoundTrip() throws {
        let original = OllamaConfiguration(
            keepAlive: "5m",
            pullOnMissing: true,
            numParallel: 2,
            numGPU: 16,
            mainGPU: 0,
            lowVRAM: true,
            numCtx: 2048,
            healthCheck: false,
            healthCheckTimeout: 10.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OllamaConfiguration.self, from: data)

        #expect(decoded.keepAlive == original.keepAlive)
        #expect(decoded.pullOnMissing == original.pullOnMissing)
        #expect(decoded.numParallel == original.numParallel)
        #expect(decoded.numGPU == original.numGPU)
        #expect(decoded.mainGPU == original.mainGPU)
        #expect(decoded.lowVRAM == original.lowVRAM)
        #expect(decoded.numCtx == original.numCtx)
        #expect(decoded.healthCheck == original.healthCheck)
        #expect(decoded.healthCheckTimeout == original.healthCheckTimeout)
    }

    @Test("Default OllamaConfiguration round-trips through JSON")
    func codableDefaultRoundTrip() throws {
        let original = OllamaConfiguration.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OllamaConfiguration.self, from: data)
        #expect(decoded == original)
    }

    @Test("All presets round-trip through JSON")
    func codablePresetsRoundTrip() throws {
        let presets: [OllamaConfiguration] = [
            .default, .lowMemory, .interactive, .batch, .alwaysOn
        ]
        for original in presets {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(OllamaConfiguration.self, from: data)
            #expect(decoded == original)
        }
    }

    // MARK: - Hashable / Equatable

    @Test("Equal configurations are equal")
    func equalConfigurations() {
        let a = OllamaConfiguration.default
        let b = OllamaConfiguration.default
        #expect(a == b)
    }

    @Test("Different configurations are not equal")
    func differentConfigurations() {
        let a = OllamaConfiguration.default
        let b = OllamaConfiguration.lowMemory
        #expect(a != b)
    }

    @Test("Sendable conformance compiles")
    func sendableConformance() {
        let config: Sendable = OllamaConfiguration.default
        #expect(config is OllamaConfiguration)
    }
}

// MARK: - OllamaModelStatus Tests

@Suite("OllamaModelStatus Tests")
struct OllamaModelStatusTests {

    @Test("available status exists")
    func availableStatus() {
        let status = OllamaModelStatus.available
        if case .available = status {
            // pass
        } else {
            Issue.record("Expected .available")
        }
    }

    @Test("pulling status stores progress")
    func pullingStatus() {
        let status = OllamaModelStatus.pulling(progress: 0.75)
        if case .pulling(let progress) = status {
            #expect(progress == 0.75)
        } else {
            Issue.record("Expected .pulling")
        }
    }

    @Test("notAvailable status exists")
    func notAvailableStatus() {
        let status = OllamaModelStatus.notAvailable
        if case .notAvailable = status {
            // pass
        } else {
            Issue.record("Expected .notAvailable")
        }
    }

    @Test("unknown status exists")
    func unknownStatus() {
        let status = OllamaModelStatus.unknown
        if case .unknown = status {
            // pass
        } else {
            Issue.record("Expected .unknown")
        }
    }

    @Test("Same statuses are equal")
    func sameStatusesEqual() {
        #expect(OllamaModelStatus.available == .available)
        #expect(OllamaModelStatus.notAvailable == .notAvailable)
        #expect(OllamaModelStatus.unknown == .unknown)
        #expect(OllamaModelStatus.pulling(progress: 0.5) == .pulling(progress: 0.5))
    }

    @Test("Different statuses are not equal")
    func differentStatusesNotEqual() {
        #expect(OllamaModelStatus.available != .notAvailable)
        #expect(OllamaModelStatus.pulling(progress: 0.5) != .pulling(progress: 0.7))
    }
}

// MARK: - OllamaServerStatus Tests

@Suite("OllamaServerStatus Tests")
struct OllamaServerStatusTests {

    @Test("running status exists")
    func runningStatus() {
        let status = OllamaServerStatus.running
        if case .running = status {
            // pass
        } else {
            Issue.record("Expected .running")
        }
    }

    @Test("notResponding status exists")
    func notRespondingStatus() {
        let status = OllamaServerStatus.notResponding
        if case .notResponding = status {
            // pass
        } else {
            Issue.record("Expected .notResponding")
        }
    }

    @Test("error status stores message")
    func errorStatus() {
        let status = OllamaServerStatus.error("connection refused")
        if case .error(let message) = status {
            #expect(message == "connection refused")
        } else {
            Issue.record("Expected .error")
        }
    }

    @Test("unknown status exists")
    func unknownStatus() {
        let status = OllamaServerStatus.unknown
        if case .unknown = status {
            // pass
        } else {
            Issue.record("Expected .unknown")
        }
    }

    @Test("Same statuses are equal")
    func sameStatusesEqual() {
        #expect(OllamaServerStatus.running == .running)
        #expect(OllamaServerStatus.notResponding == .notResponding)
        #expect(OllamaServerStatus.unknown == .unknown)
        #expect(OllamaServerStatus.error("msg") == .error("msg"))
    }

    @Test("Different statuses are not equal")
    func differentStatusesNotEqual() {
        #expect(OllamaServerStatus.running != .notResponding)
        #expect(OllamaServerStatus.error("a") != .error("b"))
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
