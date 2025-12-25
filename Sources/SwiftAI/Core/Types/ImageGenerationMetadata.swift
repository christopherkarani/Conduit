// ImageGenerationMetadata.swift
// SwiftAI
//
// Metadata from image generation responses.

import Foundation

/// Metadata from image generation responses.
///
/// Contains additional information returned by cloud providers
/// that may be useful for logging, debugging, or user display.
///
/// ## DALL-E 3 Revised Prompts
///
/// DALL-E 3 automatically enhances and rewrites prompts for better results.
/// The `revisedPrompt` property contains the actual prompt used for generation.
///
/// ## Usage
///
/// ```swift
/// let image = try await provider.generateImage(prompt: "A cat")
/// if let revised = image.metadata?.revisedPrompt {
///     print("DALL-E used prompt: \(revised)")
/// }
/// ```
public struct ImageGenerationMetadata: Sendable, Hashable, Codable {

    /// The prompt as revised/enhanced by the model.
    ///
    /// DALL-E 3 automatically rewrites prompts for better results.
    /// This contains the actual prompt that was used for generation.
    ///
    /// Returns `nil` for providers that don't revise prompts (e.g., DALL-E 2, MLX).
    public let revisedPrompt: String?

    /// Timestamp when the image was created.
    ///
    /// Corresponds to the `created` field in OpenAI's API response.
    public let createdAt: Date?

    /// The model that generated the image.
    ///
    /// For DALL-E: "dall-e-2" or "dall-e-3"
    /// For local models: the model identifier
    public let model: String?

    /// Creates image generation metadata.
    ///
    /// - Parameters:
    ///   - revisedPrompt: The prompt as revised by the model.
    ///   - createdAt: When the image was created.
    ///   - model: The model that generated the image.
    public init(
        revisedPrompt: String? = nil,
        createdAt: Date? = nil,
        model: String? = nil
    ) {
        self.revisedPrompt = revisedPrompt
        self.createdAt = createdAt
        self.model = model
    }
}
