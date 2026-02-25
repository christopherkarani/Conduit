// ModelCapabilitiesTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("ModelCapabilities Tests")
struct ModelCapabilitiesTests {

    // MARK: - Static Presets

    @Test("textOnly preset has correct capabilities")
    func textOnlyPreset() {
        let caps = ModelCapabilities.textOnly

        #expect(!caps.supportsVision)
        #expect(caps.supportsTextGeneration)
        #expect(!caps.supportsEmbeddings)
        #expect(caps.architectureType == nil)
        #expect(caps.contextWindowSize == nil)
    }

    @Test("vlm preset has correct capabilities")
    func vlmPreset() {
        let caps = ModelCapabilities.vlm

        #expect(caps.supportsVision)
        #expect(caps.supportsTextGeneration)
        #expect(!caps.supportsEmbeddings)
        #expect(caps.architectureType == .vlm)
    }

    @Test("embedding preset has correct capabilities")
    func embeddingPreset() {
        let caps = ModelCapabilities.embedding

        #expect(!caps.supportsVision)
        #expect(!caps.supportsTextGeneration)
        #expect(caps.supportsEmbeddings)
        #expect(caps.architectureType == nil)
    }

    // MARK: - Custom Init

    @Test("Custom init stores all properties")
    func customInit() {
        let caps = ModelCapabilities(
            supportsVision: true,
            supportsTextGeneration: true,
            supportsEmbeddings: false,
            architectureType: .qwen2VL,
            contextWindowSize: 32768
        )

        #expect(caps.supportsVision)
        #expect(caps.supportsTextGeneration)
        #expect(!caps.supportsEmbeddings)
        #expect(caps.architectureType == .qwen2VL)
        #expect(caps.contextWindowSize == 32768)
    }

    // MARK: - Hashable

    @Test("Equal capabilities have same hash")
    func hashEquality() {
        let a = ModelCapabilities.textOnly
        let b = ModelCapabilities.textOnly
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different capabilities are unequal")
    func inequality() {
        #expect(ModelCapabilities.textOnly != ModelCapabilities.vlm)
        #expect(ModelCapabilities.textOnly != ModelCapabilities.embedding)
        #expect(ModelCapabilities.vlm != ModelCapabilities.embedding)
    }
}

// MARK: - ArchitectureType Tests

@Suite("ArchitectureType Tests")
struct ArchitectureTypeTests {

    // MARK: - supportsVision

    @Test("Vision architectures return true for supportsVision",
          arguments: [
            ArchitectureType.vlm,
            .llava,
            .qwen2VL,
            .pixtral,
            .paligemma,
            .idefics,
            .mllama,
            .phi3Vision,
            .cogvlm,
            .internvl,
            .minicpmV,
            .florence,
            .blip
          ])
    func visionArchitectures(arch: ArchitectureType) {
        #expect(arch.supportsVision)
    }

    @Test("Non-vision architectures return false for supportsVision",
          arguments: [
            ArchitectureType.llama,
            .mistral,
            .qwen,
            .phi,
            .gemma,
            .bert,
            .bge,
            .nomic
          ])
    func nonVisionArchitectures(arch: ArchitectureType) {
        #expect(!arch.supportsVision)
    }

    // MARK: - CaseIterable

    @Test("All architecture cases are enumerated")
    func allCases() {
        // 25 total: 5 text + 13 vision + 3 embedding + 4 others
        #expect(ArchitectureType.allCases.count > 20)
    }

    // MARK: - Raw Values

    @Test("Custom raw values are correct")
    func customRawValues() {
        #expect(ArchitectureType.qwen2VL.rawValue == "qwen2_vl")
        #expect(ArchitectureType.phi3Vision.rawValue == "phi3_v")
        #expect(ArchitectureType.minicpmV.rawValue == "minicpm_v")
    }

    @Test("Default raw values match case name")
    func defaultRawValues() {
        #expect(ArchitectureType.llama.rawValue == "llama")
        #expect(ArchitectureType.mistral.rawValue == "mistral")
        #expect(ArchitectureType.bert.rawValue == "bert")
    }

    // MARK: - Codable

    @Test("Codable round-trip for all cases",
          arguments: ArchitectureType.allCases)
    func codableRoundTrip(arch: ArchitectureType) throws {
        let data = try JSONEncoder().encode(arch)
        let decoded = try JSONDecoder().decode(ArchitectureType.self, from: data)
        #expect(arch == decoded)
    }

    @Test("Decodes from raw value string")
    func decodesFromRawValue() throws {
        let json = Data("\"qwen2_vl\"".utf8)
        let decoded = try JSONDecoder().decode(ArchitectureType.self, from: json)
        #expect(decoded == .qwen2VL)
    }
}
