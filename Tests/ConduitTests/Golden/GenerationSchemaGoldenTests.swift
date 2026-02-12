import XCTest
@testable import Conduit

final class GenerationSchemaGoldenTests: XCTestCase {

    @Generable(description: "Represents a book in a library catalog.")
    struct Book: Sendable, Equatable {
        @Guide(description: "Book title", .pattern("^[A-Z].*"))
        let title: String

        @Guide(description: "Number of pages", .range(1...5000))
        let pages: Int

        @Guide(description: "Tags for search", .count(0...10))
        let tags: [String]
    }

    @Generable(description: "Validates guided references for repeated complex types.")
    struct GuidedReferenceFixture: Sendable, Equatable {
        @Guide(description: "One required tag", .count(1))
        let primaryTags: [String]

        @Guide(description: "Two required tags", .count(2))
        let secondaryTags: [String]
    }

    @Generable(description: "Covers supported guide constraints.")
    struct GuideCoverage: Sendable, Equatable {
        @Guide(description: "Category identifier", .constant("book"))
        let category: String

        @Guide(description: "Difficulty level", .anyOf(["easy", "medium", "hard"]))
        let difficulty: String

        @Guide(description: "URL slug", .pattern("^[a-z0-9-]+$"))
        let slug: String

        @Guide(description: "Priority score", .minimum(1), .maximum(5))
        let priority: Int

        @Guide(description: "Probability value", .range(0.0...1.0))
        let probability: Double

        @Guide(description: "Two required keywords", .count(2))
        let keywords: [String]

        @Guide(
            description: "One to three scores between 0 and 100",
            .minimumCount(1),
            .maximumCount(3),
            .element(.range(0...100))
        )
        let scores: [Int]
    }

    @Generable(description: "Nested object A with guided tags.")
    struct GuidedNestedA: Sendable, Equatable {
        @Guide(description: "At least one tag", .minimumCount(1))
        let tags: [String]
    }

    @Generable(description: "Nested object B with guided tags.")
    struct GuidedNestedB: Sendable, Equatable {
        @Guide(description: "At most one tag", .maximumCount(1))
        let tags: [String]
    }

    @Generable(description: "Validates guided defs are namespaced for nested collisions.")
    struct GuidedNestedCollisionFixture: Sendable, Equatable {
        let first: GuidedNestedA
        let second: GuidedNestedB
    }

    func testBookSchemaGolden() throws {
        let actual = Book.generationSchema.toJSONString(prettyPrinted: true)

        let expected = #"""
        {
          "$defs" : {
            "ConduitTests.GenerationSchemaGoldenTests.Book" : {
              "additionalProperties" : false,
              "description" : "Represents a book in a library catalog.",
              "properties" : {
                "pages" : {
                  "description" : "Number of pages",
                  "maximum" : 5000,
                  "minimum" : 1,
                  "type" : "integer"
                },
                "tags" : {
                  "$ref" : "#\/$defs\/Swift.Array<Swift.String>__guided__tags__92043084223a14c9"
                },
                "title" : {
                  "description" : "Book title",
                  "pattern" : "^[A-Z].*",
                  "type" : "string"
                }
              },
              "required" : [
                "title",
                "pages",
                "tags"
              ],
              "type" : "object"
            },
            "Swift.Array<Swift.String>__guided__tags__92043084223a14c9" : {
              "items" : {
                "type" : "string"
              },
              "maxItems" : 10,
              "minItems" : 0,
              "type" : "array"
            }
          },
          "$ref" : "#\/$defs\/ConduitTests.GenerationSchemaGoldenTests.Book"
        }
        """#

        XCTAssertEqual(try canonicalJSONString(actual), try canonicalJSONString(expected))
    }

    func testOmitAdditionalPropertiesOmitsKey() throws {
        let schema = Book.generationSchema.withResolvedRoot() ?? Book.generationSchema

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.userInfo[GenerationSchema.omitAdditionalPropertiesKey] = true

        let data = try encoder.encode(schema)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNil(object["additionalProperties"])

        let defs = try XCTUnwrap(object["$defs"] as? [String: Any])
        let book = try XCTUnwrap(defs["ConduitTests.GenerationSchemaGoldenTests.Book"] as? [String: Any])
        XCTAssertNil(book["additionalProperties"])
    }

    func testGuidedReferencesDoNotCollideAcrossSameUnderlyingType() {
        let json = GuidedReferenceFixture.generationSchema.toJSONString(prettyPrinted: true)

        XCTAssertTrue(json.contains("Swift.Array<Swift.String>__guided__primaryTags__"))
        XCTAssertTrue(json.contains("Swift.Array<Swift.String>__guided__secondaryTags__"))
    }

    func testGuidedReferencesDoNotCollideAcrossNestedOwners() throws {
        let schemaJSON = GuidedNestedCollisionFixture.generationSchema.toJSONString(prettyPrinted: false)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(schemaJSON.utf8)) as? [String: Any]
        )
        let defs = try XCTUnwrap(object["$defs"] as? [String: Any])

        let tagsDefKeys = defs.keys.filter { $0.hasPrefix("Swift.Array<Swift.String>__guided__tags__") }
        XCTAssertEqual(tagsDefKeys.count, 2)

        let nestedAName = String(reflecting: GuidedNestedA.self)
        let nestedBName = String(reflecting: GuidedNestedB.self)
        let nestedA = try XCTUnwrap(defs[nestedAName] as? [String: Any])
        let nestedB = try XCTUnwrap(defs[nestedBName] as? [String: Any])
        let nestedARef = try XCTUnwrap(
            ((nestedA["properties"] as? [String: Any])?["tags"] as? [String: Any])?["$ref"] as? String
        )
        let nestedBRef = try XCTUnwrap(
            ((nestedB["properties"] as? [String: Any])?["tags"] as? [String: Any])?["$ref"] as? String
        )

        XCTAssertNotEqual(nestedARef, nestedBRef)
    }

    func testGuideConstraintsAreAppliedToSchema() throws {
        let schemaJSON = GuideCoverage.generationSchema.toJSONString(prettyPrinted: false)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(schemaJSON.utf8)) as? [String: Any]
        )
        let defs = try XCTUnwrap(object["$defs"] as? [String: Any])

        let rootName = "ConduitTests.GenerationSchemaGoldenTests.GuideCoverage"
        let root = try XCTUnwrap(defs[rootName] as? [String: Any])
        let properties = try XCTUnwrap(root["properties"] as? [String: Any])

        let category = try XCTUnwrap(properties["category"] as? [String: Any])
        XCTAssertEqual(category["enum"] as? [String], ["book"])

        let difficulty = try XCTUnwrap(properties["difficulty"] as? [String: Any])
        XCTAssertEqual(difficulty["enum"] as? [String], ["easy", "medium", "hard"])

        let slug = try XCTUnwrap(properties["slug"] as? [String: Any])
        XCTAssertEqual(slug["pattern"] as? String, "^[a-z0-9-]+$")

        let priority = try XCTUnwrap(properties["priority"] as? [String: Any])
        XCTAssertEqual(priority["minimum"] as? Double, 1)
        XCTAssertEqual(priority["maximum"] as? Double, 5)

        let probability = try XCTUnwrap(properties["probability"] as? [String: Any])
        XCTAssertEqual(probability["minimum"] as? Double, 0)
        XCTAssertEqual(probability["maximum"] as? Double, 1)

        let keywordsRef = try XCTUnwrap((properties["keywords"] as? [String: Any])?["$ref"] as? String)
        XCTAssertTrue(keywordsRef.hasPrefix("#/$defs/Swift.Array<Swift.String>__guided__keywords__"))
        let keywordsDefName = String(keywordsRef.dropFirst("#/$defs/".count))
        let keywordsArray = try XCTUnwrap(defs[keywordsDefName] as? [String: Any])
        XCTAssertEqual(keywordsArray["minItems"] as? Int, 2)
        XCTAssertEqual(keywordsArray["maxItems"] as? Int, 2)

        let scoresRef = try XCTUnwrap((properties["scores"] as? [String: Any])?["$ref"] as? String)
        XCTAssertTrue(scoresRef.hasPrefix("#/$defs/Swift.Array<Swift.Int>__guided__scores__"))
        let scoresDefName = String(scoresRef.dropFirst("#/$defs/".count))
        let scoresArray = try XCTUnwrap(defs[scoresDefName] as? [String: Any])
        XCTAssertEqual(scoresArray["minItems"] as? Int, 1)
        XCTAssertEqual(scoresArray["maxItems"] as? Int, 3)
        let scoresItems = try XCTUnwrap(scoresArray["items"] as? [String: Any])
        XCTAssertEqual(scoresItems["minimum"] as? Double, 0)
        XCTAssertEqual(scoresItems["maximum"] as? Double, 100)
    }

    private func canonicalJSONString(_ json: String) throws -> String {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
        let canonical = canonicalizeJSON(object)
        let data = try JSONSerialization.data(withJSONObject: canonical, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func canonicalizeJSON(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var result: [String: Any] = [:]
            result.reserveCapacity(dict.count)

            for (key, rawValue) in dict {
                if key == "required", let required = rawValue as? [String] {
                    result[key] = required.sorted()
                } else {
                    result[key] = canonicalizeJSON(rawValue)
                }
            }
            return result
        }

        if let array = value as? [Any] {
            return array.map { canonicalizeJSON($0) }
        }

        return value
    }
}
