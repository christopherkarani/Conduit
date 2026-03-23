// SpeedCalculatorTests.swift
// ConduitTests

import Testing
import Foundation
@testable import ConduitAdvanced

@Suite("SpeedCalculator Tests")
struct SpeedCalculatorTests {

    @Test("Calculator returns nil with no samples")
    func testNoSamples() async {
        let calculator = SpeedCalculator()

        let speed = await calculator.averageSpeed()
        #expect(speed == nil)
    }

    @Test("Calculator returns nil with single sample")
    func testSingleSample() async {
        let calculator = SpeedCalculator()

        await calculator.addSample(bytes: 1024)

        let speed = await calculator.averageSpeed()
        #expect(speed == nil) // Need at least 2 samples with time difference
    }

    @Test("Calculator computes speed correctly with two samples")
    func testTwoSamples() async {
        let calculator = SpeedCalculator()

        // Add first sample
        await calculator.addSample(bytes: 0)

        // Wait a bit to ensure time difference
        try? await Task.sleep(for: .milliseconds(100))

        // Add second sample: 1MB downloaded after 100ms
        await calculator.addSample(bytes: 1_048_576)

        let speed = await calculator.averageSpeed()
        #expect(speed != nil)

        if let speed = speed {
            // Speed should be roughly 1MB / 0.1s = 10 MB/s = 10,485,760 bytes/s
            // Allow for timing variance
            #expect(speed > 5_000_000) // At least 5 MB/s
            #expect(speed < 20_000_000) // At most 20 MB/s
        }
    }

    @Test("Calculator handles multiple samples")
    func testMultipleSamples() async {
        let calculator = SpeedCalculator()

        // Simulate progressive download
        let samples = [
            (bytes: Int64(0), delay: 0),
            (bytes: Int64(1_048_576), delay: 100),    // 1MB after 100ms
            (bytes: Int64(2_097_152), delay: 100),    // 2MB after 200ms
            (bytes: Int64(3_145_728), delay: 100),    // 3MB after 300ms
        ]

        for sample in samples {
            if sample.delay > 0 {
                try? await Task.sleep(for: .milliseconds(sample.delay))
            }
            await calculator.addSample(bytes: sample.bytes)
        }

        let speed = await calculator.averageSpeed()
        #expect(speed != nil)

        if let speed = speed {
            // Average speed should be around 3MB / 0.3s = 10 MB/s
            #expect(speed > 5_000_000)
            #expect(speed < 20_000_000)
        }
    }

    @Test("Calculator resets correctly")
    func testReset() async {
        let calculator = SpeedCalculator()

        // Add samples
        await calculator.addSample(bytes: 0)
        try? await Task.sleep(for: .milliseconds(50))
        await calculator.addSample(bytes: 1_048_576)

        let speedBefore = await calculator.averageSpeed()
        #expect(speedBefore != nil)

        // Reset
        await calculator.reset()

        let speedAfter = await calculator.averageSpeed()
        #expect(speedAfter == nil)
    }

    @Test("Calculator handles zero speed gracefully")
    func testZeroSpeed() async {
        let calculator = SpeedCalculator()

        // Add samples with same byte count (no progress)
        await calculator.addSample(bytes: 1024)
        try? await Task.sleep(for: .milliseconds(100))
        await calculator.addSample(bytes: 1024)

        let speed = await calculator.averageSpeed()
        #expect(speed != nil)
        #expect(speed == 0.0)
    }

    @Test("Calculator handles large byte counts")
    func testLargeBytes() async {
        let calculator = SpeedCalculator()

        // Simulate downloading a 10GB file
        let tenGB = Int64(10 * 1024 * 1024 * 1024)

        await calculator.addSample(bytes: 0)
        try? await Task.sleep(for: .milliseconds(100))
        await calculator.addSample(bytes: tenGB)

        let speed = await calculator.averageSpeed()
        #expect(speed != nil)

        if let speed = speed {
            // Should handle large numbers without overflow
            #expect(speed > 0)
        }
    }
}
