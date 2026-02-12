// LinuxCompatibilityTests.swift
// Conduit
//
// Tests to verify Linux compatibility for Conduit.
// These tests focus on cross-platform functionality.
//
// Note: Tests avoid network calls on Linux CI because FoundationNetworking
// uses try! internally which crashes on network errors (libcurl error 43).

import Foundation
import Testing
@testable import Conduit

@Generable
private struct SchemaCompatibilityType {
    let name: String
    let age: Int?
}

// MARK: - Linux Compatibility Tests

@Suite("Linux Compatibility")
struct LinuxCompatibilityTests {

    // MARK: - Helpers

    /// Returns true if running in CI environment (GitHub Actions sets CI=true)
    private var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] == "true" ||
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
    }

    // MARK: - Cloud Provider Initialization

#if CONDUIT_TRAIT_ANTHROPIC
    @Test("Anthropic provider initializes on all platforms")
    func anthropicProviderInitializes() async throws {
        let provider = AnthropicProvider(apiKey: "test-key")
        // Provider should initialize without errors
        // Verify provider is created - don't call isAvailable as it may trigger network on some configs
        #expect(type(of: provider) == AnthropicProvider.self)

        // Only check availability when NOT in CI (avoids potential network calls)
        #if !os(Linux)
        _ = await provider.isAvailable
        #endif
    }
#endif

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
    @Test("OpenAI provider initializes on all platforms")
    func openAIProviderInitializes() async throws {
        let provider = OpenAIProvider(apiKey: "test-key")
        // Verify provider is created
        #expect(type(of: provider) == OpenAIProvider.self)

        // Only check availability when NOT in CI on Linux (avoids network calls)
        #if !os(Linux)
        _ = await provider.isAvailable
        #endif
    }

    @Test("OpenAI provider supports Ollama endpoint")
    func openAIProviderSupportsOllama() async throws {
        // Ollama is the recommended local inference option on Linux
        // Note: We only test initialization here, NOT isAvailable
        // because isAvailable triggers a health check HTTP request
        // which can crash on Linux CI due to FoundationNetworking's try! usage
        let provider = OpenAIProvider(endpoint: .ollama(), apiKey: nil)
        #expect(type(of: provider) == OpenAIProvider.self)

        // The endpoint should be correctly configured
        let config = await provider.configuration
        if case .ollama = config.endpoint {
            // Expected - test passes
        } else {
            Issue.record("Expected Ollama endpoint")
        }
    }
#endif

    @Test("HuggingFace provider initializes on all platforms")
    func huggingFaceProviderInitializes() async throws {
        let provider = HuggingFaceProvider()
        // Verify provider is created
        #expect(type(of: provider) == HuggingFaceProvider.self)

        // Only check availability when NOT in CI on Linux
        #if !os(Linux)
        _ = await provider.isAvailable
        #endif
    }

    // MARK: - Core Types

    @Test("DeviceCapabilities detects system info")
    func deviceCapabilitiesWorks() {
        let caps = DeviceCapabilities.current()

        // Total RAM should always be positive
        #expect(caps.totalRAM > 0, "Total RAM should be detected")

        // Available RAM should be positive and less than or equal to total
        #expect(caps.availableRAM > 0, "Available RAM should be detected")
        #expect(caps.availableRAM <= caps.totalRAM, "Available RAM should not exceed total")

        #if os(Linux)
        // On Linux, MLX and FoundationModels are never supported
        #expect(!caps.supportsMLX, "MLX should not be supported on Linux")
        #expect(!caps.supportsFoundationModels, "FoundationModels should not be supported on Linux")
        #endif
    }

    @Test("GeneratedImage saves to file on all platforms")
    func generatedImageSavesToFile() throws {
        // Create a minimal PNG (1x1 transparent pixel)
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,  // IDAT chunk
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,  // IEND chunk
            0x42, 0x60, 0x82
        ])

        let image = GeneratedImage(data: pngData, format: .png)

        // save(to:) should work on all platforms
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).png")

        try image.save(to: tempURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Message Types

    @Test("Message types work on all platforms")
    func messageTypesWork() {
        let systemMsg = Message.system("You are helpful")
        let userMsg = Message.user("Hello")
        let assistantMsg = Message.assistant("Hi there!")

        #expect(systemMsg.role == .system)
        #expect(userMsg.role == .user)
        #expect(assistantMsg.role == .assistant)
    }

    @Test("GenerateConfig works on all platforms")
    func generateConfigWorks() {
        let config = GenerateConfig(
            maxTokens: 100,
            temperature: 0.7,
            topP: 0.9
        )

        #expect(config.maxTokens == 100)
        #expect(config.temperature == 0.7)
        #expect(config.topP == 0.9)
    }

    // MARK: - MLX Availability

    #if os(Linux)
    @Test("MLX provider unavailable on non-Apple platforms")
    func mlxUnavailableOnLinux() async {
        // On Linux/non-MLX platforms, the MLX provider should not be available
        // The type may not even exist or may be a stub
        let caps = DeviceCapabilities.current()
        #expect(!caps.supportsMLX, "MLX should not be supported without Apple Silicon")
    }
    #endif

    // MARK: - GenerationSchema and Structured Output

    @Test("GenerationSchema generation works on all platforms")
    func schemaGenerationWorks() throws {
        let schema = SchemaCompatibilityType.generationSchema
        let encoded = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(GenerationSchema.self, from: encoded)
        #expect(decoded.debugDescription.contains("object"))
    }

    // MARK: - Error Types

    @Test("AIError types work on all platforms")
    func aiErrorTypesWork() {
        let authError = AIError.authenticationFailed("Invalid key")
        let networkError = AIError.networkError(URLError(.badServerResponse))

        #expect(authError.localizedDescription.contains("Invalid key"))
        #expect(networkError.localizedDescription.lowercased().contains("network"))
    }

    // MARK: - Configuration Types (MLX-only)

    #if canImport(MLX)
    @Test("MLXConfiguration works on Apple platforms")
    func mlxConfigurationWorks() {
        // MLXConfiguration is a pure value type, should work on Apple platforms
        let config = MLXConfiguration.default
        #expect(config.prefillStepSize == 512)
        #expect(config.useMemoryMapping == true)

        let memoryEfficient = MLXConfiguration.memoryEfficient
        #expect(memoryEfficient.useQuantizedKVCache == true)
    }

    @Test("DiffusionVariant enum works on Apple platforms")
    func diffusionVariantWorks() {
        let sdxl = DiffusionVariant.sdxlTurbo
        #expect(sdxl.displayName == "SDXL Turbo")
        #expect(sdxl.defaultSteps == 4)
        #expect(sdxl.isNativelySupported == true)
    }
    #endif
}

// MARK: - Cross-Platform Utilities

@Suite("Cross-Platform Utilities")
struct CrossPlatformUtilitiesTests {

    @Test("ImageFormat enum works on all platforms")
    func imageFormatWorks() {
        #expect(ImageFormat.png.fileExtension == "png")
        #expect(ImageFormat.jpeg.mimeType == "image/jpeg")
        #expect(ImageFormat.webp.rawValue == "webp")
    }

    @Test("ModelSize enum works on all platforms")
    func modelSizeWorks() {
        let small = ModelSize.small
        let large = ModelSize.large

        #expect(small.minimumRAMBytes < large.minimumRAMBytes)
    }

    @Test("FinishReason enum works on all platforms")
    func finishReasonWorks() {
        let stop = FinishReason.stop
        let length = FinishReason.maxTokens

        #expect(stop != length)
    }
}
