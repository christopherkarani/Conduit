# Error Handling

Handle errors gracefully with categorized, retryable error types.

## Overview

Conduit uses `AIError` as its primary error type. Every case is categorized, includes a recovery suggestion, and indicates whether automatic retry is appropriate. This gives you everything you need for robust error handling in production apps.

## AIError Categories

Errors are organized into logical categories accessible via the `category` property:

### Provider Errors

Issues with provider configuration or availability:

```swift
do {
    let result = try await provider.generate("Hello", model: .claudeSonnet45)
} catch let error as AIError {
    switch error {
    case .providerUnavailable(let reason):
        // Provider is not reachable
        print("Provider unavailable: \(reason)")
    case .authenticationFailed(let message):
        // Invalid or missing API key
        print("Auth failed: \(message)")
    case .modelNotFound(let model):
        // Requested model doesn't exist
        print("Model not found: \(model.rawValue)")
    case .modelNotCached(let model):
        // Local model not downloaded yet
        print("Download \(model.displayName) first")
    case .incompatibleModel(let model, let reasons):
        // Model can't run on this device/config
        for reason in reasons { print(reason) }
    default:
        break
    }
}
```

### Generation Errors

Issues during text generation:

- `.generationFailed(underlying:)` — General generation failure
- `.tokenLimitExceeded(count:limit:)` — Input exceeds context window
- `.contentFiltered(reason:)` — Content was blocked by safety filters
- `.cancelled` — Generation was cancelled
- `.timeout(TimeInterval)` — Generation timed out

### Network Errors

Connectivity and server issues:

- `.networkError(URLError)` — Connection failed, DNS resolution, etc.
- `.serverError(statusCode:message:)` — HTTP 5xx errors
- `.rateLimited(retryAfter:)` — Rate limit hit with optional retry delay

### Resource Errors

Local resource constraints:

- `.insufficientMemory(required:available:)` — Not enough RAM for the model
- `.insufficientDiskSpace(required:available:)` — Not enough storage
- `.downloadFailed(underlying:)` — Model download failed
- `.checksumMismatch(expected:actual:)` — Downloaded file is corrupted

### Input Errors

Invalid input data:

- `.invalidInput(String)` — Malformed input
- `.unsupportedAudioFormat(String)` — Audio format not supported
- `.unsupportedLanguage(String)` — Language not supported

## The isRetryable Property

Check whether an error is safe to retry:

```swift
do {
    let result = try await provider.generate("Hello", model: .claudeSonnet45)
} catch let error as AIError where error.isRetryable {
    // Safe to retry: rate limits, transient network errors, server errors
    try await Task.sleep(for: .seconds(2))
    let result = try await provider.generate("Hello", model: .claudeSonnet45)
} catch let error as AIError {
    // Not retryable: auth failures, invalid input, cancelled
    print("Permanent error: \(error.localizedDescription)")
}
```

Retryable errors include:
- `.rateLimited` — Always retryable, respects `retryAfter`
- `.serverError` — HTTP 5xx (transient)
- `.networkError` — Some `URLError` codes (timeout, connection lost)
- `.timeout` — Generation timeout

Non-retryable errors include:
- `.authenticationFailed` — Fix your API key
- `.cancelled` — User-initiated
- `.contentFiltered` — Content policy violation
- `.invalidInput` — Fix the input
- `.insufficientMemory` — Device limitation

## Recovery Suggestions

Every `AIError` provides a `recoverySuggestion` string suitable for user-facing display:

```swift
catch let error as AIError {
    if let suggestion = error.recoverySuggestion {
        showAlert(message: suggestion)
        // e.g. "Check your API key and try again"
        // e.g. "Wait 30 seconds before retrying"
        // e.g. "Download the model before using it"
    }
}
```

## Error Category Grouping

Use the `category` property to handle errors by group:

```swift
catch let error as AIError {
    switch error.category {
    case .provider:
        // Configuration or availability issues
        showProviderSettings()
    case .generation:
        // Generation-specific failures
        retryOrShowError(error)
    case .network:
        // Connectivity problems
        showOfflineUI()
    case .resource:
        // Device resource constraints
        suggestSmallerModel()
    case .input:
        // Bad user input
        showInputValidationError(error)
    case .tool:
        // Tool execution failures
        showToolError(error)
    }
}
```

## Retry with Exponential Backoff

A pattern for production retry logic:

```swift
func generateWithRetry<P: TextGenerator>(
    provider: P,
    prompt: String,
    model: P.ModelID,
    maxAttempts: Int = 3
) async throws -> String {
    var lastError: Error?
    for attempt in 0..<maxAttempts {
        do {
            return try await provider.generate(prompt, model: model)
        } catch let error as AIError where error.isRetryable {
            lastError = error
            if case .rateLimited(let retryAfter) = error, let delay = retryAfter {
                try await Task.sleep(for: .seconds(delay))
            } else {
                let backoff = pow(2.0, Double(attempt))
                try await Task.sleep(for: .seconds(backoff))
            }
        }
    }
    throw lastError!
}
```
