# SwiftAI HuggingFace Integration Guide

> **Comprehensive guide for integrating SwiftAI's HuggingFace functionality into a chat application**
>
> Covers model discovery, downloading, cache management, streaming chat responses, and SwiftUI integration patterns.

---

## Table of Contents

1. [Introduction & Prerequisites](#1-introduction--prerequisites)
2. [Authentication Setup](#2-authentication-setup)
3. [Model Discovery & Browsing](#3-model-discovery--browsing)
4. [Model Details View](#4-model-details-view)
5. [Model Download Interface](#5-model-download-interface)
6. [Cache Management](#6-cache-management)
7. [Streaming Chat Responses](#7-streaming-chat-responses)
8. [Cloud vs Local Inference Selection](#8-cloud-vs-local-inference-selection)
9. [Error Handling](#9-error-handling)
10. [Additional Capabilities](#10-additional-capabilities)
11. [Best Practices & Anti-Patterns](#11-best-practices--anti-patterns)
12. [Complete Example: Chat Application](#12-complete-example-chat-application)
13. [API Quick Reference](#13-api-quick-reference)

---

## 1. Introduction & Prerequisites

### 1.1 Document Overview

This guide provides a comprehensive integration reference for using SwiftAI's HuggingFace functionality in a chat application. SwiftAI is a unified Swift SDK for LLM inference that provides:

- **Cloud inference** via HuggingFace Inference API
- **Local inference** via MLX on Apple Silicon
- **Model management** for downloading, caching, and organizing models
- **Streaming responses** via modern Swift concurrency patterns

### 1.2 Prerequisites

| Requirement | Minimum Version |
|-------------|-----------------|
| Swift | 6.2+ |
| iOS | 17.0+ |
| macOS | 14.0+ |
| visionOS | 1.0+ |
| Xcode | 16.0+ |

### 1.3 Package Setup

Add SwiftAI to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/christopherkarani/SwiftAI", branch: "main")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter the repository URL.

### 1.4 Import

```swift
import SwiftAI
```

### 1.5 HuggingFace Account Setup

1. Create an account at [huggingface.co](https://huggingface.co)
2. Navigate to **Settings > Access Tokens**
3. Create a new token with **Read** access (or **Write** for private models)
4. Copy the token (starts with `hf_`)

---

## 2. Authentication Setup

SwiftAI provides flexible token management through `HFTokenProvider` with four strategies.

### 2.1 Token Provider Options

#### Option 1: Environment Variables (Development)

The simplest approach for development. SwiftAI auto-detects tokens from environment variables.

```swift
// Automatically reads HF_TOKEN or HUGGING_FACE_HUB_TOKEN from environment
let provider = HuggingFaceProvider()

// Explicitly specify auto-detection
let provider = HuggingFaceProvider(
    configuration: HFConfiguration.default.token(.auto)
)
```

Set the environment variable in Xcode:
- **Edit Scheme > Run > Arguments > Environment Variables**
- Add `HF_TOKEN` with your token value

#### Option 2: Static Token (Testing Only)

For quick testing. **Never commit tokens to source control.**

```swift
let provider = HuggingFaceProvider(token: "hf_your_token_here")

// Or via configuration
let config = HFConfiguration.default.token(.static("hf_your_token_here"))
let provider = HuggingFaceProvider(configuration: config)
```

#### Option 3: Keychain Storage (Production)

The recommended approach for production apps. Tokens are stored securely in the system Keychain.

```swift
// Store token in Keychain (do this once, e.g., after user login)
func storeToken(_ token: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.myapp.chat",
        kSecAttrAccount as String: "hf-api-token",
        kSecValueData as String: token.data(using: .utf8)!
    ]

    // Delete existing item first
    SecItemDelete(query as CFDictionary)

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.unableToStore
    }
}

// Configure provider to read from Keychain
let config = HFConfiguration.default.token(
    .keychain(service: "com.myapp.chat", account: "hf-api-token")
)
let provider = HuggingFaceProvider(configuration: config)
```

#### Option 4: No Authentication (Public Models Only)

For accessing public models without authentication.

```swift
let config = HFConfiguration.default.token(.none)
let provider = HuggingFaceProvider(configuration: config)
```

### 2.2 Configuration Options

`HFConfiguration` provides a fluent API for customizing provider behavior.

```swift
let config = HFConfiguration.default
    .token(.keychain(service: "com.myapp", account: "hf-token"))
    .timeout(120)           // 2 minutes for large models
    .maxRetries(5)          // Retry up to 5 times on transient failures
    .retryBaseDelay(2.0)    // Start with 2s delay (exponential backoff)

let provider = HuggingFaceProvider(configuration: config)
```

#### Configuration Presets

| Preset | Timeout | Retries | Use Case |
|--------|---------|---------|----------|
| `.default` | 60s | 3 | Standard inference |
| `.longRunning` | 120s | 3 | Large models, slow networks |
| `.endpoint(url)` | 60s | 3 | Custom/private deployments |

```swift
// For slow models or poor network conditions
let config = HFConfiguration.longRunning
    .token(.auto)
    .maxRetries(10)

// For private HuggingFace endpoint
let config = HFConfiguration.endpoint(
    url: URL(string: "https://my-endpoint.huggingface.cloud")!
).token(.static("hf_private_token"))
```

### 2.3 Checking Provider Availability

Always verify the provider is properly configured before making requests.

```swift
let provider = HuggingFaceProvider()

// Simple boolean check
if await provider.isAvailable {
    // Ready to make requests
}

// Detailed availability status
let status = await provider.availabilityStatus
switch status {
case .available:
    print("Provider ready")
case .unavailable(let reason):
    switch reason {
    case .apiKeyMissing:
        showTokenConfigurationUI()
    case .networkUnavailable:
        showOfflineMessage()
    default:
        showError("Provider unavailable: \(reason)")
    }
}
```

### 2.4 UI Integration: Token Status View

```swift
struct TokenStatusView: View {
    let provider: HuggingFaceProvider
    @State private var status: ProviderAvailability = .unavailable(.unknown)

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task {
            status = await provider.availabilityStatus
        }
    }

    private var statusColor: Color {
        switch status {
        case .available: return .green
        case .unavailable: return .red
        }
    }

    private var statusText: String {
        switch status {
        case .available: return "Connected to HuggingFace"
        case .unavailable(.apiKeyMissing): return "API Token Required"
        case .unavailable(.networkUnavailable): return "Network Unavailable"
        case .unavailable: return "Unavailable"
        }
    }
}
```

---

## 3. Model Discovery & Browsing

SwiftAI provides two approaches for discovering HuggingFace models:
1. **Curated list** via `ModelRegistry` - Pre-tested, known-good models
2. **Dynamic search** via `HFMetadataService` - Search the entire HuggingFace Hub

### 3.1 Curated Models (ModelRegistry)

`ModelRegistry` contains pre-configured models with verified compatibility.

#### Get All HuggingFace Models

```swift
// All HuggingFace cloud models
let hfModels = ModelRegistry.models(for: .huggingFace)

// Print available models
for model in hfModels {
    print("\(model.name): \(model.description)")
    print("  Size: \(model.size.displayName)")
    print("  Context: \(model.contextWindow) tokens")
    print("  Capabilities: \(model.capabilities)")
}
```

#### Filter by Capability

```swift
// Text generation models (chat, completion)
let chatModels = ModelRegistry.models(with: .textGeneration)
    .filter { $0.identifier.provider == .huggingFace }

// Embedding models (for RAG, semantic search)
let embeddingModels = ModelRegistry.models(with: .embeddings)
    .filter { $0.identifier.provider == .huggingFace }

// Transcription models (speech-to-text)
let transcriptionModels = ModelRegistry.models(with: .transcription)
    .filter { $0.identifier.provider == .huggingFace }

// Models with multiple capabilities
let multiCapable = ModelRegistry.allModels.filter { model in
    model.capabilities.contains(.textGeneration) &&
    model.capabilities.contains(.codeGeneration)
}
```

#### Get Recommended Models

```swift
// Recommended models (curated for quality/performance)
let recommended = ModelRegistry.recommendedModels()
    .filter { $0.identifier.provider == .huggingFace }
```

#### ModelInfo Properties

| Property | Type | Description |
|----------|------|-------------|
| `identifier` | `ModelIdentifier` | Unique model ID |
| `name` | `String` | Display name |
| `description` | `String` | Model description |
| `size` | `ModelSize` | small/medium/large/xlarge |
| `diskSize` | `ByteCount?` | Download size |
| `contextWindow` | `Int` | Max context tokens |
| `capabilities` | `Set<ModelCapability>` | Supported tasks |
| `isRecommended` | `Bool` | Curated recommendation |
| `parameters` | `String?` | Parameter count (e.g., "8B") |
| `quantization` | `String?` | Quantization format |

### 3.2 Dynamic HuggingFace Hub Search

For discovering models beyond the curated list, use `HFMetadataService`.

#### Fetch Model Details

```swift
// Fetch details for any HuggingFace model
let details = await HFMetadataService.shared.fetchModelDetails(
    repoId: "meta-llama/Llama-3.1-70B-Instruct"
)

if let info = details {
    print("Model: \(info.modelId)")
    print("Downloads: \(info.downloads ?? 0)")
    print("Likes: \(info.likes ?? 0)")
    print("License: \(info.license ?? "unknown")")
    print("Author: \(info.author ?? "unknown")")
    print("Pipeline: \(info.pipelineTag ?? "unknown")")
    print("Is VLM: \(info.isVLM)")  // Vision-Language Model detection
    print("Tags: \(info.tags.joined(separator: ", "))")
}
```

#### Fetch Repository File Tree

```swift
// Get list of files in a model repository
let files = await HFMetadataService.shared.fetchFileTree(
    repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit"
)

if let fileList = files {
    for file in fileList {
        print("\(file.path): \(file.effectiveSize) bytes")
    }
}
```

#### Estimate Download Size

```swift
// Estimate total download size for specific file patterns
let size = await HFMetadataService.shared.estimateTotalSize(
    repoId: "mlx-community/Llama-3.2-1B-Instruct-4bit",
    patterns: HFMetadataService.mlxFilePatterns  // ["*.safetensors", "*.json", ...]
)

if let bytes = size {
    let formatted = ByteCount(bytes).formatted
    print("Estimated download: \(formatted)")
}
```

### 3.3 UI Integration: Model Browser

```swift
@Observable
class ModelBrowserViewModel {
    var models: [ModelInfo] = []
    var searchText: String = ""
    var selectedCapability: ModelCapability? = nil
    var isLoading = false

    var filteredModels: [ModelInfo] {
        var result = models

        if let capability = selectedCapability {
            result = result.filter { $0.capabilities.contains(capability) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    func loadModels() {
        models = ModelRegistry.models(for: .huggingFace)
    }
}

struct ModelBrowserView: View {
    @State private var viewModel = ModelBrowserViewModel()
    @State private var selectedModel: ModelInfo?

    var body: some View {
        NavigationStack {
            List(viewModel.filteredModels) { model in
                ModelRowView(model: model)
                    .onTapGesture {
                        selectedModel = model
                    }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search models")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    CapabilityFilterMenu(selection: $viewModel.selectedCapability)
                }
            }
            .sheet(item: $selectedModel) { model in
                ModelDetailView(modelInfo: model)
            }
            .task {
                viewModel.loadModels()
            }
            .navigationTitle("HuggingFace Models")
        }
    }
}

struct ModelRowView: View {
    let model: ModelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.name)
                    .font(.headline)

                if model.isRecommended {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }

                Spacer()

                Text(model.size.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(model.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                if let params = model.parameters {
                    Label(params, systemImage: "cpu")
                }
                Label("\(model.contextWindow) ctx", systemImage: "text.alignleft")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct CapabilityFilterMenu: View {
    @Binding var selection: ModelCapability?

    var body: some View {
        Menu {
            Button("All Models") { selection = nil }
            Divider()
            ForEach(ModelCapability.allCases, id: \.self) { capability in
                Button {
                    selection = capability
                } label: {
                    if selection == capability {
                        Label(capability.displayName, systemImage: "checkmark")
                    } else {
                        Text(capability.displayName)
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}
```

---

## 4. Model Details View

Display comprehensive model information combining local `ModelInfo` and remote HuggingFace Hub data.

### 4.1 Model Information Sources

| Source | Data | Availability |
|--------|------|--------------|
| `ModelInfo` | name, size, capabilities, context | Always (local) |
| `HFMetadataService.ModelDetails` | downloads, likes, license, author | Requires network |
| `HFMetadataService.fetchFileTree` | File list, sizes | Requires network |

### 4.2 UI Integration: Model Detail View

```swift
@Observable
class ModelDetailViewModel {
    let modelInfo: ModelInfo
    var hubDetails: HFMetadataService.ModelDetails?
    var estimatedSize: ByteCount?
    var isCached: Bool = false
    var isLoading = false
    var error: Error?

    init(modelInfo: ModelInfo) {
        self.modelInfo = modelInfo
    }

    func loadDetails() async {
        isLoading = true
        defer { isLoading = false }

        // Check cache status
        isCached = await ModelManager.shared.isCached(modelInfo.identifier)

        // Fetch HuggingFace Hub details
        guard case .huggingFace(let repoId) = modelInfo.identifier else { return }

        hubDetails = await HFMetadataService.shared.fetchModelDetails(repoId: repoId)

        // Estimate download size if not cached
        if !isCached {
            if let bytes = await HFMetadataService.shared.estimateTotalSize(
                repoId: repoId,
                patterns: HFMetadataService.mlxFilePatterns
            ) {
                estimatedSize = ByteCount(bytes)
            }
        }
    }
}

struct ModelDetailView: View {
    @State private var viewModel: ModelDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(modelInfo: ModelInfo) {
        _viewModel = State(initialValue: ModelDetailViewModel(modelInfo: modelInfo))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Information
                Section("Overview") {
                    LabeledContent("Name", value: viewModel.modelInfo.name)
                    LabeledContent("Size Category", value: viewModel.modelInfo.size.displayName)

                    if let params = viewModel.modelInfo.parameters {
                        LabeledContent("Parameters", value: params)
                    }

                    LabeledContent("Context Window") {
                        Text("\(viewModel.modelInfo.contextWindow.formatted()) tokens")
                    }

                    if let quant = viewModel.modelInfo.quantization {
                        LabeledContent("Quantization", value: quant)
                    }
                }

                // Capabilities
                Section("Capabilities") {
                    ForEach(Array(viewModel.modelInfo.capabilities).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { capability in
                        Label {
                            Text(capability.displayName)
                        } icon: {
                            Image(systemName: iconForCapability(capability))
                                .foregroundStyle(colorForCapability(capability))
                        }
                    }
                }

                // HuggingFace Hub Stats
                if let details = viewModel.hubDetails {
                    Section("HuggingFace Hub") {
                        if let downloads = details.downloads {
                            LabeledContent("Downloads", value: downloads.formatted())
                        }

                        if let likes = details.likes {
                            LabeledContent("Likes", value: likes.formatted())
                        }

                        if let license = details.license {
                            LabeledContent("License", value: license)
                        }

                        if let author = details.author {
                            LabeledContent("Author", value: author)
                        }

                        if let pipeline = details.pipelineTag {
                            LabeledContent("Pipeline", value: pipeline)
                        }

                        if details.isVLM {
                            Label("Vision-Language Model", systemImage: "eye")
                                .foregroundStyle(.purple)
                        }
                    }
                }

                // Storage Information
                Section("Storage") {
                    if viewModel.isCached {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        if let size = viewModel.modelInfo.diskSize {
                            LabeledContent("Size on Disk", value: size.formatted)
                        }
                    } else {
                        Label("Not Downloaded", systemImage: "arrow.down.circle")
                            .foregroundStyle(.secondary)

                        if let size = viewModel.estimatedSize {
                            LabeledContent("Estimated Size", value: size.formatted)
                        }
                    }
                }

                // Description
                Section("Description") {
                    Text(viewModel.modelInfo.description)
                        .font(.body)
                }
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadDetails()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func iconForCapability(_ capability: ModelCapability) -> String {
        switch capability {
        case .textGeneration: return "text.bubble"
        case .embeddings: return "point.3.connected.trianglepath.dotted"
        case .transcription: return "waveform"
        case .codeGeneration: return "chevron.left.forwardslash.chevron.right"
        case .reasoning: return "brain"
        case .multimodal: return "photo.stack"
        }
    }

    private func colorForCapability(_ capability: ModelCapability) -> Color {
        switch capability {
        case .textGeneration: return .blue
        case .embeddings: return .purple
        case .transcription: return .orange
        case .codeGeneration: return .green
        case .reasoning: return .pink
        case .multimodal: return .indigo
        }
    }
}
```

---

## 5. Model Download Interface

SwiftAI provides comprehensive model download capabilities through `ModelManager`.

### 5.1 Download Methods Overview

| Method | Use Case | Returns |
|--------|----------|---------|
| `download(_:progress:)` | Basic download with callback | `URL` |
| `downloadWithEstimation(_:progress:)` | Download with pre-fetched size | `URL` |
| `downloadTask(for:)` | Observable task for SwiftUI | `DownloadTask` |
| `downloadValidated(_:)` | Download with MLX compatibility check | `URL` |

### 5.2 Basic Download with Progress

```swift
// Simple download with progress callback
do {
    let modelPath = try await ModelManager.shared.download(
        .huggingFace("mlx-community/Llama-3.2-1B-Instruct-4bit")
    ) { progress in
        print("Downloaded: \(progress.percentComplete)%")

        if let speed = progress.formattedSpeed {
            print("Speed: \(speed)")
        }

        if let eta = progress.formattedETA {
            print("ETA: \(eta)")
        }

        if let file = progress.currentFile {
            print("Downloading: \(file)")
        }
    }

    print("Model saved to: \(modelPath)")
} catch {
    print("Download failed: \(error)")
}
```

### 5.3 Download with Size Estimation

For accurate progress tracking, pre-fetch the total size before downloading.

```swift
// Download with accurate total size
let modelPath = try await ModelManager.shared.downloadWithEstimation(
    .huggingFace("mlx-community/Llama-3.2-1B-Instruct-4bit")
) { progress in
    // progress.totalBytes is now accurate
    let downloaded = ByteCount(progress.bytesDownloaded).formatted
    let total = progress.totalBytes.map { ByteCount($0).formatted } ?? "Unknown"

    print("\(downloaded) / \(total) (\(progress.percentComplete)%)")
}
```

### 5.4 Observable DownloadTask for SwiftUI

`DownloadTask` is `@Observable` and designed for SwiftUI integration.

```swift
@Observable
class DownloadViewModel {
    var downloadTask: DownloadTask?
    var error: Error?

    func startDownload(model: ModelIdentifier) async {
        error = nil
        downloadTask = await ModelManager.shared.downloadTask(for: model)

        // Optionally wait for completion
        do {
            let url = try await downloadTask?.result()
            print("Downloaded to: \(url?.path ?? "unknown")")
        } catch {
            self.error = error
        }
    }

    func cancel() {
        downloadTask?.cancel()
    }

    func pause() {
        downloadTask?.pause()
    }

    func resume() {
        downloadTask?.resume()
    }
}
```

### 5.5 DownloadProgress Properties

```swift
public struct DownloadProgress: Sendable, Equatable {
    // Byte counts
    public var bytesDownloaded: Int64         // Bytes transferred
    public var totalBytes: Int64?             // Total size (if known)

    // File progress
    public var currentFile: String?           // Current file name
    public var filesCompleted: Int            // Files done
    public var totalFiles: Int                // Total file count

    // Derived metrics
    public var fractionCompleted: Double      // 0.0 to 1.0
    public var percentComplete: Int           // 0 to 100

    // Speed and timing
    public var bytesPerSecond: Double?        // Transfer speed
    public var estimatedTimeRemaining: TimeInterval?  // ETA in seconds

    // Formatted strings (for display)
    public var formattedSpeed: String?        // "5.00 MB/s"
    public var formattedETA: String?          // "2m 30s"
}
```

### 5.6 DownloadState Enum

```swift
public enum DownloadState: Sendable {
    case pending               // Created, not started
    case downloading           // Actively transferring
    case paused               // Temporarily suspended
    case completed(URL)        // Successfully finished
    case failed(Error)         // Encountered error
    case cancelled            // User cancelled

    // Computed properties
    var isActive: Bool         // true for pending/downloading/paused
    var isTerminal: Bool       // true for completed/failed/cancelled
}
```

### 5.7 Cancel Active Downloads

```swift
// Cancel a specific download
await ModelManager.shared.cancelDownload(.huggingFace("model/id"))

// Or via the DownloadTask
downloadTask?.cancel()
```

### 5.8 UI Integration: Download Progress View

```swift
struct ModelDownloadView: View {
    let model: ModelIdentifier
    @State private var viewModel = DownloadViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if let task = viewModel.downloadTask {
                // Progress indicator
                VStack(spacing: 8) {
                    ProgressView(value: task.progress.fractionCompleted)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(task.progress.percentComplete)%")
                            .font(.headline)
                            .monospacedDigit()

                        Spacer()

                        if let speed = task.progress.formattedSpeed {
                            Text(speed)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let eta = task.progress.formattedETA {
                        Text("Estimated time remaining: \(eta)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let file = task.progress.currentFile {
                        Text("Downloading: \(file)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Control buttons
                HStack(spacing: 16) {
                    switch task.state {
                    case .pending:
                        ProgressView()
                            .controlSize(.small)
                        Text("Starting...")

                    case .downloading:
                        Button("Pause") {
                            viewModel.pause()
                        }
                        .buttonStyle(.bordered)

                        Button("Cancel", role: .destructive) {
                            viewModel.cancel()
                        }
                        .buttonStyle(.bordered)

                    case .paused:
                        Button("Resume") {
                            viewModel.resume()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Cancel", role: .destructive) {
                            viewModel.cancel()
                        }
                        .buttonStyle(.bordered)

                    case .completed(let url):
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title)
                        Text("Download Complete")
                            .foregroundStyle(.green)

                    case .failed(let error):
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.title)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.red)

                            Button("Retry") {
                                Task { await viewModel.startDownload(model: model) }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                    case .cancelled:
                        Text("Download Cancelled")
                            .foregroundStyle(.secondary)

                        Button("Restart") {
                            Task { await viewModel.startDownload(model: model) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                // Initial state - show download button
                Button {
                    Task { await viewModel.startDownload(model: model) }
                } label: {
                    Label("Download Model", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }
}
```

### 5.9 Download Multiple Models

```swift
@Observable
class BatchDownloadViewModel {
    var tasks: [ModelIdentifier: DownloadTask] = [:]

    func downloadModels(_ models: [ModelIdentifier]) async {
        for model in models {
            let task = await ModelManager.shared.downloadTask(for: model)
            tasks[model] = task
        }
    }

    var overallProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let total = tasks.values.reduce(0.0) { $0 + $1.progress.fractionCompleted }
        return total / Double(tasks.count)
    }
}
```

---

## 6. Cache Management

SwiftAI stores downloaded models in a local cache. Per your requirements, this implementation uses **manual deletion only** (no automatic eviction).

### 6.1 Cache Location

Models are stored in the user's cache directory:
```
~/Library/Caches/SwiftAI/Models/
├── cache-metadata.json          # Metadata persistence
├── mlx/                         # MLX local models
│   └── {repo-name}/
└── huggingface/                 # HuggingFace models
    └── {repo-name}/
```

### 6.2 Query Operations

#### Check if Model is Cached

```swift
let isCached = await ModelManager.shared.isCached(
    .huggingFace("mlx-community/Llama-3.2-1B-Instruct-4bit")
)

if isCached {
    print("Model is available locally")
}
```

#### Get Local Path

```swift
if let path = await ModelManager.shared.localPath(for: .llama3_2_1B) {
    print("Model at: \(path.path)")
}
```

#### List All Cached Models

```swift
let cachedModels = try await ModelManager.shared.cachedModels()

for model in cachedModels {
    print("Model: \(model.identifier.displayName)")
    print("  Size: \(model.size.formatted)")
    print("  Downloaded: \(model.downloadedAt)")
    print("  Last used: \(model.lastAccessedAt)")
    print("  Path: \(model.path.path)")
}
```

#### Get Total Cache Size

```swift
let totalSize = await ModelManager.shared.cacheSize()
print("Total cache: \(totalSize.formatted)")
```

### 6.3 CachedModelInfo Properties

```swift
public struct CachedModelInfo: Sendable, Identifiable, Codable {
    public let identifier: ModelIdentifier  // Model ID
    public let path: URL                    // Local file path
    public let size: ByteCount              // Size on disk
    public let downloadedAt: Date           // Download timestamp
    public let lastAccessedAt: Date         // Last use timestamp
    public let revision: String?            // Git revision/commit
}
```

### 6.4 Manual Deletion

#### Delete Specific Model

```swift
// Delete a single model (user-initiated)
try await ModelManager.shared.delete(
    .huggingFace("mlx-community/Llama-3.2-1B-Instruct-4bit")
)
```

#### Clear Entire Cache

```swift
// Clear all cached models (with user confirmation!)
try await ModelManager.shared.clearCache()
```

### 6.5 Mark Model as Accessed

Update the last-accessed timestamp for LRU tracking (useful if you implement manual cleanup suggestions).

```swift
await ModelManager.shared.markAccessed(.llama3_2_1B)
```

### 6.6 UI Integration: Cache Management View

```swift
@Observable
class CacheManagementViewModel {
    var cachedModels: [CachedModelInfo] = []
    var totalSize: ByteCount = ByteCount(0)
    var isLoading = false
    var error: Error?

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            cachedModels = try await ModelManager.shared.cachedModels()
            totalSize = await ModelManager.shared.cacheSize()
        } catch {
            self.error = error
        }
    }

    func deleteModel(_ model: CachedModelInfo) async {
        do {
            try await ModelManager.shared.delete(model.identifier)
            await refresh()
        } catch {
            self.error = error
        }
    }

    func clearAll() async {
        do {
            try await ModelManager.shared.clearCache()
            await refresh()
        } catch {
            self.error = error
        }
    }
}

struct CacheManagementView: View {
    @State private var viewModel = CacheManagementViewModel()
    @State private var showClearConfirmation = false
    @State private var modelToDelete: CachedModelInfo?

    var body: some View {
        List {
            // Summary section
            Section {
                HStack {
                    Label("Total Cache Size", systemImage: "externaldrive")
                    Spacer()
                    Text(viewModel.totalSize.formatted)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Models Downloaded", systemImage: "square.stack.3d.up")
                    Spacer()
                    Text("\(viewModel.cachedModels.count)")
                        .foregroundStyle(.secondary)
                }
            }

            // Downloaded models
            Section("Downloaded Models") {
                if viewModel.cachedModels.isEmpty {
                    ContentUnavailableView(
                        "No Downloaded Models",
                        systemImage: "arrow.down.circle.dotted",
                        description: Text("Download models to use them offline")
                    )
                } else {
                    ForEach(viewModel.cachedModels) { model in
                        CachedModelRow(model: model) {
                            modelToDelete = model
                        }
                    }
                }
            }

            // Danger zone
            if !viewModel.cachedModels.isEmpty {
                Section {
                    Button("Clear All Cached Models", role: .destructive) {
                        showClearConfirmation = true
                    }
                } footer: {
                    Text("This will delete all downloaded models. You can re-download them later.")
                }
            }
        }
        .navigationTitle("Storage")
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.refresh()
        }
        .confirmationDialog(
            "Delete Model?",
            isPresented: .init(
                get: { modelToDelete != nil },
                set: { if !$0 { modelToDelete = nil } }
            ),
            presenting: modelToDelete
        ) { model in
            Button("Delete \(model.identifier.displayName)", role: .destructive) {
                Task {
                    await viewModel.deleteModel(model)
                }
            }
        } message: { model in
            Text("This will free up \(model.size.formatted) of storage.")
        }
        .confirmationDialog(
            "Clear All Models?",
            isPresented: $showClearConfirmation
        ) {
            Button("Delete All Models", role: .destructive) {
                Task {
                    await viewModel.clearAll()
                }
            }
        } message: {
            Text("This will delete \(viewModel.cachedModels.count) models and free up \(viewModel.totalSize.formatted).")
        }
    }
}

struct CachedModelRow: View {
    let model: CachedModelInfo
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.identifier.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(model.size.formatted)
                    Text("•")
                    Text("Used \(model.lastAccessedAt, style: .relative) ago")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
```

---

## 7. Streaming Chat Responses

SwiftAI provides modern AsyncSequence-based streaming for real-time response display.

### 7.1 Basic Text Streaming

```swift
let provider = HuggingFaceProvider()

// Stream text chunks directly
let stream = provider.stream(
    "Explain quantum computing in simple terms",
    model: .huggingFace("meta-llama/Llama-3.1-70B-Instruct"),
    config: .default
)

// Iterate through text chunks
for try await text in stream {
    print(text, terminator: "")  // Prints incrementally
}
print() // Final newline
```

### 7.2 Streaming with Message History

```swift
// Build conversation messages
let messages: [Message] = [
    .system("You are a helpful assistant."),
    .user("What is Swift?"),
    .assistant("Swift is a programming language developed by Apple..."),
    .user("How does it compare to Rust?")
]

// Stream with conversation context
let stream = provider.stream(
    messages: messages,
    model: .huggingFace("meta-llama/Llama-3.1-70B-Instruct"),
    config: .default
)

for try await text in stream {
    print(text, terminator: "")
}
```

### 7.3 Streaming with Full Metadata

Get rich metadata for each chunk including token counts and performance metrics.

```swift
let stream = provider.streamWithMetadata(
    messages: messages,
    model: .huggingFace("meta-llama/Llama-3.1-70B-Instruct"),
    config: .default
)

for try await chunk in stream {
    // Text content
    print(chunk.text, terminator: "")

    // Metadata
    if let speed = chunk.tokensPerSecond {
        // Update UI with current speed
    }

    // Completion detection
    if chunk.isComplete {
        print("\n--- Generation complete ---")
        print("Finish reason: \(chunk.finishReason?.rawValue ?? "unknown")")
        print("Total tokens: \(chunk.tokenCount)")
    }
}
```

### 7.4 GenerationChunk Properties

```swift
public struct GenerationChunk: Sendable, Hashable {
    public let text: String                   // Generated text
    public let tokenCount: Int                // Cumulative token count
    public let tokenId: Int?                  // Token ID (if available)
    public let logprob: Float?                // Log probability
    public let topLogprobs: [TokenLogprob]?   // Top alternatives
    public let tokensPerSecond: Double?       // Generation speed
    public let isComplete: Bool               // Is this the final chunk?
    public let finishReason: FinishReason?    // Why generation stopped
    public let timestamp: Date                // Chunk timestamp
}
```

### 7.5 GenerationStream Conveniences

Wrap the raw stream in `GenerationStream` for additional convenience methods.

```swift
let rawStream = provider.stream(messages: messages, model: model, config: config)
let stream = GenerationStream(rawStream)

// Access text-only stream
for try await text in stream.text {
    print(text, terminator: "")
}

// Collect all text at once
let fullText = try await stream.collect()
print(fullText)

// Collect with metadata
let result = try await stream.collectWithMetadata()
print("Generated \(result.tokenCount) tokens in \(result.generationTime)s")
print("Speed: \(result.tokensPerSecond) tokens/sec")
print("Finish reason: \(result.finishReason)")

// Measure time to first token (TTFT)
if let (firstChunk, latency) = try await stream.timeToFirstToken() {
    print("TTFT: \(latency)s")
    print("First token: \(firstChunk.text)")
}
```

### 7.6 Cancellation

Cancel in-flight generation when the user stops or navigates away.

```swift
// Via provider
await provider.cancelGeneration()

// Via Task cancellation
let task = Task {
    for try await chunk in stream {
        if Task.isCancelled { break }
        process(chunk)
    }
}

// Later...
task.cancel()
```

### 7.7 Generation Configuration

```swift
// Precise responses (lower temperature)
let config = GenerateConfig.precise
    .maxTokens(1000)
    .stopSequences(["Human:", "User:"])

// Creative responses (higher temperature)
let config = GenerateConfig.creative
    .temperature(0.9)
    .topP(0.95)

// Code generation
let config = GenerateConfig.code
    .maxTokens(2000)
    .stopSequences(["```"])

// Custom configuration
let config = GenerateConfig.default
    .temperature(0.7)
    .topP(0.9)
    .maxTokens(500)
    .stopSequences(["END"])
    .frequencyPenalty(0.5)
    .presencePenalty(0.5)
```

### 7.8 UI Integration: Chat View with Streaming

```swift
@Observable
class ChatViewModel {
    var messages: [Message] = []
    var streamingResponse: String = ""
    var isGenerating = false
    var tokensPerSecond: Double = 0
    var error: AIError?

    let selectedModel: ModelIdentifier = .huggingFace("meta-llama/Llama-3.1-70B-Instruct")
    private let provider = HuggingFaceProvider()
    private var currentTask: Task<Void, Never>?

    func send(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add user message
        messages.append(.user(text))

        // Start generation
        isGenerating = true
        streamingResponse = ""
        error = nil

        currentTask = Task {
            defer {
                isGenerating = false
                currentTask = nil
            }

            do {
                let stream = provider.streamWithMetadata(
                    messages: messages,
                    model: selectedModel,
                    config: .default
                )

                for try await chunk in stream {
                    // Check for cancellation
                    if Task.isCancelled { break }

                    // Append text
                    streamingResponse += chunk.text

                    // Update speed
                    if let speed = chunk.tokensPerSecond {
                        tokensPerSecond = speed
                    }

                    // Handle completion
                    if chunk.isComplete {
                        messages.append(.assistant(streamingResponse))
                        streamingResponse = ""
                    }
                }
            } catch let aiError as AIError {
                self.error = aiError
                // Remove failed user message
                if messages.last?.role == .user {
                    messages.removeLast()
                }
            } catch {
                self.error = AIError.generation(error)
            }
        }
    }

    func stop() {
        currentTask?.cancel()

        // Keep partial response if any
        if !streamingResponse.isEmpty {
            messages.append(.assistant(streamingResponse + " [stopped]"))
            streamingResponse = ""
        }
    }

    func clear() {
        stop()
        messages.removeAll()
        error = nil
    }
}

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { index, message in
                            MessageBubbleView(message: message)
                                .id(index)
                        }

                        // Streaming response
                        if viewModel.isGenerating && !viewModel.streamingResponse.isEmpty {
                            StreamingBubbleView(
                                text: viewModel.streamingResponse,
                                tokensPerSecond: viewModel.tokensPerSecond
                            )
                            .id("streaming")
                        }

                        // Error display
                        if let error = viewModel.error {
                            ErrorBubbleView(error: error) {
                                // Retry last message
                                if let lastUserMessage = viewModel.messages.last(where: { $0.role == .user }) {
                                    viewModel.send(lastUserMessage.content.text ?? "")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.streamingResponse) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }

                if viewModel.isGenerating {
                    Button {
                        viewModel.stop()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                } else {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear") {
                    viewModel.clear()
                }
                .disabled(viewModel.messages.isEmpty && !viewModel.isGenerating)
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        viewModel.send(text)
    }
}

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            Text(message.content.text ?? "")
                .padding(12)
                .background(message.role == .user ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role != .user { Spacer() }
        }
    }
}

struct StreamingBubbleView: View {
    let text: String
    let tokensPerSecond: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .padding(12)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("\(String(format: "%.1f", tokensPerSecond)) tok/s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

struct ErrorBubbleView: View {
    let error: AIError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error.errorDescription ?? "An error occurred")
            }
            .font(.caption)

            if error.isRetryable {
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## 8. Cloud vs Local Inference Selection

SwiftAI requires explicit provider and model selection. Users must choose between cloud (HuggingFace) and local (MLX) inference.

### 8.1 Understanding the Difference

| Aspect | Cloud (HuggingFace) | Local (MLX) |
|--------|---------------------|-------------|
| Provider | `HuggingFaceProvider` | `MLXProvider` |
| Model ID | `.huggingFace("org/model")` | `.mlx("org/model")` |
| Requires | Internet, API token | Downloaded model |
| Latency | Higher (network) | Lower (local) |
| Privacy | Data sent to cloud | Data stays on device |
| Cost | API usage costs | Free after download |

### 8.2 Model Identifier Validation

Each provider validates that it receives the correct model type:

```swift
// HuggingFaceProvider only accepts .huggingFace() models
let hfProvider = HuggingFaceProvider()
try await hfProvider.generate(
    "Hello",
    model: .huggingFace("meta-llama/Llama-3.1-70B-Instruct"),  // OK
    config: .default
)

try await hfProvider.generate(
    "Hello",
    model: .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit"),  // Throws AIError.invalidInput
    config: .default
)

// MLXProvider only accepts .mlx() models
let mlxProvider = MLXProvider()
try await mlxProvider.generate(
    "Hello",
    model: .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit"),  // OK
    config: .default
)
```

### 8.3 Inference Mode Manager

```swift
enum InferenceMode: String, CaseIterable, Identifiable {
    case cloud = "Cloud"
    case local = "Local"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cloud: return "cloud"
        case .local: return "laptopcomputer"
        }
    }

    var description: String {
        switch self {
        case .cloud: return "Use HuggingFace cloud models"
        case .local: return "Use downloaded MLX models"
        }
    }
}

@Observable
class InferenceManager {
    var mode: InferenceMode = .cloud
    var cloudModel: ModelIdentifier = .huggingFace("meta-llama/Llama-3.1-70B-Instruct")
    var localModel: ModelIdentifier = .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")

    private let hfProvider = HuggingFaceProvider()
    private let mlxProvider = MLXProvider()

    var currentModel: ModelIdentifier {
        switch mode {
        case .cloud: return cloudModel
        case .local: return localModel
        }
    }

    func generate(messages: [Message], config: GenerateConfig) async throws -> String {
        switch mode {
        case .cloud:
            return try await hfProvider.generate(
                messages: messages,
                model: cloudModel,
                config: config
            ).text

        case .local:
            // Ensure model is downloaded
            let isCached = await ModelManager.shared.isCached(localModel)
            guard isCached else {
                throw AIError.invalidInput("Model not downloaded. Please download the model first.")
            }

            return try await mlxProvider.generate(
                messages: messages,
                model: localModel,
                config: config
            ).text
        }
    }

    func stream(messages: [Message], config: GenerateConfig) -> AsyncThrowingStream<String, Error> {
        switch mode {
        case .cloud:
            return hfProvider.stream(
                messages: messages,
                model: cloudModel,
                config: config
            )

        case .local:
            return mlxProvider.stream(
                messages: messages,
                model: localModel,
                config: config
            )
        }
    }

    func checkAvailability() async -> Bool {
        switch mode {
        case .cloud:
            return await hfProvider.isAvailable
        case .local:
            return await ModelManager.shared.isCached(localModel)
        }
    }
}
```

### 8.4 UI Integration: Mode Selection

```swift
struct InferenceModeSelector: View {
    @Bindable var manager: InferenceManager
    @State private var isLocalAvailable = false

    var body: some View {
        VStack(spacing: 16) {
            // Mode picker
            Picker("Inference Mode", selection: $manager.mode) {
                ForEach(InferenceMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Mode-specific options
            switch manager.mode {
            case .cloud:
                CloudModelPicker(selection: $manager.cloudModel)

            case .local:
                LocalModelPicker(
                    selection: $manager.localModel,
                    isAvailable: $isLocalAvailable
                )

                if !isLocalAvailable {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Model not downloaded")
                            .font(.caption)
                    }
                }
            }
        }
        .task {
            isLocalAvailable = await ModelManager.shared.isCached(manager.localModel)
        }
        .onChange(of: manager.localModel) {
            Task {
                isLocalAvailable = await ModelManager.shared.isCached(manager.localModel)
            }
        }
    }
}

struct CloudModelPicker: View {
    @Binding var selection: ModelIdentifier

    private let cloudModels = ModelRegistry.models(for: .huggingFace)
        .filter { $0.capabilities.contains(.textGeneration) }

    var body: some View {
        Picker("Cloud Model", selection: $selection) {
            ForEach(cloudModels) { model in
                Text(model.name)
                    .tag(model.identifier)
            }
        }
    }
}

struct LocalModelPicker: View {
    @Binding var selection: ModelIdentifier
    @Binding var isAvailable: Bool
    @State private var cachedModels: [CachedModelInfo] = []

    var body: some View {
        Picker("Local Model", selection: $selection) {
            ForEach(cachedModels) { model in
                HStack {
                    Text(model.identifier.displayName)
                    if model.identifier == selection {
                        Image(systemName: "checkmark")
                    }
                }
                .tag(model.identifier)
            }

            if cachedModels.isEmpty {
                Text("No models downloaded")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            cachedModels = (try? await ModelManager.shared.cachedModels()) ?? []
            if let first = cachedModels.first {
                selection = first.identifier
                isAvailable = true
            }
        }
    }
}
```

---

## 9. Error Handling

SwiftAI provides comprehensive error handling through the `AIError` type.

### 9.1 AIError Categories

```swift
public enum AIError: Error {
    // Provider errors
    case providerUnavailable(ProviderUnavailableReason)
    case authenticationFailed(String)

    // Generation errors
    case generationFailed(String)
    case tokenLimitExceeded(limit: Int, requested: Int)
    case contentFiltered(String)
    case cancelled
    case timeout

    // Network errors
    case networkError(Error)
    case serverError(statusCode: Int, message: String)
    case rateLimited(retryAfter: TimeInterval?)

    // Resource errors
    case insufficientMemory(required: ByteCount, available: ByteCount)
    case downloadFailed(String)
    case fileError(String)

    // Input errors
    case invalidInput(String)
    case unsupportedAudioFormat(String)
}
```

### 9.2 Error Properties

```swift
extension AIError {
    // User-friendly message
    var errorDescription: String? { ... }

    // Actionable suggestion
    var recoverySuggestion: String? { ... }

    // Can this error be retried?
    var isRetryable: Bool { ... }

    // Error category for UI grouping
    var category: AIErrorCategory { ... }
}

public enum AIErrorCategory {
    case provider
    case generation
    case network
    case resource
    case input
}
```

### 9.3 Error Handling Pattern

```swift
func handleGeneration() async {
    do {
        let response = try await provider.generate(
            messages: messages,
            model: selectedModel,
            config: .default
        )
        // Handle success
        displayResponse(response.text)

    } catch let error as AIError {
        // Handle based on category
        switch error.category {
        case .provider:
            handleProviderError(error)
        case .generation:
            handleGenerationError(error)
        case .network:
            handleNetworkError(error)
        case .resource:
            handleResourceError(error)
        case .input:
            handleInputError(error)
        }
    } catch {
        // Handle unexpected errors
        showAlert(title: "Error", message: error.localizedDescription)
    }
}

private func handleProviderError(_ error: AIError) {
    switch error {
    case .authenticationFailed:
        showTokenConfigurationSheet()
    case .providerUnavailable(let reason):
        switch reason {
        case .modelDownloading:
            showModelLoadingIndicator()
        case .networkUnavailable:
            showOfflineMessage()
        default:
            showAlert(title: "Provider Unavailable", message: error.errorDescription ?? "")
        }
    default:
        break
    }
}

private func handleNetworkError(_ error: AIError) {
    if error.isRetryable {
        showRetryDialog(error: error)
    } else if case .rateLimited(let retryAfter) = error {
        scheduleRetry(after: retryAfter ?? 60)
        showRateLimitMessage(retryAfter: retryAfter)
    } else {
        showAlert(title: "Network Error", message: error.errorDescription ?? "")
    }
}

private func handleGenerationError(_ error: AIError) {
    switch error {
    case .cancelled:
        // User cancelled, no action needed
        break
    case .contentFiltered(let reason):
        showContentFilteredAlert(reason: reason)
    case .tokenLimitExceeded(let limit, let requested):
        showTokenLimitAlert(limit: limit, requested: requested)
    default:
        showAlert(title: "Generation Failed", message: error.errorDescription ?? "")
    }
}
```

### 9.4 Automatic Retry Logic

```swift
func generateWithRetry(
    maxAttempts: Int = 3,
    baseDelay: TimeInterval = 1.0
) async throws -> GenerationResult {
    var lastError: Error?

    for attempt in 0..<maxAttempts {
        do {
            return try await provider.generate(
                messages: messages,
                model: selectedModel,
                config: .default
            )
        } catch let error as AIError {
            lastError = error

            // Don't retry non-retryable errors
            guard error.isRetryable else {
                throw error
            }

            // Handle rate limiting specifically
            if case .rateLimited(let retryAfter) = error {
                let delay = retryAfter ?? (baseDelay * pow(2, Double(attempt)))
                try await Task.sleep(for: .seconds(delay))
                continue
            }

            // Exponential backoff for other retryable errors
            let delay = baseDelay * pow(2, Double(attempt))
            try await Task.sleep(for: .seconds(delay))
        }
    }

    throw lastError ?? AIError.generationFailed("Max retry attempts exceeded")
}
```

### 9.5 UI Integration: Error Display

```swift
struct ErrorDisplayView: View {
    let error: AIError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: iconForCategory(error.category))
                .font(.system(size: 48))
                .foregroundStyle(colorForCategory(error.category))

            // Title
            Text(titleForCategory(error.category))
                .font(.headline)

            // Description
            Text(error.errorDescription ?? "An unexpected error occurred")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            // Recovery suggestion
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Actions
            HStack(spacing: 12) {
                if error.isRetryable, let retry = onRetry {
                    Button("Retry", action: retry)
                        .buttonStyle(.borderedProminent)
                }

                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
    }

    private func iconForCategory(_ category: AIErrorCategory) -> String {
        switch category {
        case .provider: return "server.rack"
        case .generation: return "text.bubble"
        case .network: return "wifi.exclamationmark"
        case .resource: return "externaldrive.badge.exclamationmark"
        case .input: return "exclamationmark.triangle"
        }
    }

    private func colorForCategory(_ category: AIErrorCategory) -> Color {
        switch category {
        case .provider: return .purple
        case .generation: return .orange
        case .network: return .red
        case .resource: return .yellow
        case .input: return .blue
        }
    }

    private func titleForCategory(_ category: AIErrorCategory) -> String {
        switch category {
        case .provider: return "Provider Error"
        case .generation: return "Generation Failed"
        case .network: return "Network Error"
        case .resource: return "Resource Error"
        case .input: return "Invalid Input"
        }
    }
}
```

---

## 10. Additional Capabilities

Beyond text generation, SwiftAI's HuggingFace provider supports embeddings and audio transcription.

### 10.1 Embeddings Generation

Embeddings convert text into numerical vectors for semantic search, RAG, and similarity comparisons.

#### Single Embedding

```swift
let provider = HuggingFaceProvider()

let result = try await provider.embed(
    "SwiftAI is a unified inference framework for Swift",
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)

print("Dimensions: \(result.dimensions)")
print("Vector: \(result.vector.prefix(5))...")  // First 5 values
```

#### Batch Embeddings

```swift
let texts = [
    "How do I use SwiftUI?",
    "What is Swift concurrency?",
    "Explain async/await in Swift"
]

let embeddings = try await provider.embedBatch(
    texts,
    model: .huggingFace("sentence-transformers/all-MiniLM-L6-v2")
)

for (text, embedding) in zip(texts, embeddings) {
    print("\(text): \(embedding.dimensions) dimensions")
}
```

#### Semantic Search Example

```swift
import Accelerate  // For cosine similarity

func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    var dot: Float = 0
    var normA: Float = 0
    var normB: Float = 0

    vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
    vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
    vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))

    return dot / (sqrt(normA) * sqrt(normB))
}

// Search for similar documents
func searchSimilar(query: String, documents: [String]) async throws -> [(String, Float)] {
    let provider = HuggingFaceProvider()
    let model: ModelIdentifier = .huggingFace("sentence-transformers/all-MiniLM-L6-v2")

    // Embed query and documents
    let queryEmbedding = try await provider.embed(query, model: model)
    let docEmbeddings = try await provider.embedBatch(documents, model: model)

    // Calculate similarities
    let similarities = docEmbeddings.map { doc in
        cosineSimilarity(queryEmbedding.vector, doc.vector)
    }

    // Sort by similarity
    return zip(documents, similarities)
        .sorted { $0.1 > $1.1 }
}
```

### 10.2 Audio Transcription

Convert speech to text using Whisper models.

#### Basic Transcription

```swift
let provider = HuggingFaceProvider()

let result = try await provider.transcribe(
    audioURL: audioFileURL,
    model: .huggingFace("openai/whisper-large-v3"),
    config: TranscriptionConfig()
)

print("Transcription: \(result.text)")
print("Duration: \(result.duration)s")
```

#### Transcription with Configuration

```swift
let config = TranscriptionConfig(
    language: "en",           // ISO 639-1 language code
    wordTimestamps: true,     // Include word-level timing
    translate: false,         // Don't translate to English
    format: .detailed         // Include segments
)

let result = try await provider.transcribe(
    audioURL: audioFileURL,
    model: .whisperLargeV3,
    config: config
)

// Access segments
for segment in result.segments {
    print("[\(formatTime(segment.startTime)) - \(formatTime(segment.endTime))]")
    print(segment.text)
}
```

#### Transcription from Audio Data

```swift
// Transcribe from in-memory audio data
let audioData: Data = ...  // Audio file data

let result = try await provider.transcribe(
    audioData: audioData,
    model: .whisperLargeV3,
    config: TranscriptionConfig(language: "en")
)
```

### 10.3 TranscriptionConfig Properties

| Property | Type | Description |
|----------|------|-------------|
| `language` | `String?` | ISO 639-1 code (e.g., "en", "es") |
| `wordTimestamps` | `Bool` | Include word-level timing |
| `translate` | `Bool` | Translate to English |
| `format` | `TranscriptionFormat` | .text, .detailed, .srt, .vtt |
| `vadSensitivity` | `Float?` | Voice activity detection (0.0-1.0) |
| `initialPrompt` | `String?` | Context/guidance for transcription |
| `temperature` | `Float?` | Sampling temperature |

### 10.4 UI Integration: Transcription View

```swift
@Observable
class TranscriptionViewModel {
    var isRecording = false
    var isTranscribing = false
    var transcription: String = ""
    var segments: [TranscriptionSegment] = []
    var error: Error?

    private let provider = HuggingFaceProvider()

    func transcribe(audioURL: URL) async {
        isTranscribing = true
        error = nil

        defer { isTranscribing = false }

        do {
            let result = try await provider.transcribe(
                audioURL: audioURL,
                model: .whisperLargeV3,
                config: TranscriptionConfig(
                    language: "en",
                    wordTimestamps: true,
                    format: .detailed
                )
            )

            transcription = result.text
            segments = result.segments
        } catch {
            self.error = error
        }
    }
}

struct TranscriptionView: View {
    @State private var viewModel = TranscriptionViewModel()
    let audioURL: URL

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isTranscribing {
                ProgressView("Transcribing...")
            } else if !viewModel.transcription.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transcription")
                            .font(.headline)

                        Text(viewModel.transcription)
                            .font(.body)

                        if !viewModel.segments.isEmpty {
                            Divider()

                            Text("Segments")
                                .font(.headline)

                            ForEach(viewModel.segments, id: \.startTime) { segment in
                                HStack(alignment: .top) {
                                    Text(formatTimeRange(segment.startTime, segment.endTime))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)

                                    Text(segment.text)
                                        .font(.body)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Button("Transcribe Audio") {
                    Task {
                        await viewModel.transcribe(audioURL: audioURL)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private func formatTimeRange(_ start: TimeInterval, _ end: TimeInterval) -> String {
        let startStr = String(format: "%02d:%05.2f", Int(start) / 60, start.truncatingRemainder(dividingBy: 60))
        let endStr = String(format: "%02d:%05.2f", Int(end) / 60, end.truncatingRemainder(dividingBy: 60))
        return "\(startStr) - \(endStr)"
    }
}
```

---

## 11. Best Practices & Anti-Patterns

### 11.1 Do's (Recommended Practices)

#### Check Provider Availability

```swift
// Always check before making requests
if await provider.isAvailable {
    let response = try await provider.generate(...)
} else {
    showConfigurationRequired()
}
```

#### Use Size Estimation for Downloads

```swift
// Get accurate progress by pre-fetching size
let url = try await ModelManager.shared.downloadWithEstimation(model) { progress in
    // progress.totalBytes is accurate
    updateProgressUI(progress)
}
```

#### Cancel Generation on Navigation

```swift
struct ChatView: View {
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        // ...
    }
    .onDisappear {
        generationTask?.cancel()
    }
}
```

#### Store Tokens Securely

```swift
// Production: Use Keychain
let config = HFConfiguration.default.token(
    .keychain(service: "com.myapp", account: "hf-token")
)

// Never hardcode tokens in source
// let token = "hf_..." // DON'T DO THIS
```

#### Handle Retryable Errors

```swift
if error.isRetryable {
    showRetryButton {
        Task { await retryLastRequest() }
    }
}
```

#### Reuse Provider Instances

```swift
// Good: Single shared instance
class AppServices {
    static let hfProvider = HuggingFaceProvider()
}

// Bad: Creating new instances repeatedly
func generate() async {
    let provider = HuggingFaceProvider()  // Wasteful
    // ...
}
```

### 11.2 Don'ts (Anti-Patterns)

#### Don't Hardcode Tokens

```swift
// WRONG: Token in source code
let provider = HuggingFaceProvider(token: "hf_abc123...")

// RIGHT: Use environment or Keychain
let provider = HuggingFaceProvider()  // Uses HF_TOKEN env var
```

#### Don't Assume Network Availability

```swift
// WRONG: Assume cloud is always available
let response = try await provider.generate(...)

// RIGHT: Check availability first
guard await provider.isAvailable else {
    showOfflineMessage()
    return
}
```

#### Don't Ignore Finish Reasons

```swift
// WRONG: Ignore why generation stopped
for try await chunk in stream {
    text += chunk.text
}

// RIGHT: Handle finish reasons appropriately
for try await chunk in stream {
    text += chunk.text
    if chunk.isComplete {
        switch chunk.finishReason {
        case .maxTokens:
            showTruncationWarning()
        case .contentFilter:
            showContentFilteredMessage()
        default:
            break
        }
    }
}
```

#### Don't Block the UI Thread

```swift
// WRONG: Synchronous call (blocks UI)
let result = await provider.generate(...)  // On main thread

// RIGHT: Use Task or background context
Task {
    let result = try await provider.generate(...)
    await MainActor.run {
        updateUI(result)
    }
}
```

#### Don't Create Multiple Provider Instances

```swift
// WRONG: New instance per request
func chat(_ message: String) async {
    let provider = HuggingFaceProvider()  // Memory waste
    // ...
}

// RIGHT: Reuse single instance
private let provider = HuggingFaceProvider()

func chat(_ message: String) async {
    // Use shared provider
}
```

### 11.3 Performance Tips

```swift
// Use appropriate configuration presets
let config = GenerateConfig.precise    // Factual responses
let config = GenerateConfig.creative   // Creative tasks
let config = GenerateConfig.code       // Code generation

// Limit token count for faster responses
let config = GenerateConfig.default.maxTokens(500)

// Use streaming for perceived performance
let stream = provider.stream(messages: messages, model: model, config: config)
// Users see output immediately, even if total generation time is same
```

---

## 12. Complete Example: Chat Application

Here's a complete, production-ready chat implementation combining all the concepts.

### 12.1 Data Models

```swift
import SwiftUI
import SwiftAI

// MARK: - Chat Session

@Observable
final class ChatSession: Identifiable {
    let id = UUID()
    var title: String = "New Chat"
    var messages: [Message] = []
    var createdAt = Date()
    var updatedAt = Date()

    // Infer title from first message
    func updateTitle() {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let text = firstUserMessage.content.text ?? ""
            title = String(text.prefix(50)) + (text.count > 50 ? "..." : "")
        }
    }
}

// MARK: - App Settings

@Observable
final class ChatSettings {
    var inferenceMode: InferenceMode = .cloud
    var cloudModel: ModelIdentifier = .huggingFace("meta-llama/Llama-3.1-70B-Instruct")
    var localModel: ModelIdentifier = .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")
    var temperature: Double = 0.7
    var maxTokens: Int = 1000
    var systemPrompt: String = "You are a helpful assistant."

    var currentModel: ModelIdentifier {
        switch inferenceMode {
        case .cloud: return cloudModel
        case .local: return localModel
        }
    }

    var generationConfig: GenerateConfig {
        GenerateConfig.default
            .temperature(Float(temperature))
            .maxTokens(maxTokens)
    }
}
```

### 12.2 Chat View Model

```swift
@Observable
final class ChatViewModel {
    // State
    var sessions: [ChatSession] = []
    var currentSession: ChatSession?
    var streamingResponse: String = ""
    var isGenerating = false
    var tokensPerSecond: Double = 0
    var error: AIError?

    // Dependencies
    let settings: ChatSettings
    private let hfProvider = HuggingFaceProvider()
    private let mlxProvider = MLXProvider()
    private var currentTask: Task<Void, Never>?

    init(settings: ChatSettings) {
        self.settings = settings
    }

    // MARK: - Session Management

    func createSession() {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        currentSession = session
    }

    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id {
            currentSession = sessions.first
        }
    }

    // MARK: - Message Sending

    func send(_ text: String) {
        guard let session = currentSession else {
            createSession()
            send(text)
            return
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add system prompt if first message
        if session.messages.isEmpty && !settings.systemPrompt.isEmpty {
            session.messages.append(.system(settings.systemPrompt))
        }

        // Add user message
        session.messages.append(.user(text))
        session.updateTitle()
        session.updatedAt = Date()

        // Start generation
        isGenerating = true
        streamingResponse = ""
        error = nil

        currentTask = Task {
            await generateResponse(for: session)
        }
    }

    private func generateResponse(for session: ChatSession) async {
        defer {
            isGenerating = false
            currentTask = nil
        }

        do {
            // Validate availability
            let isAvailable = await checkAvailability()
            guard isAvailable else {
                throw AIError.providerUnavailable(.unknown)
            }

            // Get stream based on mode
            let stream = getStream(for: session.messages)

            for try await text in stream {
                if Task.isCancelled { break }
                streamingResponse += text
            }

            // Add complete response
            if !streamingResponse.isEmpty {
                session.messages.append(.assistant(streamingResponse))
                session.updatedAt = Date()
                streamingResponse = ""
            }

        } catch let aiError as AIError {
            self.error = aiError
            // Remove failed user message
            if session.messages.last?.role == .user {
                session.messages.removeLast()
            }
        } catch {
            self.error = AIError.generation(error)
        }
    }

    private func getStream(for messages: [Message]) -> AsyncThrowingStream<String, Error> {
        switch settings.inferenceMode {
        case .cloud:
            return hfProvider.stream(
                messages: messages,
                model: settings.cloudModel,
                config: settings.generationConfig
            )
        case .local:
            return mlxProvider.stream(
                messages: messages,
                model: settings.localModel,
                config: settings.generationConfig
            )
        }
    }

    private func checkAvailability() async -> Bool {
        switch settings.inferenceMode {
        case .cloud:
            return await hfProvider.isAvailable
        case .local:
            return await ModelManager.shared.isCached(settings.localModel)
        }
    }

    // MARK: - Control

    func stop() {
        currentTask?.cancel()

        if !streamingResponse.isEmpty, let session = currentSession {
            session.messages.append(.assistant(streamingResponse + " [stopped]"))
            streamingResponse = ""
        }
    }

    func regenerate() {
        guard let session = currentSession,
              let lastUserMessage = session.messages.last(where: { $0.role == .user }),
              let text = lastUserMessage.content.text else { return }

        // Remove last assistant message if present
        if session.messages.last?.role == .assistant {
            session.messages.removeLast()
        }
        // Remove the user message too (it will be re-added)
        if session.messages.last?.role == .user {
            session.messages.removeLast()
        }

        send(text)
    }

    func clearError() {
        error = nil
    }
}
```

### 12.3 Main Chat View

```swift
struct MainChatView: View {
    @State private var settings = ChatSettings()
    @State private var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var showSettings = false
    @State private var showModelBrowser = false
    @FocusState private var isInputFocused: Bool

    init() {
        let settings = ChatSettings()
        _settings = State(initialValue: settings)
        _viewModel = State(initialValue: ChatViewModel(settings: settings))
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar: Session list
            SessionListView(viewModel: viewModel)
        } detail: {
            // Main: Chat interface
            VStack(spacing: 0) {
                // Messages
                MessageListView(
                    viewModel: viewModel,
                    onRegenerate: { viewModel.regenerate() }
                )

                Divider()

                // Input
                ChatInputView(
                    text: $inputText,
                    isGenerating: viewModel.isGenerating,
                    onSend: {
                        viewModel.send(inputText)
                        inputText = ""
                    },
                    onStop: { viewModel.stop() }
                )
            }
            .navigationTitle(viewModel.currentSession?.title ?? "SwiftAI Chat")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showModelBrowser = true
                        } label: {
                            Label("Browse Models", systemImage: "square.stack.3d.up")
                        }

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showModelBrowser) {
            ModelBrowserView()
        }
    }
}

// MARK: - Session List

struct SessionListView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        List(selection: Binding(
            get: { viewModel.currentSession?.id },
            set: { id in
                viewModel.currentSession = viewModel.sessions.first { $0.id == id }
            }
        )) {
            ForEach(viewModel.sessions) { session in
                NavigationLink(value: session.id) {
                    VStack(alignment: .leading) {
                        Text(session.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(session.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteSession(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.createSession()
                } label: {
                    Label("New Chat", systemImage: "plus")
                }
            }
        }
    }
}

// MARK: - Message List

struct MessageListView: View {
    @Bindable var viewModel: ChatViewModel
    let onRegenerate: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let session = viewModel.currentSession {
                        ForEach(Array(session.messages.enumerated()), id: \.offset) { index, message in
                            if message.role != .system {
                                ChatMessageView(message: message)
                                    .id(index)
                            }
                        }
                    }

                    // Streaming response
                    if viewModel.isGenerating && !viewModel.streamingResponse.isEmpty {
                        StreamingMessageView(
                            text: viewModel.streamingResponse,
                            speed: viewModel.tokensPerSecond
                        )
                        .id("streaming")
                    }

                    // Error
                    if let error = viewModel.error {
                        ErrorMessageView(error: error) {
                            onRegenerate()
                        } onDismiss: {
                            viewModel.clearError()
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.streamingResponse) {
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Chat Input

struct ChatInputView: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                if isGenerating {
                    onStop()
                } else {
                    onSend()
                }
            } label: {
                Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(isGenerating ? .red : .blue)
            }
            .disabled(!isGenerating && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}
```

### 12.4 Settings View

```swift
struct SettingsView: View {
    @Bindable var settings: ChatSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Inference Mode") {
                    Picker("Mode", selection: $settings.inferenceMode) {
                        ForEach(InferenceMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Model") {
                    switch settings.inferenceMode {
                    case .cloud:
                        CloudModelPickerSection(selection: $settings.cloudModel)
                    case .local:
                        LocalModelPickerSection(selection: $settings.localModel)
                    }
                }

                Section("Generation") {
                    VStack(alignment: .leading) {
                        Text("Temperature: \(settings.temperature, specifier: "%.1f")")
                        Slider(value: $settings.temperature, in: 0...2, step: 0.1)
                    }

                    Stepper("Max Tokens: \(settings.maxTokens)", value: $settings.maxTokens, in: 100...4000, step: 100)
                }

                Section("System Prompt") {
                    TextEditor(text: $settings.systemPrompt)
                        .frame(minHeight: 100)
                }

                Section {
                    NavigationLink("Manage Downloaded Models") {
                        CacheManagementView()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

---

## 13. API Quick Reference

### Providers

```swift
// HuggingFace cloud provider
let hfProvider = HuggingFaceProvider()
let hfProvider = HuggingFaceProvider(token: "hf_...")
let hfProvider = HuggingFaceProvider(configuration: HFConfiguration.default)

// MLX local provider
let mlxProvider = MLXProvider()
```

### Generation

```swift
// Non-streaming
let result = try await provider.generate("prompt", model: .llama3_1_70B, config: .default)
let result = try await provider.generate(messages: messages, model: model, config: config)

// Streaming
for try await text in provider.stream("prompt", model: model, config: config) { }
for try await chunk in provider.streamWithMetadata(messages: messages, model: model, config: config) { }
```

### Model Management

```swift
// Download
let url = try await ModelManager.shared.download(model) { progress in }
let url = try await ModelManager.shared.downloadWithEstimation(model) { progress in }
let task = await ModelManager.shared.downloadTask(for: model)

// Cache
let cached = try await ModelManager.shared.cachedModels()
let isCached = await ModelManager.shared.isCached(model)
let path = await ModelManager.shared.localPath(for: model)
let size = await ModelManager.shared.cacheSize()

// Delete
try await ModelManager.shared.delete(model)
try await ModelManager.shared.clearCache()
```

### Model Discovery

```swift
// Curated models
let models = ModelRegistry.models(for: .huggingFace)
let textModels = ModelRegistry.models(with: .textGeneration)
let recommended = ModelRegistry.recommendedModels()

// Hub search
let details = await HFMetadataService.shared.fetchModelDetails(repoId: "org/model")
let files = await HFMetadataService.shared.fetchFileTree(repoId: "org/model")
let size = await HFMetadataService.shared.estimateTotalSize(repoId: "org/model", patterns: [...])
```

### Embeddings & Transcription

```swift
// Embeddings
let embedding = try await provider.embed("text", model: embeddingModel)
let embeddings = try await provider.embedBatch(["text1", "text2"], model: embeddingModel)

// Transcription
let result = try await provider.transcribe(audioURL: url, model: .whisperLargeV3, config: config)
let result = try await provider.transcribe(audioData: data, model: model, config: config)
```

---

## Appendix: File References

| Component | Path |
|-----------|------|
| HuggingFace Provider | `Sources/SwiftAI/Providers/HuggingFace/HuggingFaceProvider.swift` |
| HF Configuration | `Sources/SwiftAI/Providers/HuggingFace/HFConfiguration.swift` |
| HF Token Provider | `Sources/SwiftAI/Providers/HuggingFace/HFTokenProvider.swift` |
| Model Manager | `Sources/SwiftAI/ModelManagement/ModelManager.swift` |
| Model Cache | `Sources/SwiftAI/ModelManagement/ModelCache.swift` |
| Download Progress | `Sources/SwiftAI/ModelManagement/DownloadProgress.swift` |
| Model Registry | `Sources/SwiftAI/ModelManagement/ModelRegistry.swift` |
| HF Metadata Service | `Sources/SwiftAI/Services/HFMetadataService.swift` |
| Generation Stream | `Sources/SwiftAI/Core/Streaming/GenerationStream.swift` |
| Generation Chunk | `Sources/SwiftAI/Core/Streaming/GenerationChunk.swift` |
| AI Error | `Sources/SwiftAI/Core/Errors/AIError.swift` |
| Message Types | `Sources/SwiftAI/Core/Types/Message.swift` |
| Model Identifier | `Sources/SwiftAI/Core/Types/ModelIdentifier.swift` |

---

*Document generated for SwiftAI integration. For the latest API documentation, refer to the SwiftAI source code and inline documentation.*
