// ImageGenerationProgress.swift
// SwiftAI

import Foundation

/// Progress information during image generation.
///
/// Local diffusion models report step-by-step progress. Cloud providers
/// may not provide granular progress updates.
///
/// ## Usage
///
/// ```swift
/// let image = try await provider.generateImage(
///     prompt: "A mountain landscape",
///     onProgress: { progress in
///         print("Step \(progress.currentStep)/\(progress.totalSteps)")
///         print("ETA: \(progress.formattedETA)")
///         updateProgressBar(progress.fractionComplete)
///     }
/// )
/// ```
public struct ImageGenerationProgress: Sendable, Equatable {

    /// The current step in the diffusion process.
    public let currentStep: Int

    /// Total number of steps for this generation.
    public let totalSteps: Int

    /// Time elapsed since generation started.
    public let elapsedTime: TimeInterval

    /// Estimated time remaining (calculated from elapsed time and progress).
    public let estimatedTimeRemaining: TimeInterval?

    /// Fraction of generation complete (0.0 to 1.0).
    public var fractionComplete: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }

    /// Percentage complete (0 to 100).
    public var percentComplete: Int {
        Int(fractionComplete * 100)
    }

    /// Formatted ETA string (e.g., "~5s remaining").
    public var formattedETA: String {
        guard let eta = estimatedTimeRemaining, eta > 0 else {
            return "Calculating..."
        }
        if eta < 60 {
            return "~\(Int(eta))s remaining"
        } else {
            let minutes = Int(eta / 60)
            let seconds = Int(eta.truncatingRemainder(dividingBy: 60))
            return "~\(minutes)m \(seconds)s remaining"
        }
    }

    /// Creates a new progress instance.
    ///
    /// - Parameters:
    ///   - currentStep: The current diffusion step (1-indexed).
    ///   - totalSteps: Total number of steps for this generation.
    ///   - elapsedTime: Time elapsed since generation started.
    ///   - estimatedTimeRemaining: Optional explicit ETA. If nil, calculated from elapsed time.
    public init(
        currentStep: Int,
        totalSteps: Int,
        elapsedTime: TimeInterval,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.elapsedTime = elapsedTime

        // Calculate ETA if not provided
        if let eta = estimatedTimeRemaining {
            self.estimatedTimeRemaining = eta
        } else if currentStep > 0 {
            let avgTimePerStep = elapsedTime / Double(currentStep)
            self.estimatedTimeRemaining = avgTimePerStep * Double(totalSteps - currentStep)
        } else {
            self.estimatedTimeRemaining = nil
        }
    }
}

// MARK: - Convenience Initializers

extension ImageGenerationProgress {

    /// Creates a progress instance with just step counts.
    ///
    /// Useful for simple progress tracking without timing information.
    ///
    /// - Parameters:
    ///   - currentStep: The current diffusion step.
    ///   - totalSteps: Total number of steps.
    public init(currentStep: Int, totalSteps: Int) {
        self.init(
            currentStep: currentStep,
            totalSteps: totalSteps,
            elapsedTime: 0,
            estimatedTimeRemaining: nil
        )
    }

    /// Creates a completed progress instance.
    ///
    /// - Parameter totalSteps: The total number of steps that were completed.
    /// - Parameter elapsedTime: Total time taken for generation.
    public static func completed(totalSteps: Int, elapsedTime: TimeInterval) -> ImageGenerationProgress {
        ImageGenerationProgress(
            currentStep: totalSteps,
            totalSteps: totalSteps,
            elapsedTime: elapsedTime,
            estimatedTimeRemaining: 0
        )
    }
}

// MARK: - CustomStringConvertible

extension ImageGenerationProgress: CustomStringConvertible {
    public var description: String {
        "ImageGenerationProgress(\(currentStep)/\(totalSteps), \(percentComplete)%)"
    }
}
