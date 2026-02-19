// ModelManager.swift
// Conduit
//
// Central manager for model downloads, caching, and lifecycle.
// Download support is provided by either `Hub` (swift-transformers) or
// `HuggingFace` (swift-huggingface, via the HuggingFaceHub trait).

#if canImport(Hub) || canImport(HuggingFace)

import Foundation
import Logging

#if canImport(Hub)
import Hub
#endif

/// Central manager for model downloads, caching, and lifecycle.
///
/// The `ModelManager` is the primary interface for managing model files on device.
/// It handles downloading from HuggingFace Hub, caching, and cleanup. Use the
/// shared singleton instance for application-wide model management.
///
/// ## Usage
///
/// ```swift
/// // Check if model is cached
/// if await ModelManager.shared.isCached(.llama3_2_1b) {
///     let path = await ModelManager.shared.localPath(for: .llama3_2_1b)
///     // Load and use the model
/// }
///
/// // Download a model with progress tracking
/// let url = try await ModelManager.shared.download(.llama3_2_1b) { progress in
///     print("Progress: \(progress.percentComplete)%")
///     if let speed = progress.bytesPerSecond {
///         print("Speed: \(ByteCount(Int64(speed)).formatted)/s")
///     }
/// }
///
/// // Manage cache size
/// let size = await ModelManager.shared.cacheSize()
/// if size > .gigabytes(50) {
///     try await ModelManager.shared.evictToFit(maxSize: .gigabytes(30))
/// }
/// ```
///
/// ## Model Storage
///
/// Models are stored in the user's cache directory organized by provider:
/// - MLX models: `~/Library/Caches/Conduit/Models/mlx/{repo-name}/`
/// - HuggingFace models: `~/Library/Caches/Conduit/Models/huggingface/{repo-name}/`
///
/// Apple Foundation Models are system-managed and cannot be downloaded.
/// llama.cpp models are local GGUF files and are not managed by ModelManager.
///
/// ## Thread Safety
///
/// As an actor, `ModelManager` provides automatic thread safety. All operations
/// are isolated to the actor's executor, ensuring safe concurrent access from
/// multiple threads or tasks.
///
/// ## SwiftUI Integration
///
/// ```swift
/// struct ModelDownloadView: View {
///     @State private var downloadTask: DownloadTask?
///
///     var body: some View {
///         if let task = downloadTask {
///             ProgressView(value: task.progress.fractionCompleted)
///             Text("\(task.progress.percentComplete)%")
///             Button("Cancel") { task.cancel() }
///         } else {
///             Button("Download") {
///                 downloadTask = await ModelManager.shared.downloadTask(for: .llama3_2_1b)
///             }
///         }
///     }
/// }
/// ```
public actor ModelManager {

    // MARK: - Logger

    /// Logger for model management operations.
    private static let logger = ConduitLoggers.modelManager

    // MARK: - Singleton

    /// Shared instance for application-wide model management.
    ///
    /// Use this singleton for all model management operations. The shared instance
    /// maintains a single cache and coordinates all downloads.
    ///
    /// ```swift
    /// let models = await ModelManager.shared.cachedModels()
    /// ```
    public static let shared = ModelManager()

    // MARK: - Properties

    /// The underlying cache for model metadata.
    ///
    /// Lazily initialized on first access to avoid blocking app startup.
    private var cache: ModelCache?

    /// Active download tasks by model identifier.
    ///
    /// Used to prevent duplicate downloads and provide cancellation.
    private var activeTasks: [ModelIdentifier: DownloadTask] = [:]

    /// Active download Swift Tasks for awaiting completion.
    private var activeDownloads: [ModelIdentifier: Task<URL, Error>] = [:]

    // MARK: - Initialization

    /// Creates a new model manager instance.
    ///
    /// - Note: Use `ModelManager.shared` for most cases. Direct initialization
    ///   is available for testing or advanced use cases.
    public init() {}

    /// Ensures the cache is initialized.
    ///
    /// - Returns: The initialized model cache.
    /// - Throws: `AIError.fileError` if cache cannot be initialized.
    private func ensureCache() async throws -> ModelCache {
        if let cache = self.cache {
            return cache
        }

        let newCache = try await ModelCache()
        self.cache = newCache
        return newCache
    }

    // MARK: - Discovery

    /// Returns all models currently cached on device.
    ///
    /// The returned array is sorted by last accessed date, with the most
    /// recently used models first.
    ///
    /// - Returns: Array of cached model information.
    ///
    /// ## Example
    /// ```swift
    /// let cached = await ModelManager.shared.cachedModels()
    /// for model in cached {
    ///     print("\(model.identifier.displayName): \(model.size.formatted)")
    /// }
    /// ```
    public func cachedModels() async throws -> [CachedModelInfo] {
        let cache = try await ensureCache()
        return await cache.allCachedModels()
    }

    /// Checks if a model is cached locally.
    ///
    /// This is a fast check that only examines the cache metadata.
    /// It does not verify that the files still exist on disk.
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: `true` if the model is cached, `false` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// if await ModelManager.shared.isCached(.llama3_2_1b) {
    ///     // Model is ready to use
    /// } else {
    ///     // Need to download first
    /// }
    /// ```
    public func isCached(_ model: ModelIdentifier) async -> Bool {
        guard let cache = try? await ensureCache() else {
            return false
        }
        return await cache.isCached(model)
    }

    /// Returns the local file path for a cached model.
    ///
    /// If the model is cached, returns the URL to its directory. The directory
    /// contains all model files (weights, config, tokenizer, etc.).
    ///
    /// - Parameter model: The model identifier to look up.
    /// - Returns: The local directory URL if cached, `nil` otherwise.
    ///
    /// ## Example
    /// ```swift
    /// if let path = await ModelManager.shared.localPath(for: .llama3_2_1b) {
    ///     // Load model from path
    ///     let files = try FileManager.default.contentsOfDirectory(at: path)
    /// }
    /// ```
    public func localPath(for model: ModelIdentifier) async -> URL? {
        guard let cache = try? await ensureCache() else {
            return nil
        }
        return await cache.localPath(for: model)
    }

    // MARK: - Download

    /// Downloads a model with progress callback.
    ///
    /// Downloads the model files from HuggingFace Hub to local storage. If the
    /// model is already cached, returns the cached path immediately (updating
    /// LRU tracking). If a download is already in progress, waits for it to complete.
    ///
    /// - Parameters:
    ///   - model: The model to download.
    ///   - progress: Optional callback for progress updates. Called on arbitrary threads.
    /// - Returns: The local URL where the model was saved.
    /// - Throws: `AIError` if the download fails.
    ///
    /// ## Error Cases
    /// - `AIError.invalidInput` if attempting to download Foundation Models
    /// - `AIError.downloadFailed` for network or HuggingFace Hub errors
    /// - `AIError.fileError` for storage issues
    ///
    /// ## Example
    /// ```swift
    /// let url = try await ModelManager.shared.download(.llama3_2_1b) { progress in
    ///     DispatchQueue.main.async {
    ///         self.progressValue = progress.fractionCompleted
    ///     }
    /// }
    /// ```
    public func download(
        _ model: ModelIdentifier,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        // Foundation Models cannot be downloaded
        if case .foundationModels = model {
            throw AIError.invalidInput(
                "Foundation Models are system-managed and cannot be downloaded. Use ModelIdentifier.mlx() or .huggingFace() instead."
            )
        }

        let cache = try await ensureCache()

        // Check if already cached
        if let existingPath = await cache.localPath(for: model) {
            await cache.markAccessed(model)
            return existingPath
        }

        // Check for existing download
        if let existingDownload = activeDownloads[model] {
            return try await existingDownload.value
        }

        // Create download task for tracking
        let downloadTask = activeTasks[model] ?? DownloadTask(model: model)
        activeTasks[model] = downloadTask

        // Create async task for the download
        let task = Task<URL, Error> {
            do {
                downloadTask.updateState(.downloading)

                // Determine destination directory
                let destinationDir = try destinationDirectory(for: model)

                // Create directory if needed
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: destinationDir.path) {
                    try fileManager.createDirectory(
                        at: destinationDir,
                        withIntermediateDirectories: true
                    )
                }

                // Download using HuggingFace Hub
                let repoId = model.rawValue

                // Use Hub.snapshot for downloading the entire model repository
                let downloadedURL = try await downloadFromHub(
                    repoId: repoId,
                    to: destinationDir,
                    progress: { [weak downloadTask] downloadProgress in
                        downloadTask?.updateProgress(downloadProgress)
                        progress?(downloadProgress)
                    }
                )

                // Calculate total size
                let size = try calculateDirectorySize(at: downloadedURL)

                // Create cache info
                let info = CachedModelInfo(
                    identifier: model,
                    path: downloadedURL,
                    size: size,
                    downloadedAt: Date(),
                    lastAccessedAt: Date(),
                    revision: "main" // Could be extracted from Hub response
                )

                // Add to cache
                try await cache.add(info)

                // Update task state
                downloadTask.updateState(.completed(downloadedURL))

                return downloadedURL

            } catch {
                // Handle cancellation
                if Task.isCancelled {
                    downloadTask.updateState(.cancelled)
                    throw CancellationError()
                }

                // Update task state
                let wrappedError = (error as? AIError) ?? AIError.download(error)
                downloadTask.updateState(.failed(wrappedError))
                throw wrappedError
            }
        }

        // Store the task and wait for result
        activeDownloads[model] = task
        downloadTask.downloadTask = task

        defer {
            activeDownloads[model] = nil
            activeTasks[model] = nil
        }

        return try await task.value
    }

    /// Creates or returns an existing download task for a model.
    ///
    /// The returned `DownloadTask` is observable and can be used in SwiftUI
    /// to track download progress. If a download is already in progress,
    /// returns the existing task.
    ///
    /// - Parameter model: The model to download.
    /// - Returns: A download task for tracking progress.
    ///
    /// ## Example
    /// ```swift
    /// let task = await ModelManager.shared.downloadTask(for: .llama3_2_1b)
    ///
    /// // Observe in SwiftUI
    /// ProgressView(value: task.progress.fractionCompleted)
    ///
    /// // Wait for completion
    /// let url = try await task.result()
    /// ```
    public func downloadTask(for model: ModelIdentifier) async -> DownloadTask {
        // Return existing task if available
        if let existingTask = activeTasks[model] {
            return existingTask
        }

        // Create new task and start download in background
        let task = DownloadTask(model: model)
        activeTasks[model] = task

        // Start the download in a detached task
        Task.detached { [weak self] in
            do {
                _ = try await self?.download(model, progress: nil)
            } catch {
                // Error is already handled in download()
            }
        }

        return task
    }

    /// Cancels an active download.
    ///
    /// If a download is in progress for the specified model, it is cancelled.
    /// Partial downloads are removed from disk.
    ///
    /// - Parameter model: The model whose download should be cancelled.
    ///
    /// ## Example
    /// ```swift
    /// // Start download
    /// let task = await ModelManager.shared.downloadTask(for: .llama3_2_1b)
    ///
    /// // Cancel later
    /// await ModelManager.shared.cancelDownload(.llama3_2_1b)
    /// ```
    public func cancelDownload(_ model: ModelIdentifier) async {
        // Cancel the download task
        activeDownloads[model]?.cancel()
        activeTasks[model]?.cancel()

        // Clean up
        activeDownloads[model] = nil
        activeTasks[model] = nil
    }

    // MARK: - Cache Management

    /// Deletes a cached model.
    ///
    /// Removes the model from the cache and deletes all associated files from disk.
    /// Does nothing if the model is not cached.
    ///
    /// - Parameter model: The model to delete.
    /// - Throws: `AIError.fileError` if files cannot be deleted.
    ///
    /// ## Example
    /// ```swift
    /// try await ModelManager.shared.delete(.llama3_2_1b)
    /// print("Model deleted, disk space freed")
    /// ```
    public func delete(_ model: ModelIdentifier) async throws {
        let cache = try await ensureCache()
        try await cache.remove(model)
    }

    /// Clears all cached models.
    ///
    /// Removes all models from the cache and deletes all model files from disk.
    /// The cache directory structure is preserved.
    ///
    /// - Throws: `AIError.fileError` if files cannot be deleted.
    ///
    /// ## Warning
    /// This operation is irreversible and will delete all downloaded models.
    ///
    /// ## Example
    /// ```swift
    /// // Confirm with user first!
    /// try await ModelManager.shared.clearCache()
    /// print("All cached models removed")
    /// ```
    public func clearCache() async throws {
        let cache = try await ensureCache()
        try await cache.clearAll()
    }

    /// Returns the total size of all cached models.
    ///
    /// Sums the size of all models in the cache.
    ///
    /// - Returns: The total cache size.
    ///
    /// ## Example
    /// ```swift
    /// let size = await ModelManager.shared.cacheSize()
    /// print("Cache is using \(size.formatted)")
    /// ```
    public func cacheSize() async -> ByteCount {
        guard let cache = try? await ensureCache() else {
            return ByteCount(0)
        }
        return await cache.totalSize()
    }

    /// Evicts models until cache size is under the limit.
    ///
    /// Uses LRU (Least Recently Used) eviction strategy to remove the oldest
    /// accessed models until the total cache size is below the specified limit.
    ///
    /// - Parameter maxSize: The maximum allowed cache size.
    /// - Throws: `AIError.fileError` if models cannot be deleted.
    ///
    /// ## Example
    /// ```swift
    /// // Keep cache under 20GB
    /// try await ModelManager.shared.evictToFit(maxSize: .gigabytes(20))
    /// ```
    public func evictToFit(maxSize: ByteCount) async throws {
        let cache = try await ensureCache()
        _ = try await cache.evictToFit(maxSize: maxSize)
    }

    // MARK: - Access Tracking

    /// Marks a model as accessed (for LRU tracking).
    ///
    /// Call this when loading a model for inference to update the LRU tracking.
    /// This ensures frequently used models are kept in cache during eviction.
    ///
    /// - Parameter model: The model that was accessed.
    ///
    /// ## Example
    /// ```swift
    /// // When loading a model for inference
    /// if let path = await ModelManager.shared.localPath(for: .llama3_2_1b) {
    ///     await ModelManager.shared.markAccessed(.llama3_2_1b)
    ///     // Load and use the model
    /// }
    /// ```
    public func markAccessed(_ model: ModelIdentifier) async {
        guard let cache = try? await ensureCache() else { return }
        await cache.markAccessed(model)
    }

    // MARK: - Private Helpers

    /// Determines the destination directory for a model.
    private func destinationDirectory(for model: ModelIdentifier) throws -> URL {
        let baseDir = ModelCache.defaultCacheDirectory

        let providerDir: String
        let repoName = model.rawValue.replacingOccurrences(of: "/", with: "--")

        switch model.provider {
        case .mlx:
            providerDir = "mlx"
        case .coreml:
            throw AIError.invalidInput("Core ML models are local .mlmodelc bundles and are not downloaded by ModelManager")
        case .llama:
            throw AIError.invalidInput("llama.cpp models are local GGUF files and are not downloaded by ModelManager")
        case .huggingFace:
            providerDir = "huggingface"
        case .foundationModels:
            throw AIError.invalidInput("Foundation Models cannot be downloaded")
        case .openAI:
            throw AIError.invalidInput("OpenAI models cannot be downloaded - they are cloud-only")
        case .openRouter:
            throw AIError.invalidInput("OpenRouter models cannot be downloaded - they are cloud-only")
        case .ollama:
            throw AIError.invalidInput("Ollama models must be managed via Ollama CLI")
        case .anthropic:
            throw AIError.invalidInput("Anthropic models cannot be downloaded - they are cloud-only")
        case .kimi:
            throw AIError.invalidInput("Kimi models cannot be downloaded - they are cloud-only")
        case .minimax:
            throw AIError.invalidInput("MiniMax models cannot be downloaded - they are cloud-only")
        case .azure:
            throw AIError.invalidInput("Azure OpenAI models cannot be downloaded - they are cloud-only")
        }

        return baseDir
            .appendingPathComponent(providerDir, isDirectory: true)
            .appendingPathComponent(repoName, isDirectory: true)
    }

    /// Downloads model files from HuggingFace Hub.
    private func downloadFromHub(
        repoId: String,
        to destination: URL,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL {
        do {
            #if canImport(HuggingFace)
            // Prefer swift-huggingface when available (HuggingFaceHub trait).
            return try await HuggingFaceHubDownloader.shared.downloadSnapshot(
                repoId: repoId,
                kind: .model,
                to: destination,
                revision: "main",
                matching: [],
                token: nil,
                progressHandler: progress
            )
            #else
            var currentProgress = DownloadProgress()
            currentProgress.totalFiles = 1 // Will be updated

            // Create repo reference
            let repo = Hub.Repo(id: repoId)

            // Download the model repository using Hub.snapshot
            // This downloads all matching files to the Hub's cache directory
            let snapshotURL = try await Hub.snapshot(
                from: repo,
                matching: ["*"] // Download all files
            ) { downloadProgress in
                // Convert Progress to our DownloadProgress
                currentProgress.bytesDownloaded = downloadProgress.completedUnitCount
                currentProgress.totalBytes = downloadProgress.totalUnitCount

                // Calculate fraction for display
                if downloadProgress.totalUnitCount > 0 {
                    let fraction = Double(downloadProgress.completedUnitCount) / Double(downloadProgress.totalUnitCount)
                    currentProgress.filesCompleted = Int(fraction * Double(currentProgress.totalFiles))
                }

                progress(currentProgress)
            }

            return snapshotURL
            #endif
        } catch {
            throw AIError.download(error)
        }
    }

    /// Calculates the total size of a directory.
    private func calculateDirectorySize(at url: URL) throws -> ByteCount {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ByteCount(0)
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])

            if resourceValues.isDirectory == false {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return ByteCount(totalSize)
    }
}

// MARK: - Size Estimation

extension ModelManager {

    /// Estimates the download size before starting a download.
    ///
    /// Uses the HuggingFace API to calculate the total size of files that would
    /// be downloaded. This allows UI to show accurate progress and help users
    /// understand storage requirements.
    ///
    /// - Parameter model: The model to estimate size for.
    /// - Returns: Estimated size in bytes, or `nil` if estimation failed or unavailable.
    ///
    /// ## Example
    /// ```swift
    /// if let size = await ModelManager.shared.estimateDownloadSize(.llama3_2_1b) {
    ///     print("Download size: \(ByteCount(size).formatted)")
    ///
    ///     // Check available storage
    ///     let available = try FileManager.default.availableCapacity(forUsage: .opportunistic)
    ///     if available < size {
    ///         print("Warning: Insufficient storage space")
    ///     }
    /// }
    /// ```
    public func estimateDownloadSize(_ model: ModelIdentifier) async -> ByteCount? {
        // Foundation Models are system-managed, no download needed
        if case .foundationModels = model {
            return nil
        }
        // Core ML models are local compiled assets, no download needed
        if case .coreml = model {
            return nil
        }

        let repoId = model.rawValue
        guard let totalBytes = await HFMetadataService.shared.estimateTotalSize(
            repoId: repoId,
            patterns: HFMetadataService.mlxFilePatterns
        ) else {
            return nil
        }

        return ByteCount(totalBytes)
    }

    /// Downloads a model with pre-fetched size estimation for accurate progress.
    ///
    /// This method first estimates the download size, then uses it to provide
    /// accurate progress reporting including byte counts and ETA.
    ///
    /// - Parameters:
    ///   - model: The model to download.
    ///   - progress: Optional callback for progress updates with accurate total size.
    /// - Returns: The local URL where the model was saved.
    /// - Throws: `AIError` if the download fails.
    ///
    /// ## Example
    /// ```swift
    /// let url = try await ModelManager.shared.downloadWithEstimation(.llama3_2_1b) { progress in
    ///     print("Progress: \(progress.percentComplete)%")
    ///     if let eta = progress.formattedETA {
    ///         print("ETA: \(eta)")
    ///     }
    ///     if let speed = progress.formattedSpeed {
    ///         print("Speed: \(speed)")
    ///     }
    /// }
    /// ```
    public func downloadWithEstimation(
        _ model: ModelIdentifier,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        // Pre-fetch estimated size
        let estimatedSize = await estimateDownloadSize(model)

        // Create speed calculator for this download
        let speedCalculator = SpeedCalculator()
        var speedTask: Task<Void, Never>?
        var speedContinuation: AsyncStream<DownloadProgress>.Continuation?
        var speedContinuationRef: AsyncStream<DownloadProgress>.Continuation?

        if let progress {
            let speedStream = AsyncStream<DownloadProgress> { continuation in
                speedContinuation = continuation
            }
            speedContinuationRef = speedContinuation
            let continuationSnapshot = speedContinuationRef
            speedTask = Task {
                for await update in speedStream {
                    await speedCalculator.addSample(bytes: update.bytesDownloaded)
                    if let speed = await speedCalculator.averageSpeed() {
                        var updated = update
                        updated.bytesPerSecond = speed

                        if let total = updated.totalBytes, speed > 0 {
                            let remaining = total - updated.bytesDownloaded
                            updated.estimatedTimeRemaining = TimeInterval(remaining) / speed
                        }

                        progress(updated)
                    }
                }
                continuationSnapshot?.finish()
            }
        }

        let speedContinuationSnapshot = speedContinuationRef

        defer {
            speedContinuationSnapshot?.finish()
            speedTask?.cancel()
        }

        // Wrap progress callback with size and speed enrichment
        let enrichedProgress: (@Sendable (DownloadProgress) -> Void)? = progress.map { callback in
            { @Sendable (downloadProgress: DownloadProgress) in
                var enriched = downloadProgress

                // Set total bytes from estimation if not provided
                if enriched.totalBytes == nil {
                    enriched.totalBytes = estimatedSize?.bytes
                }

                // Call callback immediately with basic progress
                callback(enriched)
                speedContinuationSnapshot?.yield(enriched)
            }
        }

        return try await download(model, progress: enrichedProgress)
    }

    /// Downloads a model after validating MLX compatibility.
    ///
    /// This method validates the model's compatibility with MLX before downloading,
    /// preventing wasted bandwidth and storage on incompatible models.
    ///
    /// - Parameters:
    ///   - model: The model to download.
    ///   - skipValidation: If `true`, skips compatibility validation. Defaults to `false`.
    ///   - progress: Optional callback for progress updates.
    /// - Returns: The local URL where the model was saved.
    /// - Throws: `AIError.incompatibleModel` if validation fails, or other `AIError` on download failure.
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let url = try await ModelManager.shared.downloadValidated(.llama3_2_1b)
    ///     print("Downloaded to: \(url)")
    /// } catch AIError.incompatibleModel(let model, let reasons) {
    ///     print("Cannot download \(model.rawValue):")
    ///     for reason in reasons {
    ///         print("  - \(reason)")
    ///     }
    /// }
    /// ```
    public func downloadValidated(
        _ model: ModelIdentifier,
        skipValidation: Bool = false,
        progress: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        // Skip validation for non-MLX models
        guard case .mlx = model else {
            return try await downloadWithEstimation(model, progress: progress)
        }

        if !skipValidation {
            let result = await MLXCompatibilityChecker.shared.checkCompatibility(model)

            switch result {
            case .compatible:
                break  // Proceed with download

            case .incompatible(let reasons):
                throw AIError.incompatibleModel(
                    model: model,
                    reasons: reasons.map { $0.description }
                )

            case .unknown(let error):
                // Log warning but allow download attempt
                Self.logger.warning("Could not validate compatibility for \(model.rawValue): \(error?.localizedDescription ?? "unknown")")
            }
        }

        return try await downloadWithEstimation(model, progress: progress)
    }
}

// MARK: - Convenience Extensions

extension ModelManager {

    /// Returns the number of cached models.
    public var cachedModelCount: Int {
        get async {
            (try? await cachedModels())?.count ?? 0
        }
    }

    /// Checks if any models are currently being downloaded.
    public var hasActiveDownloads: Bool {
        !activeDownloads.isEmpty
    }

    /// Returns all active download tasks.
    public var activeDownloadTasks: [DownloadTask] {
        Array(activeTasks.values)
    }
}

#endif // canImport(Hub) || canImport(HuggingFace)
