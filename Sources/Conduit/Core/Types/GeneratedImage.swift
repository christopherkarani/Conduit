// GeneratedImage.swift
// Conduit

import Foundation

// MARK: - Linux Compatibility
// NOTE: SwiftUI Image requires UIKit/AppKit for backing image types.
// On Linux, use `data` directly or `save(to:)` for file output.
// The `image` property returns nil on Linux.

#if canImport(SwiftUI)
import SwiftUI
#endif

#if os(iOS) || os(visionOS)
import UIKit
import Photos
#elseif os(macOS)
import AppKit
#endif

/// A generated image from text-to-image models.
///
/// Provides convenient access to the image data with cross-platform
/// SwiftUI support and save functionality.
///
/// ## Usage
/// ```swift
/// let result = try await provider.generateImage(
///     model: "stabilityai/stable-diffusion-3",
///     prompt: "A sunset over mountains"
/// )
///
/// // Display in SwiftUI
/// result.image
///
/// // Save to disk
/// try result.save(to: URL.documentsDirectory.appending(path: "image.png"))
///
/// // Save to Photos (iOS only)
/// try await result.saveToPhotos()
/// ```
public struct GeneratedImage: Sendable {

    /// The raw image data in the specified format.
    public let data: Data

    /// The image format.
    public let format: ImageFormat

    /// Additional metadata from the generation process.
    ///
    /// Contains provider-specific information like DALL-E 3's revised prompt.
    /// Returns `nil` for providers that don't supply metadata.
    public let metadata: ImageGenerationMetadata?

    /// Creates a generated image from raw data.
    ///
    /// - Parameters:
    ///   - data: Raw image bytes.
    ///   - format: The image format (default: PNG).
    ///   - metadata: Optional metadata from the generation process.
    public init(data: Data, format: ImageFormat = .png, metadata: ImageGenerationMetadata? = nil) {
        self.data = data
        self.format = format
        self.metadata = metadata
    }

    // MARK: - SwiftUI Image

    /// The image as a SwiftUI `Image` view.
    ///
    /// Returns `nil` if the data cannot be decoded as an image.
    ///
    /// - Note: This property is only available on platforms with UIKit or AppKit
    ///   (iOS, visionOS, macOS). On Linux and other platforms, use `data` directly
    ///   or `save(to:)` for file output.
    #if canImport(SwiftUI) && (os(iOS) || os(visionOS) || os(macOS))
    @MainActor
    public var image: Image? {
        #if os(iOS) || os(visionOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }
    #endif

    // MARK: - Platform Image

    #if os(iOS) || os(visionOS)
    /// The underlying UIImage.
    public var uiImage: UIImage? {
        UIImage(data: data)
    }
    #elseif os(macOS)
    /// The underlying NSImage.
    public var nsImage: NSImage? {
        NSImage(data: data)
    }
    #endif

    // MARK: - Save to File

    /// Saves the image to a file URL.
    ///
    /// - Parameter url: The destination file URL.
    /// - Throws: `GeneratedImageError.saveFailed` if the file cannot be written.
    public func save(to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw GeneratedImageError.saveFailed(underlying: SendableError(error))
        }
    }

    /// Saves the image to a directory with an auto-generated filename.
    ///
    /// - Parameters:
    ///   - directory: The destination directory URL.
    ///   - filename: Optional filename (without extension). Defaults to a UUID.
    /// - Returns: The URL where the image was saved.
    /// - Throws: `GeneratedImageError.saveFailed` if the file cannot be written.
    @discardableResult
    public func save(toDirectory directory: URL, filename: String? = nil) throws -> URL {
        let name = filename ?? UUID().uuidString
        let url = directory.appendingPathComponent("\(name).\(format.fileExtension)")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw GeneratedImageError.saveFailed(underlying: SendableError(error))
        }
        return url
    }

    // MARK: - Save to Photos (iOS/visionOS only)

    #if os(iOS) || os(visionOS)
    /// Saves the image to the user's Photos library.
    ///
    /// - Note: Requires `NSPhotoLibraryAddUsageDescription` in Info.plist.
    /// - Throws: `GeneratedImageError.photosAccessDenied` if permission is denied,
    ///           or `GeneratedImageError.invalidImageData` if the data is not a valid image.
    public func saveToPhotos() async throws {
        guard let uiImage = UIImage(data: data) else {
            throw GeneratedImageError.invalidImageData
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            throw GeneratedImageError.photosAccessDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAsset(from: uiImage)
        }
    }
    #endif
}

// MARK: - Image Format

/// Supported image formats for generated images.
public enum ImageFormat: String, Sendable {
    case png
    case jpeg
    case webp

    /// The file extension for this format.
    public var fileExtension: String {
        rawValue
    }

    /// The MIME type for this format.
    public var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .webp: return "image/webp"
        }
    }
}

// MARK: - Errors

/// Errors that can occur when working with generated images.
public enum GeneratedImageError: Error, LocalizedError, Sendable {
    /// The image data could not be decoded.
    case invalidImageData

    /// Access to the Photos library was denied.
    case photosAccessDenied

    /// The save operation failed.
    case saveFailed(underlying: SendableError)

    public var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The image data could not be decoded."
        case .photosAccessDenied:
            return "Access to Photos library was denied. Add NSPhotoLibraryAddUsageDescription to Info.plist."
        case .saveFailed(let error):
            return "Failed to save image: \(error.localizedDescription)"
        }
    }
}
