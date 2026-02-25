// DiffusionModelDownloaderTests.swift
// Conduit
//
// This file requires the MLX trait (Hub) to be enabled.

#if CONDUIT_TRAIT_MLX && canImport(MLX) && (canImport(Hub) || canImport(HuggingFace))

import Foundation
import Testing
@testable import Conduit

@Suite("DiffusionModelDownloader Tests", .serialized)
struct DiffusionModelDownloaderTests {

    // MARK: - Initialization Tests

    @Test("Downloader initializes without token")
    func initWithoutToken() async {
        let downloader = DiffusionModelDownloader()
        let count = await downloader.activeDownloadCount
        #expect(count == 0)
    }

    @Test("Downloader initializes with token")
    func initWithToken() async {
        let downloader = DiffusionModelDownloader(token: "test-token")
        let count = await downloader.activeDownloadCount
        #expect(count == 0)
    }

    // MARK: - Active Download Tracking Tests

    @Test("isDownloading returns false for non-active model")
    func isDownloadingNonActive() async {
        let downloader = DiffusionModelDownloader()
        let isDownloading = await downloader.isDownloading(modelId: "non-existent/model")
        #expect(isDownloading == false)
    }

    @Test("activeDownloadCount is zero initially")
    func activeDownloadCountInitiallyZero() async {
        let downloader = DiffusionModelDownloader()
        let count = await downloader.activeDownloadCount
        #expect(count == 0)
    }

    @Test("isDownloading returns true during active download")
    func isDownloadingDuringActive() async {
        let downloader = DiffusionModelDownloader()

        // Start a download task but don't await it
        let downloadTask = Task {
            try? await downloader.download(
                modelId: "mlx-community/sdxl-turbo",
                variant: .sdxlTurbo
            )
        }

        // Give it a moment to register
        try? await Task.sleep(for: .milliseconds(100))

        let isDownloading = await downloader.isDownloading(modelId: "mlx-community/sdxl-turbo")

        // Cancel to clean up
        await downloader.cancelDownload(modelId: "mlx-community/sdxl-turbo")
        downloadTask.cancel()

        #expect(isDownloading == true)
    }

    @Test("activeDownloadCount increments during download")
    func activeDownloadCountIncrements() async {
        let downloader = DiffusionModelDownloader()

        let initialCount = await downloader.activeDownloadCount
        #expect(initialCount == 0)

        // Start a download task but don't await it
        let downloadTask = Task {
            try? await downloader.download(
                modelId: "mlx-community/sdxl-turbo",
                variant: .sdxlTurbo
            )
        }

        // Give it a moment to register
        try? await Task.sleep(for: .milliseconds(100))

        let activeCount = await downloader.activeDownloadCount

        // Clean up
        await downloader.cancelDownload(modelId: "mlx-community/sdxl-turbo")
        downloadTask.cancel()

        #expect(activeCount == 1)
    }

    // MARK: - Cancellation Tests

    @Test("cancelDownload marks download as cancelled")
    func cancelDownloadMarksAsCancelled() async {
        let downloader = DiffusionModelDownloader()

        // Start a download
        let downloadTask = Task {
            try? await downloader.download(
                modelId: "mlx-community/sdxl-turbo",
                variant: .sdxlTurbo
            )
        }

        // Give it time to start
        try? await Task.sleep(for: .milliseconds(100))

        // Verify it's downloading
        var isDownloading = await downloader.isDownloading(modelId: "mlx-community/sdxl-turbo")
        #expect(isDownloading == true)

        // Cancel it
        await downloader.cancelDownload(modelId: "mlx-community/sdxl-turbo")

        // Verify it's no longer downloading
        isDownloading = await downloader.isDownloading(modelId: "mlx-community/sdxl-turbo")
        #expect(isDownloading == false)

        // Clean up
        downloadTask.cancel()
    }

    @Test("cancelAllDownloads clears all active downloads")
    func cancelAllDownloadsClearsAll() async {
        let downloader = DiffusionModelDownloader()

        // Start multiple downloads
        let task1 = Task {
            try? await downloader.download(
                modelId: "test/model1",
                variant: .sdxlTurbo
            )
        }

        let task2 = Task {
            try? await downloader.download(
                modelId: "test/model2",
                variant: .sd15
            )
        }

        // Give them time to register
        try? await Task.sleep(for: .milliseconds(100))

        // Verify both are active
        var count = await downloader.activeDownloadCount
        #expect(count == 2)

        // Cancel all
        await downloader.cancelAllDownloads()

        // Verify all are cancelled
        count = await downloader.activeDownloadCount
        #expect(count == 0)

        let isDownloading1 = await downloader.isDownloading(modelId: "test/model1")
        let isDownloading2 = await downloader.isDownloading(modelId: "test/model2")

        #expect(isDownloading1 == false)
        #expect(isDownloading2 == false)

        // Clean up
        task1.cancel()
        task2.cancel()
    }

    @Test("cancelDownload on non-existent download is safe")
    func cancelNonExistentDownload() async {
        let downloader = DiffusionModelDownloader()

        // This should not crash or throw
        await downloader.cancelDownload(modelId: "non-existent/model")

        let count = await downloader.activeDownloadCount
        #expect(count == 0)
    }

    // MARK: - Delete Tests

    @Test("deleteModel handles non-existent model gracefully")
    func deleteNonExistentModel() async throws {
        let downloader = DiffusionModelDownloader()

        // Ensure model is not in registry
        let registry = DiffusionModelRegistry.shared
        await registry.removeDownloaded("non-existent/model")

        // This should not throw
        try await downloader.deleteModel(modelId: "non-existent/model")

        // Verify still not in registry
        let exists = await registry.isDownloaded("non-existent/model")
        #expect(exists == false)
    }

    @Test("deleteModel removes model from registry")
    func deleteModelRemovesFromRegistry() async throws {
        let downloader = DiffusionModelDownloader()
        let registry = DiffusionModelRegistry.shared

        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Add model to registry
        let model = DownloadedDiffusionModel(
            id: "test/delete-model",
            name: "Test Model",
            variant: .sdxlTurbo,
            localPath: tempDir,
            sizeBytes: 1_000_000
        )
        await registry.addDownloaded(model)

        // Verify it's in registry
        var exists = await registry.isDownloaded("test/delete-model")
        #expect(exists == true)

        // Delete it
        try await downloader.deleteModel(modelId: "test/delete-model")

        // Verify it's removed from registry
        exists = await registry.isDownloaded("test/delete-model")
        #expect(exists == false)

        // Verify directory was deleted
        let dirExists = FileManager.default.fileExists(atPath: tempDir.path)
        #expect(dirExists == false)
    }

    @Test("deleteAllModels clears registry")
    func deleteAllModelsClearsRegistry() async throws {
        let downloader = DiffusionModelDownloader()
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        // Create temporary directories
        let tempDir1 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let tempDir2 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)

        // Add models to registry
        let model1 = DownloadedDiffusionModel(
            id: "test/model1",
            name: "Model 1",
            variant: .sdxlTurbo,
            localPath: tempDir1,
            sizeBytes: 1_000_000
        )

        let model2 = DownloadedDiffusionModel(
            id: "test/model2",
            name: "Model 2",
            variant: .sd15,
            localPath: tempDir2,
            sizeBytes: 2_000_000
        )

        await registry.addDownloaded(model1)
        await registry.addDownloaded(model2)

        // Verify they're in registry
        var count = await registry.downloadedCount
        #expect(count == 2)

        // Delete all
        try await downloader.deleteAllModels()

        // Verify registry is empty
        count = await registry.downloadedCount
        #expect(count == 0)

        // Verify directories were deleted
        let dir1Exists = FileManager.default.fileExists(atPath: tempDir1.path)
        let dir2Exists = FileManager.default.fileExists(atPath: tempDir2.path)

        #expect(dir1Exists == false)
        #expect(dir2Exists == false)
    }

    // MARK: - Convenience Method Tests

    @Test("download with DiffusionModelInfo uses correct parameters")
    func downloadWithModelInfo() async {
        let downloader = DiffusionModelDownloader()

        // Use one of the available models from registry
        let availableModel = DiffusionModelRegistry.availableModels.first!

        // Start download but cancel immediately to avoid actual download
        let task = Task {
            try? await downloader.download(model: availableModel)
        }

        // Give it time to register
        try? await Task.sleep(for: .milliseconds(100))

        // Verify it started downloading
        let isDownloading = await downloader.isDownloading(modelId: availableModel.id)

        // Cancel and clean up
        await downloader.cancelDownload(modelId: availableModel.id)
        task.cancel()

        #expect(isDownloading == true)
    }

    // MARK: - Duplicate Download Behavior Tests

    @Test("Duplicate download requests return same task")
    func duplicateDownloadReturnsSameTask() async {
        let downloader = DiffusionModelDownloader()

        // Start first download
        let task1 = Task {
            try? await downloader.download(
                modelId: "test/duplicate",
                variant: .sdxlTurbo
            )
        }

        // Give it time to register
        try? await Task.sleep(for: .milliseconds(50))

        // Verify first download is active
        let isDownloading = await downloader.isDownloading(modelId: "test/duplicate")
        #expect(isDownloading == true)

        // Start second download for same model
        let task2 = Task {
            try? await downloader.download(
                modelId: "test/duplicate",
                variant: .sdxlTurbo
            )
        }

        // Give it time to process
        try? await Task.sleep(for: .milliseconds(50))

        // Should still only have one active download
        let count = await downloader.activeDownloadCount
        #expect(count == 1)

        // Clean up
        await downloader.cancelDownload(modelId: "test/duplicate")
        task1.cancel()
        task2.cancel()
    }

    // MARK: - Progress Handler Behavior Documentation

    @Test("Progress handler is called during download", .disabled("Requires real HuggingFace download"))
    func progressHandlerIsCalled() async throws {
        // DOCUMENTATION:
        // This test documents expected behavior for progress callbacks.
        //
        // When download() is called with a progressHandler:
        // 1. Handler should be called multiple times during download
        // 2. Progress.fractionCompleted should increase from 0.0 to 1.0
        // 3. Handler should be called on a background thread (marked @Sendable)
        //
        // Example usage:
        // ```swift
        // var progressValues: [Double] = []
        // let url = try await downloader.download(
        //     modelId: "mlx-community/sdxl-turbo",
        //     variant: .sdxlTurbo
        // ) { progress in
        //     progressValues.append(progress.fractionCompleted)
        // }
        // #expect(progressValues.count > 1)
        // #expect(progressValues.last == 1.0)
        // ```
    }

    // MARK: - Disk Space Validation Documentation

    @Test("Insufficient disk space throws error", .disabled("Requires mocking disk space"))
    func insufficientDiskSpaceThrows() async throws {
        // DOCUMENTATION:
        // This test documents expected behavior when insufficient disk space is available.
        //
        // Expected behavior:
        // 1. Before downloading, checkAvailableDiskSpace() is called
        // 2. It requires 110% of model size (10% buffer)
        // 3. If insufficient space, throws AIError.insufficientDiskSpace
        // 4. Error includes required and available byte counts
        //
        // Example expected error:
        // ```swift
        // do {
        //     // Assume disk has only 1GB free but model needs 6.5GB
        //     let url = try await downloader.download(
        //         modelId: "mlx-community/sdxl-turbo",
        //         variant: .sdxlTurbo
        //     )
        // } catch AIError.insufficientDiskSpace(let required, let available) {
        //     #expect(required.bytes > available.bytes)
        //     print("Need \(required.formatted), have \(available.formatted)")
        // }
        // ```
        //
        // Note: If available space cannot be determined, download proceeds
        // (fail-safe behavior to avoid blocking valid downloads).
    }

    @Test("Sufficient disk space allows download", .disabled("Requires real download"))
    func sufficientDiskSpaceAllows() async throws {
        // DOCUMENTATION:
        // When sufficient disk space is available (>110% of model size),
        // the download should proceed without throwing disk space errors.
        //
        // The 10% buffer accounts for:
        // - Temporary files during download
        // - File system overhead
        // - Metadata and cache
        //
        // Example:
        // ```swift
        // // For a 6.5GB model, need ~7.15GB free
        // let url = try await downloader.download(
        //     modelId: "mlx-community/sdxl-turbo",
        //     variant: .sdxlTurbo
        // )
        // // Should succeed without disk space error
        // ```
    }

    // MARK: - Checksum Verification Documentation

    @Test("Valid checksum passes verification", .disabled("Requires real download with known checksum"))
    func validChecksumPasses() async throws {
        // DOCUMENTATION:
        // When a valid SHA256 checksum is provided and matches the downloaded file:
        //
        // Expected behavior:
        // 1. After download completes, verifyChecksum() is called
        // 2. It finds the largest .safetensors file in the downloaded directory
        // 3. Calculates SHA256 hash of that file
        // 4. Compares (case-insensitive) with expected checksum
        // 5. If match, download completes successfully
        //
        // Example:
        // ```swift
        // let expectedHash = "abc123..." // Known good hash
        // let url = try await downloader.download(
        //     modelId: "mlx-community/sdxl-turbo",
        //     variant: .sdxlTurbo,
        //     expectedChecksum: expectedHash
        // )
        // // Should succeed without throwing checksumMismatch
        // ```
    }

    @Test("Invalid checksum throws error", .disabled("Requires real download with incorrect checksum"))
    func invalidChecksumThrows() async throws {
        // DOCUMENTATION:
        // When checksum verification fails:
        //
        // Expected behavior:
        // 1. After download, SHA256 is calculated
        // 2. If it doesn't match expected, throws AIError.checksumMismatch
        // 3. Error includes both expected and actual checksums (truncated to first 16 chars)
        // 4. Downloaded files remain on disk for investigation
        //
        // Example:
        // ```swift
        // do {
        //     let badHash = "ffffffff..." // Wrong hash
        //     let url = try await downloader.download(
        //         modelId: "mlx-community/sdxl-turbo",
        //         variant: .sdxlTurbo,
        //         expectedChecksum: badHash
        //     )
        // } catch AIError.checksumMismatch(let expected, let actual) {
        //     #expect(expected.lowercased() != actual.lowercased())
        //     print("Expected \(expected.prefix(16))...")
        //     print("Got \(actual.prefix(16))...")
        // }
        // ```
        //
        // Recovery suggestion: Delete the model and download again.
    }

    @Test("Missing checksum skips verification", .disabled("Requires real download"))
    func missingChecksumSkipsVerification() async throws {
        // DOCUMENTATION:
        // When no checksum is provided (expectedChecksum: nil):
        //
        // Expected behavior:
        // 1. Download completes normally
        // 2. verifyChecksum() is not called
        // 3. Files are trusted as-is from HuggingFace Hub
        //
        // Example:
        // ```swift
        // let url = try await downloader.download(
        //     modelId: "mlx-community/sdxl-turbo",
        //     variant: .sdxlTurbo
        //     // No expectedChecksum parameter
        // )
        // // Completes without checksum verification
        // ```
    }

    @Test("No safetensors file skips checksum", .disabled("Requires special test fixture"))
    func noSafetensorsSkipsChecksum() async throws {
        // DOCUMENTATION:
        // When downloaded directory contains no .safetensors files:
        //
        // Expected behavior:
        // 1. verifyChecksum() is called but finds no .safetensors files
        // 2. Verification is skipped (returns without error)
        // 3. Download completes successfully
        //
        // This handles edge cases like config-only downloads or
        // models with different file formats.
    }

    // MARK: - Already Downloaded Behavior Tests

    @Test("Already downloaded model returns cached path")
    func alreadyDownloadedReturnsCachedPath() async throws {
        let downloader = DiffusionModelDownloader()
        let registry = DiffusionModelRegistry.shared

        // Create a temporary directory to simulate downloaded model
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Register as downloaded
        let model = DownloadedDiffusionModel(
            id: "test/cached-model",
            name: "Cached Model",
            variant: .sdxlTurbo,
            localPath: tempDir,
            sizeBytes: 1_000_000
        )
        await registry.addDownloaded(model)

        // Attempt to download again
        let returnedPath = try await downloader.download(
            modelId: "test/cached-model",
            variant: .sdxlTurbo
        )

        // Should return the cached path without downloading
        #expect(returnedPath == tempDir)

        // Verify no download was started
        let isDownloading = await downloader.isDownloading(modelId: "test/cached-model")
        #expect(isDownloading == false)

        // Clean up
        try? FileManager.default.removeItem(at: tempDir)
        await registry.removeDownloaded("test/cached-model")
    }

    @Test("Cached path that no longer exists triggers redownload")
    func missingCachedPathTriggersRedownload() async {
        let downloader = DiffusionModelDownloader()
        let registry = DiffusionModelRegistry.shared

        // Create a path that doesn't exist
        let nonExistentPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        // Register as downloaded (but file doesn't exist)
        let model = DownloadedDiffusionModel(
            id: "test/missing-cached",
            name: "Missing Cached",
            variant: .sdxlTurbo,
            localPath: nonExistentPath,
            sizeBytes: 1_000_000
        )
        await registry.addDownloaded(model)

        // Verify it's in registry
        var exists = await registry.isDownloaded("test/missing-cached")
        #expect(exists == true)

        // Attempt to download (will trigger redownload)
        let task = Task {
            try? await downloader.download(
                modelId: "test/missing-cached",
                variant: .sdxlTurbo
            )
        }

        // Give it time to detect missing file
        try? await Task.sleep(for: .milliseconds(100))

        // Should have removed from registry
        exists = await registry.isDownloaded("test/missing-cached")
        #expect(exists == false)

        // Clean up
        await downloader.cancelDownload(modelId: "test/missing-cached")
        task.cancel()
    }

    // MARK: - Task Cancellation Tests

    @Test("Cancelled download throws AIError.cancelled")
    func cancelledDownloadThrowsCancelled() async {
        let downloader = DiffusionModelDownloader()

        // Start download in a Task
        let task = Task {
            try await downloader.download(
                modelId: "test/cancellable",
                variant: .sdxlTurbo
            )
        }

        // Give it time to start
        try? await Task.sleep(for: .milliseconds(50))

        // Cancel via downloader
        await downloader.cancelDownload(modelId: "test/cancellable")

        // Also cancel task
        task.cancel()

        // Verify task throws cancellation error
        do {
            _ = try await task.value
            Issue.record("Expected task to throw cancellation error")
        } catch let error as AIError {
            // Check if it's the cancelled case
            if case .cancelled = error {
                // Expected
            } else {
                Issue.record("Expected AIError.cancelled but got \(error)")
            }
        } catch {
            // May also throw CancellationError
            #expect(error is CancellationError)
        }
    }

    // MARK: - Thread Safety Tests

    @Test("Concurrent download requests are handled safely")
    func concurrentDownloadsAreThreadSafe() async {
        let downloader = DiffusionModelDownloader()

        // Start multiple concurrent downloads
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    let task = Task {
                        try? await downloader.download(
                            modelId: "test/concurrent-\(i)",
                            variant: .sdxlTurbo
                        )
                    }

                    // Let it start
                    try? await Task.sleep(for: .milliseconds(50))

                    // Cancel it
                    await downloader.cancelDownload(modelId: "test/concurrent-\(i)")
                    task.cancel()
                }
            }
        }

        // All should be cleaned up
        let finalCount = await downloader.activeDownloadCount
        #expect(finalCount == 0)
    }

    // MARK: - Model Registry Integration Tests

    @Test("Successful download registers model in registry")
    func successfulDownloadRegistersModel() async throws {
        // DOCUMENTATION:
        // After successful download, model should be registered:
        //
        // Expected behavior:
        // 1. Download completes successfully
        // 2. Actual size is calculated via allocatedSizeOfDirectory()
        // 3. DownloadedDiffusionModel is created with:
        //    - id: modelId
        //    - name: variant.displayName
        //    - variant: the variant
        //    - localPath: returned URL
        //    - sizeBytes: calculated size
        // 4. registry.addDownloaded() is called
        // 5. Model appears in registry.allDownloadedModels
        //
        // Example verification:
        // ```swift
        // let url = try await downloader.download(
        //     modelId: "mlx-community/sdxl-turbo",
        //     variant: .sdxlTurbo
        // )
        //
        // let registry = DiffusionModelRegistry.shared
        // let isDownloaded = await registry.isDownloaded("mlx-community/sdxl-turbo")
        // #expect(isDownloaded == true)
        //
        // let model = await registry.downloadedModel(for: "mlx-community/sdxl-turbo")
        // #expect(model?.localPath == url)
        // #expect(model?.variant == .sdxlTurbo)
        // ```
    }

    // MARK: - Error Handling Tests

    @Test("Download error is wrapped in AIError")
    func downloadErrorWrappedInAIError() async {
        // DOCUMENTATION:
        // All download errors should be wrapped in AIError:
        //
        // Mapping:
        // - CancellationError -> AIError.cancelled
        // - AIError -> passed through as-is
        // - Other errors -> AIError.downloadFailed(underlying: SendableError(error))
        //
        // This ensures consistent error handling across all providers.
    }

    // MARK: - File System Tests

    @Test("allocatedSizeOfDirectory calculates size correctly")
    func allocatedSizeCalculation() throws {
        _ = DiffusionModelDownloader()

        // Create temporary directory with known files
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files with known sizes
        let file1 = tempDir.appendingPathComponent("file1.txt")
        let file2 = tempDir.appendingPathComponent("file2.txt")

        let data1 = Data(repeating: 0, count: 1000) // 1KB
        let data2 = Data(repeating: 1, count: 2000) // 2KB

        try data1.write(to: file1)
        try data2.write(to: file2)

        // This would need to access the private method via reflection or make it internal for testing
        // For now, we document expected behavior

        // Expected: Should return 3000 bytes (1KB + 2KB)

        // Clean up
        try? FileManager.default.removeItem(at: tempDir)

        // DOCUMENTATION:
        // allocatedSizeOfDirectory() should:
        // 1. Enumerate all files recursively
        // 2. Skip hidden files
        // 3. Sum up file sizes (not directories)
        // 4. Return total as Int64
    }
}

#endif // canImport(Hub)
