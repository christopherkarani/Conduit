// GenerationSchemaTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("GenerationSchema Node Tests")
struct GenerationSchemaNodeTests {

    // MARK: - Boolean Node

    @Test("Boolean node encodes as type boolean")
    func booleanEncode() throws {
        let node = GenerationSchema.Node.boolean
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"type\":\"boolean\"") || json.contains("\"type\" : \"boolean\""))
    }

    @Test("Boolean node round-trips through Codable")
    func booleanRoundTrip() throws {
        let original = GenerationSchema.Node.boolean
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .boolean = decoded {
            // success
        } else {
            Issue.record("Expected boolean node")
        }
    }

    // MARK: - String Node

    @Test("String node encodes with type string")
    func stringEncode() throws {
        let node = GenerationSchema.Node.string(
            GenerationSchema.StringNode(description: "A name", pattern: nil, enumChoices: nil)
        )
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("string"))
        #expect(json.contains("A name"))
    }

    @Test("String node with enum choices round-trips")
    func stringEnumRoundTrip() throws {
        let original = GenerationSchema.Node.string(
            GenerationSchema.StringNode(
                description: "Color",
                pattern: nil,
                enumChoices: ["red", "green", "blue"]
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .string(let str) = decoded {
            #expect(str.enumChoices == ["red", "green", "blue"])
            #expect(str.description == "Color")
        } else {
            Issue.record("Expected string node")
        }
    }

    @Test("String node with pattern round-trips")
    func stringPatternRoundTrip() throws {
        let original = GenerationSchema.Node.string(
            GenerationSchema.StringNode(
                description: nil,
                pattern: "^[a-z]+$",
                enumChoices: nil
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .string(let str) = decoded {
            #expect(str.pattern == "^[a-z]+$")
        } else {
            Issue.record("Expected string node")
        }
    }

    // MARK: - Number Node

    @Test("Number node encodes as type number")
    func numberEncode() throws {
        let node = GenerationSchema.Node.number(
            GenerationSchema.NumberNode(
                description: "Temperature",
                minimum: 0,
                maximum: 100,
                integerOnly: false
            )
        )
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("number"))
    }

    @Test("Integer-only number node encodes as type integer")
    func integerEncode() throws {
        let node = GenerationSchema.Node.number(
            GenerationSchema.NumberNode(
                description: "Count",
                minimum: nil,
                maximum: nil,
                integerOnly: true
            )
        )
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("integer"))
    }

    @Test("Number node with range round-trips")
    func numberRangeRoundTrip() throws {
        let original = GenerationSchema.Node.number(
            GenerationSchema.NumberNode(
                description: "Score",
                minimum: 1.0,
                maximum: 10.0,
                integerOnly: false
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .number(let num) = decoded {
            #expect(num.minimum == 1.0)
            #expect(num.maximum == 10.0)
            #expect(!num.integerOnly)
            #expect(num.description == "Score")
        } else {
            Issue.record("Expected number node")
        }
    }

    // MARK: - Array Node

    @Test("Array node encodes with items")
    func arrayEncode() throws {
        let node = GenerationSchema.Node.array(
            GenerationSchema.ArrayNode(
                description: "Tags",
                items: .string(GenerationSchema.StringNode(description: nil, pattern: nil, enumChoices: nil)),
                minItems: 1,
                maxItems: 10
            )
        )
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("array"))
    }

    @Test("Array node round-trips with constraints")
    func arrayRoundTrip() throws {
        let original = GenerationSchema.Node.array(
            GenerationSchema.ArrayNode(
                description: nil,
                items: .boolean,
                minItems: 2,
                maxItems: 5
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .array(let arr) = decoded {
            #expect(arr.minItems == 2)
            #expect(arr.maxItems == 5)
            if case .boolean = arr.items {
                // correct
            } else {
                Issue.record("Expected boolean items")
            }
        } else {
            Issue.record("Expected array node")
        }
    }

    // MARK: - Object Node

    @Test("Object node encodes with properties")
    func objectEncode() throws {
        let node = GenerationSchema.Node.object(
            GenerationSchema.ObjectNode(
                description: "A person",
                properties: [
                    "name": .string(GenerationSchema.StringNode(description: nil, pattern: nil, enumChoices: nil)),
                    "age": .number(GenerationSchema.NumberNode(description: nil, minimum: 0, maximum: nil, integerOnly: true))
                ],
                required: ["name", "age"]
            )
        )
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("object"))
        #expect(json.contains("name"))
        #expect(json.contains("age"))
    }

    @Test("Object node round-trips")
    func objectRoundTrip() throws {
        let original = GenerationSchema.Node.object(
            GenerationSchema.ObjectNode(
                description: "Test",
                properties: [
                    "flag": .boolean
                ],
                required: ["flag"]
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .object(let obj) = decoded {
            #expect(obj.description == "Test")
            #expect(obj.properties.count == 1)
            #expect(obj.required.contains("flag"))
        } else {
            Issue.record("Expected object node")
        }
    }

    // MARK: - Ref Node

    @Test("Ref node encodes with $ref prefix")
    func refEncode() throws {
        let node = GenerationSchema.Node.ref("MyType")
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("#/$defs/MyType"))
    }

    @Test("Ref node round-trips")
    func refRoundTrip() throws {
        let original = GenerationSchema.Node.ref("MyType")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .ref(let name) = decoded {
            #expect(name == "MyType")
        } else {
            Issue.record("Expected ref node")
        }
    }

    // MARK: - AnyOf Node

    @Test("AnyOf node encodes with choices")
    func anyOfEncode() throws {
        let node = GenerationSchema.Node.anyOf([.boolean, .ref("Option")])
        let data = try JSONEncoder().encode(node)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("anyOf"))
    }

    @Test("AnyOf node round-trips")
    func anyOfRoundTrip() throws {
        let original = GenerationSchema.Node.anyOf([
            .boolean,
            .string(GenerationSchema.StringNode(description: nil, pattern: nil, enumChoices: nil))
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GenerationSchema.Node.self, from: data)

        if case .anyOf(let nodes) = decoded {
            #expect(nodes.count == 2)
        } else {
            Issue.record("Expected anyOf node")
        }
    }
}

// MARK: - SchemaError Tests

@Suite("GenerationSchema.SchemaError Tests")
struct GenerationSchemaErrorTests {

    @Test("duplicateType has descriptive message")
    func duplicateTypeError() {
        let error = GenerationSchema.SchemaError.duplicateType(
            schema: "root",
            type: "MyType",
            context: .init(debugDescription: "test")
        )
        #expect(error.errorDescription?.contains("MyType") == true)
    }

    @Test("emptyTypeChoices has descriptive message")
    func emptyTypeChoicesError() {
        let error = GenerationSchema.SchemaError.emptyTypeChoices(
            schema: "TestEnum",
            context: .init(debugDescription: "test")
        )
        #expect(error.errorDescription?.contains("TestEnum") == true)
    }

    @Test("undefinedReferences lists missing refs")
    func undefinedReferencesError() {
        let error = GenerationSchema.SchemaError.undefinedReferences(
            schema: "root",
            references: ["Foo", "Bar"],
            context: .init(debugDescription: "test")
        )
        #expect(error.errorDescription?.contains("Foo") == true)
    }

    @Test("All errors have recovery suggestions")
    func recoverySuggestions() {
        let errors: [GenerationSchema.SchemaError] = [
            .duplicateType(schema: nil, type: "T", context: .init(debugDescription: "")),
            .duplicateProperty(schema: "S", property: "p", context: .init(debugDescription: "")),
            .emptyTypeChoices(schema: "S", context: .init(debugDescription: "")),
            .undefinedReferences(schema: nil, references: [], context: .init(debugDescription: ""))
        ]
        for error in errors {
            #expect(error.recoverySuggestion != nil)
        }
    }
}
