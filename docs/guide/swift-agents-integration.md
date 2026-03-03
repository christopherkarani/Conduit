# SwiftAgents Integration

Integrate Conduit providers with the SwiftAgents framework for building AI agent applications.

## Overview

Conduit can be used as the inference backend for [SwiftAgents](https://github.com/christopherkarani/SwiftAgents) through an adapter pattern. This guide shows how to create an adapter that bridges Conduit providers to SwiftAgents' `InferenceProvider` protocol.

## Creating the Adapter Package

Create a new Swift package that depends on both Conduit and SwiftAgents:

```swift
// Package.swift
import PackageDescription

let package = Package(
    name: "ConduitAgents",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ConduitAgents", targets: ["ConduitAgents"])
    ],
    dependencies: [
        .package(url: "https://github.com/your-org/Conduit.git", from: "1.0.0"),
        .package(url: "https://github.com/christopherkarani/SwiftAgents.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ConduitAgents",
            dependencies: ["Conduit", "SwiftAgents"]
        )
    ]
)
```

## Inference Provider Adapter

Create an adapter that wraps any Conduit `TextGenerator`:

```swift
import Conduit
import SwiftAgents

/// Adapts a Conduit TextGenerator to SwiftAgents' InferenceProvider.
public struct ConduitInferenceProvider<Provider: TextGenerator>: InferenceProvider {

    private let provider: Provider
    private let modelID: Provider.ModelID
    private let config: GenerateConfig

    public init(
        provider: Provider,
        model: Provider.ModelID,
        config: GenerateConfig = .default
    ) {
        self.provider = provider
        self.modelID = model
        self.config = config
    }

    // MARK: - InferenceProvider

    public func generate(prompt: String) async throws -> String {
        try await provider.generate(prompt, model: modelID, config: config)
    }

    public func generate(messages: [SwiftAgents.Message]) async throws -> String {
        // Convert SwiftAgents messages to Conduit messages
        let conduitMessages = messages.map { message in
            Conduit.Message(
                role: convertRole(message.role),
                content: .text(message.content)
            )
        }
        let result = try await provider.generate(
            messages: conduitMessages,
            model: modelID,
            config: config
        )
        return result.text
    }

    private func convertRole(_ role: SwiftAgents.MessageRole) -> Conduit.Message.Role {
        switch role {
        case .user: return .user
        case .assistant: return .assistant
        case .system: return .system
        }
    }
}
```

## Tool Integration

Conduit's `Tool` protocol can be adapted to SwiftAgents' `Tool` protocol using `GeneratedContent` for
argument decoding and `PromptRepresentable` output:

```swift
import Conduit
import SwiftAgents

/// Wraps a Conduit Tool for use with SwiftAgents.
public struct ConduitToolWrapper<T: Tool>: SwiftAgents.Tool {

    private let tool: T

    public init(_ tool: T) {
        self.tool = tool
    }

    public var name: String { tool.name }
    public var description: String { tool.description }

    public var parameters: SwiftAgents.ToolParameters {
        SwiftAgents.ToolParameters(jsonSchema: tool.parameters.toJSONSchema())
    }

    public func execute(arguments: [String: Any]) async throws -> String {
        let data = try JSONSerialization.data(withJSONObject: arguments)
        let json = String(decoding: data, as: UTF8.self)
        let content = try GeneratedContent(json: json)
        let parsed = try T.Arguments(content)
        let output = try await tool.call(arguments: parsed)
        return output.promptRepresentation.description
    }
}
```

## Structured Output with Generable

Use Conduit's `@Generable` types with SwiftAgents:

```swift
import Conduit
import SwiftAgents

// Define a Generable type
@Generable
struct TaskAnalysis {
    @Guide("Summary of the task")
    let summary: String

    @Guide("Estimated complexity", .anyOf(["low", "medium", "high"]))
    let complexity: String

    @Guide("Suggested approach")
    let approach: String
}

// Use with SwiftAgents
extension ConduitInferenceProvider {

    /// Generates a structured response using a Generable type.
    public func generate<T: Generable>(
        prompt: String,
        returning type: T.Type
    ) async throws -> T {
        // Add schema to prompt
        let schemaJSON = T.generationSchema.toJSONString()
        let structuredPrompt = """
        \(prompt)

        Respond with valid JSON matching this schema:
        \(schemaJSON)
        """

        let response = try await generate(prompt: structuredPrompt)
        let content = try GeneratedContent(json: response)
        return try T(content)
    }
}
```

## Usage Example

```swift
import Conduit
import SwiftAgents
import ConduitAgents

// Create Conduit provider
let anthropic = AnthropicProvider(apiKey: "your-key")

// Wrap as SwiftAgents InferenceProvider
let inferenceProvider = ConduitInferenceProvider(
    provider: anthropic,
    model: .claude4Sonnet,
    config: .default.temperature(0.7)
)

// Create SwiftAgents agent with Conduit backend
let agent = Agent(
    name: "Assistant",
    instructions: "You are a helpful assistant.",
    inferenceProvider: inferenceProvider,
    tools: [
        ConduitToolWrapper(WeatherTool()),
        ConduitToolWrapper(SearchTool())
    ]
)

// Run the agent
let response = try await agent.run("What's the weather in Paris?")
print(response)
```
