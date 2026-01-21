// HuggingFaceHubDownloader.swift
// Conduit
//
// Optional Hugging Face Hub downloader backed by huggingface/swift-huggingface.
//
// This is compiled only when the HuggingFaceHub trait is enabled (and the
// HuggingFace module is available).

#if canImport(HuggingFace)

import Foundation
import HuggingFace

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Downloads Hugging Face Hub repositories into Conduit's cache directory structure.
///
/// This intentionally disables the Hugging Face Python-compatible cache to avoid duplicating
/// large model files (once in HF's blob cache and again in Conduit's cache).
internal actor HuggingFaceHubDownloader {
    internal static let shared = HuggingFaceHubDownloader()

    private static let progressUpdateIntervalNanoseconds: UInt64 = 250_000_000

    private var currentProgress: Progress?
    private var currentFile: String?
    private var filesCompleted: Int = 0
    private var totalFiles: Int = 0

    private init() {}

    internal func downloadSnapshot(
        repoId: String,
        kind: Repo.Kind = .model,
        to destination: URL,
        revision: String = "main",
        matching globs: [String] = [],
        token: String? = nil,
        progressHandler: (@Sendable (DownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        guard let repo = Repo.ID(rawValue: repoId) else {
            throw AIError.invalidInput("Invalid Hugging Face repo ID: '\(repoId)'. Expected 'namespace/name'.")
        }

        let client = Self.makeClient(token: token)

        let entries = try await client.listFiles(in: repo, kind: kind, revision: revision, recursive: true)
        let fileEntries = entries.filter { $0.type == .file }
            .filter { entry in
                guard !globs.isEmpty else { return true }
                return globs.contains { glob in
                    fnmatch(glob, entry.path, 0) == 0
                }
            }

        totalFiles = fileEntries.count
        filesCompleted = 0
        currentFile = nil

        let totalBytes = Self.totalBytesIfKnown(for: fileEntries)
        let overallProgress = Progress(totalUnitCount: max(1, totalBytes ?? Int64(totalFiles)))
        currentProgress = overallProgress

        let progressTask = Task { [weak self] in
            guard let self, let progressHandler else { return }
            while !Task.isCancelled {
                let snapshot = await self.makeProgressSnapshot(totalBytes: totalBytes)
                progressHandler(snapshot)
                try? await Task.sleep(nanoseconds: Self.progressUpdateIntervalNanoseconds)
            }
        }
        defer {
            progressTask.cancel()
            currentProgress = nil
            currentFile = nil
        }

        // Ensure destination exists.
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let destinationRoot = destination.standardizedFileURL
        let destinationRootPath = destinationRoot.path.hasSuffix("/") ? destinationRoot.path : destinationRoot.path + "/"

        for entry in fileEntries {
            try Task.checkCancellation()

            let fileDestination = destination.appendingPathComponent(entry.path)
            let standardizedDestination = fileDestination.standardizedFileURL

            // Prevent path traversal (e.g. repo file named "../foo").
            guard standardizedDestination.path == destinationRoot.path
                || standardizedDestination.path.hasPrefix(destinationRootPath)
            else {
                throw AIError.invalidInput("Refusing to write outside destination directory: \(entry.path)")
            }

            currentFile = entry.path

            if await Self.canSkipDownload(entry: entry, destination: standardizedDestination) {
                filesCompleted += 1
                if let totalBytes {
                    overallProgress.completedUnitCount += Int64(entry.size ?? 0)
                } else {
                    overallProgress.completedUnitCount += 1
                }
                continue
            } else {
                // Remove partial/corrupt file if present before re-downloading.
                try? FileManager.default.removeItem(at: standardizedDestination)
            }

            // Track progress for this file and weight it appropriately.
            let pendingUnitCount: Int64 = {
                if let totalBytes {
                    return Int64(entry.size ?? 1)
                }
                return 1
            }()

            let fileProgress = Progress(
                totalUnitCount: pendingUnitCount,
                parent: overallProgress,
                pendingUnitCount: pendingUnitCount
            )

            _ = try await client.downloadFile(
                entry,
                from: repo,
                to: standardizedDestination,
                kind: kind,
                revision: revision,
                progress: fileProgress,
                transport: .automatic
            )

            filesCompleted += 1
        }

        // Final progress update.
        progressHandler?(await makeProgressSnapshot(totalBytes: totalBytes))

        return destination
    }

    // MARK: - Progress Snapshot

    private func makeProgressSnapshot(totalBytes: Int64?) -> DownloadProgress {
        let bytesDownloaded: Int64
        if let totalBytes, let progress = currentProgress {
            bytesDownloaded = min(progress.completedUnitCount, totalBytes)
        } else {
            bytesDownloaded = 0
        }

        return DownloadProgress(
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            currentFile: currentFile,
            filesCompleted: filesCompleted,
            totalFiles: totalFiles
        )
    }

    // MARK: - Client

    private static func makeClient(token: String?) -> HubClient {
        let host: URL = {
            if let endpoint = ProcessInfo.processInfo.environment["HF_ENDPOINT"],
               let url = URL(string: endpoint) {
                return url
            }
            return HubClient.defaultHost
        }()

        let tokenProvider: TokenProvider = token.map { .fixed(token: $0) } ?? .environment
        return HubClient(host: host, tokenProvider: tokenProvider, cache: nil)
    }

    // MARK: - Helpers

    private static func totalBytesIfKnown(for entries: [Git.TreeEntry]) -> Int64? {
        var total: Int64 = 0
        for entry in entries {
            guard let size = entry.size else { return nil }
            total += Int64(size)
        }
        return total
    }

    private static func canSkipDownload(entry: Git.TreeEntry, destination: URL) async -> Bool {
        guard let expectedSize = entry.size else { return false }
        guard FileManager.default.fileExists(atPath: destination.path) else { return false }
        let resourceValues = try? destination.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        guard resourceValues?.isDirectory != true else { return false }
        return resourceValues?.fileSize == expectedSize
    }
}

#endif

