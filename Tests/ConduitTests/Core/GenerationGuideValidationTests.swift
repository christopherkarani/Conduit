import Testing
import ConduitAdvanced

@Suite("GenerationGuide Validation")
struct GenerationGuideValidationTests {
    @Test("String anyOf with empty values degrades to unsupported guide")
    func stringAnyOfEmptyValuesIsIgnored() throws {
        let schema = GenerationSchema(
            type: GeneratedContent.self,
            description: "guide validation",
            properties: [
                .init(
                    name: "status",
                    description: "status",
                    type: String.self,
                    guides: [GenerationGuide<String>.anyOf([])]
                )
            ]
        )

        let json = schema.toJSONString(prettyPrinted: false)
        #expect(json.contains(#""status""#))
        #expect(!json.contains(#""enum":[]"#))
    }

    @Test("Negative array count guides are ignored instead of crashing")
    func negativeArrayGuidesAreIgnored() throws {
        let schema = GenerationSchema(
            type: GeneratedContent.self,
            description: "guide validation",
            properties: [
                .init(
                    name: "items",
                    description: "items",
                    type: [String].self,
                    guides: [
                        GenerationGuide<[String]>.minimumCount(-1),
                        GenerationGuide<[String]>.maximumCount(-2),
                        GenerationGuide<[String]>.count(-3),
                        GenerationGuide<[String]>.count(-2 ... 4),
                    ]
                )
            ]
        )

        let json = schema.toJSONString(prettyPrinted: false)
        #expect(json.contains(#""items""#))
        #expect(!json.contains(#""minItems":"#))
        #expect(!json.contains(#""maxItems":"#))
    }
}
