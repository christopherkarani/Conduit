// DALLEImageGenerationTests.swift
// Conduit
//
// Unit tests for DALL-E image generation components.

#if CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
import Testing
import Foundation
@testable import Conduit

// MARK: - DALLEImageSize Tests

@Suite("DALLEImageSize Tests")
struct DALLEImageSizeTests {

    @Test("DALL-E 2 supports correct sizes")
    func dallE2SizeSupport() {
        #expect(DALLEImageSize.small256.supportedByDallE2 == true)
        #expect(DALLEImageSize.medium512.supportedByDallE2 == true)
        #expect(DALLEImageSize.large1024.supportedByDallE2 == true)
        #expect(DALLEImageSize.landscape1792x1024.supportedByDallE2 == false)
        #expect(DALLEImageSize.portrait1024x1792.supportedByDallE2 == false)
    }

    @Test("DALL-E 3 supports correct sizes")
    func dallE3SizeSupport() {
        #expect(DALLEImageSize.small256.supportedByDallE3 == false)
        #expect(DALLEImageSize.medium512.supportedByDallE3 == false)
        #expect(DALLEImageSize.large1024.supportedByDallE3 == true)
        #expect(DALLEImageSize.landscape1792x1024.supportedByDallE3 == true)
        #expect(DALLEImageSize.portrait1024x1792.supportedByDallE3 == true)
    }

    @Test("Size dimensions are correct")
    func sizeDimensions() {
        #expect(DALLEImageSize.small256.width == 256)
        #expect(DALLEImageSize.small256.height == 256)

        #expect(DALLEImageSize.medium512.width == 512)
        #expect(DALLEImageSize.medium512.height == 512)

        #expect(DALLEImageSize.large1024.width == 1024)
        #expect(DALLEImageSize.large1024.height == 1024)

        #expect(DALLEImageSize.landscape1792x1024.width == 1792)
        #expect(DALLEImageSize.landscape1792x1024.height == 1024)

        #expect(DALLEImageSize.portrait1024x1792.width == 1024)
        #expect(DALLEImageSize.portrait1024x1792.height == 1792)
    }

    @Test("Raw values match API format")
    func rawValues() {
        #expect(DALLEImageSize.small256.rawValue == "256x256")
        #expect(DALLEImageSize.medium512.rawValue == "512x512")
        #expect(DALLEImageSize.large1024.rawValue == "1024x1024")
        #expect(DALLEImageSize.landscape1792x1024.rawValue == "1792x1024")
        #expect(DALLEImageSize.portrait1024x1792.rawValue == "1024x1792")
    }

    @Test("Display names are correct")
    func displayNames() {
        #expect(DALLEImageSize.small256.displayName == "256x256")
        #expect(DALLEImageSize.landscape1792x1024.displayName == "1792x1024")
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let original = DALLEImageSize.landscape1792x1024
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DALLEImageSize.self, from: data)
        #expect(decoded == original)
    }

    @Test("All cases are iterable")
    func caseIterable() {
        #expect(DALLEImageSize.allCases.count == 5)
    }
}

// MARK: - DALLEQuality Tests

@Suite("DALLEQuality Tests")
struct DALLEQualityTests {

    @Test("Raw values are correct")
    func rawValues() {
        #expect(DALLEQuality.standard.rawValue == "standard")
        #expect(DALLEQuality.hd.rawValue == "hd")
    }

    @Test("Display names are correct")
    func displayNames() {
        #expect(DALLEQuality.standard.displayName == "Standard")
        #expect(DALLEQuality.hd.displayName == "HD")
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let original = DALLEQuality.hd
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DALLEQuality.self, from: data)
        #expect(decoded == original)
    }

    @Test("All cases are iterable")
    func caseIterable() {
        #expect(DALLEQuality.allCases.count == 2)
    }
}

// MARK: - DALLEStyle Tests

@Suite("DALLEStyle Tests")
struct DALLEStyleTests {

    @Test("Raw values are correct")
    func rawValues() {
        #expect(DALLEStyle.vivid.rawValue == "vivid")
        #expect(DALLEStyle.natural.rawValue == "natural")
    }

    @Test("Display names are correct")
    func displayNames() {
        #expect(DALLEStyle.vivid.displayName == "Vivid")
        #expect(DALLEStyle.natural.displayName == "Natural")
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let original = DALLEStyle.natural
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DALLEStyle.self, from: data)
        #expect(decoded == original)
    }

    @Test("All cases are iterable")
    func caseIterable() {
        #expect(DALLEStyle.allCases.count == 2)
    }
}

// MARK: - ImageGenerationMetadata Tests

@Suite("ImageGenerationMetadata Tests")
struct ImageGenerationMetadataTests {

    @Test("Default initialization has nil properties")
    func defaultNilProperties() {
        let metadata = ImageGenerationMetadata()
        #expect(metadata.revisedPrompt == nil)
        #expect(metadata.createdAt == nil)
        #expect(metadata.model == nil)
    }

    @Test("Full initialization preserves values")
    func fullInitialization() {
        let date = Date()
        let metadata = ImageGenerationMetadata(
            revisedPrompt: "Enhanced prompt",
            createdAt: date,
            model: "dall-e-3"
        )
        #expect(metadata.revisedPrompt == "Enhanced prompt")
        #expect(metadata.createdAt == date)
        #expect(metadata.model == "dall-e-3")
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let metadata = ImageGenerationMetadata(
            revisedPrompt: "A beautiful landscape",
            createdAt: Date(timeIntervalSince1970: 1700000000),
            model: "dall-e-3"
        )
        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ImageGenerationMetadata.self, from: data)
        #expect(decoded.revisedPrompt == metadata.revisedPrompt)
        #expect(decoded.model == metadata.model)
    }

    @Test("Hashable conformance")
    func hashableConformance() {
        let metadata1 = ImageGenerationMetadata(revisedPrompt: "Test")
        let metadata2 = ImageGenerationMetadata(revisedPrompt: "Test")
        #expect(metadata1 == metadata2)
        #expect(metadata1.hashValue == metadata2.hashValue)
    }
}

// MARK: - ImageGenerationConfig DALL-E Tests

@Suite("ImageGenerationConfig DALL-E Tests")
struct ImageGenerationConfigDALLETests {

    @Test("dalleHD preset is correctly configured")
    func dalleHDPreset() {
        let config = ImageGenerationConfig.dalleHD
        #expect(config.dalleSize == .large1024)
        #expect(config.dalleQuality == .hd)
        #expect(config.dalleStyle == .vivid)
    }

    @Test("dalleNatural preset is correctly configured")
    func dalleNaturalPreset() {
        let config = ImageGenerationConfig.dalleNatural
        #expect(config.dalleSize == .large1024)
        #expect(config.dalleQuality == .standard)
        #expect(config.dalleStyle == .natural)
    }

    @Test("dalleLandscape preset is correctly configured")
    func dalleLandscapePreset() {
        let config = ImageGenerationConfig.dalleLandscape
        #expect(config.dalleSize == .landscape1792x1024)
    }

    @Test("dallePortrait preset is correctly configured")
    func dallePortraitPreset() {
        let config = ImageGenerationConfig.dallePortrait
        #expect(config.dalleSize == .portrait1024x1792)
    }

    @Test("dalleSize fluent builder works")
    func dalleSizeBuilder() {
        let config = ImageGenerationConfig.default.dalleSize(.landscape1792x1024)
        #expect(config.dalleSize == .landscape1792x1024)
    }

    @Test("dalleQuality fluent builder works")
    func dalleQualityBuilder() {
        let config = ImageGenerationConfig.default.dalleQuality(.hd)
        #expect(config.dalleQuality == .hd)
    }

    @Test("dalleStyle fluent builder works")
    func dalleStyleBuilder() {
        let config = ImageGenerationConfig.default.dalleStyle(.natural)
        #expect(config.dalleStyle == .natural)
    }

    @Test("Fluent builders preserve other properties")
    func fluentBuilderPreservesProperties() {
        let config = ImageGenerationConfig(width: 1024, height: 768, steps: 50)
            .dalleSize(.large1024)
            .dalleQuality(.hd)

        #expect(config.width == 1024)
        #expect(config.height == 768)
        #expect(config.steps == 50)
        #expect(config.dalleSize == .large1024)
        #expect(config.dalleQuality == .hd)
    }

    @Test("DALL-E properties preserved by other builders")
    func otherBuildersPreserveDALLEProperties() {
        let config = ImageGenerationConfig.dalleHD.width(512)

        #expect(config.width == 512)
        #expect(config.dalleSize == .large1024)
        #expect(config.dalleQuality == .hd)
        #expect(config.dalleStyle == .vivid)
    }

    @Test("hasParameters includes DALL-E properties")
    func hasParametersIncludesDALLE() {
        let emptyConfig = ImageGenerationConfig.default
        let dalleConfig = ImageGenerationConfig.default.dalleSize(.large1024)

        #expect(emptyConfig.hasParameters == false)
        #expect(dalleConfig.hasParameters == true)
    }
}

// MARK: - GeneratedImage Metadata Tests

@Suite("GeneratedImage Metadata Tests")
struct GeneratedImageMetadataTests {

    @Test("Default metadata is nil")
    func defaultMetadataNil() {
        let image = GeneratedImage(data: Data())
        #expect(image.metadata == nil)
    }

    @Test("Metadata is preserved when set")
    func metadataPreserved() {
        let metadata = ImageGenerationMetadata(
            revisedPrompt: "Enhanced prompt",
            model: "dall-e-3"
        )
        let image = GeneratedImage(data: Data(), format: .png, metadata: metadata)

        #expect(image.metadata?.revisedPrompt == "Enhanced prompt")
        #expect(image.metadata?.model == "dall-e-3")
    }

    @Test("Format defaults to PNG")
    func formatDefaultsPNG() {
        let image = GeneratedImage(data: Data())
        #expect(image.format == .png)
    }

    @Test("Custom format is preserved")
    func customFormatPreserved() {
        let image = GeneratedImage(data: Data(), format: .jpeg)
        #expect(image.format == .jpeg)
    }
}

#endif // CONDUIT_TRAIT_OPENAI || CONDUIT_TRAIT_OPENROUTER
