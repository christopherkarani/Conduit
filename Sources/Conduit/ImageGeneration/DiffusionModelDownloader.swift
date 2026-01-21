// DiffusionModelDownloader.swift
// Conduit
//
// This file is only available when MLX is available, and can download models
// using either `Hub` (swift-transformers) or `HuggingFace` (swift-huggingface,
// via the HuggingFaceHub trait).

#if canImport(MLX) && (canImport(Hub) || canImport(HuggingFace))

import Foundation
#if canImport(Hub)
import Hub
#endif
import CryptoKit

/// Downloads diffusion models from HuggingFace Hub.
///
/// ## Usage
///
/// ```swift
/// let downloader = DiffusionModelDownloader()
///
/// // Download with progress
/// let localPath = try await downloader.download(
///     modelId: "mlx-community/sdxl-turbo",
///     variant: .sdxlTurbo
/// ) { progress in
///     print("Downloaded: \(Int(progress.fractionCompleted * 100))%")
/// }
/// ```
public actor DiffusionModelDownloader {

    // MARK: - Properties

#if canImport(Hub)
    private let hubApi: HubApi
#endif
    private let token: String?
    private var activeDownloads: [String: Task<URL, Error>] = [:]
    private let registry = DiffusionModelRegistry.shared

    // MARK: - Initialization

    /// Creates a new downloader.
    ///
    /// - Parameter token: Optional HuggingFace token for authenticated downloads.
    public init(token: String? = nil) {
        self.token = token
        #if canImport(Hub)
        if let token {
            self.hubApi = HubApi(hfToken: token)
        } else {
            self.hubApi = HubApi()
        }
        #endif
    }

    // MARK: - Download

    /// Downloads a diffusion model from HuggingFace.
    ///
    /// - Parameters:
    ///   - modelId: HuggingFace repository ID (e.g., "mlx-community/sdxl-turbo").
    ///   - variant: The diffusion model variant.
    ///   - expectedChecksum: Optional SHA256 checksum to verify after download.
    ///   - progressHandler: Optional callback for download progress.
    /// - Returns: Local URL where the model was saved.
    /// - Throws: `AIError` if download fails, disk space is insufficient, or checksum verification fails.
    public func download(
        modelId: String,
        variant: DiffusionVariant,
        expectedChecksum: String? = nil,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> URL {

        // Check if already downloaded first (fast path)
        if let existingPath = await registry.localPath(for: modelId) {
            // Verify the path still exists
            if FileManager.default.fileExists(atPath: existingPath.path) {
                return existingPath
            } else {
                // Path no longer exists, remove from registry
                await registry.removeDownloaded(modelId)
            }
        }

        // Check available disk space before downloading
        let requiredBytes = variant.sizeBytes
        try checkAvailableDiskSpace(requiredBytes: requiredBytes)

        // Create download task
        let task = Task<URL, Error> { [weak self] in
            guard let self = self else {
                throw AIError.downloadFailed(underlying: SendableError(CancellationError()))
            }

            do {
                // Check for cancellation before starting
                try Task.checkCancellation()

                let localURL: URL
                #if canImport(HuggingFace)
                // Prefer swift-huggingface when available (HuggingFaceHub trait).
                let destinationDir = try Self.destinationDirectory(for: modelId)
                let foundationProgress = Progress(totalUnitCount: 1)
                localURL = try await HuggingFaceHubDownloader.shared.downloadSnapshot(
                    repoId: modelId,
                    kind: .model,
                    to: destinationDir,
                    revision: "main",
                    matching: ["*.safetensors", "*.json", "tokenizer*", "*.txt", "*.model"],
                    token: token,
                    progressHandler: { snapshot in
                        if let totalBytes = snapshot.totalBytes {
                            foundationProgress.totalUnitCount = totalBytes
                            foundationProgress.completedUnitCount = snapshot.bytesDownloaded
                        } else {
                            foundationProgress.totalUnitCount = Int64(snapshot.totalFiles)
                            foundationProgress.completedUnitCount = Int64(snapshot.filesCompleted)
                        }
                        progressHandler?(foundationProgress)
                    }
                )
                #else
                localURL = try await hubApi.snapshot(
                    from: Hub.Repo(id: modelId),
                    matching: ["*.safetensors", "*.json", "tokenizer*", "*.txt", "*.model"],
                    progressHandler: { progress in
                        progressHandler?(progress)
                    }
                )
                #endif

                // Check for cancellation after download
                try Task.checkCancellation()

                // Verify checksum if provided
                // WARNING: Checksum verification is optional but HIGHLY RECOMMENDED
                // for production use to prevent loading corrupted or malicious models.
                // A compromised model could execute arbitrary code or produce incorrect results.
                if let expectedChecksum = expectedChecksum {
                    try await self.verifyChecksum(at: localURL, expected: expectedChecksum)
                } else {
                    // Log warning when checksum is skipped
                    #if DEBUG
                    print("⚠️ WARNING: Downloading model '\(modelId)' without checksum verification. " +
                          "This is insecure and not recommended for production use.")
                    #endif
                }

                // Calculate actual size
                let size = try self.allocatedSizeOfDirectory(at: localURL)

                // Register as downloaded
                let downloaded = DownloadedDiffusionModel(
                    id: modelId,
                    name: variant.displayName,
                    variant: variant,
                    localPath: localURL,
                    sizeBytes: size
                )
                await registry.addDownloaded(downloaded)

                return localURL
            } catch is CancellationError {
                throw AIError.cancelled
            } catch let error as AIError {
                throw error
            } catch {
                throw AIError.downloadFailed(underlying: SendableError(error))
            }
        }

        // Atomically insert task - if another task was inserted concurrently,
        // cancel ours and use theirs instead
        if let existingTask = activeDownloads[modelId] {
            task.cancel()
            return try await existingTask.value
        }
        activeDownloads[modelId] = task

        do {
            let result = try await task.value
            cleanupDownloadTask(modelId: modelId)
            return result
        } catch {
            cleanupDownloadTask(modelId: modelId)
            throw error
        }
    }

    /// Cleans up a download task from the active downloads dictionary.
    private func cleanupDownloadTask(modelId: String) {
        activeDownloads.removeValue(forKey: modelId)
    }

    /// Cancels an active download.
    ///
    /// - Parameter modelId: The model ID to cancel.
    public func cancelDownload(modelId: String) {
        activeDownloads[modelId]?.cancel()
        activeDownloads.removeValue(forKey: modelId)
    }

    /// Checks if a model is currently being downloaded.
    ///
    /// - Parameter modelId: The model ID to check.
    /// - Returns: `true` if the model is currently downloading.
    public func isDownloading(modelId: String) -> Bool {
        activeDownloads[modelId] != nil
    }

    /// Cancels all active downloads.
    public func cancelAllDownloads() {
        for task in activeDownloads.values {
            task.cancel()
        }
        activeDownloads.removeAll()
    }

    /// Number of active downloads.
    public var activeDownloadCount: Int {
        activeDownloads.count
    }

    // MARK: - Delete

    /// Deletes a downloaded model from disk.
    ///
    /// - Parameter modelId: The model ID to delete.
    /// - Throws: Error if file deletion fails.
    public func deleteModel(modelId: String) async throws {
        guard let path = await registry.localPath(for: modelId) else {
            return // Not downloaded
        }

        try FileManager.default.removeItem(at: path)
        await registry.removeDownloaded(modelId)
    }

    /// Deletes all downloaded models.
    ///
    /// - Throws: Error if any deletion fails.
    public func deleteAllModels() async throws {
        let models = await registry.allDownloadedModels
        for model in models {
            try? FileManager.default.removeItem(at: model.localPath)
        }
        await registry.clearAllRecords()
    }

    // MARK: - Helpers

    private nonisolated static func destinationDirectory(for modelId: String) throws -> URL {
        let baseDir = ModelCache.defaultCacheDirectory
        let repoName = modelId.replacingOccurrences(of: "/", with: "--")
        return baseDir
            .appendingPathComponent("diffusion", isDirectory: true)
            .appendingPathComponent(repoName, isDirectory: true)
    }

    /// Calculates the allocated size of a directory.
    private nonisolated func allocatedSizeOfDirectory(at url: URL) throws -> Int64 {
        var size: Int64 = 0
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if resourceValues.isDirectory == false {
                size += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return size
    }

    // MARK: - Disk Space Validation

    /// Checks if sufficient disk space is available for download.
    ///
    /// - Parameter requiredBytes: The number of bytes required.
    /// - Throws: `AIError.insufficientDiskSpace` if not enough space is available.
    private nonisolated func checkAvailableDiskSpace(requiredBytes: Int64) throws {
        let fileManager = FileManager.default

        // Use the home directory to check available space
        let homeURL = fileManager.homeDirectoryForCurrentUser

        do {
            let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])

            guard let availableBytes = resourceValues.volumeAvailableCapacityForImportantUsage else {
                // If we can't determine available space, proceed with download
                return
            }

            // Require 10% buffer above the model size for safety
            let requiredWithBuffer = Int64(Double(requiredBytes) * 1.1)

            if availableBytes < requiredWithBuffer {
                throw AIError.insufficientDiskSpace(
                    required: ByteCount(requiredWithBuffer),
                    available: ByteCount(availableBytes)
                )
            }
        } catch let error as AIError {
            throw error
        } catch {
            // If we can't check disk space, log but proceed
            // This is a non-critical check
        }
    }

    // MARK: - Checksum Verification

    /// Verifies the SHA256 checksum of downloaded files.
    ///
    /// - Parameters:
    ///   - directoryURL: The directory containing downloaded files.
    ///   - expected: The expected SHA256 checksum (hex string).
    /// - Throws: `AIError.checksumMismatch` if verification fails.
    private nonisolated func verifyChecksum(at directoryURL: URL, expected: String) async throws {
        let fileManager = FileManager.default

        // Find the primary model file (largest .safetensors file)
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AIError.downloadFailed(
                underlying: SendableError(NSError(
                    domain: "DiffusionModelDownloader",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Cannot enumerate downloaded files"]
                ))
            )
        }

        var primaryFile: URL?
        var maxSize: Int64 = 0

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "safetensors" else { continue }
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            let size = Int64(resourceValues.fileSize ?? 0)
            if size > maxSize {
                maxSize = size
                primaryFile = fileURL
            }
        }

        guard let fileToVerify = primaryFile else {
            // No safetensors file found, skip verification
            return
        }

        // Calculate SHA256 checksum
        let actualChecksum = try await calculateSHA256(of: fileToVerify)

        // Compare checksums (case-insensitive)
        if actualChecksum.lowercased() != expected.lowercased() {
            throw AIError.checksumMismatch(expected: expected, actual: actualChecksum)
        }
    }

    /// Calculates the SHA256 checksum of a file.
    ///
    /// - Parameter fileURL: The file URL.
    /// - Returns: The SHA256 checksum as a hex string.
    private nonisolated func calculateSHA256(of fileURL: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024 // 1MB chunks

        while true {
            let data = try handle.read(upToCount: bufferSize)
            guard let data = data, !data.isEmpty else { break }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Convenience Extensions

extension DiffusionModelDownloader {

    /// Downloads a model from the available models catalog.
    ///
    /// - Parameters:
    ///   - info: Model info from `DiffusionModelRegistry.availableModels`.
    ///   - progressHandler: Optional progress callback.
    /// - Returns: Local URL where the model was saved.
    public func download(
        model info: DiffusionModelInfo,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> URL {
        try await download(
            modelId: info.id,
            variant: info.variant,
            expectedChecksum: info.checksum,
            progressHandler: progressHandler
        )
    }
}

#endif // canImport(MLX) && (canImport(Hub) || canImport(HuggingFace))
