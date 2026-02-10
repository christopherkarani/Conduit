# Model Management

Download, cache, and manage local models for MLX inference. Control storage usage and optimize for your deployment needs.

## Table of Contents

- [Overview](#overview)
- [Checking Cached Models](#checking-cached-models)
- [Downloading Models](#downloading-models)
- [Cache Management](#cache-management)
- [Storage Locations](#storage-locations)
- [SwiftUI Integration](#swiftui-integration)
- [Best Practices](#best-practices)

---

## Overview

Model management applies to local inference providers (primarily MLX). Cloud providers don't require model downloads.

The `ModelManager` handles:

- **Discovery**: Check which models are available
- **Downloading**: Fetch models from HuggingFace
- **Caching**: Store models locally for fast access
- **Cleanup**: Remove unused models to free space

---

## Checking Cached Models

### Is Model Cached?

```swift
let manager = ModelManager.shared

// Check specific model
if await manager.isCached(.llama3_2_1B) {
    print("Model ready to use")
} else {
    print("Model needs to be downloaded")
}
```

### List All Cached Models

```swift
let cached = await manager.cachedModels()

for model in cached {
    print("Model: \(model.name)")
    print("Size: \(model.size.formatted())")
    print("Path: \(model.path)")
}
```

### Check Before Generation

```swift
let model = ModelIdentifier.llama3_2_1B

if await manager.isCached(model) {
    let response = try await provider.generate(prompt, model: model)
} else {
    // Download first
    try await manager.download(model)
    let response = try await provider.generate(prompt, model: model)
}
```

---

## Downloading Models

### Basic Download

```swift
let manager = ModelManager.shared

let modelPath = try await manager.download(.llama3_2_1B)
print("Downloaded to: \(modelPath)")
```

### With Progress Tracking

```swift
let modelPath = try await manager.download(.llama3_2_1B) { progress in
    print("Progress: \(Int(progress.percentComplete))%")
    print("Downloaded: \(progress.bytesDownloaded.formatted())")
    print("Total: \(progress.totalBytes.formatted())")
    print("Speed: \(progress.bytesPerSecond.formatted())/s")
    print("ETA: \(progress.estimatedTimeRemaining?.formatted() ?? "calculating...")")
}
```

### Download Task API

For more control and SwiftUI integration:

```swift
let task = manager.download(.llama3_2_3B)

// Observe progress
for await progress in task.progress {
    updateUI(progress)
}

// Get result
let path = try await task.result
```

### Cancel Download

```swift
let task = manager.download(.llama3_2_3B)

// Cancel if needed
task.cancel()
```

---

## Cache Management

### Cache Size

```swift
let size = await manager.cacheSize()
print("Total cache: \(size.formatted())")
// e.g., "12.5 GB"
```

### Remove Specific Model

```swift
try await manager.remove(.llama3_2_1B)
```

### Clear All Cache

```swift
try await manager.clearCache()
```

### Evict to Fit Size

Keep cache under a specific size (removes oldest models first):

```swift
// Keep cache under 10 GB
try await manager.evictToFit(maxSize: .gigabytes(10))
```

### Evict Least Recently Used

```swift
// Remove models not used in 30 days
try await manager.evictOlderThan(days: 30)
```

---

## Storage Locations

### Default Location

Models are stored at:

```
~/Library/Caches/Conduit/Models/
```

### Custom Location

```swift
let customPath = URL.documentsDirectory.appending(path: "Models")
let manager = ModelManager(cacheDirectory: customPath)
```

### Model Structure

Each model is stored as a directory:

```
~/Library/Caches/Conduit/Models/
├── mlx-community--Llama-3.2-1B-Instruct-4bit/
│   ├── config.json
│   ├── model.safetensors
│   ├── tokenizer.json
│   └── ...
├── mlx-community--Phi-4-4bit/
│   └── ...
```

---

## SwiftUI Integration

### Download View

```swift
struct ModelDownloadView: View {
    @State private var progress: DownloadProgress?
    @State private var isDownloading = false
    @State private var error: Error?

    let model: ModelIdentifier

    var body: some View {
        VStack(spacing: 16) {
            if let progress {
                ProgressView(value: progress.percentComplete / 100)

                Text("\(Int(progress.percentComplete))%")
                    .font(.headline)

                Text("\(progress.bytesDownloaded.formatted()) / \(progress.totalBytes.formatted())")
                    .font(.caption)

                if let eta = progress.estimatedTimeRemaining {
                    Text("ETA: \(eta.formatted())")
                        .font(.caption)
                }
            }

            if let error {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
            }

            Button(isDownloading ? "Downloading..." : "Download") {
                Task { await download() }
            }
            .disabled(isDownloading)
        }
        .padding()
    }

    func download() async {
        isDownloading = true
        error = nil

        do {
            _ = try await ModelManager.shared.download(model) { prog in
                Task { @MainActor in
                    self.progress = prog
                }
            }
        } catch {
            self.error = error
        }

        isDownloading = false
    }
}
```

### Model List View

```swift
struct ModelListView: View {
    @State private var cachedModels: [CachedModelInfo] = []
    @State private var cacheSize: ByteCount = .zero

    var body: some View {
        List {
            Section("Cache: \(cacheSize.formatted())") {
                ForEach(cachedModels, id: \.name) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.name)
                                .font(.headline)
                            Text(model.size.formatted())
                                .font(.caption)
                        }

                        Spacer()

                        Button("Delete") {
                            Task { await delete(model) }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .task {
            await refresh()
        }
    }

    func refresh() async {
        cachedModels = await ModelManager.shared.cachedModels()
        cacheSize = await ModelManager.shared.cacheSize()
    }

    func delete(_ model: CachedModelInfo) async {
        try? await ModelManager.shared.remove(model.identifier)
        await refresh()
    }
}
```

### Storage Settings View

```swift
struct StorageSettingsView: View {
    @State private var cacheSize: ByteCount = .zero
    @State private var maxCacheSize: Double = 20 // GB

    var body: some View {
        Form {
            Section("Model Cache") {
                LabeledContent("Current Size", value: cacheSize.formatted())

                Slider(value: $maxCacheSize, in: 5...50, step: 5) {
                    Text("Max Cache Size")
                }

                Text("\(Int(maxCacheSize)) GB limit")
                    .font(.caption)
            }

            Section {
                Button("Clear Cache") {
                    Task { await clearCache() }
                }
                .foregroundStyle(.red)

                Button("Optimize Storage") {
                    Task { await optimize() }
                }
            }
        }
        .task {
            cacheSize = await ModelManager.shared.cacheSize()
        }
    }

    func clearCache() async {
        try? await ModelManager.shared.clearCache()
        cacheSize = await ModelManager.shared.cacheSize()
    }

    func optimize() async {
        try? await ModelManager.shared.evictToFit(
            maxSize: .gigabytes(Int(maxCacheSize))
        )
        cacheSize = await ModelManager.shared.cacheSize()
    }
}
```

---

## Best Practices

### 1. Check Before Download

```swift
// Avoid redundant downloads
if await !manager.isCached(model) {
    try await manager.download(model)
}
```

### 2. Handle Download Errors

```swift
do {
    try await manager.download(model)
} catch AIError.networkError(let error) {
    print("Network issue: \(error)")
} catch AIError.insufficientDiskSpace(let required, let available) {
    print("Need \(required.formatted()), have \(available.formatted())")
} catch AIError.downloadFailed(let error) {
    print("Download failed: \(error)")
}
```

### 3. Provide User Feedback

```swift
// Always show progress for large downloads
try await manager.download(model) { progress in
    // Update UI
    DispatchQueue.main.async {
        self.downloadProgress = progress.percentComplete
        self.downloadSpeed = progress.bytesPerSecond.formatted() + "/s"
    }
}
```

### 4. Manage Storage Proactively

```swift
// Check available space before download
let modelSize = ByteCount.gigabytes(2)  // Approximate
let available = getAvailableDiskSpace()

if available < modelSize * 2 {  // Want 2x buffer
    // Prompt user to free space or evict models
    try await manager.evictToFit(maxSize: .gigabytes(5))
}
```

### 5. Background Downloads on iOS

```swift
// Request background time for downloads
UIApplication.shared.beginBackgroundTask {
    // Handle expiration
}

try await manager.download(model) { progress in
    // Track progress
}

UIApplication.shared.endBackgroundTask(taskId)
```

### 6. Pre-download in App Setup

```swift
// Download essential models during onboarding
func setupModels() async {
    let essentialModels: [ModelIdentifier] = [.llama3_2_1B]

    for model in essentialModels {
        if await !ModelManager.shared.isCached(model) {
            try? await ModelManager.shared.download(model)
        }
    }
}
```

---

## Model Size Reference

| Model | Approximate Size |
|-------|------------------|
| Llama 3.2 1B | ~1 GB |
| Llama 3.2 3B | ~2 GB |
| Phi-4 | ~8 GB |
| Qwen 2.5 3B | ~2 GB |
| Mistral 7B | ~5 GB |
| Llama 3.1 8B | ~6 GB |

---

## Next Steps

- [MLX Provider](Providers/MLX.md) - Use downloaded models
- [Error Handling](ErrorHandling.md) - Handle download errors
- [ChatSession](ChatSession.md) - Build conversations with local models
