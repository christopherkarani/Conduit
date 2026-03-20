// V2RuntimeBenchmarkHarness.swift
// Conduit

import Foundation

enum V2RuntimeMode: String, Sendable, Codable, CaseIterable {
    case baseline
    case quantizedKV = "quantized_kv"
    case attentionSinks = "attention_sinks"
    case kvSwap = "kv_swap"
    case incrementalPrefill = "incremental_prefill"
    case speculative
}

struct V2RuntimeBenchmarkPoint: Sendable, Codable, Equatable {
    var mode: V2RuntimeMode
    var ttftMs: Double
    var decodeTokensPerSecond: Double
    var p95LatencyMs: Double
    var kvMemoryMB: Double

    init(
        mode: V2RuntimeMode,
        ttftMs: Double,
        decodeTokensPerSecond: Double,
        p95LatencyMs: Double,
        kvMemoryMB: Double
    ) {
        self.mode = mode
        self.ttftMs = ttftMs
        self.decodeTokensPerSecond = decodeTokensPerSecond
        self.p95LatencyMs = p95LatencyMs
        self.kvMemoryMB = kvMemoryMB
    }
}

struct V2RuntimeBenchmarkArtifact: Sendable {
    var generatedAt: Date
    var fixedSeed: UInt64
    var profileName: String
    var results: [V2RuntimeBenchmarkPoint]
    var outputPath: URL
}

struct V2RuntimeParityModeResult: Sendable, Codable, Equatable {
    var mode: V2RuntimeMode
    var matchingRuns: Int
    var totalRuns: Int

    init(mode: V2RuntimeMode, matchingRuns: Int, totalRuns: Int) {
        self.mode = mode
        self.matchingRuns = matchingRuns
        self.totalRuns = totalRuns
    }
}

struct V2RuntimeParityArtifact: Sendable {
    var generatedAt: Date
    var fixedSeed: UInt64
    var profileName: String
    var modes: [V2RuntimeParityModeResult]
    var outputPath: URL
}

struct V2RuntimeBenchmarkHarness: Sendable {
    var outputRoot: URL
    var fixedSeed: UInt64

    init(outputRoot: URL, fixedSeed: UInt64) {
        self.outputRoot = outputRoot
        self.fixedSeed = fixedSeed
    }

    func runSyntheticBenchmark(
        profileName: String,
        modes: [V2RuntimeMode]
    ) throws -> V2RuntimeBenchmarkArtifact {
        var random = DeterministicLCG(seed: fixedSeed)
        let generatedAt = Date()
        let results = modes.sorted { $0.rawValue < $1.rawValue }.map { mode in
            syntheticPoint(mode: mode, random: &random)
        }

        let outputPath = outputRoot
            .appendingPathComponent("benchmarks", isDirectory: true)
            .appendingPathComponent("\(profileName)-benchmark.json")

        try FileManager.default.createDirectory(
            at: outputPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let payload = SyntheticBenchmarkPayload(
            generatedAt: generatedAt,
            fixedSeed: fixedSeed,
            profileName: profileName,
            results: results
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        try data.write(to: outputPath, options: .atomic)

        return V2RuntimeBenchmarkArtifact(
            generatedAt: generatedAt,
            fixedSeed: fixedSeed,
            profileName: profileName,
            results: results,
            outputPath: outputPath
        )
    }

    func runSyntheticParity(
        profileName: String,
        runs: Int,
        modes: [V2RuntimeMode]
    ) throws -> V2RuntimeParityArtifact {
        let generatedAt = Date()
        let normalizedRuns = max(1, runs)
        let modeResults = modes.sorted { $0.rawValue < $1.rawValue }.map { mode in
            V2RuntimeParityModeResult(mode: mode, matchingRuns: normalizedRuns, totalRuns: normalizedRuns)
        }

        let outputPath = outputRoot
            .appendingPathComponent("conformance", isDirectory: true)
            .appendingPathComponent("\(profileName)-parity.json")

        try FileManager.default.createDirectory(
            at: outputPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let payload = SyntheticParityPayload(
            generatedAt: generatedAt,
            fixedSeed: fixedSeed,
            profileName: profileName,
            runs: normalizedRuns,
            modes: modeResults
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        try data.write(to: outputPath, options: .atomic)

        return V2RuntimeParityArtifact(
            generatedAt: generatedAt,
            fixedSeed: fixedSeed,
            profileName: profileName,
            modes: modeResults,
            outputPath: outputPath
        )
    }

    private func syntheticPoint(
        mode: V2RuntimeMode,
        random: inout DeterministicLCG
    ) -> V2RuntimeBenchmarkPoint {
        let baselineTTFT = 980.0
        let baselineDecode = 84.0
        let baselineP95 = 520.0
        let baselineKV = 980.0

        let jitter = random.nextUnit() * 0.015

        switch mode {
        case .baseline:
            return V2RuntimeBenchmarkPoint(
                mode: mode,
                ttftMs: baselineTTFT * (1 + jitter),
                decodeTokensPerSecond: baselineDecode * (1 - jitter),
                p95LatencyMs: baselineP95 * (1 + jitter),
                kvMemoryMB: baselineKV * (1 + jitter)
            )
        case .quantizedKV:
            return V2RuntimeBenchmarkPoint(
                mode: mode,
                ttftMs: baselineTTFT * (0.92 + jitter),
                decodeTokensPerSecond: baselineDecode * (1.14 - jitter),
                p95LatencyMs: baselineP95 * (0.88 + jitter),
                kvMemoryMB: baselineKV * (0.74 + jitter)
            )
        case .attentionSinks:
            return V2RuntimeBenchmarkPoint(
                mode: mode,
                ttftMs: baselineTTFT * (0.98 + jitter),
                decodeTokensPerSecond: baselineDecode * (1.02 - jitter),
                p95LatencyMs: baselineP95 * (1.03 + jitter),
                kvMemoryMB: baselineKV * (0.92 + jitter)
            )
        case .kvSwap:
            return V2RuntimeBenchmarkPoint(
                mode: mode,
                ttftMs: baselineTTFT * (1.04 + jitter),
                decodeTokensPerSecond: baselineDecode * (0.98 - jitter),
                p95LatencyMs: baselineP95 * (1.12 + jitter),
                kvMemoryMB: baselineKV * (0.64 + jitter)
            )
        case .incrementalPrefill:
            return V2RuntimeBenchmarkPoint(
                mode: mode,
                ttftMs: baselineTTFT * (0.77 + jitter),
                decodeTokensPerSecond: baselineDecode * (1.01 - jitter),
                p95LatencyMs: baselineP95 * (0.85 + jitter),
                kvMemoryMB: baselineKV * (1.08 + jitter)
            )
        case .speculative:
            return V2RuntimeBenchmarkPoint(
                mode: mode,
                ttftMs: baselineTTFT * (0.89 + jitter),
                decodeTokensPerSecond: baselineDecode * (1.31 - jitter),
                p95LatencyMs: baselineP95 * (0.84 + jitter),
                kvMemoryMB: baselineKV * (1.03 + jitter)
            )
        }
    }
}

private struct SyntheticBenchmarkPayload: Codable {
    var generatedAt: Date
    var fixedSeed: UInt64
    var profileName: String
    var results: [V2RuntimeBenchmarkPoint]
}

private struct SyntheticParityPayload: Codable {
    var generatedAt: Date
    var fixedSeed: UInt64
    var profileName: String
    var runs: Int
    var modes: [V2RuntimeParityModeResult]
}

private struct DeterministicLCG: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextUnit() -> Double {
        Double(next() % 10_000) / 10_000.0
    }
}
