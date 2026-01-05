# Tool Calling

Let LLMs invoke your Swift functions. Define tools that models can call to access external data, perform calculations, or trigger actions.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Defining Tools](#defining-tools)
- [Tool Arguments](#tool-arguments)
- [The AIToolExecutor](#the-aitoolexecutor)
- [Tool Choice Options](#tool-choice-options)
- [Multi-Tool Workflows](#multi-tool-workflows)
- [Streaming with Tools](#streaming-with-tools)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)

---

## Overview

Tool calling (also called function calling) enables LLMs to:

- **Access real-time data**: Weather, stock prices, database queries
- **Perform calculations**: Math operations, data processing
- **Take actions**: Send emails, create records, trigger workflows
- **Integrate systems**: Connect to APIs, services, and databases

### How It Works

1. You define tools with typed arguments using `@Generable`
2. The model receives tool definitions with your prompt
3. If the model decides a tool is needed, it generates a tool call
4. Your code executes the tool and returns results
5. The model incorporates results into its response

---

## Quick Start

### 1. Define a Tool

```swift
import Conduit

struct WeatherTool: AITool {
    @Generable
    struct Arguments {
        @Guide("City name to get weather for")
        let city: String
    }

    var description: String { "Get current weather for a city" }

    func call(arguments: Arguments) async throws -> String {
        // Your implementation
        return "Weather in \(arguments.city): 22°C, Sunny"
    }
}
```

### 2. Use with a Provider

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

// Configure with tools
let config = GenerateConfig.default
    .tools([WeatherTool()])
    .toolChoice(.auto)

// Generate with tool access
let response = try await provider.generate(
    messages: [.user("What's the weather in Paris?")],
    model: .claudeSonnet45,
    config: config
)

// Check for tool calls
if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
    // Execute tools and continue conversation
}
```

---

## Defining Tools

### The AITool Protocol

```swift
protocol AITool: Sendable {
    associatedtype Arguments: Generable
    associatedtype Output: PromptRepresentable

    var name: String { get }           // Auto-generated from type name
    var description: String { get }    // Describe what the tool does
    static var parameters: Schema { get } // Auto-generated from Arguments

    func call(arguments: Arguments) async throws -> Output
}
```

### Basic Tool

```swift
struct CalculatorTool: AITool {
    @Generable
    struct Arguments {
        @Guide("Mathematical expression to evaluate")
        let expression: String
    }

    var description: String {
        "Evaluate a mathematical expression"
    }

    func call(arguments: Arguments) async throws -> String {
        // Implement calculation
        let result = evaluate(arguments.expression)
        return "Result: \(result)"
    }
}
```

### Tool with Complex Output

```swift
struct SearchTool: AITool {
    @Generable
    struct Arguments {
        @Guide("Search query")
        let query: String

        @Guide("Maximum results", .range(1...20))
        let maxResults: Int?
    }

    var description: String {
        "Search the knowledge base"
    }

    func call(arguments: Arguments) async throws -> String {
        let limit = arguments.maxResults ?? 10
        let results = try await searchDatabase(
            query: arguments.query,
            limit: limit
        )
        return results.map { "• \($0.title): \($0.snippet)" }.joined(separator: "\n")
    }
}
```

---

## Tool Arguments

Use `@Generable` to define typed arguments:

### Basic Arguments

```swift
@Generable
struct Arguments {
    @Guide("User's name")
    let name: String

    @Guide("User's age")
    let age: Int
}
```

### With Constraints

```swift
@Generable
struct Arguments {
    @Guide("City name")
    let city: String

    @Guide("Temperature unit", .anyOf(["celsius", "fahrenheit"]))
    let unit: String?

    @Guide("Days to forecast", .range(1...7))
    let days: Int?
}
```

### Optional Arguments

```swift
@Generable
struct Arguments {
    @Guide("Required search query")
    let query: String

    @Guide("Optional category filter")
    let category: String?

    @Guide("Optional result limit")
    let limit: Int?
}
```

### Complex Arguments

```swift
@Generable
struct Location {
    let latitude: Double
    let longitude: Double
}

@Generable
struct Arguments {
    @Guide("Starting location")
    let from: Location

    @Guide("Destination location")
    let to: Location
}
```

---

## The AIToolExecutor

`AIToolExecutor` manages tool registration and execution:

### Basic Usage

```swift
// Create executor
let executor = AIToolExecutor()

// Register tools
await executor.register(WeatherTool())
await executor.register(CalculatorTool())
await executor.register(SearchTool())

// Get tool definitions for provider
let toolDefinitions = await executor.toolDefinitions
```

### Executing Tool Calls

```swift
// After getting response with tool calls
if let toolCalls = response.toolCalls {
    // Execute all tool calls
    let results = try await executor.execute(toolCalls: toolCalls)

    // Results are AIToolOutput - can be added to conversation
    for result in results {
        print("Tool \(result.toolName): \(result.content)")
    }
}
```

### Single Tool Execution

```swift
let toolCall = response.toolCalls.first!
let result = try await executor.execute(toolCall: toolCall)
```

---

## Tool Choice Options

Control how the model uses tools:

```swift
// Model decides whether to use tools
.toolChoice(.auto)

// Model must use a tool
.toolChoice(.required)

// Model cannot use tools
.toolChoice(.none)

// Model must use specific tool
.toolChoice(.tool(name: "WeatherTool"))
```

### Example

```swift
// Force tool use
let config = GenerateConfig.default
    .tools([WeatherTool()])
    .toolChoice(.required)

// Force specific tool
let config = GenerateConfig.default
    .tools([WeatherTool(), SearchTool()])
    .toolChoice(.tool(name: "SearchTool"))
```

---

## Multi-Tool Workflows

### Conversation Loop

```swift
let executor = AIToolExecutor()
await executor.register(WeatherTool())
await executor.register(SearchTool())

var messages: [Message] = [
    .system("You have access to weather and search tools."),
    .user("What's the weather like in cities with major tech companies?")
]

let config = GenerateConfig.default
    .tools([WeatherTool(), SearchTool()])
    .toolChoice(.auto)

// Conversation loop
while true {
    let response = try await provider.generate(
        messages: messages,
        model: .claudeSonnet45,
        config: config
    )

    // Add assistant response
    messages.append(.assistant(response.text))

    // Check for tool calls
    guard let toolCalls = response.toolCalls, !toolCalls.isEmpty else {
        // No more tool calls - done
        print("Final response: \(response.text)")
        break
    }

    // Execute tools
    let results = try await executor.execute(toolCalls: toolCalls)

    // Add tool results to conversation
    for result in results {
        messages.append(.toolOutput(
            id: result.id,
            toolName: result.toolName,
            content: result.content
        ))
    }
}
```

### Parallel Tool Calls

Some models can call multiple tools in parallel:

```swift
if let toolCalls = response.toolCalls {
    // Execute all tools (executor handles parallelism)
    let results = try await executor.execute(toolCalls: toolCalls)

    // All results returned together
    for result in results {
        messages.append(.toolOutput(
            id: result.id,
            toolName: result.toolName,
            content: result.content
        ))
    }
}
```

---

## Streaming with Tools

Handle tool calls during streaming:

```swift
let stream = provider.streamWithMetadata(
    messages: messages,
    model: .claudeSonnet45,
    config: config
)

var fullText = ""

for try await chunk in stream {
    fullText += chunk.text
    print(chunk.text, terminator: "")

    // Check for tool calls in final chunk
    if let toolCalls = chunk.completedToolCalls {
        print("\n[Tool calls detected]")
        // Handle tool calls
    }
}
```

### Partial Tool Call Updates

During streaming, you can observe tool arguments being built:

```swift
for try await chunk in stream {
    if let partial = chunk.partialToolCall {
        print("Building tool call: \(partial.toolName)")
        print("Arguments so far: \(partial.argumentsFragment)")
    }
}
```

---

## Error Handling

### Tool Execution Errors

```swift
do {
    let result = try await executor.execute(toolCall: toolCall)
} catch AIToolError.toolNotFound(let name) {
    // Tool not registered
    print("Unknown tool: \(name)")
} catch AIToolError.invalidArgumentEncoding {
    // Failed to decode arguments
    print("Invalid arguments")
} catch AIToolError.executionFailed(let tool, let error) {
    // Tool threw an error
    print("Tool \(tool) failed: \(error)")
}
```

### Handling Errors in Conversation

```swift
let results: [AIToolOutput]

do {
    results = try await executor.execute(toolCalls: toolCalls)
} catch {
    // Return error to model
    results = toolCalls.map { call in
        AIToolOutput(
            id: call.id,
            toolName: call.toolName,
            content: "Error: \(error.localizedDescription)"
        )
    }
}

// Add results (success or error) to conversation
for result in results {
    messages.append(.toolOutput(result))
}
```

---

## Best Practices

### 1. Clear Descriptions

```swift
// Good - specific and actionable
var description: String {
    "Get the current weather forecast for a city. Returns temperature, conditions, and humidity."
}

// Bad - vague
var description: String { "Weather" }
```

### 2. Constrain Arguments

```swift
@Generable
struct Arguments {
    // Good - constrained, clear purpose
    @Guide("City name (e.g., 'Paris', 'New York')")
    let city: String

    @Guide("Forecast days", .range(1...7))
    let days: Int?
}
```

### 3. Return Structured Information

```swift
func call(arguments: Arguments) async throws -> String {
    let weather = try await fetchWeather(arguments.city)

    // Good - structured, easy for model to parse
    return """
        Location: \(arguments.city)
        Temperature: \(weather.temp)°C
        Conditions: \(weather.conditions)
        Humidity: \(weather.humidity)%
        """
}
```

### 4. Handle Edge Cases

```swift
func call(arguments: Arguments) async throws -> String {
    guard !arguments.city.isEmpty else {
        return "Error: City name is required"
    }

    guard let weather = try await fetchWeather(arguments.city) else {
        return "Error: Could not find weather data for '\(arguments.city)'"
    }

    return formatWeather(weather)
}
```

### 5. Minimize Side Effects

```swift
// Good - read-only tool
struct GetUserTool: AITool { ... }

// Careful - has side effects, document clearly
struct SendEmailTool: AITool {
    var description: String {
        "Send an email. WARNING: This actually sends the email."
    }
}
```

---

## Common Patterns

### Database Query Tool

```swift
struct QueryTool: AITool {
    @Generable
    struct Arguments {
        @Guide("Natural language query")
        let query: String

        @Guide("Table to query", .anyOf(["users", "orders", "products"]))
        let table: String
    }

    let database: Database

    var description: String {
        "Query the database using natural language"
    }

    func call(arguments: Arguments) async throws -> String {
        let results = try await database.query(
            table: arguments.table,
            naturalLanguage: arguments.query
        )
        return results.map { $0.description }.joined(separator: "\n")
    }
}
```

### API Integration Tool

```swift
struct GitHubTool: AITool {
    @Generable
    struct Arguments {
        @Guide("GitHub username")
        let username: String

        @Guide("Action", .anyOf(["repos", "profile", "activity"]))
        let action: String
    }

    var description: String {
        "Get GitHub user information"
    }

    func call(arguments: Arguments) async throws -> String {
        switch arguments.action {
        case "repos":
            let repos = try await fetchRepos(arguments.username)
            return repos.map { "• \($0.name): \($0.description)" }.joined(separator: "\n")
        case "profile":
            let profile = try await fetchProfile(arguments.username)
            return "Name: \(profile.name)\nBio: \(profile.bio)"
        default:
            return "Unknown action"
        }
    }
}
```

### Calculation Tool

```swift
struct MathTool: AITool {
    @Generable
    struct Arguments {
        @Guide("Operation", .anyOf(["add", "subtract", "multiply", "divide"]))
        let operation: String

        @Guide("First number")
        let a: Double

        @Guide("Second number")
        let b: Double
    }

    var description: String {
        "Perform basic math operations"
    }

    func call(arguments: Arguments) async throws -> String {
        let result: Double
        switch arguments.operation {
        case "add": result = arguments.a + arguments.b
        case "subtract": result = arguments.a - arguments.b
        case "multiply": result = arguments.a * arguments.b
        case "divide":
            guard arguments.b != 0 else {
                return "Error: Division by zero"
            }
            result = arguments.a / arguments.b
        default:
            return "Error: Unknown operation"
        }
        return "\(arguments.a) \(arguments.operation) \(arguments.b) = \(result)"
    }
}
```

---

## Next Steps

- [Structured Output](StructuredOutput.md) - More on `@Generable`
- [Streaming](Streaming.md) - Stream tool calls
- [Providers](Providers/README.md) - Provider tool support
- [ChatSession](ChatSession.md) - Managed conversations with tools
