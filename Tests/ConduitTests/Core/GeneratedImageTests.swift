// GeneratedImageTests.swift
// Conduit Tests

import XCTest
@testable import Conduit

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Comprehensive test suite for GeneratedImage.
///
/// Tests cover:
/// - Initialization
/// - Image format handling
/// - File save operations
/// - Platform-specific image properties (UIImage/NSImage)
/// - SwiftUI Image conversion
/// - Error handling
final class GeneratedImageTests: XCTestCase {

    // MARK: - Helper Methods

    /// Creates a simple 1x1 PNG image data for testing.
    private func createTestPNGData() -> Data {
        // Minimal valid 1x1 PNG (8-bit grayscale)
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
            0x08, 0x00, 0x00, 0x00, 0x00, 0x3A, 0x7E, 0x9B,
            0x55, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x08, 0x1D, 0x01, 0x00, 0x00, 0xFF, 0xFF,
            0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE2, 0x21,
            0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
            0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
        ])
        return pngData
    }

    /// Creates invalid image data for testing error cases.
    private func createInvalidImageData() -> Data {
        return Data([0x00, 0x01, 0x02, 0x03, 0x04])
    }

    /// Creates a temporary directory for testing file operations.
    private func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    // MARK: - Initialization Tests

    func testInitWithPNGData() {
        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        XCTAssertEqual(image.data, data, "Data should be stored")
        XCTAssertEqual(image.format, .png, "Default format should be PNG")
    }

    func testInitWithJPEGFormat() {
        let data = createTestPNGData()
        let image = GeneratedImage(data: data, format: .jpeg)

        XCTAssertEqual(image.data, data, "Data should be stored")
        XCTAssertEqual(image.format, .jpeg, "Format should be JPEG")
    }

    func testInitWithWebPFormat() {
        let data = createTestPNGData()
        let image = GeneratedImage(data: data, format: .webp)

        XCTAssertEqual(image.data, data, "Data should be stored")
        XCTAssertEqual(image.format, .webp, "Format should be WebP")
    }

    func testInitWithEmptyData() {
        let image = GeneratedImage(data: Data())
        XCTAssertEqual(image.data.count, 0, "Empty data should be allowed")
    }

    // MARK: - ImageFormat Tests

    func testPNGFileExtension() {
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
    }

    func testJPEGFileExtension() {
        XCTAssertEqual(ImageFormat.jpeg.fileExtension, "jpeg")
    }

    func testWebPFileExtension() {
        XCTAssertEqual(ImageFormat.webp.fileExtension, "webp")
    }

    func testPNGMimeType() {
        XCTAssertEqual(ImageFormat.png.mimeType, "image/png")
    }

    func testJPEGMimeType() {
        XCTAssertEqual(ImageFormat.jpeg.mimeType, "image/jpeg")
    }

    func testWebPMimeType() {
        XCTAssertEqual(ImageFormat.webp.mimeType, "image/webp")
    }

    // MARK: - Platform Image Tests

    #if os(iOS) || os(visionOS)
    func testUIImageWithValidData() {
        let data = createTestPNGData()
        let generatedImage = GeneratedImage(data: data)

        XCTAssertNotNil(generatedImage.uiImage, "Should create UIImage from valid PNG data")
    }

    func testUIImageWithInvalidData() {
        let data = createInvalidImageData()
        let generatedImage = GeneratedImage(data: data)

        XCTAssertNil(generatedImage.uiImage, "Should return nil for invalid image data")
    }
    #elseif os(macOS)
    func testNSImageWithValidData() {
        let data = createTestPNGData()
        let generatedImage = GeneratedImage(data: data)

        XCTAssertNotNil(generatedImage.nsImage, "Should create NSImage from valid PNG data")
    }

    func testNSImageWithInvalidData() {
        let data = createInvalidImageData()
        let generatedImage = GeneratedImage(data: data)

        XCTAssertNil(generatedImage.nsImage, "Should return nil for invalid image data")
    }
    #endif

    // MARK: - SwiftUI Image Tests

    // SwiftUI Image property is only available on platforms with UIKit/AppKit backing
    #if canImport(SwiftUI) && (os(iOS) || os(visionOS) || os(macOS))
    @MainActor
    func testSwiftUIImageWithValidData() async {
        let data = createTestPNGData()
        let generatedImage = GeneratedImage(data: data)

        XCTAssertNotNil(generatedImage.image, "Should create SwiftUI Image from valid PNG data")
    }

    @MainActor
    func testSwiftUIImageWithInvalidData() async {
        let data = createInvalidImageData()
        let generatedImage = GeneratedImage(data: data)

        XCTAssertNil(generatedImage.image, "Should return nil SwiftUI Image for invalid data")
    }
    #endif

    // MARK: - File Save Tests

    func testSaveToURL() throws {
        let tempDir = try createTempDirectory()
        let fileURL = tempDir.appendingPathComponent("test.png")

        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        try image.save(to: fileURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "File should exist at URL")

        let savedData = try Data(contentsOf: fileURL)
        XCTAssertEqual(savedData, data, "Saved data should match original")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveToDirectory() throws {
        let tempDir = try createTempDirectory()

        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        let savedURL = try image.save(toDirectory: tempDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path), "File should exist")
        XCTAssertTrue(savedURL.lastPathComponent.hasSuffix(".png"), "File should have .png extension")

        let savedData = try Data(contentsOf: savedURL)
        XCTAssertEqual(savedData, data, "Saved data should match original")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveToDirectoryWithCustomFilename() throws {
        let tempDir = try createTempDirectory()

        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        let savedURL = try image.save(toDirectory: tempDir, filename: "custom")

        XCTAssertEqual(savedURL.lastPathComponent, "custom.png", "Should use custom filename")
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path), "File should exist")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveToDirectoryWithJPEGFormat() throws {
        let tempDir = try createTempDirectory()

        let data = createTestPNGData()
        let image = GeneratedImage(data: data, format: .jpeg)

        let savedURL = try image.save(toDirectory: tempDir, filename: "test")

        XCTAssertEqual(savedURL.lastPathComponent, "test.jpeg", "Should use .jpeg extension")
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path), "File should exist")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveToDirectoryWithWebPFormat() throws {
        let tempDir = try createTempDirectory()

        let data = createTestPNGData()
        let image = GeneratedImage(data: data, format: .webp)

        let savedURL = try image.save(toDirectory: tempDir, filename: "test")

        XCTAssertEqual(savedURL.lastPathComponent, "test.webp", "Should use .webp extension")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveToDirectoryWithoutFilenameGeneratesUUID() throws {
        let tempDir = try createTempDirectory()

        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        let savedURL = try image.save(toDirectory: tempDir)

        // Check that filename looks like a UUID
        let filename = savedURL.deletingPathExtension().lastPathComponent
        XCTAssertNotEqual(filename, "", "Filename should not be empty")
        XCTAssertTrue(savedURL.lastPathComponent.hasSuffix(".png"), "Should have .png extension")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testMultipleSavesToDirectory() throws {
        let tempDir = try createTempDirectory()

        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        let url1 = try image.save(toDirectory: tempDir)
        let url2 = try image.save(toDirectory: tempDir)

        XCTAssertNotEqual(url1, url2, "Multiple saves should generate unique filenames")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url1.path), "First file should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url2.path), "Second file should exist")

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveToInvalidPath() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/directory/test.png")

        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        XCTAssertThrowsError(try image.save(to: invalidURL), "Should throw error for invalid path") { error in
            // Verify it throws GeneratedImageError.saveFailed
            guard case GeneratedImageError.saveFailed = error else {
                XCTFail("Expected GeneratedImageError.saveFailed, got \(error)")
                return
            }
        }
    }

    func testSaveToDirectoryInvalidPathThrowsSaveFailed() throws {
        let invalidDir = URL(fileURLWithPath: "/nonexistent/directory")
        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        XCTAssertThrowsError(
            try image.save(toDirectory: invalidDir, filename: "test"),
            "Should throw error for invalid directory"
        ) { error in
            // Verify it throws GeneratedImageError.saveFailed
            guard case GeneratedImageError.saveFailed = error else {
                XCTFail("Expected GeneratedImageError.saveFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Error Tests

    func testInvalidImageDataError() {
        let error = GeneratedImageError.invalidImageData
        XCTAssertNotNil(error.errorDescription, "Error should have description")
        XCTAssertTrue(error.errorDescription?.contains("could not be decoded") ?? false,
                     "Error should mention decoding")
    }

    func testPhotosAccessDeniedError() {
        let error = GeneratedImageError.photosAccessDenied
        XCTAssertNotNil(error.errorDescription, "Error should have description")
        XCTAssertTrue(error.errorDescription?.contains("denied") ?? false,
                     "Error should mention access denial")
        XCTAssertTrue(error.errorDescription?.contains("NSPhotoLibraryAddUsageDescription") ?? false,
                     "Error should mention Info.plist requirement")
    }

    func testSaveFailedError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = GeneratedImageError.saveFailed(underlying: SendableError(underlyingError))

        XCTAssertNotNil(error.errorDescription, "Error should have description")
        XCTAssertTrue(error.errorDescription?.contains("Failed to save") ?? false,
                     "Error should mention save failure")
        XCTAssertTrue(error.errorDescription?.contains("Test error") ?? false,
                     "Error should include underlying error description")
    }

    // MARK: - Sendable Conformance Tests

    func testSendableConformance() async {
        let data = createTestPNGData()
        let image = GeneratedImage(data: data)

        // Test that image can be sent across concurrency boundaries
        await Task {
            XCTAssertEqual(image.format, .png)
            XCTAssertEqual(image.data, data)
        }.value
    }

    // MARK: - Integration Tests

    func testFullWorkflow() throws {
        // Create image
        let data = createTestPNGData()
        let image = GeneratedImage(data: data, format: .png)

        // Save to temporary directory
        let tempDir = try createTempDirectory()
        let savedURL = try image.save(toDirectory: tempDir, filename: "workflow-test")

        // Verify file exists and has correct extension
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(savedURL.lastPathComponent, "workflow-test.png")

        // Load saved data and verify it matches
        let loadedData = try Data(contentsOf: savedURL)
        XCTAssertEqual(loadedData, data)

        // Create new GeneratedImage from loaded data
        let loadedImage = GeneratedImage(data: loadedData)
        XCTAssertEqual(loadedImage.data, image.data)

        #if os(iOS) || os(visionOS) || os(macOS)
        // Verify platform image can be created
        #if os(iOS) || os(visionOS)
        XCTAssertNotNil(loadedImage.uiImage)
        #elseif os(macOS)
        XCTAssertNotNil(loadedImage.nsImage)
        #endif
        #endif

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
}
