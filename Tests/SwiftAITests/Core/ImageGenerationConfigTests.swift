// ImageGenerationConfigTests.swift
// SwiftAI Tests

import XCTest
@testable import SwiftAI

/// Comprehensive test suite for ImageGenerationConfig.
///
/// Tests cover:
/// - Default values
/// - Presets (default, highQuality, fast, square512, square1024, landscape, portrait)
/// - Fluent API (immutability, chaining)
/// - Hashable/Equatable (equality, hashing)
/// - hasParameters computed property
/// - Edge cases
final class ImageGenerationConfigTests: XCTestCase {

    // MARK: - Default Values Tests

    func testDefaultWidth() {
        let config = ImageGenerationConfig.default
        XCTAssertNil(config.width, "Default width should be nil")
    }

    func testDefaultHeight() {
        let config = ImageGenerationConfig.default
        XCTAssertNil(config.height, "Default height should be nil")
    }

    func testDefaultSteps() {
        let config = ImageGenerationConfig.default
        XCTAssertNil(config.steps, "Default steps should be nil")
    }

    func testDefaultGuidanceScale() {
        let config = ImageGenerationConfig.default
        XCTAssertNil(config.guidanceScale, "Default guidanceScale should be nil")
    }

    func testDefaultHasNoParameters() {
        let config = ImageGenerationConfig.default
        XCTAssertFalse(config.hasParameters, "Default config should have no parameters")
    }

    // MARK: - Preset Tests

    func testHighQualityPreset() {
        let config = ImageGenerationConfig.highQuality
        XCTAssertNil(config.width, "High quality should not set width")
        XCTAssertNil(config.height, "High quality should not set height")
        XCTAssertEqual(config.steps, 50, "High quality should have 50 steps")
        XCTAssertEqual(
            Double(config.guidanceScale!),
            7.5,
            accuracy: 0.001,
            "High quality should have guidance scale of 7.5"
        )
        XCTAssertTrue(config.hasParameters, "High quality should have parameters")
    }

    func testFastPreset() {
        let config = ImageGenerationConfig.fast
        XCTAssertNil(config.width, "Fast should not set width")
        XCTAssertNil(config.height, "Fast should not set height")
        XCTAssertEqual(config.steps, 20, "Fast should have 20 steps")
        XCTAssertNil(config.guidanceScale, "Fast should not set guidance scale")
        XCTAssertTrue(config.hasParameters, "Fast should have parameters")
    }

    func testSquare512Preset() {
        let config = ImageGenerationConfig.square512
        XCTAssertEqual(config.width, 512, "Square512 should have width of 512")
        XCTAssertEqual(config.height, 512, "Square512 should have height of 512")
        XCTAssertNil(config.steps, "Square512 should not set steps")
        XCTAssertNil(config.guidanceScale, "Square512 should not set guidance scale")
        XCTAssertTrue(config.hasParameters, "Square512 should have parameters")
    }

    func testSquare1024Preset() {
        let config = ImageGenerationConfig.square1024
        XCTAssertEqual(config.width, 1024, "Square1024 should have width of 1024")
        XCTAssertEqual(config.height, 1024, "Square1024 should have height of 1024")
        XCTAssertNil(config.steps, "Square1024 should not set steps")
        XCTAssertNil(config.guidanceScale, "Square1024 should not set guidance scale")
        XCTAssertTrue(config.hasParameters, "Square1024 should have parameters")
    }

    func testLandscapePreset() {
        let config = ImageGenerationConfig.landscape
        XCTAssertEqual(config.width, 1024, "Landscape should have width of 1024")
        XCTAssertEqual(config.height, 768, "Landscape should have height of 768")
        XCTAssertNil(config.steps, "Landscape should not set steps")
        XCTAssertNil(config.guidanceScale, "Landscape should not set guidance scale")
        XCTAssertTrue(config.hasParameters, "Landscape should have parameters")
    }

    func testPortraitPreset() {
        let config = ImageGenerationConfig.portrait
        XCTAssertEqual(config.width, 768, "Portrait should have width of 768")
        XCTAssertEqual(config.height, 1024, "Portrait should have height of 1024")
        XCTAssertNil(config.steps, "Portrait should not set steps")
        XCTAssertNil(config.guidanceScale, "Portrait should not set guidance scale")
        XCTAssertTrue(config.hasParameters, "Portrait should have parameters")
    }

    // MARK: - Fluent API Tests

    func testFluentWidthReturnsNewInstance() {
        let original = ImageGenerationConfig.default
        let modified = original.width(1024)

        XCTAssertNil(original.width, "Original should remain unchanged")
        XCTAssertEqual(modified.width, 1024, "Modified should have new width")
    }

    func testFluentHeightReturnsNewInstance() {
        let original = ImageGenerationConfig.default
        let modified = original.height(768)

        XCTAssertNil(original.height, "Original should remain unchanged")
        XCTAssertEqual(modified.height, 768, "Modified should have new height")
    }

    func testFluentStepsReturnsNewInstance() {
        let original = ImageGenerationConfig.default
        let modified = original.steps(30)

        XCTAssertNil(original.steps, "Original should remain unchanged")
        XCTAssertEqual(modified.steps, 30, "Modified should have new steps")
    }

    func testFluentGuidanceScaleReturnsNewInstance() {
        let original = ImageGenerationConfig.default
        let modified = original.guidanceScale(8.0)

        XCTAssertNil(original.guidanceScale, "Original should remain unchanged")
        XCTAssertEqual(Double(modified.guidanceScale!), 8.0, accuracy: 0.001, "Modified should have new guidance scale")
    }

    func testFluentSizeReturnsNewInstance() {
        let original = ImageGenerationConfig.default
        let modified = original.size(width: 512, height: 768)

        XCTAssertNil(original.width, "Original width should remain unchanged")
        XCTAssertNil(original.height, "Original height should remain unchanged")
        XCTAssertEqual(modified.width, 512, "Modified should have new width")
        XCTAssertEqual(modified.height, 768, "Modified should have new height")
    }

    func testFluentChaining() {
        let config = ImageGenerationConfig.default
            .width(1024)
            .height(768)
            .steps(40)
            .guidanceScale(10.0)

        XCTAssertEqual(config.width, 1024, "Chained width should be set")
        XCTAssertEqual(config.height, 768, "Chained height should be set")
        XCTAssertEqual(config.steps, 40, "Chained steps should be set")
        XCTAssertEqual(Double(config.guidanceScale!), 10.0, accuracy: 0.001, "Chained guidance scale should be set")
    }

    func testFluentChainingWithSize() {
        let config = ImageGenerationConfig.default
            .size(width: 512, height: 512)
            .steps(25)
            .guidanceScale(7.5)

        XCTAssertEqual(config.width, 512, "Width should be set via size()")
        XCTAssertEqual(config.height, 512, "Height should be set via size()")
        XCTAssertEqual(config.steps, 25, "Steps should be set")
        XCTAssertEqual(Double(config.guidanceScale!), 7.5, accuracy: 0.001, "Guidance scale should be set")
    }

    func testFluentModificationPreservesOtherProperties() {
        let config = ImageGenerationConfig(width: 512, height: 512, steps: 30, guidanceScale: 7.5)
        let modified = config.width(1024)

        XCTAssertEqual(modified.width, 1024, "Width should be updated")
        XCTAssertEqual(modified.height, 512, "Height should be preserved")
        XCTAssertEqual(modified.steps, 30, "Steps should be preserved")
        XCTAssertEqual(Double(modified.guidanceScale!), 7.5, accuracy: 0.001, "Guidance scale should be preserved")
    }

    // MARK: - hasParameters Tests

    func testHasParametersWithWidth() {
        let config = ImageGenerationConfig(width: 512)
        XCTAssertTrue(config.hasParameters, "Should have parameters when width is set")
    }

    func testHasParametersWithHeight() {
        let config = ImageGenerationConfig(height: 768)
        XCTAssertTrue(config.hasParameters, "Should have parameters when height is set")
    }

    func testHasParametersWithSteps() {
        let config = ImageGenerationConfig(steps: 30)
        XCTAssertTrue(config.hasParameters, "Should have parameters when steps is set")
    }

    func testHasParametersWithGuidanceScale() {
        let config = ImageGenerationConfig(guidanceScale: 7.5)
        XCTAssertTrue(config.hasParameters, "Should have parameters when guidance scale is set")
    }

    func testHasParametersWithAllNil() {
        let config = ImageGenerationConfig()
        XCTAssertFalse(config.hasParameters, "Should not have parameters when all are nil")
    }

    func testHasParametersWithMultipleSet() {
        let config = ImageGenerationConfig(width: 512, height: 512, steps: 30, guidanceScale: 7.5)
        XCTAssertTrue(config.hasParameters, "Should have parameters when any is set")
    }

    // MARK: - Hashable/Equatable Tests

    func testEquality() {
        let config1 = ImageGenerationConfig(width: 1024, height: 768, steps: 30, guidanceScale: 7.5)
        let config2 = ImageGenerationConfig(width: 1024, height: 768, steps: 30, guidanceScale: 7.5)

        XCTAssertEqual(config1, config2, "Configs with same values should be equal")
    }

    func testInequalityDifferentWidth() {
        let config1 = ImageGenerationConfig(width: 512)
        let config2 = ImageGenerationConfig(width: 1024)

        XCTAssertNotEqual(config1, config2, "Configs with different widths should not be equal")
    }

    func testInequalityDifferentHeight() {
        let config1 = ImageGenerationConfig(height: 512)
        let config2 = ImageGenerationConfig(height: 768)

        XCTAssertNotEqual(config1, config2, "Configs with different heights should not be equal")
    }

    func testInequalityDifferentSteps() {
        let config1 = ImageGenerationConfig(steps: 20)
        let config2 = ImageGenerationConfig(steps: 50)

        XCTAssertNotEqual(config1, config2, "Configs with different steps should not be equal")
    }

    func testInequalityDifferentGuidanceScale() {
        let config1 = ImageGenerationConfig(guidanceScale: 5.0)
        let config2 = ImageGenerationConfig(guidanceScale: 10.0)

        XCTAssertNotEqual(config1, config2, "Configs with different guidance scales should not be equal")
    }

    func testHashableInSet() {
        let config1 = ImageGenerationConfig.square512
        let config2 = ImageGenerationConfig.square1024
        let config3 = ImageGenerationConfig.square512 // Same as config1

        let set: Set<ImageGenerationConfig> = [config1, config2, config3]

        XCTAssertEqual(set.count, 2, "Set should contain 2 unique configs")
        XCTAssertTrue(set.contains(config1), "Set should contain config1")
        XCTAssertTrue(set.contains(config2), "Set should contain config2")
    }

    func testHashableInDictionary() {
        let config1 = ImageGenerationConfig.default
        let config2 = ImageGenerationConfig.highQuality

        var dict: [ImageGenerationConfig: String] = [:]
        dict[config1] = "default"
        dict[config2] = "highQuality"

        XCTAssertEqual(dict[config1], "default")
        XCTAssertEqual(dict[config2], "highQuality")
        XCTAssertEqual(dict.count, 2)
    }

    // MARK: - Edge Cases

    func testZeroWidth() {
        let config = ImageGenerationConfig(width: 0)
        XCTAssertEqual(config.width, 0, "Zero width should be allowed")
        XCTAssertTrue(config.hasParameters, "Should have parameters with zero width")
    }

    func testNegativeWidth() {
        let config = ImageGenerationConfig(width: -100)
        XCTAssertEqual(config.width, -100, "Negative width should be allowed (will be validated by API)")
    }

    func testVeryLargeWidth() {
        let config = ImageGenerationConfig(width: 8192)
        XCTAssertEqual(config.width, 8192, "Large width should be allowed")
    }

    func testZeroSteps() {
        let config = ImageGenerationConfig(steps: 0)
        XCTAssertEqual(config.steps, 0, "Zero steps should be allowed")
    }

    func testNegativeGuidanceScale() {
        let config = ImageGenerationConfig(guidanceScale: -1.0)
        XCTAssertEqual(
            Double(config.guidanceScale!),
            -1.0,
            accuracy: 0.001,
            "Negative guidance scale should be allowed"
        )
    }

    func testComplexChaining() {
        let config = ImageGenerationConfig.highQuality
            .width(1024)
            .height(768)
            .steps(60)
            .guidanceScale(12.0)

        XCTAssertEqual(config.width, 1024, "Complex chain should set width")
        XCTAssertEqual(config.height, 768, "Complex chain should set height")
        XCTAssertEqual(config.steps, 60, "Complex chain should override steps from preset")
        XCTAssertEqual(
            Double(config.guidanceScale!),
            12.0,
            accuracy: 0.001,
            "Complex chain should override guidance scale"
        )
    }

    func testPresetModification() {
        let config = ImageGenerationConfig.square512.steps(40)

        XCTAssertEqual(config.width, 512, "Should preserve width from preset")
        XCTAssertEqual(config.height, 512, "Should preserve height from preset")
        XCTAssertEqual(config.steps, 40, "Should add steps to preset")
    }

    func testSizeOverridesPreviousDimensions() {
        let config = ImageGenerationConfig(width: 1024, height: 1024)
            .size(width: 512, height: 768)

        XCTAssertEqual(config.width, 512, "size() should override previous width")
        XCTAssertEqual(config.height, 768, "size() should override previous height")
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        let config = ImageGenerationConfig.highQuality

        // Test that config can be sent across concurrency boundaries
        await Task {
            XCTAssertEqual(config.steps, 50)
        }.value
    }

    // MARK: - Validation Tests

    func testValidDimensionDivisibleBy8() {
        // Valid dimension (divisible by 8) - should not print warning
        let config = ImageGenerationConfig.default.width(512)
        XCTAssertEqual(config.width, 512, "Should accept valid width")
    }

    func testInvalidDimensionNotDivisibleBy8() {
        // Invalid dimension (not divisible by 8) - prints warning but still sets value
        let config = ImageGenerationConfig.default.width(500)
        XCTAssertEqual(config.width, 500, "Should accept dimension not divisible by 8 with warning")
    }

    func testZeroOrNegativeDimensionValidation() {
        // Zero and negative dimensions - prints warning but still sets value
        let config1 = ImageGenerationConfig.default.width(0)
        let config2 = ImageGenerationConfig.default.height(-10)
        XCTAssertEqual(config1.width, 0, "Should accept zero width with warning")
        XCTAssertEqual(config2.height, -10, "Should accept negative height with warning")
    }

    func testValidStepsRange() {
        // Valid steps (1-150) - should not print warning
        let config = ImageGenerationConfig.default.steps(50)
        XCTAssertEqual(config.steps, 50, "Should accept valid steps")
    }

    func testStepsBelowMinimum() {
        // Steps below 1 - prints warning but still sets value
        let config = ImageGenerationConfig.default.steps(0)
        XCTAssertEqual(config.steps, 0, "Should accept steps below 1 with warning")
    }

    func testStepsAboveMaximum() {
        // Steps above 150 - prints warning but still sets value
        let config = ImageGenerationConfig.default.steps(200)
        XCTAssertEqual(config.steps, 200, "Should accept steps above 150 with warning")
    }

    func testValidGuidanceScale() {
        // Valid guidance scale (0-30) - should not print warning
        let config = ImageGenerationConfig.default.guidanceScale(7.5)
        XCTAssertEqual(Double(config.guidanceScale!), 7.5, accuracy: 0.001, "Should accept valid guidance scale")
    }

    func testNegativeGuidanceScaleValidation() {
        // Negative guidance scale - prints warning but still sets value
        let config = ImageGenerationConfig.default.guidanceScale(-5.0)
        XCTAssertEqual(
            Double(config.guidanceScale!),
            -5.0,
            accuracy: 0.001,
            "Should accept negative guidance scale with warning"
        )
    }

    func testExcessiveGuidanceScale() {
        // Guidance scale above 30 - prints warning but still sets value
        let config = ImageGenerationConfig.default.guidanceScale(50.0)
        XCTAssertEqual(
            Double(config.guidanceScale!),
            50.0,
            accuracy: 0.001,
            "Should accept high guidance scale with warning"
        )
    }

    func testSizeValidation() {
        // Test size() method validation
        let config = ImageGenerationConfig.default.size(width: 512, height: 768)
        XCTAssertEqual(config.width, 512, "Size should set valid width")
        XCTAssertEqual(config.height, 768, "Size should set valid height")
    }

    func testSizeValidationWithInvalidValues() {
        // Size with invalid values - prints warnings but still sets values
        let config = ImageGenerationConfig.default.size(width: 500, height: 700)
        XCTAssertEqual(config.width, 500, "Size should set width with warning")
        XCTAssertEqual(config.height, 700, "Size should set height with warning")
    }
}
