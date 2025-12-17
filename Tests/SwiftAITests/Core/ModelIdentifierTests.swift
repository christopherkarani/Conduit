// ModelIdentifierTests.swift
// SwiftAI

import XCTest
@testable import SwiftAI

final class ModelIdentifierTests: XCTestCase {

    // MARK: - ModelIdentifier Basic Tests

    func testMLXModelIdentifier() {
        let model: ModelIdentifier = .mlx("mlx-community/Llama-3.2-1B-Instruct-4bit")

        XCTAssertEqual(model.rawValue, "mlx-community/Llama-3.2-1B-Instruct-4bit")
        XCTAssertEqual(model.displayName, "Llama-3.2-1B-Instruct-4bit")
        XCTAssertEqual(model.provider, .mlx)
        XCTAssertFalse(model.requiresNetwork)
        XCTAssertTrue(model.isLocal)
    }

    func testHuggingFaceModelIdentifier() {
        let model: ModelIdentifier = .huggingFace("meta-llama/Llama-3.1-70B-Instruct")

        XCTAssertEqual(model.rawValue, "meta-llama/Llama-3.1-70B-Instruct")
        XCTAssertEqual(model.displayName, "Llama-3.1-70B-Instruct")
        XCTAssertEqual(model.provider, .huggingFace)
        XCTAssertTrue(model.requiresNetwork)
        XCTAssertFalse(model.isLocal)
    }

    func testFoundationModelsIdentifier() {
        let model: ModelIdentifier = .foundationModels

        XCTAssertEqual(model.rawValue, "apple-foundation-models")
        XCTAssertEqual(model.displayName, "Apple Intelligence")
        XCTAssertEqual(model.provider, .foundationModels)
        XCTAssertFalse(model.requiresNetwork)
        XCTAssertTrue(model.isLocal)
    }

    func testModelIdentifierDescription() {
        let mlxModel: ModelIdentifier = .mlx("mlx-community/model")
        XCTAssertEqual(mlxModel.description, "[MLX (Local)] mlx-community/model")

        let hfModel: ModelIdentifier = .huggingFace("org/model")
        XCTAssertEqual(hfModel.description, "[HuggingFace (Cloud)] org/model")

        let appleModel: ModelIdentifier = .foundationModels
        XCTAssertEqual(appleModel.description, "[Apple Foundation Models] apple-foundation-models")
    }

    // MARK: - Hashable Tests

    func testModelIdentifierIsHashable() {
        let model1: ModelIdentifier = .mlx("test-model")
        let model2: ModelIdentifier = .mlx("test-model")
        let model3: ModelIdentifier = .mlx("different-model")

        var set = Set<ModelIdentifier>()
        set.insert(model1)
        set.insert(model2) // Should not increase count
        set.insert(model3) // Should increase count

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(model1))
        XCTAssertTrue(set.contains(model2))
        XCTAssertTrue(set.contains(model3))
    }

    func testModelIdentifierEquality() {
        let mlx1: ModelIdentifier = .mlx("model-id")
        let mlx2: ModelIdentifier = .mlx("model-id")
        let mlx3: ModelIdentifier = .mlx("different-id")

        XCTAssertEqual(mlx1, mlx2)
        XCTAssertNotEqual(mlx1, mlx3)

        let hf1: ModelIdentifier = .huggingFace("model-id")
        let hf2: ModelIdentifier = .huggingFace("model-id")

        XCTAssertEqual(hf1, hf2)
        XCTAssertNotEqual(mlx1, hf1) // Different providers

        let apple1: ModelIdentifier = .foundationModels
        let apple2: ModelIdentifier = .foundationModels

        XCTAssertEqual(apple1, apple2)
        XCTAssertNotEqual(apple1, mlx1)
    }

    // MARK: - Codable Tests

    func testMLXCodableRoundTrip() throws {
        let original: ModelIdentifier = .mlx("mlx-community/test-model")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModelIdentifier.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.rawValue, "mlx-community/test-model")
    }

    func testHuggingFaceCodableRoundTrip() throws {
        let original: ModelIdentifier = .huggingFace("meta-llama/test-model")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModelIdentifier.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.rawValue, "meta-llama/test-model")
    }

    func testFoundationModelsCodableRoundTrip() throws {
        let original: ModelIdentifier = .foundationModels

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModelIdentifier.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.rawValue, "apple-foundation-models")
    }

    func testCodableJSONStructure() throws {
        let mlxModel: ModelIdentifier = .mlx("mlx-model-id")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let mlxData = try encoder.encode(mlxModel)
        let mlxJSON = String(data: mlxData, encoding: .utf8)!

        XCTAssertTrue(mlxJSON.contains("\"type\":\"mlx\""))
        XCTAssertTrue(mlxJSON.contains("\"id\":\"mlx-model-id\""))

        let hfModel: ModelIdentifier = .huggingFace("hf-model-id")
        let hfData = try encoder.encode(hfModel)
        let hfJSON = String(data: hfData, encoding: .utf8)!

        XCTAssertTrue(hfJSON.contains("\"type\":\"huggingFace\""))
        XCTAssertTrue(hfJSON.contains("\"id\":\"hf-model-id\""))

        let appleModel: ModelIdentifier = .foundationModels
        let appleData = try encoder.encode(appleModel)
        let appleJSON = String(data: appleData, encoding: .utf8)!

        XCTAssertTrue(appleJSON.contains("\"type\":\"foundationModels\""))
        XCTAssertFalse(appleJSON.contains("\"id\"")) // Should not have id field
    }

    func testFoundationModelsCodableNoId() throws {
        let model: ModelIdentifier = .foundationModels
        let encoder = JSONEncoder()
        let data = try encoder.encode(model)

        // Decode as dictionary to verify structure
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["type"] as? String, "foundationModels")
        XCTAssertNil(json?["id"]) // Foundation models should not have id field
    }

    // MARK: - Sendable Tests

    func testModelIdentifierIsSendable() async {
        let model: ModelIdentifier = .mlx("test-model")

        // This test verifies Sendable conformance by using the value across actor boundaries
        await Task {
            let localModel = model
            XCTAssertEqual(localModel.rawValue, "test-model")
        }.value
    }

    // MARK: - Registry Constant Tests

    func testRegistryMLXModels() {
        XCTAssertEqual(ModelIdentifier.llama3_2_1B.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.llama3_2_1B.rawValue, "mlx-community/Llama-3.2-1B-Instruct-4bit")

        XCTAssertEqual(ModelIdentifier.llama3_2_3B.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.llama3_2_3B.rawValue, "mlx-community/Llama-3.2-3B-Instruct-4bit")

        XCTAssertEqual(ModelIdentifier.phi3Mini.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.phi4.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.qwen2_5_3B.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.mistral7B.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.gemma2_2B.provider, .mlx)
    }

    func testRegistryEmbeddingModels() {
        XCTAssertEqual(ModelIdentifier.bgeSmall.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.bgeSmall.rawValue, "mlx-community/bge-small-en-v1.5")

        XCTAssertEqual(ModelIdentifier.bgeLarge.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.bgeLarge.rawValue, "mlx-community/bge-large-en-v1.5")

        XCTAssertEqual(ModelIdentifier.nomicEmbed.provider, .mlx)
        XCTAssertEqual(ModelIdentifier.nomicEmbed.rawValue, "mlx-community/nomic-embed-text-v1.5")
    }

    func testRegistryHuggingFaceModels() {
        XCTAssertEqual(ModelIdentifier.llama3_1_70B.provider, .huggingFace)
        XCTAssertEqual(ModelIdentifier.llama3_1_70B.rawValue, "meta-llama/Llama-3.1-70B-Instruct")

        XCTAssertEqual(ModelIdentifier.llama3_1_8B.provider, .huggingFace)
        XCTAssertEqual(ModelIdentifier.mixtral8x7B.provider, .huggingFace)
        XCTAssertEqual(ModelIdentifier.deepseekR1.provider, .huggingFace)
        XCTAssertEqual(ModelIdentifier.whisperLargeV3.provider, .huggingFace)
    }

    func testRegistryAppleModel() {
        XCTAssertEqual(ModelIdentifier.apple, .foundationModels)
        XCTAssertEqual(ModelIdentifier.apple.provider, .foundationModels)
        XCTAssertEqual(ModelIdentifier.apple.displayName, "Apple Intelligence")
    }

    // MARK: - ModelCapability Tests

    func testModelCapabilityDisplayNames() {
        XCTAssertEqual(ModelCapability.textGeneration.displayName, "Text Generation")
        XCTAssertEqual(ModelCapability.embeddings.displayName, "Embeddings")
        XCTAssertEqual(ModelCapability.transcription.displayName, "Transcription")
        XCTAssertEqual(ModelCapability.codeGeneration.displayName, "Code Generation")
        XCTAssertEqual(ModelCapability.reasoning.displayName, "Reasoning")
        XCTAssertEqual(ModelCapability.multimodal.displayName, "Multimodal")
    }

    func testModelCapabilityIsCaseIterable() {
        let allCapabilities = ModelCapability.allCases

        XCTAssertEqual(allCapabilities.count, 6)
        XCTAssertTrue(allCapabilities.contains(.textGeneration))
        XCTAssertTrue(allCapabilities.contains(.embeddings))
        XCTAssertTrue(allCapabilities.contains(.transcription))
        XCTAssertTrue(allCapabilities.contains(.codeGeneration))
        XCTAssertTrue(allCapabilities.contains(.reasoning))
        XCTAssertTrue(allCapabilities.contains(.multimodal))
    }

    func testModelCapabilityIsCodable() throws {
        let capability: ModelCapability = .textGeneration

        let encoder = JSONEncoder()
        let data = try encoder.encode(capability)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModelCapability.self, from: data)

        XCTAssertEqual(capability, decoded)
    }

    // MARK: - ModelSize Tests

    func testModelSizeComparable() {
        XCTAssertLessThan(ModelSize.tiny, ModelSize.small)
        XCTAssertLessThan(ModelSize.small, ModelSize.medium)
        XCTAssertLessThan(ModelSize.medium, ModelSize.large)
        XCTAssertLessThan(ModelSize.large, ModelSize.xlarge)

        XCTAssertFalse(ModelSize.medium < ModelSize.small)
        XCTAssertFalse(ModelSize.large < ModelSize.medium)

        // Test sorting
        let sizes: [ModelSize] = [.xlarge, .small, .large, .medium, .tiny]
        let sorted = sizes.sorted()

        XCTAssertEqual(sorted, [.tiny, .small, .medium, .large, .xlarge])
    }

    func testModelSizeDisplayNames() {
        XCTAssertEqual(ModelSize.tiny.displayName, "Tiny (< 500MB)")
        XCTAssertEqual(ModelSize.small.displayName, "Small (500MB - 2GB)")
        XCTAssertEqual(ModelSize.medium.displayName, "Medium (2GB - 8GB)")
        XCTAssertEqual(ModelSize.large.displayName, "Large (8GB - 32GB)")
        XCTAssertEqual(ModelSize.xlarge.displayName, "Extra Large (> 32GB)")
    }

    func testModelSizeApproximateRAM() {
        XCTAssertEqual(ModelSize.tiny.approximateRAM, .megabytes(512))
        XCTAssertEqual(ModelSize.small.approximateRAM, .gigabytes(2))
        XCTAssertEqual(ModelSize.medium.approximateRAM, .gigabytes(8))
        XCTAssertEqual(ModelSize.large.approximateRAM, .gigabytes(16))
        XCTAssertEqual(ModelSize.xlarge.approximateRAM, .gigabytes(32))
    }

    // MARK: - ModelInfo Tests

    func testModelInfoIdentifiable() {
        let model = ModelInfo(
            identifier: .llama3_2_1B,
            name: "Test Model",
            description: "Test description",
            size: .small,
            contextWindow: 8192,
            capabilities: [.textGeneration]
        )

        XCTAssertEqual(model.id, "mlx-community/Llama-3.2-1B-Instruct-4bit")
        XCTAssertEqual(model.id, model.identifier.rawValue)
    }

    func testModelInfoHashable() {
        let model1 = ModelInfo(
            identifier: .llama3_2_1B,
            name: "Model 1",
            description: "Description 1",
            size: .small,
            contextWindow: 8192,
            capabilities: [.textGeneration]
        )

        let model2 = ModelInfo(
            identifier: .llama3_2_1B,
            name: "Model 2", // Different name
            description: "Description 2",
            size: .medium,
            contextWindow: 4096,
            capabilities: [.embeddings]
        )

        let model3 = ModelInfo(
            identifier: .llama3_2_3B,
            name: "Model 3",
            description: "Description 3",
            size: .small,
            contextWindow: 8192,
            capabilities: [.textGeneration]
        )

        var set = Set<ModelInfo>()
        set.insert(model1)
        set.insert(model2) // Same identifier, should not increase count
        set.insert(model3) // Different identifier, should increase count

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - ModelRegistry Tests

    func testRegistryContainsAllExpectedModels() {
        let allModels = ModelRegistry.allModels

        // Should have 16 models total
        XCTAssertEqual(allModels.count, 16)

        // Count by provider
        let mlxModels = allModels.filter { $0.identifier.provider == .mlx }
        let hfModels = allModels.filter { $0.identifier.provider == .huggingFace }
        let appleModels = allModels.filter { $0.identifier.provider == .foundationModels }

        XCTAssertEqual(mlxModels.count, 10) // 7 text gen + 3 embedding
        XCTAssertEqual(hfModels.count, 5)
        XCTAssertEqual(appleModels.count, 1)
    }

    func testRegistryInfoLookup() {
        let model = ModelRegistry.info(for: .llama3_2_1B)

        XCTAssertNotNil(model)
        XCTAssertEqual(model?.name, "Llama 3.2 1B")
        XCTAssertEqual(model?.identifier, .llama3_2_1B)
        XCTAssertEqual(model?.size, .small)
        XCTAssertEqual(model?.contextWindow, 8192)
        XCTAssertTrue(model?.isRecommended ?? false)
        XCTAssertEqual(model?.parameters, "1B")
        XCTAssertEqual(model?.quantization, "4-bit")
    }

    func testRegistryInfoNotFound() {
        let customModel: ModelIdentifier = .mlx("custom/unknown-model")
        let model = ModelRegistry.info(for: customModel)

        XCTAssertNil(model)
    }

    func testRegistryModelsByProvider() {
        let mlxModels = ModelRegistry.models(for: .mlx)
        let hfModels = ModelRegistry.models(for: .huggingFace)
        let appleModels = ModelRegistry.models(for: .foundationModels)

        XCTAssertEqual(mlxModels.count, 10)
        XCTAssertEqual(hfModels.count, 5)
        XCTAssertEqual(appleModels.count, 1)

        // Verify all MLX models are actually MLX
        XCTAssertTrue(mlxModels.allSatisfy { $0.identifier.provider == .mlx })
        XCTAssertTrue(hfModels.allSatisfy { $0.identifier.provider == .huggingFace })
        XCTAssertTrue(appleModels.allSatisfy { $0.identifier.provider == .foundationModels })
    }

    func testRegistryModelsByCapability() {
        let textGenModels = ModelRegistry.models(with: .textGeneration)
        let embeddingModels = ModelRegistry.models(with: .embeddings)
        let codeGenModels = ModelRegistry.models(with: .codeGeneration)
        let reasoningModels = ModelRegistry.models(with: .reasoning)
        let transcriptionModels = ModelRegistry.models(with: .transcription)

        XCTAssertEqual(textGenModels.count, 12) // Most models support text generation
        XCTAssertEqual(embeddingModels.count, 3) // BGE small, BGE large, Nomic
        XCTAssertEqual(codeGenModels.count, 3) // Phi-3 Mini, Phi-4, Llama 3.1 70B
        XCTAssertEqual(reasoningModels.count, 4) // Phi-3 Mini, Phi-4, Llama 3.1 70B, DeepSeek R1
        XCTAssertEqual(transcriptionModels.count, 1) // Whisper Large V3

        // Verify all embedding models actually have the capability
        XCTAssertTrue(embeddingModels.allSatisfy { $0.capabilities.contains(.embeddings) })
    }

    func testRegistryRecommendedModels() {
        let recommended = ModelRegistry.recommendedModels()

        // Should have at least 5 recommended models
        XCTAssertGreaterThanOrEqual(recommended.count, 5)

        // All should have isRecommended flag
        XCTAssertTrue(recommended.allSatisfy { $0.isRecommended })

        // Verify specific recommended models
        let recommendedNames = recommended.map { $0.name }
        XCTAssertTrue(recommendedNames.contains("Llama 3.2 1B"))
        XCTAssertTrue(recommendedNames.contains("Llama 3.2 3B"))
        XCTAssertTrue(recommendedNames.contains("BGE Small"))
        XCTAssertTrue(recommendedNames.contains("Llama 3.1 70B"))
        XCTAssertTrue(recommendedNames.contains("Apple Intelligence"))
    }

    func testRegistryLocalModels() {
        let localModels = ModelRegistry.localModels()

        // Local models should be MLX + Apple
        XCTAssertEqual(localModels.count, 11) // 10 MLX + 1 Apple

        // All should not require network
        XCTAssertTrue(localModels.allSatisfy { !$0.identifier.requiresNetwork })
        XCTAssertTrue(localModels.allSatisfy { $0.identifier.isLocal })

        // Should include both MLX and Apple
        let providers = Set(localModels.map { $0.identifier.provider })
        XCTAssertTrue(providers.contains(.mlx))
        XCTAssertTrue(providers.contains(.foundationModels))
        XCTAssertFalse(providers.contains(.huggingFace))
    }

    func testRegistryCloudModels() {
        let cloudModels = ModelRegistry.cloudModels()

        // Cloud models should be HuggingFace only
        XCTAssertEqual(cloudModels.count, 5)

        // All should require network
        XCTAssertTrue(cloudModels.allSatisfy { $0.identifier.requiresNetwork })
        XCTAssertTrue(cloudModels.allSatisfy { !$0.identifier.isLocal })

        // All should be HuggingFace
        XCTAssertTrue(cloudModels.allSatisfy { $0.identifier.provider == .huggingFace })
    }

    // MARK: - ProviderType Tests

    func testProviderTypeRequiresNetwork() {
        XCTAssertFalse(ProviderType.mlx.requiresNetwork)
        XCTAssertTrue(ProviderType.huggingFace.requiresNetwork)
        XCTAssertFalse(ProviderType.foundationModels.requiresNetwork)
    }

    // MARK: - Display Name Edge Cases

    func testDisplayNameWithoutSlash() {
        let model: ModelIdentifier = .mlx("simple-model")
        XCTAssertEqual(model.displayName, "simple-model")
    }

    func testDisplayNameWithMultipleSlashes() {
        let model: ModelIdentifier = .mlx("org/category/model-name")
        XCTAssertEqual(model.displayName, "model-name")
    }

    // MARK: - DiskSize Tests

    func testModelInfoWithDiskSize() {
        let model = ModelRegistry.info(for: .llama3_2_1B)
        XCTAssertNotNil(model?.diskSize)
        XCTAssertEqual(model?.diskSize, .megabytes(800))
    }

    func testModelInfoWithoutDiskSize() {
        let model = ModelRegistry.info(for: .llama3_1_70B)
        XCTAssertNil(model?.diskSize) // Cloud model has no disk size
    }

    // MARK: - Context Window Tests

    func testModelInfoContextWindows() {
        let llama32 = ModelRegistry.info(for: .llama3_2_1B)
        XCTAssertEqual(llama32?.contextWindow, 8192)

        let llama31 = ModelRegistry.info(for: .llama3_1_70B)
        XCTAssertEqual(llama31?.contextWindow, 128000)

        let whisper = ModelRegistry.info(for: .whisperLargeV3)
        XCTAssertEqual(whisper?.contextWindow, 0) // N/A for transcription
    }

    // MARK: - Multi-Capability Tests

    func testModelInfoMultipleCapabilities() {
        let phi3 = ModelRegistry.info(for: .phi3Mini)
        XCTAssertNotNil(phi3)

        let capabilities = phi3?.capabilities ?? []
        XCTAssertTrue(capabilities.contains(.textGeneration))
        XCTAssertTrue(capabilities.contains(.codeGeneration))
        XCTAssertTrue(capabilities.contains(.reasoning))
        XCTAssertEqual(capabilities.count, 3)
    }
}
