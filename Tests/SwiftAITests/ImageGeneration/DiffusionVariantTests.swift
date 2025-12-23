// DiffusionVariantTests.swift
// SwiftAI

import Testing
@testable import SwiftAI

@Suite("DiffusionVariant Tests")
struct DiffusionVariantTests {

    // MARK: - Cases Tests

    @Test("All cases exist")
    func allCases() {
        let cases = DiffusionVariant.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.sdxlTurbo))
        #expect(cases.contains(.sd15))
        #expect(cases.contains(.flux))
    }

    // MARK: - Raw Value Tests

    @Test("Raw values are correct")
    func rawValues() {
        #expect(DiffusionVariant.sdxlTurbo.rawValue == "sdxl-turbo")
        #expect(DiffusionVariant.sd15.rawValue == "sd-1.5")
        #expect(DiffusionVariant.flux.rawValue == "flux")
    }

    @Test("Can initialize from raw value")
    func initFromRawValue() {
        #expect(DiffusionVariant(rawValue: "sdxl-turbo") == .sdxlTurbo)
        #expect(DiffusionVariant(rawValue: "sd-1.5") == .sd15)
        #expect(DiffusionVariant(rawValue: "flux") == .flux)
        #expect(DiffusionVariant(rawValue: "invalid") == nil)
    }

    // MARK: - Display Name Tests

    @Test("Display names are human-readable")
    func displayNames() {
        #expect(DiffusionVariant.sdxlTurbo.displayName == "SDXL Turbo")
        #expect(DiffusionVariant.sd15.displayName == "Stable Diffusion 1.5")
        #expect(DiffusionVariant.flux.displayName == "Flux Schnell")
    }

    // MARK: - Default Steps Tests

    @Test("Default steps are appropriate for each variant", arguments: [
        (DiffusionVariant.sdxlTurbo, 4),
        (DiffusionVariant.sd15, 20),
        (DiffusionVariant.flux, 4)
    ])
    func defaultSteps(variant: DiffusionVariant, expectedSteps: Int) {
        #expect(variant.defaultSteps == expectedSteps)
    }

    // MARK: - Size Tests

    @Test("Size in GiB is correct", arguments: [
        (DiffusionVariant.sdxlTurbo, 6.5),
        (DiffusionVariant.sd15, 2.0),
        (DiffusionVariant.flux, 4.0)
    ])
    func sizeGiB(variant: DiffusionVariant, expectedSize: Double) {
        #expect(variant.sizeGiB == expectedSize)
    }

    @Test("Size in bytes is calculated correctly")
    func sizeBytes() {
        // 6.5 GiB = 6.5 * 1024^3 bytes
        #expect(DiffusionVariant.sdxlTurbo.sizeBytes == 6_979_321_856)
        // 2.0 GiB
        #expect(DiffusionVariant.sd15.sizeBytes == 2_147_483_648)
        // 4.0 GiB
        #expect(DiffusionVariant.flux.sizeBytes == 4_294_967_296)
    }

    @Test("Formatted size is correct", arguments: [
        (DiffusionVariant.sdxlTurbo, "6.5 GiB"),
        (DiffusionVariant.sd15, "2.0 GiB"),
        (DiffusionVariant.flux, "4.0 GiB")
    ])
    func formattedSize(variant: DiffusionVariant, expected: String) {
        #expect(variant.formattedSize == expected)
    }

    // MARK: - Resolution Tests

    @Test("Default resolutions are correct")
    func defaultResolutions() {
        #expect(DiffusionVariant.sdxlTurbo.defaultResolution == (1024, 1024))
        #expect(DiffusionVariant.sd15.defaultResolution == (512, 512))
        #expect(DiffusionVariant.flux.defaultResolution == (1024, 1024))
    }

    @Test("Resolution width and height can be accessed separately")
    func resolutionComponents() {
        let resolution = DiffusionVariant.sdxlTurbo.defaultResolution
        #expect(resolution.width == 1024)
        #expect(resolution.height == 1024)
    }

    // MARK: - Guidance Scale Tests

    @Test("Default guidance scales are correct", arguments: [
        (DiffusionVariant.sdxlTurbo, 0.0),
        (DiffusionVariant.sd15, 7.5),
        (DiffusionVariant.flux, 3.5)
    ])
    func defaultGuidanceScale(variant: DiffusionVariant, expected: Double) {
        #expect(variant.defaultGuidanceScale == expected)
    }

    // MARK: - Memory Requirements Tests

    @Test("Minimum memory requirements are correct", arguments: [
        (DiffusionVariant.sdxlTurbo, 8.0),
        (DiffusionVariant.sd15, 4.0),
        (DiffusionVariant.flux, 6.0)
    ])
    func minimumMemoryGB(variant: DiffusionVariant, expected: Double) {
        #expect(variant.minimumMemoryGB == expected)
    }

    // MARK: - Description Tests

    @Test("Model description is informative")
    func modelDescription() {
        #expect(DiffusionVariant.sdxlTurbo.modelDescription.contains("4 steps"))
        #expect(DiffusionVariant.sd15.modelDescription.contains("quantized"))
        #expect(DiffusionVariant.flux.modelDescription.contains("fast"))
    }

    // MARK: - Codable Tests

    @Test("Encodes to JSON correctly", arguments: [
        (DiffusionVariant.sdxlTurbo, "\"sdxl-turbo\""),
        (DiffusionVariant.sd15, "\"sd-1.5\""),
        (DiffusionVariant.flux, "\"flux\"")
    ])
    func encodeToJSON(variant: DiffusionVariant, expectedJSON: String) throws {
        let data = try JSONEncoder().encode(variant)
        let json = String(data: data, encoding: .utf8)
        #expect(json == expectedJSON)
    }

    @Test("Decodes from JSON correctly", arguments: [
        ("\"sdxl-turbo\"", DiffusionVariant.sdxlTurbo),
        ("\"sd-1.5\"", DiffusionVariant.sd15),
        ("\"flux\"", DiffusionVariant.flux)
    ])
    func decodeFromJSON(json: String, expected: DiffusionVariant) throws {
        let data = json.data(using: .utf8)!
        let variant = try JSONDecoder().decode(DiffusionVariant.self, from: data)
        #expect(variant == expected)
    }

    @Test("Decoding invalid JSON throws error")
    func decodeInvalidJSON() throws {
        let json = "\"invalid-variant\""
        let data = json.data(using: .utf8)!

        #expect(throws: Error.self) {
            try JSONDecoder().decode(DiffusionVariant.self, from: data)
        }
    }

    @Test("Round-trip encoding preserves value")
    func roundTripEncoding() throws {
        for variant in DiffusionVariant.allCases {
            let encoded = try JSONEncoder().encode(variant)
            let decoded = try JSONDecoder().decode(DiffusionVariant.self, from: encoded)
            #expect(decoded == variant)
        }
    }

    // MARK: - Identifiable Tests

    @Test("ID matches raw value", arguments: DiffusionVariant.allCases)
    func identifiable(variant: DiffusionVariant) {
        #expect(variant.id == variant.rawValue)
    }

    // MARK: - CustomStringConvertible Tests

    @Test("Description includes key info")
    func description() {
        let desc = DiffusionVariant.sdxlTurbo.description
        #expect(desc.contains("SDXL Turbo"))
        #expect(desc.contains("6.5 GiB"))
        #expect(desc.contains("4 steps"))
    }

    @Test("Description format is consistent", arguments: DiffusionVariant.allCases)
    func descriptionFormat(variant: DiffusionVariant) {
        let desc = variant.description
        // Should contain display name, size, and steps
        #expect(desc.contains(variant.displayName))
        #expect(desc.contains(variant.formattedSize))
        #expect(desc.contains("\(variant.defaultSteps) steps"))
    }

    // MARK: - Sendable Tests

    @Test("DiffusionVariant is Sendable across tasks")
    func sendableAcrossTasks() async {
        let variant = DiffusionVariant.sdxlTurbo

        await Task {
            #expect(variant.rawValue == "sdxl-turbo")
            #expect(variant.displayName == "SDXL Turbo")
        }.value
    }

    // MARK: - Comparison Tests

    @Test("Different variants are not equal")
    func inequalityBetweenVariants() {
        #expect(DiffusionVariant.sdxlTurbo != .sd15)
        #expect(DiffusionVariant.sd15 != .flux)
        #expect(DiffusionVariant.flux != .sdxlTurbo)
    }

    @Test("Same variant is equal")
    func equality() {
        #expect(DiffusionVariant.sdxlTurbo == .sdxlTurbo)
        #expect(DiffusionVariant.sd15 == .sd15)
        #expect(DiffusionVariant.flux == .flux)
    }

    // MARK: - Practical Usage Tests

    @Test("Can switch on variant")
    func switchStatement() {
        let variant = DiffusionVariant.sdxlTurbo
        var name = ""

        switch variant {
        case .sdxlTurbo:
            name = "turbo"
        case .sd15:
            name = "sd15"
        case .flux:
            name = "flux"
        }

        #expect(name == "turbo")
    }

    @Test("Can be used in collections")
    func collections() {
        let variants: Set<DiffusionVariant> = [.sdxlTurbo, .sd15, .flux, .sdxlTurbo]
        #expect(variants.count == 3)  // Set removes duplicate

        let array: [DiffusionVariant] = [.sdxlTurbo, .sd15]
        #expect(array.count == 2)
    }

    @Test("Can be filtered by properties")
    func filtering() {
        let fastVariants = DiffusionVariant.allCases.filter { $0.defaultSteps <= 4 }
        #expect(fastVariants.count == 2)
        #expect(fastVariants.contains(.sdxlTurbo))
        #expect(fastVariants.contains(.flux))
    }
}
