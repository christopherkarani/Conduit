import XCTest
@testable import Conduit

final class GenerationSchemaGoldenTests: XCTestCase {

    @Generable(description: "Represents a book in a library catalog.")
    struct Book: Sendable, Equatable {
        @Guide(description: "Book title", .pattern(#/^[A-Z].*/#))
        let title: String

        @Guide(description: "Number of pages", .range(1...5000))
        let pages: Int

        @Guide(description: "Tags for search", .count(0...10))
        let tags: [String]
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
                  "type" : "integer"
                },
                "tags" : {
                  "$ref" : "#\/$defs\/Swift.Array<Swift.String>"
                },
                "title" : {
                  "description" : "Book title",
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
            "Swift.Array<Swift.String>" : {
              "items" : {
                "type" : "string"
              },
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
