// ImageGenerationProgressTests.swift
// SwiftAI

import Testing
@testable import SwiftAI

@Suite("ImageGenerationProgress Tests")
struct ImageGenerationProgressTests {

    // MARK: - Initialization Tests

    @Test("Full initializer sets all properties")
    func fullInitializer() {
        let progress = ImageGenerationProgress(
            currentStep: 5,
            totalSteps: 20,
            elapsedTime: 2.5,
            estimatedTimeRemaining: 7.5
        )

        #expect(progress.currentStep == 5)
        #expect(progress.totalSteps == 20)
        #expect(progress.elapsedTime == 2.5)
        #expect(progress.estimatedTimeRemaining == 7.5)
    }

    @Test("Simple initializer with just steps")
    func simpleInitializer() {
        let progress = ImageGenerationProgress(currentStep: 3, totalSteps: 10)

        #expect(progress.currentStep == 3)
        #expect(progress.totalSteps == 10)
        #expect(progress.elapsedTime == 0)
        #expect(progress.estimatedTimeRemaining == nil)
    }

    @Test("Auto-calculates ETA when not provided")
    func autoCalculatesETA() {
        let progress = ImageGenerationProgress(
            currentStep: 5,
            totalSteps: 10,
            elapsedTime: 5.0  // 1 second per step
        )

        // Should estimate 5 more seconds (5 remaining steps × 1 sec/step)
        #expect(progress.estimatedTimeRemaining != nil)
        #expect(progress.estimatedTimeRemaining! == 5.0)
    }

    @Test("Completed factory method")
    func completedFactoryMethod() {
        let progress = ImageGenerationProgress.completed(totalSteps: 20, elapsedTime: 10.0)

        #expect(progress.currentStep == 20)
        #expect(progress.totalSteps == 20)
        #expect(progress.fractionComplete == 1.0)
        #expect(progress.percentComplete == 100)
        #expect(progress.estimatedTimeRemaining == 0)
    }

    @Test("Auto-calculates ETA returns nil when currentStep is zero")
    func autoCalculatesETAZeroSteps() {
        let progress = ImageGenerationProgress(
            currentStep: 0,
            totalSteps: 10,
            elapsedTime: 0.0
        )

        #expect(progress.estimatedTimeRemaining == nil)
    }

    // MARK: - Computed Properties Tests

    @Test("fractionComplete calculates correctly")
    func fractionComplete() {
        let progress = ImageGenerationProgress(currentStep: 5, totalSteps: 20)
        #expect(progress.fractionComplete == 0.25)
    }

    @Test("fractionComplete handles zero totalSteps")
    func fractionCompleteZeroSteps() {
        let progress = ImageGenerationProgress(currentStep: 0, totalSteps: 0)
        #expect(progress.fractionComplete == 0)
    }

    @Test("percentComplete rounds correctly")
    func percentComplete() {
        let progress = ImageGenerationProgress(currentStep: 1, totalSteps: 3)
        #expect(progress.percentComplete == 33)  // 0.333... → 33
    }

    @Test("percentComplete is 100 when complete")
    func percentCompleteFullCompletion() {
        let progress = ImageGenerationProgress(currentStep: 10, totalSteps: 10)
        #expect(progress.percentComplete == 100)
    }

    @Test("formattedETA shows calculating when no ETA")
    func formattedETACalculating() {
        let progress = ImageGenerationProgress(currentStep: 0, totalSteps: 10)
        #expect(progress.formattedETA == "Calculating...")
    }

    @Test("formattedETA shows calculating when ETA is zero")
    func formattedETAZero() {
        let progress = ImageGenerationProgress(
            currentStep: 10,
            totalSteps: 10,
            elapsedTime: 5.0,
            estimatedTimeRemaining: 0.0
        )
        #expect(progress.formattedETA == "Calculating...")
    }

    @Test("formattedETA shows seconds")
    func formattedETASeconds() {
        let progress = ImageGenerationProgress(
            currentStep: 5,
            totalSteps: 10,
            elapsedTime: 5.0,
            estimatedTimeRemaining: 30.0
        )
        #expect(progress.formattedETA == "~30s remaining")
    }

    @Test("formattedETA shows minutes and seconds")
    func formattedETAMinutes() {
        let progress = ImageGenerationProgress(
            currentStep: 1,
            totalSteps: 10,
            elapsedTime: 10.0,
            estimatedTimeRemaining: 90.0
        )
        #expect(progress.formattedETA == "~1m 30s remaining")
    }

    @Test("formattedETA shows multiple minutes")
    func formattedETAMultipleMinutes() {
        let progress = ImageGenerationProgress(
            currentStep: 1,
            totalSteps: 100,
            elapsedTime: 10.0,
            estimatedTimeRemaining: 185.0
        )
        #expect(progress.formattedETA == "~3m 5s remaining")
    }

    // MARK: - Equatable Tests

    @Test("Equal progress instances are equal")
    func equalInstances() {
        let p1 = ImageGenerationProgress(currentStep: 5, totalSteps: 10, elapsedTime: 2.0)
        let p2 = ImageGenerationProgress(currentStep: 5, totalSteps: 10, elapsedTime: 2.0)
        #expect(p1 == p2)
    }

    @Test("Different progress instances are not equal")
    func differentInstances() {
        let p1 = ImageGenerationProgress(currentStep: 5, totalSteps: 10)
        let p2 = ImageGenerationProgress(currentStep: 6, totalSteps: 10)
        #expect(p1 != p2)
    }

    @Test("Different elapsed times make instances unequal")
    func differentElapsedTimes() {
        let p1 = ImageGenerationProgress(currentStep: 5, totalSteps: 10, elapsedTime: 1.0)
        let p2 = ImageGenerationProgress(currentStep: 5, totalSteps: 10, elapsedTime: 2.0)
        #expect(p1 != p2)
    }

    // MARK: - CustomStringConvertible Tests

    @Test("Description format is correct")
    func description() {
        let progress = ImageGenerationProgress(currentStep: 5, totalSteps: 20)
        #expect(progress.description == "ImageGenerationProgress(5/20, 25%)")
    }

    @Test("Description for completed progress")
    func descriptionCompleted() {
        let progress = ImageGenerationProgress.completed(totalSteps: 10, elapsedTime: 5.0)
        #expect(progress.description == "ImageGenerationProgress(10/10, 100%)")
    }

    // MARK: - Sendable Tests

    @Test("ImageGenerationProgress is Sendable across tasks")
    func sendableAcrossTasks() async {
        let progress = ImageGenerationProgress(currentStep: 5, totalSteps: 10)

        await Task {
            #expect(progress.currentStep == 5)
            #expect(progress.totalSteps == 10)
        }.value
    }

    // MARK: - Edge Cases

    @Test("Handles fractional elapsed time")
    func fractionalElapsedTime() {
        let progress = ImageGenerationProgress(
            currentStep: 3,
            totalSteps: 10,
            elapsedTime: 1.234
        )

        #expect(progress.elapsedTime == 1.234)
        #expect(progress.estimatedTimeRemaining != nil)
    }

    @Test("Handles large step counts")
    func largeStepCounts() {
        let progress = ImageGenerationProgress(currentStep: 500, totalSteps: 1000)

        #expect(progress.fractionComplete == 0.5)
        #expect(progress.percentComplete == 50)
    }

    @Test("Handles single step generation")
    func singleStepGeneration() {
        let progress = ImageGenerationProgress(currentStep: 1, totalSteps: 1)

        #expect(progress.fractionComplete == 1.0)
        #expect(progress.percentComplete == 100)
    }
}
