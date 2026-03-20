// VLMDetectorTests.swift
// ConduitTests

import Testing
@testable import ConduitAdvanced

@Suite("VLMDetector Tests")
struct VLMDetectorTests {

    @Test("Name-based detection identifies VLM models")
    func testNameBasedDetection() async {
        let detector = VLMDetector.shared

        // Known VLM model names should be detected
        let vlmModels: [ModelIdentifier] = [
            .mlx("mlx-community/llava-1.5-7b-4bit"),
            .mlx("mlx-community/pixtral-12b-4bit"),
            .mlx("mlx-community/qwen2-vl-7b-4bit"),
        ]

        for model in vlmModels {
            let isVLM = await detector.isVLM(model)
            #expect(isVLM == true, "Expected \(model.rawValue) to be detected as VLM")
        }
    }

    @Test("Name-based detection excludes text-only models")
    func testTextOnlyDetection() async {
        let detector = VLMDetector.shared

        // Known text-only model names should not be detected as VLM
        let textModels: [ModelIdentifier] = [
            .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit"),
            .mlx("mlx-community/Mistral-7B-Instruct-v0.3-4bit"),
            .mlx("mlx-community/Qwen2.5-7B-Instruct-4bit"),
        ]

        for model in textModels {
            let isVLM = await detector.isVLM(model)
            #expect(isVLM == false, "Expected \(model.rawValue) to NOT be detected as VLM")
        }
    }

    @Test("Capabilities detection includes vision flag")
    func testCapabilitiesDetection() async {
        let detector = VLMDetector.shared

        // VLM model should have supportsVision = true
        let vlmModel = ModelIdentifier.mlx("mlx-community/llava-1.5-7b-4bit")
        let capabilities = await detector.detectCapabilities(vlmModel)

        #expect(capabilities.supportsVision == true)
        #expect(capabilities.supportsTextGeneration == true)
    }

    @Test("Architecture type detection works for known VLMs")
    func testArchitectureTypeDetection() async {
        let detector = VLMDetector.shared

        let testCases: [(ModelIdentifier, String?)] = [
            (.mlx("mlx-community/llava-1.5-7b-4bit"), "llava"),
            (.mlx("mlx-community/pixtral-12b-4bit"), "pixtral"),
            (.mlx("mlx-community/qwen2-vl-7b-4bit"), "qwen2_vl"),
        ]

        for (model, expectedArch) in testCases {
            let capabilities = await detector.detectCapabilities(model)
            if let expected = expectedArch {
                #expect(capabilities.architectureType?.rawValue.lowercased().contains(expected) == true,
                       "Expected architecture to contain '\(expected)' for \(model.rawValue)")
            }
        }
    }

    @Test("Non-MLX models are handled correctly")
    func testNonMLXModels() async {
        let detector = VLMDetector.shared

        // HuggingFace and Foundation Models should also be detectable
        let hfVLM = ModelIdentifier.huggingFace("llava-hf/llava-1.5-7b-hf")
        let isVLM = await detector.isVLM(hfVLM)

        // Should detect based on name even for HF models
        #expect(isVLM == true)
    }
}
