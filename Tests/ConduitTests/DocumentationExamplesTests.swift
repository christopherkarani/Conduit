// DocumentationExamplesTests.swift
// Conduit

import XCTest
@testable import Conduit

final class DocumentationExamplesTests: XCTestCase {

    func testReadmeRunnerAggregatesEveryProvider() async throws {
        let runner = DocumentationRunner(prompt: "Plan a three-day sprint.")

        let steps = [
            DocumentationRunner.Step(label: "Claude Opus 4.5") {
                let provider = ExampleMockProvider(label: "Anthropic", modelID: ExampleMockModel.anthropicOpus)
                return try await runner.run(provider: provider, model: provider.modelID)
            },
            DocumentationRunner.Step(label: "OpenRouter GPT-5.2") {
                let provider = ExampleMockProvider(label: "OpenRouter", modelID: ExampleMockModel.openRouterGPT52)
                return try await runner.run(provider: provider, model: provider.modelID)
            },
            DocumentationRunner.Step(label: "Ollama Llama3.2") {
                let provider = ExampleMockProvider(label: "Ollama", modelID: ExampleMockModel.ollamaLlama32)
                return try await runner.run(provider: provider, model: provider.modelID)
            },
            DocumentationRunner.Step(label: "MLX Llama3.2 1B") {
                let provider = ExampleMockProvider(label: "MLX", modelID: ExampleMockModel.mlxLlama32)
                return try await runner.run(provider: provider, model: provider.modelID)
            }
        ]

        let results = try await runner.collect(steps: steps)
        XCTAssertEqual(results.count, steps.count)

        for (step, result) in zip(steps, results) {
            XCTAssertEqual(step.label, result.label)
            XCTAssertTrue(result.text.contains(step.label.components(separatedBy: " ").first ?? ""))
        }
    }
}

private struct DocumentationRunner {
    let prompt: String

    struct Step {
        let label: String
        let job: () async throws -> String
    }

    func run<P: TextGenerator>(provider: P, model: P.ModelID) async throws -> String {
        try await provider.generate(prompt, model: model, config: .creative)
    }

    func collect(steps: [Step]) async throws -> [(label: String, text: String)] {
        var finished: [(String, String)] = []
        for step in steps {
            let text = try await step.job()
            finished.append((step.label, text))
        }
        return finished
    }
}

private struct ExampleMockProvider: TextGenerator {
    typealias ModelID = ExampleMockModel

    let label: String
    let modelID: ExampleMockModel

    func generate(_ prompt: String, model: ExampleMockModel, config: GenerateConfig) async throws -> String {
        "\(label): \(prompt) [\(model.displayName)]"
    }

    func generate(messages: [Message], model: ExampleMockModel, config: GenerateConfig) async throws -> GenerationResult {
        let joined = messages.map { $0.content.textValue }.joined(separator: " ")
        return GenerationResult.text(joined.isEmpty ? model.displayName : joined)
    }

    func stream(_ prompt: String, model: ExampleMockModel, config: GenerateConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("\(label) stream: \(prompt)")
            continuation.finish()
        }
    }

    func streamWithMetadata(messages: [Message], model: ExampleMockModel, config: GenerateConfig) -> AsyncThrowingStream<GenerationChunk, Error> {
        AsyncThrowingStream { continuation in
            let chunk = GenerationChunk(text: "\(label) chunk", isComplete: true, finishReason: .stop)
            continuation.yield(chunk)
            continuation.finish()
        }
    }
}

private struct ExampleMockModel: ModelIdentifying {
    let rawValue: String
    let providerType: ProviderType

    var displayName: String { rawValue }
    var provider: ProviderType { providerType }
    var description: String { "[\(provider.displayName)] \(rawValue)" }

    static let anthropicOpus = ExampleMockModel(rawValue: "claude-opus-4-5-20251101", providerType: .anthropic)
    static let openRouterGPT52 = ExampleMockModel(rawValue: "openai/gpt-5.2-opus", providerType: .openRouter)
    static let ollamaLlama32 = ExampleMockModel(rawValue: "llama3.2", providerType: .ollama)
    static let mlxLlama32 = ExampleMockModel(rawValue: "mlx-community/Llama-3.2-1B-Instruct-4bit", providerType: .mlx)
}
