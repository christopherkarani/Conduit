// DiffusionModelRegistry.swift
// SwiftAI

import Foundation

/// Registry for managing diffusion model information and downloads.
///
/// Provides a catalog of available models and tracks which models
/// have been downloaded locally.
///
/// ## Usage
///
/// ```swift
/// let registry = DiffusionModelRegistry.shared
///
/// // List available models
/// for model in DiffusionModelRegistry.availableModels {
///     print("\(model.name): \(model.formattedSize)")
/// }
///
/// // Check if downloaded
/// if await registry.isDownloaded("mlx-community/sdxl-turbo") {
///     let path = await registry.localPath(for: "mlx-community/sdxl-turbo")
/// }
/// ```
public actor DiffusionModelRegistry {

    // MARK: - Singleton

    /// Shared registry instance.
    public static let shared = DiffusionModelRegistry()

    // MARK: - Available Models Catalog

    /// Catalog of available diffusion models.
    public static let availableModels: [DiffusionModelInfo] = [
        DiffusionModelInfo(
            id: "mlx-community/sdxl-turbo",
            name: "SDXL Turbo",
            variant: .sdxlTurbo,
            sizeGiB: 6.5,
            description: "Fast, high-quality 1024×1024 images in just 4 steps",
            huggingFaceURL: URL(string: "https://huggingface.co/mlx-community/sdxl-turbo")!
        ),
        DiffusionModelInfo(
            id: "mlx-community/stable-diffusion-v1-5-4bit",
            name: "Stable Diffusion 1.5 (4-bit)",
            variant: .sd15,
            sizeGiB: 2.0,
            description: "Classic SD 1.5, quantized for efficiency",
            huggingFaceURL: URL(string: "https://huggingface.co/mlx-community/stable-diffusion-v1-5-4bit")!
        ),
        DiffusionModelInfo(
            id: "mlx-community/flux-schnell-4bit",
            name: "Flux Schnell (4-bit)",
            variant: .flux,
            sizeGiB: 4.0,
            description: "Fast Flux variant, 4 steps for quick generation",
            huggingFaceURL: URL(string: "https://huggingface.co/mlx-community/flux-schnell-4bit")!
        )
    ]

    // MARK: - Properties

    /// Downloaded models tracked by this registry.
    private var downloadedModels: [String: DownloadedDiffusionModel] = [:]

    /// Custom user-registered models.
    private var customModels: [String: DiffusionModelInfo] = [:]

    /// UserDefaults key for downloaded models persistence.
    private nonisolated let storageKey = "swiftai.diffusion.downloaded"

    /// UserDefaults key for custom models persistence.
    private nonisolated let customModelsKey = "swiftai.diffusion.custom"

    // MARK: - Initialization

    private init() {
        // Load persisted data using nonisolated helper
        self.downloadedModels = Self.loadFromStorage(key: storageKey)
        self.customModels = Self.loadCustomModelsFromStorage(key: customModelsKey)
    }

    // MARK: - Thread-Safe UserDefaults Access

    /// Loads downloaded models from UserDefaults (nonisolated for thread-safety).
    private nonisolated static func loadFromStorage(key: String) -> [String: DownloadedDiffusionModel] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let models = try? JSONDecoder().decode([String: DownloadedDiffusionModel].self, from: data) else {
            return [:]
        }
        return models
    }

    /// Saves data to UserDefaults (nonisolated for thread-safety).
    private nonisolated func persistToStorage(_ models: [String: DownloadedDiffusionModel]) {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Loads custom models from UserDefaults (nonisolated for thread-safety).
    private nonisolated static func loadCustomModelsFromStorage(key: String) -> [String: DiffusionModelInfo] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let models = try? JSONDecoder().decode([String: DiffusionModelInfo].self, from: data) else {
            return [:]
        }
        return models
    }

    /// Saves custom models to UserDefaults (nonisolated for thread-safety).
    private nonisolated func persistCustomModels(_ models: [String: DiffusionModelInfo]) {
        guard let data = try? JSONEncoder().encode(models) else { return }
        UserDefaults.standard.set(data, forKey: customModelsKey)
    }

    // MARK: - Query Methods

    /// Checks if a model is downloaded.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: `true` if the model is downloaded locally.
    public func isDownloaded(_ modelId: String) -> Bool {
        downloadedModels[modelId] != nil
    }

    /// Gets the local path for a downloaded model.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: Local file URL, or `nil` if not downloaded.
    public func localPath(for modelId: String) -> URL? {
        downloadedModels[modelId]?.localPath
    }

    /// Gets information about a downloaded model.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: Downloaded model info, or `nil` if not downloaded.
    public func downloadedModel(for modelId: String) -> DownloadedDiffusionModel? {
        downloadedModels[modelId]
    }

    /// All downloaded models sorted by download date (newest first).
    public var allDownloadedModels: [DownloadedDiffusionModel] {
        Array(downloadedModels.values).sorted { $0.downloadedAt > $1.downloadedAt }
    }

    /// Number of downloaded models.
    public var downloadedCount: Int {
        downloadedModels.count
    }

    // MARK: - Management Methods

    /// Records a model as downloaded.
    ///
    /// - Parameter model: The downloaded model information.
    public func addDownloaded(_ model: DownloadedDiffusionModel) {
        downloadedModels[model.id] = model
        saveToStorage()
    }

    /// Removes a model from the downloaded list.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Note: This does not delete the files from disk.
    public func removeDownloaded(_ modelId: String) {
        downloadedModels.removeValue(forKey: modelId)
        saveToStorage()
    }

    /// Total size of all downloaded models in bytes.
    public var totalDownloadedSize: Int64 {
        downloadedModels.values.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Formatted total size string.
    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalDownloadedSize, countStyle: .file)
    }

    // MARK: - Persistence

    private func saveToStorage() {
        // Capture current state and persist using nonisolated method
        let currentModels = downloadedModels
        persistToStorage(currentModels)
    }

    /// Clears all download records.
    ///
    /// - Note: This does not delete the files from disk.
    public func clearAllRecords() {
        downloadedModels.removeAll()
        saveToStorage()
    }

    // MARK: - Custom Model Catalog

    /// All available models (built-in + custom).
    ///
    /// Returns a combined list of the built-in model catalog and any
    /// user-registered custom models.
    public var allAvailableModels: [DiffusionModelInfo] {
        var models = Self.availableModels
        models.append(contentsOf: customModels.values)
        return models.sorted { $0.name < $1.name }
    }

    /// Registers a custom diffusion model.
    ///
    /// This allows users to add their own models to the catalog, enabling
    /// downloads and tracking for models not in the built-in list.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let customModel = DiffusionModelInfo(
    ///     id: "my-org/custom-sd-model",
    ///     name: "My Custom Model",
    ///     variant: .sdxlTurbo,
    ///     sizeGiB: 5.2,
    ///     description: "Custom fine-tuned model",
    ///     huggingFaceURL: URL(string: "https://huggingface.co/my-org/custom-sd-model")!,
    ///     checksum: "abc123..."
    /// )
    ///
    /// await DiffusionModelRegistry.shared.registerCustomModel(customModel)
    /// ```
    ///
    /// - Parameter model: The custom model information to register.
    public func registerCustomModel(_ model: DiffusionModelInfo) {
        customModels[model.id] = model
        saveCustomModels()
    }

    /// Unregisters a custom model from the catalog.
    ///
    /// - Parameter modelId: The HuggingFace repository ID of the custom model.
    /// - Note: This does not remove the model from downloaded records or delete files.
    public func unregisterCustomModel(_ modelId: String) {
        customModels.removeValue(forKey: modelId)
        saveCustomModels()
    }

    /// Checks if a model ID is a custom (user-registered) model.
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: `true` if this is a custom model.
    public func isCustomModel(_ modelId: String) -> Bool {
        customModels[modelId] != nil
    }

    /// All custom models registered by the user.
    public var allCustomModels: [DiffusionModelInfo] {
        Array(customModels.values).sorted { $0.name < $1.name }
    }

    /// Number of registered custom models.
    public var customModelCount: Int {
        customModels.count
    }

    /// Finds a model in the catalog (built-in or custom).
    ///
    /// - Parameter modelId: The HuggingFace repository ID.
    /// - Returns: Model info if found in either catalog.
    public func findModel(_ modelId: String) -> DiffusionModelInfo? {
        // Check custom models first (allows overriding built-in)
        if let custom = customModels[modelId] {
            return custom
        }

        // Check built-in models
        return Self.availableModels.first { $0.id == modelId }
    }

    /// Clears all custom model registrations.
    ///
    /// - Note: This does not affect downloaded models or files.
    public func clearAllCustomModels() {
        customModels.removeAll()
        saveCustomModels()
    }

    private func saveCustomModels() {
        let current = customModels
        persistCustomModels(current)
    }
}

// MARK: - Model Info Types

/// Information about an available diffusion model.
public struct DiffusionModelInfo: Sendable, Identifiable, Codable {

    /// HuggingFace repository ID (e.g., "mlx-community/sdxl-turbo").
    public let id: String

    /// Human-readable model name.
    public let name: String

    /// Model variant type.
    public let variant: DiffusionVariant

    /// Approximate download size in GiB (gibibytes, 1024^3 bytes).
    public let sizeGiB: Double

    /// Brief description of the model.
    public let description: String

    /// URL to the HuggingFace model page.
    public let huggingFaceURL: URL

    /// Optional SHA256 checksum for verification.
    public let checksum: String?

    /// Formatted size string.
    public var formattedSize: String {
        String(format: "%.1f GiB", sizeGiB)
    }

    /// Approximate size in bytes.
    public var sizeBytes: Int64 {
        Int64(sizeGiB * 1_073_741_824) // 1 GiB = 1024^3 bytes
    }

    /// Creates diffusion model info.
    ///
    /// - Parameters:
    ///   - id: HuggingFace repository ID.
    ///   - name: Human-readable name.
    ///   - variant: Model variant type.
    ///   - sizeGiB: Approximate size in gibibytes.
    ///   - description: Brief description.
    ///   - huggingFaceURL: URL to HuggingFace page.
    ///   - checksum: Optional SHA256 checksum for verification.
    public init(
        id: String,
        name: String,
        variant: DiffusionVariant,
        sizeGiB: Double,
        description: String,
        huggingFaceURL: URL,
        checksum: String? = nil
    ) {
        self.id = id
        self.name = name
        self.variant = variant
        self.sizeGiB = sizeGiB
        self.description = description
        self.huggingFaceURL = huggingFaceURL
        self.checksum = checksum
    }
}

/// Information about a downloaded diffusion model.
public struct DownloadedDiffusionModel: Sendable, Codable, Identifiable {

    /// HuggingFace repository ID.
    public let id: String

    /// Human-readable model name.
    public let name: String

    /// Model variant type.
    public let variant: DiffusionVariant

    /// Local path to model files.
    public let localPath: URL

    /// When the model was downloaded.
    public let downloadedAt: Date

    /// Size in bytes.
    public let sizeBytes: Int64

    /// Formatted size string.
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    /// Time since download.
    public var downloadedAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: downloadedAt, relativeTo: Date())
    }

    public init(
        id: String,
        name: String,
        variant: DiffusionVariant,
        localPath: URL,
        downloadedAt: Date = Date(),
        sizeBytes: Int64
    ) {
        self.id = id
        self.name = name
        self.variant = variant
        self.localPath = localPath
        self.downloadedAt = downloadedAt
        self.sizeBytes = sizeBytes
    }
}
