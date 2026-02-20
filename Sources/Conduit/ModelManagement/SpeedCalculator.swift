//
//  SpeedCalculator.swift
//  Conduit
//
//  Created by SwiftAI on 2025-12-17.
//

import Foundation

/// A thread-safe calculator for computing rolling average download speeds.
///
/// Uses a 5-second sliding window to track speed samples and compute
/// a smoothed average speed over time. This prevents speed fluctuations
/// from causing erratic progress estimates.
///
/// ## Usage
/// ```swift
/// let calculator = SpeedCalculator()
/// await calculator.addSample(bytes: 1024)
/// if let speed = await calculator.averageSpeed() {
///     print("Current speed: \(speed) bytes/second")
/// }
/// ```
actor SpeedCalculator {
    /// A single speed measurement sample.
    private struct Sample: Sendable {
        /// The timestamp when this sample was recorded.
        let timestamp: TimeInterval

        /// The cumulative number of bytes downloaded at this timestamp.
        let bytes: Int64
    }

    /// The collection of samples within the sliding window.
    private var samples: [Sample] = []

    /// The size of the sliding window in seconds.
    private let windowSize: TimeInterval = 5.0

    /// Provider for a monotonic timestamp in seconds.
    private let timeProvider: @Sendable () -> TimeInterval

    /// Initializes a new speed calculator with an empty sample set.
    ///
    /// - Parameter timeProvider: Monotonic time source (defaults to system uptime).
    init(timeProvider: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.timeProvider = timeProvider
    }

    /// Adds a new speed sample and prunes samples outside the sliding window.
    ///
    /// This method records the current time and cumulative byte count,
    /// then removes any samples older than the 5-second window.
    ///
    /// - Parameter bytes: The cumulative number of bytes downloaded.
    func addSample(bytes: Int64) {
        let now = timeProvider()

        if let last = samples.last, now < last.timestamp {
            // If the clock regresses, drop prior samples to avoid negative/invalid deltas.
            samples.removeAll(keepingCapacity: true)
        }
        samples.append(Sample(timestamp: now, bytes: bytes))

        // Keep only the last 5 seconds of samples
        samples = samples.filter { now - $0.timestamp <= windowSize }
    }

    /// Calculates the rolling average speed based on samples in the window.
    ///
    /// The speed is computed by dividing the change in bytes by the change
    /// in time between the first and last samples in the window.
    ///
    /// - Returns: The average speed in bytes per second, or `nil` if
    ///   insufficient data is available to compute a meaningful average.
    func averageSpeed() -> Double? {
        guard let first = samples.first,
              let last = samples.last,
              last.timestamp > first.timestamp else {
            return nil
        }

        let bytesDelta = Double(last.bytes - first.bytes)
        let timeDelta = last.timestamp - first.timestamp

        guard timeDelta > 0 else {
            return nil
        }

        return max(0, bytesDelta / timeDelta)
    }

    /// Resets the calculator by clearing all samples.
    ///
    /// Use this when starting a new download or when the speed
    /// calculation should restart from scratch.
    func reset() {
        samples.removeAll()
    }
}
