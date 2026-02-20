// SpeedCalculatorTests.swift
// ConduitTests

import Testing
import Foundation
@testable import Conduit

private final class TestTimeSource: @unchecked Sendable {
    private let lock = NSLock()
    private var now: TimeInterval

    init(now: TimeInterval = 0) {
        self.now = now
    }

    func advance(by delta: TimeInterval) {
        lock.lock()
        now += delta
        lock.unlock()
    }

    func current() -> TimeInterval {
        lock.lock()
        let value = now
        lock.unlock()
        return value
    }
}

@Suite("SpeedCalculator Tests")
struct SpeedCalculatorTests {

    @Test("Calculator returns nil with no samples")
    func testNoSamples() async {
        let timeSource = TestTimeSource()
        let calculator = SpeedCalculator(timeProvider: { timeSource.current() })

        let speed = await calculator.averageSpeed()
        #expect(speed == nil)
    }

    @Test("Calculator returns nil with single sample")
    func testSingleSample() async {
        let timeSource = TestTimeSource()
        let calculator = SpeedCalculator(timeProvider: { timeSource.current() })

        await calculator.addSample(bytes: 1024)

        let speed = await calculator.averageSpeed()
        #expect(speed == nil) // Need at least 2 samples with time difference
    }

    @Test("Calculator computes speed correctly with two samples")
    func testTwoSamples() async {
        let timeSource = TestTimeSource()
        let calculator = SpeedCalculator(timeProvider: { timeSource.current() })

        // Add first sample
        await calculator.addSample(bytes: 0)

        // Advance time to ensure time difference
        timeSource.advance(by: 0.1)

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
        let timeSource = TestTimeSource()
        let calculator = SpeedCalculator(timeProvider: { timeSource.current() })

        // Simulate progressive download
        let samples = [
            (bytes: Int64(0), delay: 0),
            (bytes: Int64(1_048_576), delay: 100),    // 1MB after 100ms
            (bytes: Int64(2_097_152), delay: 100),    // 2MB after 200ms
            (bytes: Int64(3_145_728), delay: 100),    // 3MB after 300ms
        ]

        for sample in samples {
            if sample.delay > 0 {
                timeSource.advance(by: TimeInterval(sample.delay) / 1000.0)
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
        let timeSource = TestTimeSource()
        let calculator = SpeedCalculator(timeProvider: { timeSource.current() })

        // Add samples
        await calculator.addSample(bytes: 0)
        timeSource.advance(by: 0.05)
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
        let timeSource = TestTimeSource()
        let calculator = SpeedCalculator(timeProvider: { timeSource.current() })

        // Add samples with same byte count (no progress)
        await calculator.addSample(bytes: 1024)
        timeSource.advance(by: 0.1)
        await calculator.addSample(bytes: 1024)

        let speed = await calculator.averageSpeed()
        #expect(speed != nil)
        #expect(speed == 0.0)
    }

    @Test("Calculator handles large byte counts")
    func testLargeBytes() async {
        let timeSource = TestTimeSource()
        let calculator = SpeedCalculator(timeProvider: { timeSource.current() })

        // Simulate downloading a 10GB file
        let tenGB = Int64(10 * 1024 * 1024 * 1024)

        await calculator.addSample(bytes: 0)
        timeSource.advance(by: 0.1)
        await calculator.addSample(bytes: tenGB)

        let speed = await calculator.averageSpeed()
        #expect(speed != nil)

        if let speed = speed {
            // Should handle large numbers without overflow
            #expect(speed > 0)
        }
    }
}
