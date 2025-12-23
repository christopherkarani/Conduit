// DiffusionModelRegistryTests.swift
// SwiftAI

import Foundation
import Testing
@testable import SwiftAI

@Suite("DiffusionModelRegistry Tests")
struct DiffusionModelRegistryTests {

    // MARK: - Available Models Catalog Tests

    @Test("Available models catalog is populated")
    func availableModelsCatalog() {
        let models = DiffusionModelRegistry.availableModels
        #expect(models.count == 3)
    }

    @Test("Available models have correct IDs")
    func availableModelIds() {
        let ids = DiffusionModelRegistry.availableModels.map(\.id)
        #expect(ids.contains("mlx-community/sdxl-turbo"))
        #expect(ids.contains("mlx-community/stable-diffusion-v1-5-4bit"))
        #expect(ids.contains("mlx-community/flux-schnell-4bit"))
    }

    @Test("Available models have HuggingFace URLs")
    func availableModelsHaveURLs() {
        for model in DiffusionModelRegistry.availableModels {
            #expect(model.huggingFaceURL.absoluteString.contains("huggingface.co"))
        }
    }

    @Test("Available models have all required properties")
    func availableModelsComplete() {
        for model in DiffusionModelRegistry.availableModels {
            #expect(!model.id.isEmpty)
            #expect(!model.name.isEmpty)
            #expect(model.sizeGiB > 0)
            #expect(!model.description.isEmpty)
        }
    }

    @Test("Available models have correct variants")
    func availableModelsVariants() {
        let models = DiffusionModelRegistry.availableModels
        let variants = models.map(\.variant)

        #expect(variants.contains(.sdxlTurbo))
        #expect(variants.contains(.sd15))
        #expect(variants.contains(.flux))
    }

    // MARK: - DiffusionModelInfo Tests

    @Test("DiffusionModelInfo properties are correct")
    func modelInfoProperties() {
        let model = DiffusionModelRegistry.availableModels.first!

        #expect(!model.id.isEmpty)
        #expect(!model.name.isEmpty)
        #expect(model.sizeGiB > 0)
        #expect(!model.description.isEmpty)
    }

    @Test("DiffusionModelInfo formatted size")
    func modelInfoFormattedSize() {
        let model = DiffusionModelInfo(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            sizeGiB: 6.5,
            description: "Test model",
            huggingFaceURL: URL(string: "https://example.com")!
        )
        #expect(model.formattedSize == "6.5 GiB")
    }

    @Test("DiffusionModelInfo size bytes calculation")
    func modelInfoSizeBytes() {
        let model = DiffusionModelInfo(
            id: "test/model",
            name: "Test",
            variant: .sd15,
            sizeGiB: 2.0,
            description: "Test model",
            huggingFaceURL: URL(string: "https://example.com")!
        )
        #expect(model.sizeBytes == 2_147_483_648)  // 2 GiB
    }

    @Test("DiffusionModelInfo Identifiable conformance")
    func modelInfoIdentifiable() {
        let model = DiffusionModelRegistry.availableModels[0]
        #expect(model.id == "mlx-community/sdxl-turbo")
    }

    // MARK: - DownloadedDiffusionModel Tests

    @Test("DownloadedDiffusionModel initializes correctly")
    func downloadedModelInit() {
        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test Model",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp/model"),
            sizeBytes: 1_000_000_000
        )

        #expect(model.id == "test/model")
        #expect(model.name == "Test Model")
        #expect(model.variant == .sdxlTurbo)
        #expect(model.sizeBytes == 1_000_000_000)
    }

    @Test("DownloadedDiffusionModel formatted size")
    func downloadedModelFormattedSize() {
        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sd15,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 2_147_483_648  // 2GB
        )
        // ByteCountFormatter output varies by locale but should contain GB or numeric value
        let formattedSize = model.formattedSize
        #expect(!formattedSize.isEmpty)
    }

    @Test("DownloadedDiffusionModel is Codable")
    func downloadedModelCodable() throws {
        let original = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .flux,
            localPath: URL(fileURLWithPath: "/tmp/model"),
            downloadedAt: Date(),
            sizeBytes: 500_000_000
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DownloadedDiffusionModel.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.variant == original.variant)
        #expect(decoded.sizeBytes == original.sizeBytes)
    }

    @Test("DownloadedDiffusionModel Identifiable conformance")
    func downloadedModelIdentifiable() {
        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        #expect(model.id == "test/model")
    }

    @Test("DownloadedDiffusionModel default downloadedAt is recent")
    func downloadedAtDefault() {
        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        let now = Date()
        #expect(abs(model.downloadedAt.timeIntervalSince(now)) < 1.0)
    }

    @Test("DownloadedDiffusionModel downloadedAgo provides relative time")
    func downloadedAgo() {
        let pastDate = Date().addingTimeInterval(-3600)  // 1 hour ago
        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            downloadedAt: pastDate,
            sizeBytes: 1_000_000_000
        )

        let ago = model.downloadedAgo
        #expect(!ago.isEmpty)
    }

    // MARK: - Registry Instance Tests

    @Test("Registry singleton is accessible")
    func singletonAccess() async {
        let registry = DiffusionModelRegistry.shared
        let count = await registry.downloadedCount
        #expect(count >= 0)
    }

    @Test("Registry starts with no downloaded models")
    func initiallyEmpty() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()
        let count = await registry.downloadedCount
        #expect(count == 0)
    }

    // MARK: - Query Methods Tests

    @Test("isDownloaded returns false for non-existent model")
    func isDownloadedNegative() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let result = await registry.isDownloaded("non-existent/model")
        #expect(result == false)
    }

    @Test("isDownloaded returns true after adding model")
    func isDownloadedPositive() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        await registry.addDownloaded(model)
        let result = await registry.isDownloaded("test/model")
        #expect(result == true)
    }

    @Test("localPath returns nil for non-existent model")
    func localPathNil() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let path = await registry.localPath(for: "non-existent/model")
        #expect(path == nil)
    }

    @Test("localPath returns correct URL for downloaded model")
    func localPathFound() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let expectedPath = URL(fileURLWithPath: "/tmp/test-model")
        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: expectedPath,
            sizeBytes: 1_000_000_000
        )

        await registry.addDownloaded(model)
        let actualPath = await registry.localPath(for: "test/model")
        #expect(actualPath == expectedPath)
    }

    @Test("downloadedModel returns nil for non-existent model")
    func downloadedModelNil() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model = await registry.downloadedModel(for: "non-existent/model")
        #expect(model == nil)
    }

    @Test("downloadedModel returns correct info")
    func downloadedModelFound() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let original = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test Model",
            variant: .flux,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 2_000_000_000
        )

        await registry.addDownloaded(original)
        let retrieved = await registry.downloadedModel(for: "test/model")

        #expect(retrieved?.id == original.id)
        #expect(retrieved?.name == original.name)
        #expect(retrieved?.variant == original.variant)
    }

    // MARK: - Collection Methods Tests

    @Test("allDownloadedModels returns empty array initially")
    func allDownloadedModelsEmpty() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let models = await registry.allDownloadedModels
        #expect(models.isEmpty)
    }

    @Test("allDownloadedModels includes all added models")
    func allDownloadedModelsPopulated() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model1 = DownloadedDiffusionModel(
            id: "test/model1",
            name: "Model 1",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp/1"),
            sizeBytes: 1_000_000_000
        )

        let model2 = DownloadedDiffusionModel(
            id: "test/model2",
            name: "Model 2",
            variant: .sd15,
            localPath: URL(fileURLWithPath: "/tmp/2"),
            sizeBytes: 2_000_000_000
        )

        await registry.addDownloaded(model1)
        await registry.addDownloaded(model2)

        let models = await registry.allDownloadedModels
        #expect(models.count == 2)
        #expect(models.contains { $0.id == "test/model1" })
        #expect(models.contains { $0.id == "test/model2" })
    }

    @Test("allDownloadedModels sorted by date newest first")
    func allDownloadedModelsSorted() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let oldModel = DownloadedDiffusionModel(
            id: "old/model",
            name: "Old Model",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp/old"),
            downloadedAt: Date().addingTimeInterval(-3600),
            sizeBytes: 1_000_000_000
        )

        let newModel = DownloadedDiffusionModel(
            id: "new/model",
            name: "New Model",
            variant: .sd15,
            localPath: URL(fileURLWithPath: "/tmp/new"),
            downloadedAt: Date(),
            sizeBytes: 2_000_000_000
        )

        await registry.addDownloaded(oldModel)
        await registry.addDownloaded(newModel)

        let models = await registry.allDownloadedModels
        #expect(models.first?.id == "new/model")
    }

    @Test("downloadedCount reflects number of models")
    func downloadedCountAccurate() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        var count = await registry.downloadedCount
        #expect(count == 0)

        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        await registry.addDownloaded(model)
        count = await registry.downloadedCount
        #expect(count == 1)
    }

    // MARK: - Management Methods Tests

    @Test("addDownloaded registers model")
    func addDownloadedRegisters() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        await registry.addDownloaded(model)
        let exists = await registry.isDownloaded("test/model")
        #expect(exists == true)
    }

    @Test("addDownloaded overwrites existing model")
    func addDownloadedOverwrites() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model1 = DownloadedDiffusionModel(
            id: "test/model",
            name: "Original",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp/1"),
            sizeBytes: 1_000_000_000
        )

        let model2 = DownloadedDiffusionModel(
            id: "test/model",
            name: "Updated",
            variant: .sd15,
            localPath: URL(fileURLWithPath: "/tmp/2"),
            sizeBytes: 2_000_000_000
        )

        await registry.addDownloaded(model1)
        await registry.addDownloaded(model2)

        let retrieved = await registry.downloadedModel(for: "test/model")
        #expect(retrieved?.name == "Updated")
    }

    @Test("removeDownloaded unregisters model")
    func removeDownloadedUnregisters() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        await registry.addDownloaded(model)
        var exists = await registry.isDownloaded("test/model")
        #expect(exists == true)

        await registry.removeDownloaded("test/model")
        exists = await registry.isDownloaded("test/model")
        #expect(exists == false)
    }

    @Test("removeDownloaded handles non-existent model")
    func removeDownloadedNonExistent() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        await registry.removeDownloaded("non-existent/model")
        let count = await registry.downloadedCount
        #expect(count == 0)
    }

    // MARK: - Size Calculations Tests

    @Test("totalDownloadedSize is zero initially")
    func totalSizeEmpty() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let size = await registry.totalDownloadedSize
        #expect(size == 0)
    }

    @Test("totalDownloadedSize sums all model sizes")
    func totalSizeCalculation() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model1 = DownloadedDiffusionModel(
            id: "test/model1",
            name: "Model 1",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp/1"),
            sizeBytes: 1_000_000_000
        )

        let model2 = DownloadedDiffusionModel(
            id: "test/model2",
            name: "Model 2",
            variant: .sd15,
            localPath: URL(fileURLWithPath: "/tmp/2"),
            sizeBytes: 2_000_000_000
        )

        await registry.addDownloaded(model1)
        await registry.addDownloaded(model2)

        let size = await registry.totalDownloadedSize
        #expect(size == 3_000_000_000)
    }

    @Test("formattedTotalSize provides human-readable string")
    func formattedTotalSizeOutput() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        await registry.addDownloaded(model)
        let formatted = await registry.formattedTotalSize
        #expect(!formatted.isEmpty)
    }

    // MARK: - Clear Tests

    @Test("clearAllRecords removes all models")
    func clearAllRecords() async {
        let registry = DiffusionModelRegistry.shared

        let model = DownloadedDiffusionModel(
            id: "test/model",
            name: "Test",
            variant: .sdxlTurbo,
            localPath: URL(fileURLWithPath: "/tmp"),
            sizeBytes: 1_000_000_000
        )

        await registry.addDownloaded(model)
        var count = await registry.downloadedCount
        #expect(count > 0)

        await registry.clearAllRecords()
        count = await registry.downloadedCount
        #expect(count == 0)
    }

    // MARK: - Actor Isolation Tests

    @Test("Registry is thread-safe")
    func threadSafety() async {
        let registry = DiffusionModelRegistry.shared
        await registry.clearAllRecords()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let model = DownloadedDiffusionModel(
                        id: "test/model\(i)",
                        name: "Model \(i)",
                        variant: .sdxlTurbo,
                        localPath: URL(fileURLWithPath: "/tmp/\(i)"),
                        sizeBytes: 1_000_000_000
                    )
                    await registry.addDownloaded(model)
                }
            }
        }

        let count = await registry.downloadedCount
        #expect(count == 10)
    }
}
