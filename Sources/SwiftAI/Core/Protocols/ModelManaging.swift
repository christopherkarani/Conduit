// ModelManaging.swift
// SwiftAI
//
// Protocol for managing model lifecycle: discovery, download, caching, and deletion.
// Implementations handle model acquisition and storage for offline inference.

import Foundation

/// A type that manages model downloads, caching, and deletion.
///
/// The `ModelManaging` protocol defines the interface for managing the complete
/// lifecycle of models used in local inference. This includes discovering available
/// models, downloading them to device storage, tracking cached models, and
/// managing storage space.
///
/// ## Model Lifecycle
///
/// 1. **Discovery**: Query available models from a provider
/// 2. **Download**: Fetch model files to local storage with progress tracking
/// 3. **Cache**: Store and track models on disk
/// 4. **Deletion**: Remove cached models to free storage
///
/// ## Thread Safety
///
/// All methods are `async` and thread-safe. The protocol conforms to `Sendable`,
/// ensuring implementations can be safely used across actor boundaries.
///
/// ## Provider Implementation
///
/// Each inference provider (MLX, HuggingFace, etc.) implements this protocol
/// with provider-specific model discovery and download logic. Cloud providers
/// may return empty lists for cached models since they don't require local storage.
///
/// ## Usage Example
///
/// ```swift
/// let provider = MLXProvider()
///
/// // Discover available models
/// let available = try await provider.availableModels()
/// print("Found \(available.count) models")
///
/// // Check if model is already cached
/// let model = MLXModelIdentifier.llama3_2_1B
/// if await provider.isCached(model) {
///     print("Model ready for inference")
/// } else {
///     // Download with progress tracking
///     try await provider.download(model) { progress in
///         print("Download: \(progress.percentComplete)%")
///     }
/// }
///
/// // View cached models and storage usage
/// let cached = await provider.cachedModels()
/// let size = await provider.cacheSize()
/// print("Cached: \(cached.count) models, \(size.formatted)")
/// ```
///
/// ## Cancellation
///
/// Download operations support cancellation via structured concurrency:
///
/// ```swift
/// let task = Task {
///     try await provider.download(model) { progress in
///         print(progress.percentComplete)
///     }
/// }
///
/// // Later: cancel download
/// task.cancel()
/// ```
///
/// ## Storage Management
///
/// Use `cacheSize()` to monitor disk usage and `clearCache()` or selective
/// `delete(_:)` calls to manage storage:
///
/// ```swift
/// // Check storage
/// let size = await provider.cacheSize()
/// if size > .gigabytes(10) {
///     // Remove least recently used model
///     let cached = await provider.cachedModels()
///         .sorted { $0.lastAccessedAt < $1.lastAccessedAt }
///     if let oldest = cached.first {
///         try await provider.delete(oldest.modelId)
///     }
/// }
/// ```
///
/// - Note: Not all providers require model management. Cloud-based providers
///   like HuggingFace may provide minimal implementations since inference
///   happens remotely without local model storage.
public protocol ModelManaging: Sendable {
    /// The type of model identifier used by this provider.
    ///
    /// Each provider defines its own model identifier type that conforms
    /// to `ModelIdentifying`. For example, MLX uses `MLXModelIdentifier`,
    /// while HuggingFace uses `HuggingFaceModelIdentifier`.
    associatedtype ModelID: ModelIdentifying

    // MARK: - Discovery

    /// Lists all models available from this provider.
    ///
    /// Queries the provider's catalog of available models. For local providers
    /// like MLX, this returns models that can be downloaded from HuggingFace
    /// or other sources. For cloud providers, this returns models available
    /// via their API.
    ///
    /// The returned list includes metadata about each model such as size,
    /// description, and capabilities. Use this information to help users
    /// choose appropriate models for their use case.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = MLXProvider()
    /// let models = try await provider.availableModels()
    ///
    /// for model in models {
    ///     print("\(model.name) - \(model.size?.formatted ?? "unknown size")")
    ///     if let desc = model.description {
    ///         print("  \(desc)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// This method may perform network requests to fetch the latest catalog.
    /// Consider caching results if querying frequently.
    ///
    /// - Returns: An array of `ModelInfo` describing available models.
    /// - Throws: An error if the catalog cannot be retrieved (e.g., network failure).
    func availableModels() async throws -> [ModelInfo]

    /// Lists models currently cached on device.
    ///
    /// Returns information about all models that have been downloaded and are
    /// stored locally. Each entry includes the model identifier, local file path,
    /// disk size, and access timestamps.
    ///
    /// Use this method to:
    /// - Display cached models to the user
    /// - Identify candidates for deletion when storage is low
    /// - Verify a model is ready for offline inference
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cached = await provider.cachedModels()
    /// print("You have \(cached.count) models downloaded:")
    ///
    /// for info in cached.sorted(by: { $0.size > $1.size }) {
    ///     print("  \(info.modelId): \(info.size.formatted)")
    ///     print("    Last used: \(info.lastAccessedAt)")
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// This method reads from local storage and does not perform network requests.
    /// It should complete quickly even with many cached models.
    ///
    /// - Returns: An array of `CachedModelInfo` for locally stored models.
    func cachedModels() async -> [CachedModelInfo]

    /// Checks if a specific model is cached locally.
    ///
    /// Quickly determines whether a model has been downloaded and is available
    /// for immediate use without network access. This is useful before attempting
    /// inference to ensure the model is ready.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = MLXModelIdentifier.llama3_2_1B
    ///
    /// if await provider.isCached(model) {
    ///     // Model ready - can use immediately
    ///     let result = try await provider.generate("Hello", model: model)
    /// } else {
    ///     // Need to download first
    ///     print("Downloading model...")
    ///     try await provider.download(model) { progress in
    ///         print("\(progress.percentComplete)%")
    ///     }
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// This is a fast local check that does not perform network requests.
    ///
    /// - Parameter model: The model identifier to check.
    /// - Returns: `true` if the model is cached locally, `false` otherwise.
    func isCached(_ model: ModelID) async -> Bool

    // MARK: - Download

    /// Downloads a model to local storage.
    ///
    /// Fetches all required files for the specified model and stores them locally
    /// for offline inference. Progress is reported via the provided callback,
    /// allowing UI updates during the download.
    ///
    /// ## Progress Tracking
    ///
    /// The `progress` callback is called periodically with download status:
    /// - Byte counts (downloaded and total)
    /// - Current file being downloaded
    /// - Number of files completed
    /// - Calculated progress percentage
    ///
    /// ## Cancellation
    ///
    /// Downloads can be cancelled using task cancellation:
    ///
    /// ```swift
    /// let task = Task {
    ///     try await provider.download(model) { progress in
    ///         print("Download: \(progress.percentComplete)%")
    ///     }
    /// }
    ///
    /// // Cancel if user navigates away
    /// task.cancel()
    /// ```
    ///
    /// ## Resumption
    ///
    /// Implementations may support resuming interrupted downloads. If a download
    /// is cancelled or fails, calling `download(_:progress:)` again may continue
    /// from where it left off rather than restarting.
    ///
    /// ## Storage Requirements
    ///
    /// Before downloading, ensure sufficient storage is available. Use
    /// `availableModels()` to check the model's size, then verify disk space.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = MLXModelIdentifier.llama3_2_1B
    ///
    /// do {
    ///     let localURL = try await provider.download(model) { progress in
    ///         DispatchQueue.main.async {
    ///             self.progressBar.progress = progress.fractionCompleted
    ///             self.statusLabel.text = progress.currentFile ?? "Downloading..."
    ///         }
    ///     }
    ///     print("Model downloaded to: \(localURL)")
    /// } catch {
    ///     print("Download failed: \(error)")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - model: The model identifier to download.
    ///   - progress: A callback invoked periodically with download progress.
    ///               The callback is called on an arbitrary queue and may be called
    ///               frequently; avoid expensive work in the callback.
    /// - Returns: The local file URL where the model was saved.
    /// - Throws: An error if the download fails due to network issues, insufficient
    ///           storage, or invalid model identifier.
    func download(
        _ model: ModelID,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> URL

    /// Downloads a model with structured concurrency progress.
    ///
    /// Returns a `DownloadTask` that can be observed for progress updates and
    /// controlled (e.g., cancelled) independently. This is useful when you need
    /// to manage multiple downloads or integrate with SwiftUI's task modifiers.
    ///
    /// ## DownloadTask API
    ///
    /// The returned task provides:
    /// - `.progress`: Current download progress
    /// - `.isCancelled`: Whether cancellation was requested
    /// - `.isComplete`: Whether download finished successfully
    /// - `.error`: Error if download failed
    /// - `.cancel()`: Request cancellation
    /// - `.result()`: Await completion and get the URL
    ///
    /// ## Example
    ///
    /// ```swift
    /// let task = provider.download(model)
    ///
    /// // Monitor progress in a separate task
    /// Task {
    ///     while !task.isComplete && !task.isCancelled {
    ///         print("Progress: \(task.progress.percentComplete)%")
    ///         try? await Task.sleep(for: .seconds(1))
    ///     }
    /// }
    ///
    /// // Wait for completion
    /// do {
    ///     let url = try await task.result()
    ///     print("Downloaded to: \(url)")
    /// } catch {
    ///     print("Failed: \(error)")
    /// }
    /// ```
    ///
    /// ## SwiftUI Integration
    ///
    /// ```swift
    /// struct ModelDownloadView: View {
    ///     @State private var task: DownloadTask?
    ///
    ///     var body: some View {
    ///         VStack {
    ///             if let task = task {
    ///                 ProgressView(value: task.progress.fractionCompleted)
    ///                 Button("Cancel") { task.cancel() }
    ///             } else {
    ///                 Button("Download") {
    ///                     task = provider.download(model)
    ///                 }
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter model: The model identifier to download.
    /// - Returns: A `DownloadTask` representing the in-progress download.
    func download(_ model: ModelID) -> DownloadTask

    // MARK: - Cache Management

    /// Deletes a cached model from local storage.
    ///
    /// Removes all files associated with the specified model, freeing up disk space.
    /// After deletion, the model must be re-downloaded before it can be used again.
    ///
    /// ## Safety
    ///
    /// This operation cannot be undone. Ensure the model is not currently in use
    /// before deleting it. Attempting to delete a model that is actively loaded
    /// for inference may result in an error.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Remove a specific model
    /// let model = MLXModelIdentifier.llama3_2_1B
    /// try await provider.delete(model)
    /// print("Model deleted")
    ///
    /// // Verify it's gone
    /// let cached = await provider.isCached(model)
    /// assert(!cached)
    /// ```
    ///
    /// ## Storage Management
    ///
    /// Use this method to selectively remove models when storage is constrained:
    ///
    /// ```swift
    /// // Remove least recently used models to free space
    /// let cached = await provider.cachedModels()
    ///     .sorted { $0.lastAccessedAt < $1.lastAccessedAt }
    ///
    /// for info in cached.prefix(3) {
    ///     try await provider.delete(info.modelId)
    ///     print("Deleted \(info.modelId)")
    /// }
    /// ```
    ///
    /// - Parameter model: The model identifier to delete.
    /// - Throws: An error if the model cannot be deleted (e.g., file system error,
    ///           model not found, or model currently in use).
    func delete(_ model: ModelID) async throws

    /// Clears all cached models.
    ///
    /// Removes all downloaded models from local storage, freeing up all disk space
    /// used by the provider's model cache. This is a destructive operation that
    /// cannot be undone.
    ///
    /// ## Use Cases
    ///
    /// - User explicitly requests to clear app storage
    /// - Implementing a "Reset" or "Clear Data" feature
    /// - Recovering from corrupted model files
    /// - Freeing maximum storage space
    ///
    /// ## Safety
    ///
    /// Ensure no models are currently loaded for inference before calling this method.
    /// Active inference sessions may fail or produce errors if their models are deleted.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Show confirmation dialog
    /// let size = await provider.cacheSize()
    /// let alert = "Delete all cached models and free \(size.formatted)?"
    ///
    /// // User confirmed
    /// try await provider.clearCache()
    /// print("All models deleted")
    ///
    /// // Verify
    /// let remaining = await provider.cachedModels()
    /// assert(remaining.isEmpty)
    /// ```
    ///
    /// ## Alternative
    ///
    /// For selective deletion, use `delete(_:)` to remove individual models
    /// rather than clearing the entire cache.
    ///
    /// - Throws: An error if the cache cannot be cleared (e.g., file system error
    ///           or models currently in use).
    func clearCache() async throws

    /// Returns the total size of cached models.
    ///
    /// Calculates the combined disk space used by all cached models. This is useful
    /// for displaying storage usage to users or determining when to trigger cleanup.
    ///
    /// ## Performance
    ///
    /// This method reads file system metadata and may take longer if many models
    /// are cached. Consider caching the result if querying frequently.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Display storage usage
    /// let size = await provider.cacheSize()
    /// let cached = await provider.cachedModels()
    /// print("Storage: \(size.formatted) across \(cached.count) models")
    ///
    /// // Warn if storage is high
    /// if size > .gigabytes(10) {
    ///     print("Warning: High storage usage. Consider deleting unused models.")
    /// }
    /// ```
    ///
    /// ## Breakdown
    ///
    /// For per-model size information, use `cachedModels()` which includes
    /// `size` for each cached model.
    ///
    /// - Returns: The total size of all cached models as a `ByteCount`.
    func cacheSize() async -> ByteCount
}
