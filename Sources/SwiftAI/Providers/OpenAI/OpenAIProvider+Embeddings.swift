// OpenAIProvider+Embeddings.swift
// SwiftAI
//
// Embedding generation functionality for OpenAIProvider.

import Foundation

// MARK: - EmbeddingGenerator Protocol

extension OpenAIProvider {

    /// Generates an embedding for the given text.
    public func embed(
        _ text: String,
        model: OpenAIModelID
    ) async throws -> EmbeddingResult {
        let url = configuration.endpoint.embeddingsURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add headers
        for (name, value) in configuration.buildHeaders() {
            request.setValue(value, forHTTPHeaderField: name)
        }

        // Build request body
        let body: [String: Any] = [
            "model": model.rawValue,
            "input": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.serverError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Double] else {
            throw AIError.generationFailed(underlying: SendableError(NSError(
                domain: "OpenAIProvider",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid embedding response"]
            )))
        }

        let floatEmbedding = embedding.map { Float($0) }
        return EmbeddingResult(
            vector: floatEmbedding,
            text: text,
            model: model.rawValue
        )
    }

    /// Generates embeddings for multiple texts.
    ///
    /// This method uses concurrent processing with structured concurrency
    /// to generate embeddings in parallel while preserving the original order.
    ///
    /// To prevent rate limiting, concurrency is limited to 10 concurrent requests.
    /// For large batches, requests are processed in waves.
    ///
    /// - Parameters:
    ///   - texts: Array of text strings to generate embeddings for.
    ///   - model: The model to use for generating embeddings.
    /// - Returns: Array of `EmbeddingResult` in the same order as input texts.
    /// - Throws: `AIError` if any embedding generation fails.
    public func embedBatch(
        _ texts: [String],
        model: OpenAIModelID
    ) async throws -> [EmbeddingResult] {
        // Limit concurrency to prevent rate limiting
        let maxConcurrent = 10

        return try await withThrowingTaskGroup(of: (Int, EmbeddingResult).self) { group in
            var results = [(Int, EmbeddingResult)]()
            results.reserveCapacity(texts.count)

            var nextIndex = 0
            let totalCount = texts.count

            // Start initial batch of tasks
            for index in 0..<min(maxConcurrent, totalCount) {
                let text = texts[index]
                group.addTask {
                    let result = try await self.embed(text, model: model)
                    return (index, result)
                }
                nextIndex = index + 1
            }

            // Process results and add new tasks as slots become available
            while let indexedResult = try await group.next() {
                results.append(indexedResult)

                // Add next task if there are more texts to process
                if nextIndex < totalCount {
                    let index = nextIndex
                    let text = texts[index]
                    group.addTask {
                        let result = try await self.embed(text, model: model)
                        return (index, result)
                    }
                    nextIndex += 1
                }
            }

            // Sort by original index to preserve order
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }
}
