import Foundation
import Testing
@testable import ConduitAdvanced

@Generable
private struct GuideValidationProbe {
    @Guide(description: "labels")
    var labels: [String]

    @Guide(description: "status")
    var status: String
}

@Suite("GenerationGuide Validation")
struct GenerationGuideValidationTests {
    @Test("Empty anyOf guide degrades to no-op")
    func emptyAnyOfGuideIsNoOp() throws {
        let schema = GenerationSchema(
            type: GuideValidationProbe.self,
            properties: [
                .init(
                    name: "status",
                    description: "status",
                    type: String.self,
                    guides: [.anyOf([])]
                )
            ]
        )

        let data = try JSONEncoder().encode(schema)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"status\""))
        #expect(!json.contains("\"enum\""))
    }

    @Test("Negative count guides degrade to no-op")
    func negativeCountGuidesAreNoOp() throws {
        let schema = GenerationSchema(
            type: GuideValidationProbe.self,
            properties: [
                .init(
                    name: "labels",
                    description: "labels",
                    type: [String].self,
                    guides: [
                        .minimumCount(-1),
                        .maximumCount(-2),
                        .count(-3),
                        .count(-4 ... 5),
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(schema)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"labels\""))
        #expect(!json.contains("\"minItems\""))
        #expect(!json.contains("\"maxItems\""))
    }
}
