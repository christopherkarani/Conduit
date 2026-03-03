import Testing
@testable import Conduit

@Suite("GeneratedContent")
struct GeneratedContentTests {
    @Test("jsonString serializes finite numbers")
    func jsonStringFiniteNumber() {
        let content = GeneratedContent(kind: .number(42.5))
        #expect(content.jsonString == "42.5")
    }

    @Test("jsonString maps non-finite numbers to null")
    func jsonStringNonFiniteNumber() {
        let content = GeneratedContent(kind: .number(.nan))
        #expect(content.jsonString == "null")
    }
}
