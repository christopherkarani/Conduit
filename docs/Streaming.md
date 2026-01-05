# Streaming

Real-time token generation with `AsyncSequence`. Display responses as they're generated for better user experience.

## Table of Contents

- [Overview](#overview)
- [Basic Streaming](#basic-streaming)
- [Streaming with Metadata](#streaming-with-metadata)
- [Collecting Results](#collecting-results)
- [Time-to-First-Token](#time-to-first-token)
- [Cancellation](#cancellation)
- [Structured Output Streaming](#structured-output-streaming)
- [SwiftUI Integration](#swiftui-integration)
- [Error Handling](#error-handling)
- [Performance Tips](#performance-tips)

---

## Overview

Streaming provides tokens as they're generated, rather than waiting for the complete response:

**Without Streaming:**
```
User: "Write a poem"
[Wait 3 seconds...]
Complete poem appears at once
```

**With Streaming:**
```
User: "Write a poem"
R... Ro... Ros... Rose... Roses... [tokens appear in real-time]
```

### Benefits

- **Better UX**: Users see progress immediately
- **Lower perceived latency**: First token in ~100-500ms
- **Interruptible**: Users can cancel mid-generation
- **Progress tracking**: Monitor generation speed

---

## Basic Streaming

### Simple Text Stream

```swift
let provider = MLXProvider()

for try await text in provider.stream(
    "Write a short story",
    model: .llama3_2_1B,
    config: .default
) {
    print(text, terminator: "")
}
print() // Final newline
```

### With Messages

```swift
let messages = Messages {
    Message.system("You are a helpful assistant.")
    Message.user("Explain Swift concurrency")
}

for try await text in provider.stream(
    messages: messages,
    model: .llama3_2_1B,
    config: .default
) {
    print(text, terminator: "")
}
```

---

## Streaming with Metadata

Access generation metrics during streaming:

```swift
let stream = provider.streamWithMetadata(
    messages: messages,
    model: .llama3_2_1B,
    config: .default
)

for try await chunk in stream {
    // The generated text
    print(chunk.text, terminator: "")

    // Generation speed (tokens per second)
    if let tokensPerSecond = chunk.tokensPerSecond {
        // Typical: 30-100 tok/s on Apple Silicon
    }

    // Token count in this chunk
    let tokens = chunk.tokenCount  // Usually 1

    // Check if this is the final chunk
    if chunk.isComplete {
        print("\n[Generation complete]")
    }

    // Finish reason (only on final chunk)
    if let reason = chunk.finishReason {
        switch reason {
        case .stop:
            print("Natural completion")
        case .maxTokens:
            print("Hit token limit")
        case .cancelled:
            print("User cancelled")
        default:
            print("Finished: \(reason)")
        }
    }
}
```

### Available Metadata

| Property | Type | Description |
|----------|------|-------------|
| `text` | `String` | Generated text in this chunk |
| `tokenCount` | `Int` | Tokens in this chunk (usually 1) |
| `tokenId` | `Int?` | Raw token ID |
| `tokensPerSecond` | `Double?` | Current generation speed |
| `isComplete` | `Bool` | Whether this is the final chunk |
| `finishReason` | `FinishReason?` | Why generation stopped |
| `usage` | `UsageStats?` | Token usage (final chunk) |
| `timestamp` | `Date` | When chunk was generated |

---

## Collecting Results

### Collect All Text

```swift
let stream = provider.stream("Write a poem", model: model)
let fullText = try await stream.collect()
print(fullText)
```

### Collect with Metadata

```swift
let stream = provider.streamWithMetadata(messages: messages, model: model, config: config)
let result = try await stream.collectWithMetadata()

print("Text: \(result.text)")
print("Tokens: \(result.tokenCount)")
print("Time: \(result.generationTime)s")
print("Speed: \(result.tokensPerSecond) tok/s")
print("Finish: \(result.finishReason)")
```

### Stream and Collect

Process chunks while collecting:

```swift
let stream = provider.streamWithMetadata(messages: messages, model: model, config: config)

var chunks: [GenerationChunk] = []

for try await chunk in stream {
    chunks.append(chunk)
    print(chunk.text, terminator: "")
}

// Now process collected chunks
let totalTokens = chunks.reduce(0) { $0 + $1.tokenCount }
```

---

## Time-to-First-Token

Measure how quickly the first token arrives:

```swift
let stream = provider.streamWithMetadata(messages: messages, model: model, config: config)

if let (firstChunk, latency) = try await stream.timeToFirstToken() {
    print("First token: '\(firstChunk.text)'")
    print("TTFT: \(latency)s")  // Time to first token

    // Continue processing remaining chunks
    for try await chunk in stream {
        print(chunk.text, terminator: "")
    }
}
```

### Benchmarking

```swift
let startTime = Date()

for try await chunk in stream {
    if chunk == stream.first {
        let ttft = Date().timeIntervalSince(startTime)
        print("TTFT: \(ttft)s")
    }
}

let totalTime = Date().timeIntervalSince(startTime)
print("Total time: \(totalTime)s")
```

---

## Cancellation

### Using Task Cancellation

```swift
let task = Task {
    for try await text in provider.stream("Long story", model: model) {
        print(text, terminator: "")
    }
}

// Cancel after 5 seconds
try await Task.sleep(for: .seconds(5))
task.cancel()
```

### SwiftUI with Task

```swift
struct ChatView: View {
    @State private var generationTask: Task<Void, Error>?
    @State private var response = ""

    var body: some View {
        VStack {
            Text(response)

            Button("Generate") {
                generate()
            }

            Button("Stop") {
                generationTask?.cancel()
            }
        }
    }

    func generate() {
        generationTask = Task {
            response = ""
            for try await text in provider.stream(prompt, model: model) {
                response += text
            }
        }
    }
}
```

### Provider Cancellation

```swift
// Some providers support explicit cancellation
await provider.cancelGeneration()
```

---

## Structured Output Streaming

Stream typed responses with progressive updates:

```swift
@Generable
struct Article {
    let title: String
    let summary: String
    let sections: [String]
}

let stream = provider.stream(
    "Write an article about Swift",
    returning: Article.self,
    model: .claudeSonnet45
)

for try await partial in stream {
    // Properties appear as they're generated
    if let title = partial.title {
        print("Title: \(title)")
    }
    if let summary = partial.summary {
        print("Summary: \(summary)")
    }
    if let sections = partial.sections {
        print("Sections: \(sections.count)")
    }
}

// Get final complete result
let article = try await stream.collect()
```

### Progressive UI Updates

```swift
for try await partial in stream {
    // Update UI as fields become available
    titleLabel.text = partial.title ?? "Generating..."
    summaryLabel.text = partial.summary ?? ""
    sectionsCount.text = "\(partial.sections?.count ?? 0) sections"
}
```

---

## SwiftUI Integration

### Basic Pattern

```swift
struct StreamingView: View {
    @State private var response = ""
    @State private var isGenerating = false

    var body: some View {
        VStack {
            ScrollView {
                Text(response)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(isGenerating ? "Generating..." : "Generate") {
                Task { await generate() }
            }
            .disabled(isGenerating)
        }
    }

    func generate() async {
        isGenerating = true
        response = ""

        do {
            for try await text in provider.stream(prompt, model: model) {
                response += text
            }
        } catch {
            response = "Error: \(error.localizedDescription)"
        }

        isGenerating = false
    }
}
```

### With @Observable

```swift
@Observable
class ChatViewModel {
    var response = ""
    var isGenerating = false
    var tokensPerSecond: Double?

    private var generationTask: Task<Void, Error>?

    func generate(prompt: String) {
        generationTask = Task {
            isGenerating = true
            response = ""

            let stream = provider.streamWithMetadata(
                messages: [.user(prompt)],
                model: model,
                config: config
            )

            for try await chunk in stream {
                await MainActor.run {
                    response += chunk.text
                    tokensPerSecond = chunk.tokensPerSecond
                }
            }

            await MainActor.run {
                isGenerating = false
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
        isGenerating = false
    }
}
```

### Structured Output in SwiftUI

```swift
struct RecipeView: View {
    @State private var title: String?
    @State private var ingredients: [String] = []
    @State private var isLoading = false

    var body: some View {
        VStack {
            if let title {
                Text(title).font(.headline)
            }

            ForEach(ingredients, id: \.self) { ingredient in
                Text("• \(ingredient)")
            }

            ProgressView()
                .opacity(isLoading ? 1 : 0)
        }
        .task {
            await generateRecipe()
        }
    }

    func generateRecipe() async {
        isLoading = true

        let stream = provider.stream(
            "Create a pasta recipe",
            returning: Recipe.self,
            model: model
        )

        do {
            _ = try await stream.reduceOnMain { partial in
                self.title = partial.title
                self.ingredients = partial.ingredients ?? []
            }
        } catch {
            // Handle error
        }

        isLoading = false
    }
}
```

---

## Error Handling

### During Streaming

```swift
do {
    for try await chunk in stream {
        print(chunk.text, terminator: "")
    }
} catch AIError.networkError(let error) {
    print("Network error: \(error)")
} catch AIError.rateLimited(let retryAfter) {
    print("Rate limited, retry after: \(retryAfter ?? 0)s")
} catch {
    print("Error: \(error)")
}
```

### Retry Pattern

```swift
func streamWithRetry(
    prompt: String,
    maxRetries: Int = 3
) async throws -> String {
    var lastError: Error?

    for attempt in 1...maxRetries {
        do {
            var result = ""
            for try await text in provider.stream(prompt, model: model) {
                result += text
            }
            return result
        } catch AIError.rateLimited(let retryAfter) {
            let delay = retryAfter ?? Double(attempt * 2)
            try await Task.sleep(for: .seconds(delay))
            lastError = AIError.rateLimited(retryAfter: retryAfter)
        } catch {
            lastError = error
            break
        }
    }

    throw lastError ?? AIError.generationFailed(underlying: nil)
}
```

---

## Performance Tips

### 1. Batch UI Updates

```swift
// Less efficient - updates on every token
for try await chunk in stream {
    await MainActor.run {
        self.response += chunk.text  // Causes re-render
    }
}

// More efficient - batch updates
var buffer = ""
var lastUpdate = Date()

for try await chunk in stream {
    buffer += chunk.text

    // Update UI at most every 50ms
    if Date().timeIntervalSince(lastUpdate) > 0.05 {
        await MainActor.run {
            self.response += buffer
        }
        buffer = ""
        lastUpdate = Date()
    }
}

// Final update
if !buffer.isEmpty {
    await MainActor.run {
        self.response += buffer
    }
}
```

### 2. Use Text View Efficiently

```swift
// Good - single Text view
Text(response)

// Avoid - creating new views per token
ForEach(tokens) { token in
    Text(token)
}
```

### 3. Warm Up for Fast TTFT

```swift
// Warm up model before user interaction
try await provider.warmUp(model: model, maxTokens: 5)

// Now streaming starts faster
for try await text in provider.stream(prompt, model: model) {
    // First token arrives quickly
}
```

### 4. Monitor Performance

```swift
var tokenCount = 0
var startTime = Date()

for try await chunk in stream {
    tokenCount += chunk.tokenCount

    if let tps = chunk.tokensPerSecond {
        print("Speed: \(tps) tok/s")
    }
}

let totalTime = Date().timeIntervalSince(startTime)
print("Average: \(Double(tokenCount) / totalTime) tok/s")
```

---

## Next Steps

- [Structured Output](StructuredOutput.md) - Type-safe streaming
- [ChatSession](ChatSession.md) - Managed streaming conversations
- [Tool Calling](ToolCalling.md) - Stream with tools
- [Providers](Providers/README.md) - Provider-specific streaming
