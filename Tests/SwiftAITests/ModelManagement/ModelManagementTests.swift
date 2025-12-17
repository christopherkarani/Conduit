// ModelManagementTests.swift
// SwiftAI Tests
//
// Comprehensive test suite for Model Management types.

import XCTest
@testable import SwiftAI

// MARK: - DownloadProgress Tests

/// Tests for DownloadProgress struct.
final class DownloadProgressTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let progress = DownloadProgress()

        XCTAssertEqual(progress.bytesDownloaded, 0)
        XCTAssertNil(progress.totalBytes)
        XCTAssertNil(progress.currentFile)
        XCTAssertEqual(progress.filesCompleted, 0)
        XCTAssertEqual(progress.totalFiles, 0)
        XCTAssertNil(progress.estimatedTimeRemaining)
        XCTAssertNil(progress.bytesPerSecond)
    }

    func testFullInitialization() {
        let progress = DownloadProgress(
            bytesDownloaded: 500_000_000,
            totalBytes: 2_000_000_000,
            currentFile: "model.safetensors",
            filesCompleted: 2,
            totalFiles: 5,
            estimatedTimeRemaining: 300.0,
            bytesPerSecond: 5_000_000.0
        )

        XCTAssertEqual(progress.bytesDownloaded, 500_000_000)
        XCTAssertEqual(progress.totalBytes, 2_000_000_000)
        XCTAssertEqual(progress.currentFile, "model.safetensors")
        XCTAssertEqual(progress.filesCompleted, 2)
        XCTAssertEqual(progress.totalFiles, 5)
        XCTAssertEqual(progress.estimatedTimeRemaining, 300.0)
        XCTAssertEqual(progress.bytesPerSecond, 5_000_000.0)
    }

    // MARK: - Fraction Completed Tests

    func testFractionCompletedWithTotalBytes() {
        let progress = DownloadProgress(
            bytesDownloaded: 500_000_000,
            totalBytes: 2_000_000_000
        )

        XCTAssertEqual(progress.fractionCompleted, 0.25, accuracy: 0.001)
    }

    func testFractionCompletedAtZero() {
        let progress = DownloadProgress(
            bytesDownloaded: 0,
            totalBytes: 1_000_000_000
        )

        XCTAssertEqual(progress.fractionCompleted, 0.0, accuracy: 0.001)
    }

    func testFractionCompletedAtHundredPercent() {
        let progress = DownloadProgress(
            bytesDownloaded: 1_000_000_000,
            totalBytes: 1_000_000_000
        )

        XCTAssertEqual(progress.fractionCompleted, 1.0, accuracy: 0.001)
    }

    func testFractionCompletedWithZeroTotalBytes() {
        // When totalBytes is 0, falls back to file-based progress
        let progress = DownloadProgress(
            bytesDownloaded: 100,
            totalBytes: 0,
            filesCompleted: 2,
            totalFiles: 4
        )

        // Should use file-based progress: 2/4 = 0.5
        XCTAssertEqual(progress.fractionCompleted, 0.5, accuracy: 0.001)
    }

    func testFractionCompletedWithNilTotalBytes() {
        // When totalBytes is nil, falls back to file-based progress
        let progress = DownloadProgress(
            bytesDownloaded: 100,
            totalBytes: nil,
            filesCompleted: 3,
            totalFiles: 6
        )

        // Should use file-based progress: 3/6 = 0.5
        XCTAssertEqual(progress.fractionCompleted, 0.5, accuracy: 0.001)
    }

    func testFractionCompletedWithNoFiles() {
        // When both totalBytes is 0/nil and totalFiles is 0
        let progress = DownloadProgress(
            bytesDownloaded: 0,
            totalBytes: nil,
            filesCompleted: 0,
            totalFiles: 0
        )

        XCTAssertEqual(progress.fractionCompleted, 0.0, accuracy: 0.001)
    }

    // MARK: - Percent Complete Tests

    func testPercentCompleteRounding() {
        let progress = DownloadProgress(
            bytesDownloaded: 375,
            totalBytes: 1000
        )

        // 37.5% should round to 38
        XCTAssertEqual(progress.percentComplete, 38)
    }

    func testPercentCompleteAtBoundaries() {
        let zeroProgress = DownloadProgress(bytesDownloaded: 0, totalBytes: 1000)
        XCTAssertEqual(zeroProgress.percentComplete, 0)

        let halfProgress = DownloadProgress(bytesDownloaded: 500, totalBytes: 1000)
        XCTAssertEqual(halfProgress.percentComplete, 50)

        let fullProgress = DownloadProgress(bytesDownloaded: 1000, totalBytes: 1000)
        XCTAssertEqual(fullProgress.percentComplete, 100)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let progress1 = DownloadProgress(
            bytesDownloaded: 100,
            totalBytes: 1000,
            currentFile: "test.bin",
            filesCompleted: 1,
            totalFiles: 2
        )

        let progress2 = DownloadProgress(
            bytesDownloaded: 100,
            totalBytes: 1000,
            currentFile: "test.bin",
            filesCompleted: 1,
            totalFiles: 2
        )

        XCTAssertEqual(progress1, progress2)
    }

    func testEquatableWithDifferentValues() {
        let progress1 = DownloadProgress(bytesDownloaded: 100, totalBytes: 1000)
        let progress2 = DownloadProgress(bytesDownloaded: 200, totalBytes: 1000)

        XCTAssertNotEqual(progress1, progress2)
    }

    // MARK: - Sendable Conformance

    func testSendableConformance() async {
        let progress = DownloadProgress(
            bytesDownloaded: 500,
            totalBytes: 1000
        )

        await Task {
            XCTAssertEqual(progress.bytesDownloaded, 500)
            XCTAssertEqual(progress.fractionCompleted, 0.5, accuracy: 0.001)
        }.value
    }
}

// MARK: - DownloadState Tests

/// Tests for DownloadState enum.
final class DownloadStateTests: XCTestCase {

    // MARK: - isActive Tests

    func testIsActiveForPending() {
        let state = DownloadState.pending
        XCTAssertTrue(state.isActive, "Pending should be active")
    }

    func testIsActiveForDownloading() {
        let state = DownloadState.downloading
        XCTAssertTrue(state.isActive, "Downloading should be active")
    }

    func testIsActiveForPaused() {
        let state = DownloadState.paused
        XCTAssertTrue(state.isActive, "Paused should be active")
    }

    func testIsActiveForCompleted() {
        let url = URL(fileURLWithPath: "/tmp/model")
        let state = DownloadState.completed(url)
        XCTAssertFalse(state.isActive, "Completed should not be active")
    }

    func testIsActiveForFailed() {
        let error = NSError(domain: "test", code: 1)
        let state = DownloadState.failed(error)
        XCTAssertFalse(state.isActive, "Failed should not be active")
    }

    func testIsActiveForCancelled() {
        let state = DownloadState.cancelled
        XCTAssertFalse(state.isActive, "Cancelled should not be active")
    }

    // MARK: - isTerminal Tests

    func testIsTerminalForActiveStates() {
        XCTAssertFalse(DownloadState.pending.isTerminal)
        XCTAssertFalse(DownloadState.downloading.isTerminal)
        XCTAssertFalse(DownloadState.paused.isTerminal)
    }

    func testIsTerminalForTerminalStates() {
        let url = URL(fileURLWithPath: "/tmp/model")
        XCTAssertTrue(DownloadState.completed(url).isTerminal)

        let error = NSError(domain: "test", code: 1)
        XCTAssertTrue(DownloadState.failed(error).isTerminal)

        XCTAssertTrue(DownloadState.cancelled.isTerminal)
    }

    // MARK: - Equatable Tests

    func testEquatablePending() {
        XCTAssertEqual(DownloadState.pending, DownloadState.pending)
    }

    func testEquatableDownloading() {
        XCTAssertEqual(DownloadState.downloading, DownloadState.downloading)
    }

    func testEquatablePaused() {
        XCTAssertEqual(DownloadState.paused, DownloadState.paused)
    }

    func testEquatableCancelled() {
        XCTAssertEqual(DownloadState.cancelled, DownloadState.cancelled)
    }

    func testEquatableCompletedSameURL() {
        let url = URL(fileURLWithPath: "/tmp/model")
        XCTAssertEqual(
            DownloadState.completed(url),
            DownloadState.completed(url)
        )
    }

    func testEquatableCompletedDifferentURL() {
        let url1 = URL(fileURLWithPath: "/tmp/model1")
        let url2 = URL(fileURLWithPath: "/tmp/model2")
        XCTAssertNotEqual(
            DownloadState.completed(url1),
            DownloadState.completed(url2)
        )
    }

    func testEquatableFailedSameDescription() {
        let error1 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error"])
        let error2 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Error"])
        XCTAssertEqual(
            DownloadState.failed(error1),
            DownloadState.failed(error2)
        )
    }

    func testNotEqualDifferentStates() {
        XCTAssertNotEqual(DownloadState.pending, DownloadState.downloading)
        XCTAssertNotEqual(DownloadState.downloading, DownloadState.paused)
        XCTAssertNotEqual(DownloadState.paused, DownloadState.cancelled)
    }
}

// MARK: - DownloadTask Tests

/// Tests for DownloadTask class.
final class DownloadTaskTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization() {
        let task = DownloadTask(model: .llama3_2_1B)

        XCTAssertEqual(task.model, .llama3_2_1B)
        XCTAssertEqual(task.state, .pending)
        XCTAssertEqual(task.progress.bytesDownloaded, 0)
    }

    // MARK: - Cancel Tests

    func testCancelFromPending() {
        let task = DownloadTask(model: .llama3_2_1B)

        task.cancel()

        XCTAssertEqual(task.state, .cancelled)
    }

    func testCancelIdempotent() {
        let task = DownloadTask(model: .llama3_2_1B)

        task.cancel()
        task.cancel() // Second call should be no-op

        XCTAssertEqual(task.state, .cancelled)
    }

    func testCancelFromTerminalStateNoOp() {
        let task = DownloadTask(model: .llama3_2_1B)
        task.updateState(.cancelled)

        // Should be no-op since already cancelled
        task.cancel()

        XCTAssertEqual(task.state, .cancelled)
    }

    // MARK: - Pause/Resume Tests

    func testPauseFromDownloading() {
        let task = DownloadTask(model: .llama3_2_1B)
        task.updateState(.downloading)

        task.pause()

        XCTAssertEqual(task.state, .paused)
    }

    func testPauseFromNonDownloadingNoOp() {
        let task = DownloadTask(model: .llama3_2_1B)
        // Task is in pending state

        task.pause()

        // Should still be pending
        XCTAssertEqual(task.state, .pending)
    }

    func testResumeFromPaused() {
        let task = DownloadTask(model: .llama3_2_1B)
        task.updateState(.downloading)
        task.pause()

        XCTAssertEqual(task.state, .paused)

        task.resume()

        XCTAssertEqual(task.state, .downloading)
    }

    func testResumeFromNonPausedNoOp() {
        let task = DownloadTask(model: .llama3_2_1B)
        task.updateState(.downloading)

        task.resume()

        // Should still be downloading
        XCTAssertEqual(task.state, .downloading)
    }

    // MARK: - Progress Update Tests

    func testUpdateProgress() {
        let task = DownloadTask(model: .llama3_2_1B)

        let newProgress = DownloadProgress(
            bytesDownloaded: 500_000_000,
            totalBytes: 2_000_000_000
        )
        task.updateProgress(newProgress)

        XCTAssertEqual(task.progress.bytesDownloaded, 500_000_000)
        XCTAssertEqual(task.progress.totalBytes, 2_000_000_000)
    }

    // MARK: - State Update Tests

    func testUpdateState() {
        let task = DownloadTask(model: .llama3_2_1B)

        task.updateState(.downloading)
        XCTAssertEqual(task.state, .downloading)

        let completedURL = URL(fileURLWithPath: "/tmp/model")
        task.updateState(.completed(completedURL))
        XCTAssertEqual(task.state, .completed(completedURL))
    }

    // MARK: - Sendable Tests

    func testSendableConformance() async {
        let task = DownloadTask(model: .llama3_2_1B)

        await Task {
            XCTAssertEqual(task.model, .llama3_2_1B)
            XCTAssertEqual(task.state, .pending)
        }.value
    }
}

// MARK: - CachedModelInfo Tests

/// Tests for CachedModelInfo struct.
final class CachedModelInfoTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitializationWithDefaults() {
        let path = URL(fileURLWithPath: "/tmp/models/llama")
        let size = ByteCount.gigabytes(4)

        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: path,
            size: size
        )

        XCTAssertEqual(info.identifier, .llama3_2_1B)
        XCTAssertEqual(info.path, path)
        XCTAssertEqual(info.size, size)
        XCTAssertNil(info.revision)
        // downloadedAt and lastAccessedAt should be close to now
        XCTAssertLessThan(abs(info.downloadedAt.timeIntervalSinceNow), 1.0)
        XCTAssertLessThan(abs(info.lastAccessedAt.timeIntervalSinceNow), 1.0)
    }

    func testInitializationWithAllParameters() {
        let path = URL(fileURLWithPath: "/tmp/models/llama")
        let size = ByteCount.gigabytes(4)
        let downloadedAt = Date(timeIntervalSince1970: 1700000000)
        let lastAccessedAt = Date(timeIntervalSince1970: 1700100000)

        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: path,
            size: size,
            downloadedAt: downloadedAt,
            lastAccessedAt: lastAccessedAt,
            revision: "main"
        )

        XCTAssertEqual(info.identifier, .llama3_2_1B)
        XCTAssertEqual(info.path, path)
        XCTAssertEqual(info.size, size)
        XCTAssertEqual(info.downloadedAt, downloadedAt)
        XCTAssertEqual(info.lastAccessedAt, lastAccessedAt)
        XCTAssertEqual(info.revision, "main")
    }

    // MARK: - Identifiable Tests

    func testIdentifiableId() {
        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: URL(fileURLWithPath: "/tmp/model"),
            size: .gigabytes(4)
        )

        XCTAssertEqual(info.id, ModelIdentifier.llama3_2_1B.rawValue)
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() throws {
        let originalDate = Date(timeIntervalSince1970: 1700000000)
        let path = URL(fileURLWithPath: "/tmp/models/llama")

        let original = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: path,
            size: .gigabytes(4),
            downloadedAt: originalDate,
            lastAccessedAt: originalDate,
            revision: "v1.0"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CachedModelInfo.self, from: data)

        XCTAssertEqual(original.identifier, decoded.identifier)
        XCTAssertEqual(original.path, decoded.path)
        XCTAssertEqual(original.size, decoded.size)
        XCTAssertEqual(original.downloadedAt.timeIntervalSince1970, decoded.downloadedAt.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(original.lastAccessedAt.timeIntervalSince1970, decoded.lastAccessedAt.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(original.revision, decoded.revision)
    }

    func testCodableWithNilRevision() throws {
        let path = URL(fileURLWithPath: "/tmp/models/llama")
        let original = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: path,
            size: .megabytes(500)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CachedModelInfo.self, from: data)

        XCTAssertNil(decoded.revision)
    }
}

// MARK: - ByteCount Model Management Tests

/// Tests for ByteCount struct in model management context.
final class ByteCountModelManagementTests: XCTestCase {

    func testMegabytesFactory() {
        let size = ByteCount.megabytes(100)
        XCTAssertEqual(size.bytes, 100_000_000)
    }

    func testGigabytesFactory() {
        let size = ByteCount.gigabytes(4)
        XCTAssertEqual(size.bytes, 4_000_000_000)
    }

    func testComparable() {
        let small = ByteCount.megabytes(100)
        let large = ByteCount.gigabytes(1)

        XCTAssertTrue(small < large)
        XCTAssertFalse(large < small)
    }

    func testEquatable() {
        let a = ByteCount.megabytes(500)
        let b = ByteCount.megabytes(500)
        let c = ByteCount.megabytes(600)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testFormattedOutput() {
        let kb = ByteCount(500_000)
        XCTAssertFalse(kb.formatted.isEmpty)

        let mb = ByteCount.megabytes(100)
        XCTAssertFalse(mb.formatted.isEmpty)

        let gb = ByteCount.gigabytes(4)
        XCTAssertFalse(gb.formatted.isEmpty)
    }

    func testCodable() throws {
        let original = ByteCount.gigabytes(8)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ByteCount.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testHashable() {
        let a = ByteCount.megabytes(100)
        let b = ByteCount.megabytes(100)
        let c = ByteCount.megabytes(200)

        var set = Set<ByteCount>()
        set.insert(a)
        set.insert(b)
        set.insert(c)

        XCTAssertEqual(set.count, 2) // a and b are equal
    }
}

// MARK: - ModelCache Tests

/// Tests for ModelCache actor.
final class ModelCacheTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        // Create a unique temporary directory for each test
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftAITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempPath, withIntermediateDirectories: true)
        tempDirectory = tempPath
    }

    override func tearDown() async throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationCreatesDirectory() async throws {
        let cacheDir = tempDirectory.appendingPathComponent("cache")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheDir.path))

        _ = try await ModelCache(cacheDirectory: cacheDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheDir.path))
    }

    func testEmptyCacheHasNoModels() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let models = await cache.allCachedModels()

        XCTAssertTrue(models.isEmpty)
        let isEmpty = await cache.isEmpty
        XCTAssertTrue(isEmpty)
        let count = await cache.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - Add and Query Tests

    func testAddModel() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let modelPath = tempDirectory.appendingPathComponent("model1")
        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)

        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: modelPath,
            size: .gigabytes(4)
        )
        try await cache.add(info)

        let isCached = await cache.isCached(.llama3_2_1B)
        XCTAssertTrue(isCached)

        let count = await cache.count
        XCTAssertEqual(count, 1)
    }

    func testInfoForModel() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let modelPath = tempDirectory.appendingPathComponent("model1")
        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)

        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: modelPath,
            size: .gigabytes(4),
            revision: "v1.0"
        )
        try await cache.add(info)

        let retrieved = await cache.info(for: .llama3_2_1B)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.identifier, .llama3_2_1B)
        XCTAssertEqual(retrieved?.path, modelPath)
        XCTAssertEqual(retrieved?.size, .gigabytes(4))
        XCTAssertEqual(retrieved?.revision, "v1.0")
    }

    func testInfoForNonExistentModel() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let info = await cache.info(for: .llama3_2_1B)
        XCTAssertNil(info)
    }

    func testLocalPathForModel() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let modelPath = tempDirectory.appendingPathComponent("model1")
        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)

        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: modelPath,
            size: .gigabytes(4)
        )
        try await cache.add(info)

        let path = await cache.localPath(for: .llama3_2_1B)
        XCTAssertEqual(path, modelPath)
    }

    func testLocalPathForNonExistentModel() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let path = await cache.localPath(for: .llama3_2_1B)
        XCTAssertNil(path)
    }

    // MARK: - Total Size Tests

    func testTotalSize() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let model1Path = tempDirectory.appendingPathComponent("model1")
        let model2Path = tempDirectory.appendingPathComponent("model2")
        try FileManager.default.createDirectory(at: model1Path, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: model2Path, withIntermediateDirectories: true)

        try await cache.add(CachedModelInfo(
            identifier: .llama3_2_1B,
            path: model1Path,
            size: .gigabytes(4)
        ))

        try await cache.add(CachedModelInfo(
            identifier: .llama3_2_3B,
            path: model2Path,
            size: .gigabytes(6)
        ))

        let total = await cache.totalSize()
        XCTAssertEqual(total, .gigabytes(10))
    }

    func testTotalSizeEmptyCache() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let total = await cache.totalSize()
        XCTAssertEqual(total.bytes, 0)
    }

    // MARK: - Mark Accessed Tests

    func testMarkAccessedUpdatesTimestamp() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let modelPath = tempDirectory.appendingPathComponent("model1")
        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)

        let originalDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: modelPath,
            size: .gigabytes(4),
            lastAccessedAt: originalDate
        )
        try await cache.add(info)

        // Wait briefly to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        await cache.markAccessed(.llama3_2_1B)

        let updated = await cache.info(for: .llama3_2_1B)
        XCTAssertNotNil(updated)
        XCTAssertGreaterThan(updated!.lastAccessedAt, originalDate)
    }

    func testMarkAccessedNonExistentModelNoOp() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        // Should not crash
        await cache.markAccessed(.llama3_2_1B)

        let info = await cache.info(for: .llama3_2_1B)
        XCTAssertNil(info)
    }

    // MARK: - Remove Tests

    func testRemoveModel() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let modelPath = tempDirectory.appendingPathComponent("model1")
        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)

        let info = CachedModelInfo(
            identifier: .llama3_2_1B,
            path: modelPath,
            size: .gigabytes(4)
        )
        try await cache.add(info)

        // Verify it's added
        var isCached = await cache.isCached(.llama3_2_1B)
        XCTAssertTrue(isCached)

        // Remove it
        try await cache.remove(.llama3_2_1B)

        // Verify it's removed
        isCached = await cache.isCached(.llama3_2_1B)
        XCTAssertFalse(isCached)

        // Verify directory is deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelPath.path))
    }

    func testRemoveNonExistentModelNoOp() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        // Should not throw
        try await cache.remove(.llama3_2_1B)
    }

    // MARK: - Clear All Tests

    func testClearAll() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let model1Path = tempDirectory.appendingPathComponent("model1")
        let model2Path = tempDirectory.appendingPathComponent("model2")
        try FileManager.default.createDirectory(at: model1Path, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: model2Path, withIntermediateDirectories: true)

        try await cache.add(CachedModelInfo(
            identifier: .llama3_2_1B,
            path: model1Path,
            size: .gigabytes(4)
        ))

        try await cache.add(CachedModelInfo(
            identifier: .llama3_2_3B,
            path: model2Path,
            size: .gigabytes(6)
        ))

        // Verify models are added
        var count = await cache.count
        XCTAssertEqual(count, 2)

        // Clear all
        try await cache.clearAll()

        // Verify cache is empty
        count = await cache.count
        XCTAssertEqual(count, 0)

        let isEmpty = await cache.isEmpty
        XCTAssertTrue(isEmpty)
    }

    // MARK: - LRU Eviction Tests

    func testEvictToFitLRU() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        // Create 3 models with different access times
        let model1Path = tempDirectory.appendingPathComponent("model1")
        let model2Path = tempDirectory.appendingPathComponent("model2")
        let model3Path = tempDirectory.appendingPathComponent("model3")

        try FileManager.default.createDirectory(at: model1Path, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: model2Path, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: model3Path, withIntermediateDirectories: true)

        // Add models with specific access times (oldest first)
        let now = Date()
        try await cache.add(CachedModelInfo(
            identifier: .llama3_2_1B,
            path: model1Path,
            size: .gigabytes(4),
            lastAccessedAt: now.addingTimeInterval(-3600) // 1 hour ago (oldest)
        ))

        try await cache.add(CachedModelInfo(
            identifier: .llama3_2_3B,
            path: model2Path,
            size: .gigabytes(4),
            lastAccessedAt: now.addingTimeInterval(-1800) // 30 min ago
        ))

        try await cache.add(CachedModelInfo(
            identifier: .mlx("test/model"),
            path: model3Path,
            size: .gigabytes(4),
            lastAccessedAt: now // Just now (newest)
        ))

        // Total is 12GB, evict to fit in 8GB
        let evicted = try await cache.evictToFit(maxSize: .gigabytes(8))

        // Should evict the oldest model (llama3_2_1B)
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(evicted.first?.identifier, .llama3_2_1B)

        // Verify remaining models
        let isCached1B = await cache.isCached(.llama3_2_1B)
        let isCached3B = await cache.isCached(.llama3_2_3B)
        let isCachedMLX = await cache.isCached(.mlx("test/model"))

        XCTAssertFalse(isCached1B, "Oldest model should be evicted")
        XCTAssertTrue(isCached3B, "Second oldest should remain")
        XCTAssertTrue(isCachedMLX, "Newest should remain")

        // Total should now be 8GB
        let totalSize = await cache.totalSize()
        XCTAssertEqual(totalSize.bytes, ByteCount.gigabytes(8).bytes)
    }

    func testEvictToFitAlreadyUnderLimit() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let modelPath = tempDirectory.appendingPathComponent("model1")
        try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)

        try await cache.add(CachedModelInfo(
            identifier: .llama3_2_1B,
            path: modelPath,
            size: .gigabytes(4)
        ))

        // Already under 20GB limit
        let evicted = try await cache.evictToFit(maxSize: .gigabytes(20))

        XCTAssertTrue(evicted.isEmpty, "No models should be evicted when under limit")

        let isCached = await cache.isCached(.llama3_2_1B)
        XCTAssertTrue(isCached)
    }

    func testEvictMultipleModels() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        // Create 4 models of 4GB each (16GB total)
        let models: [(ModelIdentifier, TimeInterval)] = [
            (.llama3_2_1B, -4000),  // Oldest
            (.llama3_2_3B, -3000),
            (.mlx("model/a"), -2000),
            (.mlx("model/b"), -1000)  // Newest
        ]

        let now = Date()
        for (model, offset) in models {
            let path = tempDirectory.appendingPathComponent(model.rawValue.replacingOccurrences(of: "/", with: "_"))
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)

            try await cache.add(CachedModelInfo(
                identifier: model,
                path: path,
                size: .gigabytes(4),
                lastAccessedAt: now.addingTimeInterval(offset)
            ))
        }

        // Evict to fit 8GB (need to remove 2 models)
        let evicted = try await cache.evictToFit(maxSize: .gigabytes(8))

        XCTAssertEqual(evicted.count, 2, "Should evict 2 models")

        // Verify oldest two were evicted (LRU order)
        let evictedIds = Set(evicted.map { $0.identifier })
        XCTAssertTrue(evictedIds.contains(.llama3_2_1B))
        XCTAssertTrue(evictedIds.contains(.llama3_2_3B))

        let count = await cache.count
        XCTAssertEqual(count, 2)
    }

    // MARK: - All Cached Models Tests

    func testAllCachedModelsSortedByRecency() async throws {
        let cache = try await ModelCache(cacheDirectory: tempDirectory)

        let now = Date()
        let models: [(ModelIdentifier, TimeInterval)] = [
            (.llama3_2_1B, -3600),  // Oldest
            (.llama3_2_3B, -1800),
            (.mlx("test/model"), 0)  // Most recent
        ]

        for (model, offset) in models {
            let path = tempDirectory.appendingPathComponent(model.rawValue.replacingOccurrences(of: "/", with: "_"))
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)

            try await cache.add(CachedModelInfo(
                identifier: model,
                path: path,
                size: .gigabytes(1),
                lastAccessedAt: now.addingTimeInterval(offset)
            ))
        }

        let allModels = await cache.allCachedModels()

        XCTAssertEqual(allModels.count, 3)
        // Should be sorted most recent first
        XCTAssertEqual(allModels[0].identifier, .mlx("test/model"))
        XCTAssertEqual(allModels[1].identifier, .llama3_2_3B)
        XCTAssertEqual(allModels[2].identifier, .llama3_2_1B)
    }
}
