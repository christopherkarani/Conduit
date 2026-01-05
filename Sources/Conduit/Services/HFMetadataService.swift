//
//  HFMetadataService.swift
//  Conduit
//
//  HuggingFace metadata service for fetching repository information,
//  file trees, and model details from the HuggingFace API.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - HFMetadataService

/// Actor-based service for fetching metadata from HuggingFace API.
///
/// Provides methods to estimate download sizes, fetch file trees,
/// and retrieve detailed model information including VLM detection.
///
/// ## Usage
/// ```swift
/// let service = HFMetadataService.shared
/// let size = await service.estimateTotalSize(
///     repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
///     patterns: HFMetadataService.mlxFilePatterns
/// )
/// ```
public actor HFMetadataService {

    // MARK: - Singleton

    /// Shared singleton instance.
    public static let shared = HFMetadataService()

    // MARK: - Default Patterns

    /// Default file patterns for MLX models.
    ///
    /// Includes safetensors weights, JSON configs, tokenizer files, and model files.
    public static let mlxFilePatterns: [String] = [
        "*.safetensors",
        "*.json",
        "*.txt",
        "*.model",
        "*.tiktoken"
    ]

    // MARK: - Types

    /// Represents a file in a HuggingFace repository.
    public struct RepoFile: Sendable, Decodable {
        /// The file path relative to repository root.
        public let path: String

        /// The type of entry ("file" or "directory").
        public let type: String?

        /// The file size in bytes (may be nil for directories or LFS files).
        public let size: Int64?

        /// LFS (Large File Storage) metadata if applicable.
        public let lfs: LFSInfo?

        /// LFS metadata structure.
        public struct LFSInfo: Sendable, Decodable {
            /// The actual size of the LFS file in bytes.
            public let size: Int64?
        }

        /// Returns the effective size, preferring `size` then falling back to `lfs.size`.
        public var effectiveSize: Int64 {
            size ?? lfs?.size ?? 0
        }
    }

    /// Comprehensive metadata for a HuggingFace repository.
    public struct RepoMetadata: Sendable {
        /// The repository identifier (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit").
        public let id: String

        /// List of files in the repository.
        public let files: [RepoFile]

        /// Model tags from HuggingFace.
        public let tags: [String]

        /// The pipeline tag indicating model type (e.g., "text-generation").
        public let pipelineTag: String?

        /// The model architecture type (e.g., "llama", "qwen2").
        public let modelType: String?
    }

    /// Detailed model information from HuggingFace API.
    public struct ModelDetails: Sendable {
        /// The repository identifier.
        public let id: String

        /// The model author/organization.
        public let author: String?

        /// Total number of downloads.
        public let downloads: Int?

        /// Number of likes/stars.
        public let likes: Int?

        /// Last modification timestamp.
        public let lastModified: Date?

        /// Software license identifier.
        public let license: String?

        /// Pipeline tag (e.g., "text-generation", "image-to-text").
        public let pipelineTag: String?

        /// Model architecture type.
        public let modelType: String?

        /// All tags associated with the model.
        public let tags: [String]

        /// Whether this is a Vision Language Model.
        public let isVLM: Bool
    }

    // MARK: - Private Response Types

    /// Raw API response for basic model metadata.
    private struct ModelMetaResponse: Decodable {
        let id: String
        let tags: [String]?
        let pipeline_tag: String?
        let config: ConfigInfo?
        let cardData: CardData?

        struct ConfigInfo: Decodable {
            let model_type: String?
        }

        struct CardData: Decodable {
            let model_type: String?
        }
    }

    /// Raw API response for detailed model information.
    private struct ModelDetailsResponse: Decodable {
        let id: String
        let author: String?
        let downloads: Int?
        let likes: Int?
        let lastModified: String?
        let tags: [String]?
        let pipeline_tag: String?
        let config: ConfigInfo?
        let cardData: CardData?

        struct ConfigInfo: Decodable {
            let model_type: String?
        }

        struct CardData: Decodable {
            let license: String?
            let model_type: String?
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Estimates the total download size for files matching the provided patterns.
    ///
    /// Uses the HuggingFace tree API to fetch a recursive file listing
    /// and sums the sizes of files matching the glob patterns.
    ///
    /// - Parameters:
    ///   - repoId: The repository identifier (e.g., "mlx-community/Llama-3.2-1B-Instruct-4bit").
    ///   - patterns: Glob patterns to match files (e.g., `["*.safetensors", "*.json"]`).
    /// - Returns: Total size in bytes, or `nil` if unable to fetch or no matching files found.
    ///
    /// ## Example
    /// ```swift
    /// let size = await service.estimateTotalSize(
    ///     repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
    ///     patterns: HFMetadataService.mlxFilePatterns
    /// )
    /// if let sizeInGB = size.map({ Double($0) / 1_000_000_000 }) {
    ///     print("Estimated size: \(String(format: "%.2f", sizeInGB)) GB")
    /// }
    /// ```
    public func estimateTotalSize(repoId: String, patterns: [String]) async -> Int64? {
        guard let files = await fetchFileTree(repoId: repoId) else {
            return nil
        }

        let matchers = patterns.compactMap { GlobMatcher($0) }
        guard !matchers.isEmpty else { return nil }

        let total = files.reduce(Int64(0)) { acc, file in
            // Only sum files, not directories
            if file.type == "directory" { return acc }

            let filename = (file.path as NSString).lastPathComponent
            let matched = matchers.contains { $0.matches(filename) }
            guard matched else { return acc }

            return acc + file.effectiveSize
        }

        return total > 0 ? total : nil
    }

    /// Fetches the complete file tree for a repository.
    ///
    /// Uses the HuggingFace `/api/models/{repo}/tree/main?recursive=1` endpoint
    /// to retrieve all files and directories in the repository.
    ///
    /// - Parameter repoId: The repository identifier.
    /// - Returns: Array of files, or `nil` on failure.
    private func fetchFileTree(repoId: String) async -> [RepoFile]? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "huggingface.co"
        comps.path = "/api/models/\(repoId)/tree/main"
        comps.queryItems = [URLQueryItem(name: "recursive", value: "1")]

        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }

            let files = try JSONDecoder().decode([RepoFile].self, from: data)
            return files.isEmpty ? nil : files
        } catch {
            return nil
        }
    }

    /// Fetches repository metadata including file tree and model tags.
    ///
    /// Combines the file tree from the tree API with basic metadata
    /// from the models API to provide comprehensive repository information.
    ///
    /// - Parameter repoId: The repository identifier.
    /// - Returns: Repository metadata, or `nil` on failure.
    ///
    /// ## Example
    /// ```swift
    /// let metadata = await service.fetchRepoMetadata(repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit")
    /// if let meta = metadata {
    ///     print("Files: \(meta.files.count)")
    ///     print("Tags: \(meta.tags)")
    ///     print("Model type: \(meta.modelType ?? "unknown")")
    /// }
    /// ```
    public func fetchRepoMetadata(repoId: String) async -> RepoMetadata? {
        // Fetch both file tree and basic metadata concurrently
        async let filesTask = fetchFileTree(repoId: repoId)
        async let metaTask = fetchBasicMetadata(repoId: repoId)

        guard let files = await filesTask,
              let meta = await metaTask else {
            return nil
        }

        let modelType = meta.config?.model_type ?? meta.cardData?.model_type

        return RepoMetadata(
            id: meta.id,
            files: files,
            tags: meta.tags ?? [],
            pipelineTag: meta.pipeline_tag,
            modelType: modelType
        )
    }

    /// Fetches detailed model information including VLM detection.
    ///
    /// Uses the HuggingFace `/api/models/{repo}?full=1` endpoint to retrieve
    /// comprehensive model metadata including downloads, likes, license, and more.
    ///
    /// - Parameter repoId: The repository identifier.
    /// - Returns: Detailed model information, or `nil` on failure.
    ///
    /// ## Example
    /// ```swift
    /// let details = await service.fetchModelDetails(repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit")
    /// if let info = details {
    ///     print("Downloads: \(info.downloads ?? 0)")
    ///     print("License: \(info.license ?? "unknown")")
    ///     print("Is VLM: \(info.isVLM)")
    /// }
    /// ```
    public func fetchModelDetails(repoId: String) async -> ModelDetails? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "huggingface.co"
        comps.path = "/api/models/\(repoId)"
        comps.queryItems = [URLQueryItem(name: "full", value: "1")]

        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }

            let decoder = JSONDecoder()
            let raw = try decoder.decode(ModelDetailsResponse.self, from: data)

            // Parse lastModified date
            var lastModified: Date?
            if let dateStr = raw.lastModified {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                lastModified = formatter.date(from: dateStr)

                // Try without fractional seconds if failed
                if lastModified == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    lastModified = formatter.date(from: dateStr)
                }
            }

            // Extract license from tags or cardData
            let tags = raw.tags ?? []
            let license = raw.cardData?.license ?? extractLicenseFromTags(tags)

            // Determine if VLM based on tags and pipeline
            let isVLM = detectVLMFromMetadata(tags: tags, pipelineTag: raw.pipeline_tag)

            // Extract model type from config or cardData
            let modelType = raw.config?.model_type ?? raw.cardData?.model_type

            return ModelDetails(
                id: raw.id,
                author: raw.author,
                downloads: raw.downloads,
                likes: raw.likes,
                lastModified: lastModified,
                license: license,
                pipelineTag: raw.pipeline_tag,
                modelType: modelType,
                tags: tags,
                isVLM: isVLM
            )
        } catch {
            return nil
        }
    }

    // MARK: - Private Helper Methods

    /// Fetches basic metadata without the full details.
    private func fetchBasicMetadata(repoId: String) async -> ModelMetaResponse? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "huggingface.co"
        comps.path = "/api/models/\(repoId)"

        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }

            return try JSONDecoder().decode(ModelMetaResponse.self, from: data)
        } catch {
            return nil
        }
    }

    /// Extracts license identifier from HuggingFace tags.
    ///
    /// Tags often include a "license:" prefix. This method also checks
    /// for common license identifiers directly in the tags.
    private func extractLicenseFromTags(_ tags: [String]) -> String? {
        // Check for license: prefix
        for tag in tags {
            let lower = tag.lowercased()
            if lower.hasPrefix("license:") {
                return String(tag.dropFirst("license:".count))
            }
        }

        // Check for common license identifiers directly in tags
        let knownLicenses = [
            "mit", "apache-2.0", "gpl-3.0", "cc-by-4.0", "cc-by-nc-4.0",
            "llama2", "llama3", "gemma"
        ]
        for tag in tags {
            if knownLicenses.contains(tag.lowercased()) {
                return tag
            }
        }

        return nil
    }

    /// Detects if a model is a Vision Language Model based on metadata.
    ///
    /// Uses a multi-layer detection strategy:
    /// 1. Check pipeline_tag for VLM-specific pipelines
    /// 2. Check tags for VLM indicators
    ///
    /// - Parameters:
    ///   - tags: Model tags from HuggingFace.
    ///   - pipelineTag: The pipeline_tag field from model metadata.
    /// - Returns: `true` if the model is likely a VLM.
    private func detectVLMFromMetadata(tags: [String], pipelineTag: String?) -> Bool {
        // Check pipeline tag
        if let pipeline = pipelineTag?.lowercased() {
            let vlmPipelines = [
                "image-to-text",
                "visual-question-answering",
                "image-text-to-text",
                "document-question-answering"
            ]
            if vlmPipelines.contains(pipeline) {
                return true
            }
        }

        // Check tags for VLM indicators
        let lowerTags = tags.map { $0.lowercased() }
        let vlmTags = [
            "vision", "multimodal", "vlm", "image-text",
            "llava", "vqa", "image-to-text"
        ]
        for vlmTag in vlmTags {
            if lowerTags.contains(where: { $0.contains(vlmTag) }) {
                return true
            }
        }

        return false
    }
}

// Note: GlobMatcher is defined in Utilities/GlobMatcher.swift and available module-wide
