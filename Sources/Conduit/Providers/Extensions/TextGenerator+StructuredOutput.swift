// TextGenerator+StructuredOutput.swift
// Conduit
//
// Extension for non-streaming structured Generable responses.

import Foundation

// MARK: - TextGenerator Structured Output

extension TextGenerator {

    /// Generates a structured response, returning a fully-typed value.
    ///
    /// This method provides a non-streaming structured output API, modeled after
    /// Apple's FoundationModels `generate(_:returning:)` pattern. It augments the
    /// prompt with the target type's GenerationSchema and instructs the model to respond
    /// with valid JSON matching that GenerationSchema.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// @Generable
    /// struct Recipe {
    ///     let title: String
    ///     let ingredients: [String]
    /// }
    ///
    /// let recipe = try await provider.generate(
    ///     "Create a cookie recipe",
    ///     returning: Recipe.self,
    ///     model: .llama3_2_1B
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to the model.
    ///   - type: The `Generable` type to parse responses into.
    ///   - model: The model to use for generation.
    ///   - config: Configuration options for the request.
    /// - Returns: A fully parsed `T` value.
    /// - Throws: `AIError` if generation or parsing fails.
    public func generate<T: Generable>(
        _ prompt: String,
        returning type: T.Type,
        model: ModelID,
        config: GenerateConfig = .default
    ) async throws -> T {
        let schemaJSON = T.generationSchema.toJSONString()
        let structuredPrompt = """
        \(prompt)

        Respond with valid JSON matching this schema:
        \(schemaJSON)
        """

        let text = try await generate(structuredPrompt, model: model, config: config)

        do {
            let content = try GeneratedContent(json: text)
            return try T(content)
        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }
    }

    /// Generates a structured response using conversation messages.
    ///
    /// This variant preserves the provider's chat/message formatting by sending
    /// the conversation as messages, while appending a final instruction to
    /// respond with valid JSON matching the requested schema.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages.
    ///   - type: The `Generable` type to parse responses into.
    ///   - model: The model to use for generation.
    ///   - config: Configuration options for the request.
    /// - Returns: A fully parsed `T` value.
    /// - Throws: `AIError` if generation or parsing fails.
    public func generate<T: Generable>(
        messages: [Message],
        returning type: T.Type,
        model: ModelID,
        config: GenerateConfig = .default
    ) async throws -> T {
        guard !messages.isEmpty else {
            throw AIError.invalidInput("Messages array cannot be empty")
        }

        let schemaJSON = T.generationSchema.toJSONString()
        let instruction = """
        Respond with valid JSON matching this schema:
        \(schemaJSON)
        """

        var structuredMessages = messages
        structuredMessages.append(.user(instruction))

        let result = try await generate(messages: structuredMessages, model: model, config: config)

        do {
            let content = try GeneratedContent(json: result.text)
            return try T(content)
        } catch {
            throw AIError.generationFailed(underlying: SendableError(error))
        }
    }
}
