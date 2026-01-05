# Error Handling

Handle errors gracefully with Conduit's comprehensive error system. Provide meaningful feedback and implement robust recovery strategies.

## Table of Contents

- [Overview](#overview)
- [AIError Categories](#aierror-categories)
- [Common Errors](#common-errors)
- [Provider-Specific Errors](#provider-specific-errors)
- [Recovery Strategies](#recovery-strategies)
- [Logging](#logging)
- [Best Practices](#best-practices)

---

## Overview

Conduit uses a unified `AIError` type across all providers, making error handling consistent regardless of which provider you use.

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch let error as AIError {
    // Handle specific AI errors
    switch error {
    case .authenticationFailed(let message):
        print("Auth failed: \(message)")
    case .rateLimited(let retryAfter):
        print("Rate limited, retry after: \(retryAfter ?? 0)s")
    default:
        print("Error: \(error.localizedDescription)")
    }
} catch {
    // Handle unexpected errors
    print("Unexpected error: \(error)")
}
```

---

## AIError Categories

### Provider Errors

Issues with provider setup or availability:

| Error | Description |
|-------|-------------|
| `providerUnavailable(reason:)` | Provider not available |
| `modelNotFound(_:)` | Model doesn't exist |
| `modelNotCached(_:)` | Local model not downloaded |
| `incompatibleModel(model:, reasons:)` | Model incompatible with provider |
| `authenticationFailed(_:)` | Invalid or missing credentials |
| `billingError(_:)` | Payment or billing issue |
| `unsupportedModel(variant:, reason:)` | Model variant not supported |

### Generation Errors

Issues during response generation:

| Error | Description |
|-------|-------------|
| `generationFailed(underlying:)` | Inference failed |
| `tokenLimitExceeded(count:, limit:)` | Input too long |
| `contentFiltered(reason:)` | Safety filter triggered |
| `cancelled` | User cancelled generation |
| `timeout(_:)` | Operation timed out |

### Network Errors

Issues with API communication:

| Error | Description |
|-------|-------------|
| `networkError(_:)` | Network connectivity issue |
| `serverError(statusCode:, message:)` | HTTP error from API |
| `rateLimited(retryAfter:)` | Rate limit exceeded |

### Resource Errors

Issues with local resources:

| Error | Description |
|-------|-------------|
| `insufficientMemory(required:, available:)` | Not enough RAM |
| `downloadFailed(underlying:)` | Model download failed |
| `fileError(underlying:)` | File system error |
| `insufficientDiskSpace(required:, available:)` | Not enough storage |
| `checksumMismatch(expected:, actual:)` | Download corrupted |

### Platform Errors

Issues with platform compatibility:

| Error | Description |
|-------|-------------|
| `unsupportedPlatform(_:)` | Platform not supported |
| `modelNotLoaded(_:)` | Model not loaded in memory |

### Input Errors

Issues with user input:

| Error | Description |
|-------|-------------|
| `invalidInput(_:)` | Invalid input format |
| `unsupportedAudioFormat(_:)` | Audio format not supported |
| `unsupportedLanguage(_:)` | Language not supported |
| `invalidToolName(name:, reason:)` | Invalid tool name |

---

## Common Errors

### Authentication Errors

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.authenticationFailed(let message) {
    // Invalid API key
    print("Authentication failed: \(message)")

    // Recovery: prompt user to update API key
    showAPIKeySettingsAlert()
}
```

### Rate Limiting

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.rateLimited(let retryAfter) {
    // Rate limit exceeded
    if let seconds = retryAfter {
        print("Rate limited. Retry after \(seconds) seconds.")

        // Automatic retry after delay
        try await Task.sleep(for: .seconds(seconds))
        return try await provider.generate(prompt, model: model)
    }
}
```

### Token Limit Exceeded

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.tokenLimitExceeded(let count, let limit) {
    print("Input has \(count) tokens, limit is \(limit)")

    // Recovery: truncate input
    let truncatedPrompt = truncateToFit(prompt, limit: limit - 500)
    return try await provider.generate(truncatedPrompt, model: model)
}
```

### Model Not Cached

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.modelNotCached(let modelId) {
    print("Model not downloaded: \(modelId)")

    // Recovery: download model
    try await ModelManager.shared.download(modelId)
    return try await provider.generate(prompt, model: model)
}
```

### Network Errors

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.networkError(let error) {
    print("Network error: \(error.localizedDescription)")

    // Recovery: check connectivity, retry
    if isConnected() {
        try await Task.sleep(for: .seconds(2))
        return try await provider.generate(prompt, model: model)
    } else {
        showOfflineAlert()
    }
}
```

### Server Errors

```swift
do {
    let response = try await provider.generate(prompt, model: model)
} catch AIError.serverError(let statusCode, let message) {
    print("Server error \(statusCode): \(message)")

    switch statusCode {
    case 500...599:
        // Server issue - retry with backoff
        try await Task.sleep(for: .seconds(5))
        return try await provider.generate(prompt, model: model)
    case 400:
        // Bad request - check input
        print("Invalid request: \(message)")
    default:
        print("HTTP \(statusCode): \(message)")
    }
}
```

---

## Provider-Specific Errors

### MLX Provider

```swift
do {
    let response = try await mlxProvider.generate(prompt, model: model)
} catch AIError.modelNotCached(let model) {
    // Download required
    try await ModelManager.shared.download(model)
} catch AIError.insufficientMemory(let required, let available) {
    // Not enough RAM
    print("Need \(required.formatted()), have \(available.formatted())")
    // Try smaller model or evict cached models
} catch AIError.unsupportedPlatform(let platform) {
    // Not Apple Silicon
    print("MLX requires Apple Silicon, got: \(platform)")
}
```

### Anthropic Provider

```swift
do {
    let response = try await anthropicProvider.generate(prompt, model: model)
} catch AIError.authenticationFailed(let message) {
    // Invalid API key
    print("Check your ANTHROPIC_API_KEY")
} catch AIError.rateLimited(let retryAfter) {
    // Claude rate limits
    print("Rate limited by Anthropic")
} catch AIError.contentFiltered(let reason) {
    // Safety filter
    print("Content blocked: \(reason)")
}
```

### HuggingFace Provider

```swift
do {
    let response = try await hfProvider.generate(prompt, model: model)
} catch AIError.modelNotFound(let model) {
    // Model not on HuggingFace or no inference API
    print("Model not available: \(model)")
} catch AIError.timeout(let duration) {
    // Model might be loading
    print("Timed out after \(duration)s - model may be warming up")
    // Retry
}
```

---

## Recovery Strategies

### Automatic Retry with Backoff

```swift
func generateWithRetry(
    prompt: String,
    maxAttempts: Int = 3
) async throws -> String {
    var lastError: Error?
    var delay: TimeInterval = 1

    for attempt in 1...maxAttempts {
        do {
            return try await provider.generate(prompt, model: model)
        } catch AIError.rateLimited(let retryAfter) {
            delay = retryAfter ?? delay * 2
            try await Task.sleep(for: .seconds(delay))
            lastError = AIError.rateLimited(retryAfter: retryAfter)
        } catch AIError.networkError(let error) {
            delay *= 2
            try await Task.sleep(for: .seconds(min(delay, 30)))
            lastError = AIError.networkError(error)
        } catch AIError.serverError(let code, _) where code >= 500 {
            delay *= 2
            try await Task.sleep(for: .seconds(min(delay, 30)))
            lastError = AIError.serverError(statusCode: code, message: "")
        } catch {
            // Non-retryable error
            throw error
        }
    }

    throw lastError ?? AIError.generationFailed(underlying: nil)
}
```

### Fallback Provider

```swift
func generateWithFallback(prompt: String) async throws -> String {
    // Try primary provider
    do {
        return try await anthropicProvider.generate(prompt, model: .claudeSonnet45)
    } catch AIError.rateLimited, AIError.serverError {
        // Fall back to secondary
        print("Falling back to HuggingFace")
        return try await hfProvider.generate(
            prompt,
            model: .huggingFace("meta-llama/Llama-3.1-8B-Instruct")
        )
    }
}
```

### Graceful Degradation

```swift
func generateSafely(prompt: String) async -> String {
    do {
        return try await provider.generate(prompt, model: model)
    } catch AIError.tokenLimitExceeded {
        // Truncate and retry
        let shorter = String(prompt.prefix(2000))
        return try await provider.generate(shorter, model: model)
    } catch AIError.contentFiltered {
        return "I can't help with that request."
    } catch AIError.rateLimited {
        return "Service is busy. Please try again in a moment."
    } catch {
        return "Something went wrong. Please try again."
    }
}
```

---

## Logging

### Using AIError Properties

```swift
catch let error as AIError {
    // User-friendly message
    print(error.localizedDescription)

    // Recovery suggestion
    if let suggestion = error.recoverySuggestion {
        print("Try: \(suggestion)")
    }

    // Check if retry makes sense
    if error.isRetryable {
        // Implement retry logic
    }

    // Error category for analytics
    switch error.category {
    case .provider:
        logProviderError(error)
    case .generation:
        logGenerationError(error)
    case .network:
        logNetworkError(error)
    case .resource:
        logResourceError(error)
    case .input:
        logInputError(error)
    }
}
```

### Structured Logging

```swift
func logError(_ error: AIError, context: [String: Any]) {
    let logEntry: [String: Any] = [
        "error_type": String(describing: type(of: error)),
        "description": error.localizedDescription,
        "category": String(describing: error.category),
        "is_retryable": error.isRetryable,
        "context": context,
        "timestamp": Date()
    ]

    // Send to logging service
    Logger.shared.log(logEntry)
}
```

---

## Best Practices

### 1. Be Specific

```swift
// Good - handle specific errors
catch AIError.rateLimited(let retryAfter) {
    // Handle rate limit specifically
}
catch AIError.authenticationFailed {
    // Handle auth specifically
}
catch {
    // Fallback for unexpected errors
}

// Avoid - catching everything generically
catch {
    print("Error occurred")
}
```

### 2. Provide User Feedback

```swift
func userFriendlyMessage(for error: AIError) -> String {
    switch error {
    case .authenticationFailed:
        return "Please check your API key in Settings."
    case .rateLimited:
        return "Service is busy. Please wait a moment."
    case .networkError:
        return "Check your internet connection."
    case .tokenLimitExceeded:
        return "Your message is too long. Please shorten it."
    case .modelNotCached:
        return "Downloading required files..."
    case .contentFiltered:
        return "I can't help with that request."
    default:
        return "Something went wrong. Please try again."
    }
}
```

### 3. Log for Debugging

```swift
catch let error as AIError {
    // Log detailed info for debugging
    #if DEBUG
    print("AIError: \(error)")
    print("Description: \(error.localizedDescription)")
    print("Recovery: \(error.recoverySuggestion ?? "none")")
    print("Retryable: \(error.isRetryable)")
    #endif

    // Show user-friendly message
    showAlert(userFriendlyMessage(for: error))
}
```

### 4. Test Error Scenarios

```swift
// In tests, verify error handling
@Test("Handles rate limiting gracefully")
func testRateLimitHandling() async throws {
    // Mock rate limit response
    mockProvider.shouldThrow = AIError.rateLimited(retryAfter: 5)

    let result = await viewModel.sendMessage("Test")

    #expect(result.contains("busy"))
    #expect(!viewModel.isLoading)
}
```

---

## Next Steps

- [Streaming](Streaming.md) - Handle streaming errors
- [Providers](Providers/README.md) - Provider-specific error handling
- [ChatSession](ChatSession.md) - Error handling in conversations
