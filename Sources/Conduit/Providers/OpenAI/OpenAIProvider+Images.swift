// OpenAIProvider+Images.swift
// Conduit
//
// Image generation functionality for OpenAIProvider using DALL-E.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - ImageGenerator Protocol

extension OpenAIProvider {

    /// Generates an image from a text prompt using DALL-E.
    ///
    /// Uses DALL-E 3 by default unless DALL-E 2-only sizes are specified.
    /// Always uses base64 response format for reliable data (URLs expire in 60 min).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let provider = OpenAIProvider(apiKey: "sk-...")
    /// let image = try await provider.generateImage(
    ///     prompt: "A cat wearing a top hat",
    ///     config: .dalleHD
    /// )
    /// try image.save(to: documentsURL.appending(path: "cat.png"))
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: Text description of desired image (max 4000 chars for DALL-E 3).
    ///   - negativePrompt: Not supported by DALL-E (ignored).
    ///   - config: Image generation configuration.
    ///   - onProgress: Not supported by DALL-E (ignored).
    /// - Returns: Generated image with metadata including revised prompt.
    /// - Throws: `AIError.invalidInput` if prompt is empty.
    /// - Throws: `AIError.providerUnavailable` if endpoint is not OpenAI.
    /// - Throws: `AIError.contentFiltered` if prompt violates content policy.
    public func generateImage(
        prompt: String,
        negativePrompt: String? = nil,
        config: ImageGenerationConfig = .default,
        onProgress: (@Sendable (ImageGenerationProgress) -> Void)? = nil
    ) async throws -> GeneratedImage {
        // 1. Check cancellation
        try Task.checkCancellation()

        // 2. Validate prompt
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw AIError.invalidInput("Prompt cannot be empty")
        }

        // 3. Validate endpoint supports image generation
        guard configuration.endpoint == .openAI else {
            throw AIError.providerUnavailable(reason: .unknown(
                "Image generation is only supported with OpenAI endpoint"
            ))
        }

        // 4. Determine model based on size compatibility
        let model: String
        if let size = config.dalleSize, !size.supportedByDallE3 {
            model = "dall-e-2"
        } else {
            model = "dall-e-3"
        }

        // 5. Validate prompt length based on selected model
        // DALL-E 3: 4000 character limit
        // DALL-E 2: 1000 character limit
        // Note: Using character count as a proxy since actual token limits are:
        // DALL-E 3: ~1000 tokens, DALL-E 2: ~400 tokens
        // Character limits are more conservative and easier to validate
        let maxPromptLength = model == "dall-e-3" ? 4000 : 1000
        if trimmedPrompt.count > maxPromptLength {
            throw AIError.invalidInput(
                "Prompt exceeds maximum length of \(maxPromptLength) characters for \(model). " +
                "Current length: \(trimmedPrompt.count) characters."
            )
        }

        // 6. Determine size
        let size: String
        if let dalleSize = config.dalleSize {
            size = dalleSize.rawValue
        } else if let width = config.width, let height = config.height {
            size = mapToDALLESize(width: width, height: height, model: model)
        } else {
            size = "1024x1024"
        }

        // 7. Build request
        let url = configuration.endpoint.imagesGenerationsURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        for (name, value) in configuration.buildHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
        }

        // 8. Build request body
        var body: [String: Any] = [
            "model": model,
            "prompt": trimmedPrompt,
            "n": 1,
            "size": size,
            "response_format": "b64_json"
        ]

        // Add DALL-E 3 specific options
        if model == "dall-e-3" {
            if let quality = config.dalleQuality {
                body["quality"] = quality.rawValue
            }
            if let style = config.dalleStyle {
                body["style"] = style.rawValue
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 9. Execute request
        try Task.checkCancellation()

        let (data, response) = try await session.data(for: request)

        // 9. Check HTTP status
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            // Check for rate limiting
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) }
                throw AIError.rateLimited(retryAfter: retryAfter)
            }

            // Try to parse error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                if message.contains("content policy") || message.contains("safety") {
                    throw AIError.contentFiltered(reason: message)
                }
                throw AIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
            throw AIError.serverError(statusCode: httpResponse.statusCode, message: nil)
        }

        // 10. Check cancellation after response
        try Task.checkCancellation()

        // 11. Parse response
        return try parseImageResponse(data: data, model: model)
    }

    // MARK: - Helper Methods

    /// Maps arbitrary dimensions to the nearest supported DALL-E size.
    internal func mapToDALLESize(width: Int, height: Int, model: String) -> String {
        if model == "dall-e-2" {
            // DALL-E 2: 256, 512, or 1024 square only
            let maxDim = max(width, height)
            if maxDim <= 256 { return "256x256" }
            if maxDim <= 512 { return "512x512" }
            return "1024x1024"
        } else {
            // DALL-E 3: 1024x1024, 1792x1024, 1024x1792
            let aspectRatio = Float(width) / Float(height)
            if aspectRatio > 1.5 {
                return "1792x1024" // Landscape
            } else if aspectRatio < 0.67 {
                return "1024x1792" // Portrait
            }
            return "1024x1024" // Square
        }
    }

    /// Parses DALL-E image generation response.
    internal func parseImageResponse(data: Data, model: String) throws -> GeneratedImage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.generationFailed(underlying: SendableError(
                NSError(domain: "OpenAIProvider", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
            ))
        }

        guard let dataArray = json["data"] as? [[String: Any]],
              let firstImage = dataArray.first,
              let b64Json = firstImage["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64Json) else {
            throw AIError.generationFailed(underlying: SendableError(
                NSError(domain: "OpenAIProvider", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid image data in response"])
            ))
        }

        // Extract metadata
        let revisedPrompt = firstImage["revised_prompt"] as? String
        let created = json["created"] as? TimeInterval

        let metadata = ImageGenerationMetadata(
            revisedPrompt: revisedPrompt,
            createdAt: created.map { Date(timeIntervalSince1970: $0) },
            model: model
        )

        return GeneratedImage(data: imageData, format: .png, metadata: metadata)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
