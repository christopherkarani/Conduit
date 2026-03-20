// V2RuntimeBenchmarkHarnessTests.swift
// ConduitTests

import Foundation
import Testing
@testable import ConduitAdvanced

@Suite("V2 Runtime Benchmark Harness")
struct V2RuntimeBenchmarkHarnessTests {
    @Test("deterministic benchmark harness writes stable machine-readable artifact")
    func writesStableArtifact() async throws {
        let harness = V2RuntimeBenchmarkHarness(
            outputRoot: URL(fileURLWithPath: "/tmp/phase7_v2_final_2026-02-27"),
            fixedSeed: 0xC0FFEE27
        )

        let artifact = try harness.runSyntheticBenchmark(
            profileName: "p0-baseline",
            modes: [.baseline, .quantizedKV, .attentionSinks, .kvSwap, .incrementalPrefill, .speculative]
        )

        #expect(artifact.fixedSeed == 0xC0FFEE27)
        #expect(artifact.results.count == 6)
        #expect(FileManager.default.fileExists(atPath: artifact.outputPath.path))
    }

    @Test("deterministic parity harness reports 100/100 stability for synthetic runtime modes")
    func parityHarnessReportsStability() async throws {
        let harness = V2RuntimeBenchmarkHarness(
            outputRoot: URL(fileURLWithPath: "/tmp/phase7_v2_final_2026-02-27"),
            fixedSeed: 0xC0FFEE27
        )

        let artifact = try harness.runSyntheticParity(
            profileName: "p0-parity",
            runs: 100,
            modes: [.baseline, .quantizedKV, .attentionSinks, .kvSwap, .incrementalPrefill, .speculative]
        )

        #expect(artifact.modes.count == 6)
        #expect(artifact.modes.allSatisfy { $0.matchingRuns == 100 })
        #expect(FileManager.default.fileExists(atPath: artifact.outputPath.path))
    }
}
