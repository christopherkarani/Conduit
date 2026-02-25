# Model Management

Download models from HuggingFace Hub, manage local cache, and discover available models.

## Overview

Conduit provides a comprehensive model management system through `ModelManager`, `DownloadTask`, and `ModelRegistry`. Download any HuggingFace model for local inference, track progress with `@Observable` download tasks, and manage cache storage.

## Downloading Models

Use the shared `ModelManager` actor to download models:

```swift
let manager = ModelManager.shared

// Download a pre-configured model
let url = try await manager.download(.llama3_2_1b) { progress in
    print("Downloading: \(progress.percentComplete)%")
    if let speed = progress.formattedSpeed {
        print("Speed: \(speed)")
    }
    if let eta = progress.formattedETA {
        print("ETA: \(eta)")
    }
}

// Download any HuggingFace model by repository ID
let model = ModelIdentifier.mlx("mlx-community/Mistral-7B-Instruct-v0.3-4bit")
let url = try await manager.download(model)
```

### Download with Validation

Validate model compatibility before downloading:

```swift
do {
    let url = try await manager.downloadValidated(.llama3_2_1b) { progress in
        print("Progress: \(progress.percentComplete)%")
    }
} catch AIError.incompatibleModel(let model, let reasons) {
    print("Cannot download \(model.rawValue):")
    for reason in reasons {
        print("  - \(reason)")
    }
}
```

### Size Estimation

Check download size before committing bandwidth:

```swift
if let size = await manager.estimateDownloadSize(.llama3_2_1b) {
    print("Download size: \(size.formatted)")  // e.g. "2.1 GB"
}
```

## DownloadTask

`DownloadTask` is an `@Observable` type that tracks download progress in real time:

```swift
let task = await manager.downloadTask(for: .llama3_2_1b)

// Observe progress
task.progress.fractionCompleted  // 0.0...1.0
task.progress.percentComplete    // 0...100
task.progress.formattedSpeed     // "12.5 MB/s"
task.progress.formattedETA       // "2m 30s"

// Control the download
task.cancel()
task.pause()
task.resume()

// Wait for completion
let url = try await task.result()
```

### DownloadProgress Fields

| Property | Type | Description |
|----------|------|-------------|
| `bytesDownloaded` | `Int64` | Bytes received so far |
| `totalBytes` | `Int64?` | Total expected bytes |
| `fractionCompleted` | `Double` | Progress from 0.0 to 1.0 |
| `percentComplete` | `Int` | Progress from 0 to 100 |
| `bytesPerSecond` | `Double` | Current download speed |
| `formattedSpeed` | `String?` | Human-readable speed (e.g. "12.5 MB/s") |
| `formattedETA` | `String?` | Human-readable time remaining (e.g. "2m 30s") |
| `currentFile` | `String?` | Name of the file currently downloading |
| `filesCompleted` | `Int` | Number of files completed |
| `totalFiles` | `Int` | Total number of files to download |

### DownloadState

| State | Description |
|-------|-------------|
| `.pending` | Queued, not yet started |
| `.downloading` | Actively downloading |
| `.paused` | Paused by user |
| `.completed(URL)` | Finished, local URL available |
| `.failed(Error)` | Failed with error |
| `.cancelled` | Cancelled by user |

### SwiftUI Integration

Since `DownloadTask` is `@Observable`, it works seamlessly with SwiftUI:

```swift
struct ModelDownloadView: View {
    @State private var downloadTask: DownloadTask?

    var body: some View {
        if let task = downloadTask {
            VStack {
                ProgressView(value: task.progress.fractionCompleted)
                Text("\(task.progress.percentComplete)%")

                if let speed = task.progress.formattedSpeed {
                    Text(speed)
                }

                HStack {
                    Button("Pause") { task.pause() }
                    Button("Cancel") { task.cancel() }
                }
            }
        } else {
            Button("Download Model") {
                Task {
                    downloadTask = await ModelManager.shared.downloadTask(for: .llama3_2_1b)
                }
            }
        }
    }
}
```

## Cache Management

Manage locally stored models:

```swift
let manager = ModelManager.shared

// Check if a model is cached
if await manager.isCached(.llama3_2_1b) {
    print("Model ready")
}

// Get local path
if let path = await manager.localPath(for: .llama3_2_1b) {
    print("Model at: \(path)")
}

// List all cached models
let cached = try await manager.cachedModels()
for model in cached {
    print("\(model.identifier.displayName): \(model.size.formatted)")
}

// Total cache size
let size = await manager.cacheSize()
print("Cache size: \(size.formatted)")
```

### Eviction and Cleanup

```swift
// Evict least-recently-used models to fit a storage limit
try await manager.evictToFit(maxSize: .gigabytes(30))

// Remove a specific model
try await manager.delete(.llama3_2_1b)

// Clear the entire cache
try await manager.clearCache()
```

### Storage Paths

Models are stored under the user's cache directory:

- MLX models: `~/Library/Caches/Conduit/Models/mlx/`
- HuggingFace models: `~/Library/Caches/Conduit/Models/huggingface/`

## ModelRegistry

`ModelRegistry` provides metadata about known models:

```swift
// All known models
let allModels = ModelRegistry.allModels

// Filter by provider
let mlxModels = ModelRegistry.models(for: .mlx)
let cloudModels = ModelRegistry.models(for: .huggingFace)

// Filter by capability
let embeddingModels = ModelRegistry.models(with: .embeddings)
let reasoningModels = ModelRegistry.models(with: .reasoning)

// Get recommended models
let recommended = ModelRegistry.recommendedModels()

// Look up model info
if let info = ModelRegistry.info(for: .llama3_2_1b) {
    print("Name: \(info.name)")
    print("Context: \(info.contextWindow) tokens")
    print("Disk: \(info.diskSize?.formatted ?? "N/A")")
    print("Capabilities: \(info.capabilities)")
}
```

### Model Capabilities

`ModelCapability` defines what a model can do:

- `.textGeneration` — Standard text output
- `.embeddings` — Vector embeddings
- `.transcription` — Audio-to-text
- `.codeGeneration` — Code-optimized
- `.reasoning` — Enhanced reasoning
- `.multimodal` — Vision and other modalities
