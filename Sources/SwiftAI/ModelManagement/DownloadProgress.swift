// DownloadProgress.swift
// SwiftAI
//
// Types for tracking model download progress and state.

import Foundation
import Observation

// MARK: - DownloadProgress

/// Progress information for a model download.
///
/// Tracks the progress of downloading model files from remote sources,
/// including byte counts, file progress, transfer speed, and estimated
/// time remaining.
///
/// ## Usage
///
/// ```swift
/// let progress = DownloadProgress(
///     bytesDownloaded: 512_000_000,
///     totalBytes: 2_000_000_000,
///     currentFile: "model.safetensors",
///     filesCompleted: 2,
///     totalFiles: 5
/// )
///
/// print("Progress: \(progress.percentComplete)%")  // "Progress: 25%"
/// print("Fraction: \(progress.fractionCompleted)")  // "Fraction: 0.256"
/// ```
///
/// ## Computed Properties
///
/// - `fractionCompleted`: Progress as a decimal (0.0 to 1.0)
/// - `percentComplete`: Progress as an integer (0 to 100)
///
/// ## Thread Safety
///
/// This struct conforms to `Sendable` and can be safely passed across
/// actor boundaries for progress reporting.
public struct DownloadProgress: Sendable, Equatable {

    // MARK: - Properties

    /// Number of bytes downloaded so far.
    ///
    /// This value increases as the download progresses. It may be updated
    /// multiple times per second during active downloads.
    public var bytesDownloaded: Int64

    /// Total number of bytes to download, if known.
    ///
    /// This may be `nil` if the server doesn't provide a `Content-Length`
    /// header or if downloading multiple files with unknown total size.
    public var totalBytes: Int64?

    /// The name of the file currently being downloaded.
    ///
    /// For model downloads involving multiple files (weights, config, tokenizer),
    /// this indicates which file is currently in progress.
    ///
    /// Example: `"model.safetensors"`, `"tokenizer.json"`, `"config.json"`
    public var currentFile: String?

    /// Number of files that have been fully downloaded.
    ///
    /// This increments each time a file completes. Together with `totalFiles`,
    /// it provides an alternative progress metric when byte counts are unavailable.
    public var filesCompleted: Int

    /// Total number of files to download.
    ///
    /// Models typically consist of multiple files:
    /// - Model weights (`.safetensors`, `.gguf`, etc.)
    /// - Configuration files (`.json`)
    /// - Tokenizer data
    /// - Metadata
    public var totalFiles: Int

    /// Estimated time remaining for the download to complete.
    ///
    /// Calculated based on current transfer speed and remaining bytes.
    /// This value may fluctuate as network conditions change.
    ///
    /// `nil` if the estimate cannot be calculated (e.g., insufficient data
    /// or unknown total size).
    public var estimatedTimeRemaining: TimeInterval?

    /// Current download speed in bytes per second.
    ///
    /// This value is typically averaged over a short window (e.g., 5 seconds)
    /// to smooth out network fluctuations.
    ///
    /// Example values:
    /// - 1,000,000 bytes/sec = ~1 MB/s
    /// - 10,000,000 bytes/sec = ~10 MB/s
    public var bytesPerSecond: Double?

    // MARK: - Computed Properties

    /// Progress as a fraction between 0.0 and 1.0.
    ///
    /// This is calculated from either:
    /// 1. Byte progress (`bytesDownloaded / totalBytes`), if total size is known
    /// 2. File progress (`filesCompleted / totalFiles`), if total size is unknown
    ///
    /// Returns `0.0` if progress cannot be determined.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let progress = DownloadProgress(
    ///     bytesDownloaded: 500_000_000,
    ///     totalBytes: 2_000_000_000
    /// )
    /// print(progress.fractionCompleted)  // 0.25
    /// ```
    public var fractionCompleted: Double {
        // Prefer byte-based progress if total size is known
        if let total = totalBytes, total > 0 {
            return Double(bytesDownloaded) / Double(total)
        }

        // Fall back to file-based progress
        guard totalFiles > 0 else { return 0.0 }
        return Double(filesCompleted) / Double(totalFiles)
    }

    /// Progress as a percentage between 0 and 100.
    ///
    /// Derived from `fractionCompleted` and rounded to the nearest integer.
    /// Useful for displaying progress to users.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let progress = DownloadProgress(
    ///     bytesDownloaded: 750_000_000,
    ///     totalBytes: 2_000_000_000
    /// )
    /// print("\(progress.percentComplete)%")  // "37%"
    /// ```
    public var percentComplete: Int {
        Int((fractionCompleted * 100).rounded())
    }

    // MARK: - Initialization

    /// Creates a download progress instance.
    ///
    /// - Parameters:
    ///   - bytesDownloaded: Number of bytes downloaded so far. Defaults to 0.
    ///   - totalBytes: Total bytes to download, if known. Defaults to `nil`.
    ///   - currentFile: Name of the file currently being downloaded. Defaults to `nil`.
    ///   - filesCompleted: Number of files completed. Defaults to 0.
    ///   - totalFiles: Total number of files to download. Defaults to 0.
    ///   - estimatedTimeRemaining: Estimated time remaining in seconds. Defaults to `nil`.
    ///   - bytesPerSecond: Current download speed in bytes/second. Defaults to `nil`.
    public init(
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64? = nil,
        currentFile: String? = nil,
        filesCompleted: Int = 0,
        totalFiles: Int = 0,
        estimatedTimeRemaining: TimeInterval? = nil,
        bytesPerSecond: Double? = nil
    ) {
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.currentFile = currentFile
        self.filesCompleted = filesCompleted
        self.totalFiles = totalFiles
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.bytesPerSecond = bytesPerSecond
    }
}

// MARK: - DownloadState

/// The current state of a download task.
///
/// A download progresses through several states during its lifecycle:
///
/// 1. `.pending` - Created but not yet started
/// 2. `.downloading` - Actively downloading files
/// 3. `.paused` - Temporarily suspended (if supported)
/// 4. `.completed(URL)` - Successfully finished
/// 5. `.failed(Error)` - Encountered an error
/// 6. `.cancelled` - User cancelled the download
///
/// ## State Transitions
///
/// ```
///     pending ──> downloading ──> completed(URL)
///                     │    │
///                     │    └──> paused ──> downloading
///                     │
///                     └──> failed(Error)
///                     │
///                     └──> cancelled
/// ```
///
/// ## Usage
///
/// ```swift
/// switch downloadState {
/// case .pending:
///     print("Waiting to start...")
/// case .downloading:
///     print("Downloading: \(progress.percentComplete)%")
/// case .paused:
///     print("Paused - tap to resume")
/// case .completed(let url):
///     print("Downloaded to: \(url)")
/// case .failed(let error):
///     print("Error: \(error)")
/// case .cancelled:
///     print("Cancelled by user")
/// }
/// ```
///
/// ## Active vs Terminal States
///
/// Use `isActive` and `isTerminal` to check state categories:
///
/// ```swift
/// if state.isActive {
///     // Show progress indicator
/// }
///
/// if state.isTerminal {
///     // Hide progress, show result
/// }
/// ```
public enum DownloadState: Sendable {
    /// The download has been created but not yet started.
    ///
    /// This is the initial state when a `DownloadTask` is created.
    case pending

    /// The download is actively transferring data.
    ///
    /// Progress updates are being reported during this state.
    case downloading

    /// The download has been temporarily paused.
    ///
    /// - Note: Not all implementations support pausing. Check provider
    ///   documentation for pause/resume support.
    case paused

    /// The download completed successfully.
    ///
    /// - Parameter url: The local file URL where the model was saved.
    case completed(URL)

    /// The download failed due to an error.
    ///
    /// - Parameter error: The error that caused the failure. Common errors include:
    ///   - Network connectivity issues
    ///   - Insufficient disk space
    ///   - File system errors
    ///   - Invalid model identifier
    ///   - Server errors (404, 500, etc.)
    case failed(Error)

    /// The download was cancelled by the user.
    ///
    /// This state is reached when `cancel()` is called on the `DownloadTask`.
    /// Partial downloads may remain on disk but are not usable.
    case cancelled

    // MARK: - Computed Properties

    /// Whether this state represents an active download.
    ///
    /// Returns `true` for states where the download is in progress and may
    /// still be making progress:
    /// - `.pending`
    /// - `.downloading`
    /// - `.paused`
    ///
    /// Returns `false` for terminal states (completed, failed, cancelled).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// if downloadState.isActive {
    ///     // Show progress bar
    ///     ProgressView(value: progress.fractionCompleted)
    /// }
    /// ```
    public var isActive: Bool {
        switch self {
        case .pending, .downloading, .paused:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    /// Whether this state is terminal (download finished).
    ///
    /// Returns `true` for states where the download has finished and will
    /// not make further progress:
    /// - `.completed(URL)`
    /// - `.failed(Error)`
    /// - `.cancelled`
    ///
    /// Returns `false` for active states (pending, downloading, paused).
    ///
    /// ## Usage
    ///
    /// ```swift
    /// if downloadState.isTerminal {
    ///     // Hide progress UI
    ///     // Show result or error message
    /// }
    /// ```
    public var isTerminal: Bool {
        !isActive
    }
}

// MARK: - DownloadState Equatable Conformance

extension DownloadState: Equatable {
    /// Compares two download states for equality.
    ///
    /// Two states are equal if:
    /// - They are the same case
    /// - For `.completed`, the URLs are equal
    /// - For `.failed`, the errors have the same localized description
    ///   (since `Error` itself is not `Equatable`)
    ///
    /// - Note: Error comparison is based on localized description, which may
    ///   not capture all error details. Use pattern matching for precise error handling.
    public static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending):
            return true
        case (.downloading, .downloading):
            return true
        case (.paused, .paused):
            return true
        case (.completed(let lhsURL), .completed(let rhsURL)):
            return lhsURL == rhsURL
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}

// MARK: - DownloadTask

/// A task representing an in-progress model download.
///
/// `DownloadTask` provides observable state for model downloads, allowing
/// UI components to track progress and control the download lifecycle.
///
/// ## Observable State
///
/// The task is marked with `@Observable`, making it work seamlessly with
/// SwiftUI and other observation frameworks:
///
/// ```swift
/// struct DownloadView: View {
///     @State var task: DownloadTask
///
///     var body: some View {
///         VStack {
///             ProgressView(value: task.progress.fractionCompleted)
///             Text("\(task.progress.percentComplete)%")
///
///             switch task.state {
///             case .downloading:
///                 Button("Cancel") { task.cancel() }
///             case .paused:
///                 Button("Resume") { task.resume() }
///             case .completed:
///                 Text("Download complete!")
///             default:
///                 EmptyView()
///             }
///         }
///     }
/// }
/// ```
///
/// ## Lifecycle
///
/// 1. Create task via `ModelManager.download(_:)` or provider method
/// 2. Task starts in `.pending` state
/// 3. Automatically transitions to `.downloading`
/// 4. Progress updates flow through `progress` property
/// 5. Ends in `.completed`, `.failed`, or `.cancelled` state
///
/// ## Concurrency
///
/// The task is `@unchecked Sendable` because it uses an `NSLock` for
/// thread-safe access to mutable state. This is necessary because
/// `@Observable` types with mutable state require synchronization.
///
/// ## Cancellation
///
/// ```swift
/// let task = provider.download(model)
///
/// // Cancel from any thread
/// task.cancel()
///
/// // Wait for cancellation to complete
/// do {
///     _ = try await task.result()
/// } catch {
///     // Handle cancellation error
/// }
/// ```
///
/// ## Pause/Resume
///
/// Not all providers support pause/resume. Check provider documentation:
///
/// ```swift
/// task.pause()
/// // ... later ...
/// task.resume()
/// ```
@Observable
public final class DownloadTask: @unchecked Sendable {

    // MARK: - Properties

    /// The model being downloaded.
    public let model: ModelIdentifier

    /// Current download progress.
    ///
    /// This property is updated frequently during active downloads.
    /// Observe it for UI updates.
    public private(set) var progress: DownloadProgress

    /// Current state of the download.
    ///
    /// Transitions through the download lifecycle: pending → downloading →
    /// completed/failed/cancelled.
    public private(set) var state: DownloadState

    // MARK: - Internal State

    /// The underlying async task performing the download.
    ///
    /// Used internally to cancel the download operation.
    internal var downloadTask: Task<URL, Error>?

    /// Stream continuation for progress updates.
    ///
    /// Used internally to send progress updates to observers.
    internal var continuation: AsyncStream<DownloadProgress>.Continuation?

    /// Lock for thread-safe access to mutable state.
    ///
    /// Required because `@Observable` classes with mutable state need
    /// synchronization for `@unchecked Sendable` conformance.
    private let lock = NSLock()

    // MARK: - Initialization

    /// Creates a download task for the specified model.
    ///
    /// - Parameter model: The model identifier to download.
    public init(model: ModelIdentifier) {
        self.model = model
        self.progress = DownloadProgress()
        self.state = .pending
    }

    // MARK: - Control Methods

    /// Cancels the download.
    ///
    /// This method can be called from any thread. The download will stop
    /// as soon as possible, transitioning to the `.cancelled` state.
    ///
    /// If the download has already completed or failed, calling this method
    /// has no effect.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let task = provider.download(model)
    ///
    /// // User taps cancel button
    /// task.cancel()
    ///
    /// // Wait for cancellation
    /// do {
    ///     _ = try await task.result()
    /// } catch is CancellationError {
    ///     print("Download cancelled")
    /// }
    /// ```
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }

        // Only cancel if in an active state
        guard state.isActive else { return }

        // Cancel the underlying task
        downloadTask?.cancel()

        // Update state
        state = .cancelled

        // Finish progress stream
        continuation?.finish()
    }

    /// Pauses the download.
    ///
    /// - Note: Not all providers support pausing. This method may have no
    ///   effect depending on the provider implementation.
    ///
    /// If pause is supported, the download transitions to `.paused` state
    /// and can be resumed with `resume()`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let task = provider.download(model)
    ///
    /// // Pause when app enters background
    /// task.pause()
    ///
    /// // Resume when app becomes active
    /// task.resume()
    /// ```
    public func pause() {
        lock.lock()
        defer { lock.unlock() }

        // Only pause if currently downloading
        guard case .downloading = state else { return }

        state = .paused
    }

    /// Resumes a paused download.
    ///
    /// If the download is in `.paused` state, this transitions back to
    /// `.downloading` and continues the transfer.
    ///
    /// If the download is not paused, this method has no effect.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if case .paused = task.state {
    ///     task.resume()
    /// }
    /// ```
    public func resume() {
        lock.lock()
        defer { lock.unlock() }

        // Only resume if currently paused
        guard case .paused = state else { return }

        state = .downloading
    }

    /// Waits for the download to complete and returns the result.
    ///
    /// This method suspends until the download finishes (successfully or with error).
    /// It returns the local file URL where the model was saved on success.
    ///
    /// ## Throws
    ///
    /// - The error from `.failed(Error)` state
    /// - `CancellationError` if the download was cancelled
    /// - Other errors if the download task throws
    ///
    /// ## Example
    ///
    /// ```swift
    /// let task = provider.download(model)
    ///
    /// do {
    ///     let url = try await task.result()
    ///     print("Model saved to: \(url)")
    /// } catch {
    ///     print("Download failed: \(error)")
    /// }
    /// ```
    ///
    /// ## SwiftUI Usage
    ///
    /// ```swift
    /// Button("Download") {
    ///     let task = provider.download(model)
    ///     Task {
    ///         do {
    ///             let url = try await task.result()
    ///             modelURL = url
    ///         } catch {
    ///             errorMessage = error.localizedDescription
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: The local file URL where the model was saved.
    /// - Throws: An error if the download failed or was cancelled.
    public func result() async throws -> URL {
        // Read current state atomically
        let (currentState, task) = _readState()

        func _readState() -> (DownloadState, Task<URL, Error>?) {
            lock.lock()
            defer { lock.unlock() }
            return (state, downloadTask)
        }

        // Check current state
        switch currentState {
        case .completed(let url):
            // Already finished successfully
            return url

        case .failed(let error):
            // Already failed
            throw error

        case .cancelled:
            // Already cancelled
            throw CancellationError()

        case .pending, .downloading, .paused:
            // Wait for the download task to complete
            guard let task = task else {
                throw DownloadError.taskNotStarted
            }

            return try await task.value
        }
    }

    // MARK: - Internal Update Methods

    /// Updates the progress (called internally by download implementation).
    ///
    /// - Parameter newProgress: The updated progress information.
    internal func updateProgress(_ newProgress: DownloadProgress) {
        lock.lock()
        defer { lock.unlock() }

        progress = newProgress
        continuation?.yield(newProgress)
    }

    /// Updates the state (called internally by download implementation).
    ///
    /// - Parameter newState: The new download state.
    internal func updateState(_ newState: DownloadState) {
        lock.lock()
        defer { lock.unlock() }

        state = newState

        // Finish stream if terminal state
        if newState.isTerminal {
            continuation?.finish()
        }
    }
}

// MARK: - DownloadError

/// Errors specific to download tasks.
internal enum DownloadError: Error, LocalizedError {
    /// The download task was not started before calling `result()`.
    case taskNotStarted

    var errorDescription: String? {
        switch self {
        case .taskNotStarted:
            return "Download task has not been started"
        }
    }
}
