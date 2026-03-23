import Foundation

/// Tracks download progress samples and derives an average byte/sec rate.
public actor SpeedCalculator {
    private struct Sample: Sendable {
        let bytes: Int64
        let timestamp: ContinuousClock.Instant
    }

    private let clock = ContinuousClock()
    private var samples: [Sample] = []

    public init() {}

    public func addSample(bytes: Int64) {
        samples.append(Sample(bytes: bytes, timestamp: clock.now))
    }

    public func averageSpeed() -> Double? {
        guard
            let first = samples.first,
            let last = samples.last,
            samples.count >= 2
        else {
            return nil
        }

        let duration = first.timestamp.duration(to: last.timestamp)
        let elapsedSeconds = Double(duration.components.seconds)
            + (Double(duration.components.attoseconds) / 1_000_000_000_000_000_000.0)
        guard elapsedSeconds > 0 else {
            return 0
        }

        let byteDelta = last.bytes - first.bytes
        guard byteDelta >= 0 else {
            return 0
        }

        return Double(byteDelta) / elapsedSeconds
    }

    public func reset() {
        samples.removeAll(keepingCapacity: true)
    }
}
