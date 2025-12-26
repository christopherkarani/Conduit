// SchemaTests.swift
// SwiftAITests

import Foundation
import Testing
import OrderedCollections
@testable import SwiftAI

/// Tests for Schema - Type structure definitions for LLM generation
@Suite("Schema")
struct SchemaTests {

    // MARK: - Schema Construction Tests

    @Suite("Schema Construction")
    struct SchemaConstructionTests {

        @Test("String schema construction")
        func stringSchemaConstruction() {
            let schema = Schema.string(constraints: [])

            if case .string(let constraints) = schema {
                #expect(constraints.isEmpty)
            } else {
                Issue.record("Expected string schema")
            }
        }

        @Test("String schema with constraints")
        func stringSchemaWithConstraints() {
            let schema = Schema.string(constraints: [.pattern("^[a-z]+$")])

            if case .string(let constraints) = schema {
                #expect(constraints.count == 1)
                if case .pattern(let pattern) = constraints[0] {
                    #expect(pattern == "^[a-z]+$")
                } else {
                    Issue.record("Expected pattern constraint")
                }
            } else {
                Issue.record("Expected string schema")
            }
        }

        @Test("Integer schema construction")
        func integerSchemaConstruction() {
            let schema = Schema.integer(constraints: [])

            if case .integer(let constraints) = schema {
                #expect(constraints.isEmpty)
            } else {
                Issue.record("Expected integer schema")
            }
        }

        @Test("Integer schema with range constraint")
        func integerSchemaWithRange() {
            let schema = Schema.integer(constraints: [.range(lowerBound: 0, upperBound: 100)])

            if case .integer(let constraints) = schema {
                #expect(constraints.count == 1)
                if case .range(let lower, let upper) = constraints[0] {
                    #expect(lower == 0)
                    #expect(upper == 100)
                } else {
                    Issue.record("Expected range constraint")
                }
            } else {
                Issue.record("Expected integer schema")
            }
        }

        @Test("Number schema construction")
        func numberSchemaConstruction() {
            let schema = Schema.number(constraints: [])

            if case .number(let constraints) = schema {
                #expect(constraints.isEmpty)
            } else {
                Issue.record("Expected number schema")
            }
        }

        @Test("Boolean schema construction")
        func booleanSchemaConstruction() {
            let schema = Schema.boolean(constraints: [])

            if case .boolean(let constraints) = schema {
                #expect(constraints.isEmpty)
            } else {
                Issue.record("Expected boolean schema")
            }
        }

        @Test("Array schema construction")
        func arraySchemaConstruction() {
            let itemSchema = Schema.string(constraints: [])
            let schema = Schema.array(items: itemSchema, constraints: [])

            if case .array(let items, let constraints) = schema {
                #expect(constraints.isEmpty)
                if case .string = items {
                    // Expected
                } else {
                    Issue.record("Expected string items schema")
                }
            } else {
                Issue.record("Expected array schema")
            }
        }

        @Test("Array schema with count constraint")
        func arraySchemaWithCount() {
            let schema = Schema.array(
                items: .integer(constraints: []),
                constraints: [.count(lowerBound: 1, upperBound: 10)]
            )

            if case .array(_, let constraints) = schema {
                #expect(constraints.count == 1)
                if case .count(let lower, let upper) = constraints[0] {
                    #expect(lower == 1)
                    #expect(upper == 10)
                } else {
                    Issue.record("Expected count constraint")
                }
            } else {
                Issue.record("Expected array schema")
            }
        }

        @Test("Object schema construction")
        func objectSchemaConstruction() {
            let properties: OrderedDictionary<String, Schema.Property> = [
                "name": Schema.Property(schema: .string(constraints: []), description: "The name"),
                "age": Schema.Property(schema: .integer(constraints: []), description: "The age")
            ]

            let schema = Schema.object(
                name: "Person",
                description: "A person record",
                properties: properties
            )

            if case .object(let name, let description, let props) = schema {
                #expect(name == "Person")
                #expect(description == "A person record")
                #expect(props.count == 2)
                #expect(props["name"]?.description == "The name")
                #expect(props["age"]?.description == "The age")
            } else {
                Issue.record("Expected object schema")
            }
        }

        @Test("Optional schema construction")
        func optionalSchemaConstruction() {
            let wrapped = Schema.string(constraints: [])
            let schema = Schema.optional(wrapped: wrapped)

            if case .optional(let inner) = schema {
                if case .string = inner {
                    // Expected
                } else {
                    Issue.record("Expected wrapped string schema")
                }
            } else {
                Issue.record("Expected optional schema")
            }
        }

        @Test("AnyOf schema construction")
        func anyOfSchemaConstruction() {
            let schema = Schema.anyOf(
                name: "StringOrInt",
                description: "Either a string or an integer",
                schemas: [
                    .string(constraints: []),
                    .integer(constraints: [])
                ]
            )

            if case .anyOf(let name, let description, let schemas) = schema {
                #expect(name == "StringOrInt")
                #expect(description == "Either a string or an integer")
                #expect(schemas.count == 2)
            } else {
                Issue.record("Expected anyOf schema")
            }
        }
    }

    // MARK: - Property Tests

    @Suite("Property")
    struct PropertyTests {

        @Test("Property initialization with all fields")
        func propertyFullInit() {
            let property = Schema.Property(
                schema: .string(constraints: []),
                description: "A test property",
                isRequired: true
            )

            #expect(property.description == "A test property")
            #expect(property.isRequired == true)
            if case .string = property.schema {
                // Expected
            } else {
                Issue.record("Expected string schema")
            }
        }

        @Test("Property defaults to required")
        func propertyDefaultsToRequired() {
            let property = Schema.Property(
                schema: .integer(constraints: []),
                description: nil
            )

            #expect(property.isRequired == true)
            #expect(property.description == nil)
        }

        @Test("Optional property")
        func optionalProperty() {
            let property = Schema.Property(
                schema: .optional(wrapped: .string(constraints: [])),
                description: "An optional field",
                isRequired: false
            )

            #expect(property.isRequired == false)
        }

        @Test("Property equality")
        func propertyEquality() {
            let prop1 = Schema.Property(schema: .string(constraints: []), description: "test", isRequired: true)
            let prop2 = Schema.Property(schema: .string(constraints: []), description: "test", isRequired: true)
            let prop3 = Schema.Property(schema: .string(constraints: []), description: "different", isRequired: true)

            #expect(prop1 == prop2)
            #expect(prop1 != prop3)
        }

        @Test("Property is Hashable")
        func propertyHashable() {
            let prop1 = Schema.Property(schema: .string(constraints: []), description: "a", isRequired: true)
            let prop2 = Schema.Property(schema: .string(constraints: []), description: "b", isRequired: true)

            var set: Set<Schema.Property> = []
            set.insert(prop1)
            set.insert(prop2)

            #expect(set.count == 2)
        }
    }

    // MARK: - Constraint Application Tests

    @Suite("Constraint Application")
    struct ConstraintApplicationTests {

        @Test("Apply string constraint to string schema")
        func applyStringConstraint() {
            let schema = Schema.string(constraints: [])
            let constrained = schema.withConstraint(Constraint<String>.pattern("^[a-z]+$"))

            if case .string(let constraints) = constrained {
                #expect(constraints.count == 1)
            } else {
                Issue.record("Expected string schema")
            }
        }

        @Test("Apply integer constraint to integer schema")
        func applyIntegerConstraint() {
            let schema = Schema.integer(constraints: [])
            let constrained = schema.withConstraint(Constraint<Int>.range(0...100))

            if case .integer(let constraints) = constrained {
                #expect(constraints.count == 1)
            } else {
                Issue.record("Expected integer schema")
            }
        }

        @Test("Apply double constraint to number schema")
        func applyDoubleConstraint() {
            let schema = Schema.number(constraints: [])
            let constrained = schema.withConstraint(Constraint<Double>.range(0.0...1.0))

            if case .number(let constraints) = constrained {
                #expect(constraints.count == 1)
            } else {
                Issue.record("Expected number schema")
            }
        }

        @Test("Apply array constraint to array schema")
        func applyArrayConstraint() {
            let schema = Schema.array(items: .string(constraints: []), constraints: [])
            let constrained = schema.withConstraint(Constraint<[String]>.minimumCount(1))

            if case .array(_, let constraints) = constrained {
                #expect(constraints.count == 1)
            } else {
                Issue.record("Expected array schema")
            }
        }

        @Test("Apply multiple constraints")
        func applyMultipleConstraints() {
            let schema = Schema.string(constraints: [])
            let constrained = schema.withConstraints([
                Constraint<String>.minLength(1),
                Constraint<String>.maxLength(100)
            ])

            if case .string(let constraints) = constrained {
                #expect(constraints.count == 2)
            } else {
                Issue.record("Expected string schema")
            }
        }

        @Test("Apply constraint to optional unwraps and applies")
        func applyConstraintToOptional() {
            let schema = Schema.optional(wrapped: .string(constraints: []))
            let constrained = schema.withConstraint(Constraint<String>.minLength(5))

            if case .optional(let wrapped) = constrained {
                if case .string(let constraints) = wrapped {
                    #expect(constraints.count == 1)
                } else {
                    Issue.record("Expected wrapped string schema")
                }
            } else {
                Issue.record("Expected optional schema")
            }
        }

        @Test("Apply element constraint to array items")
        func applyElementConstraint() {
            let schema = Schema.array(items: .integer(constraints: []), constraints: [])
            let constrained = schema.withConstraint(Constraint<[Int]>.element(.range(0...100)))

            if case .array(let items, _) = constrained {
                if case .integer(let constraints) = items {
                    #expect(constraints.count == 1)
                } else {
                    Issue.record("Expected integer items schema")
                }
            } else {
                Issue.record("Expected array schema")
            }
        }
    }

    // MARK: - Unwrapped Property Tests

    @Suite("Unwrapped Property")
    struct UnwrappedPropertyTests {

        @Test("isOptional returns true for optional")
        func isOptionalTrue() {
            let schema = Schema.optional(wrapped: .string(constraints: []))

            #expect(schema.isOptional == true)
        }

        @Test("isOptional returns false for non-optional")
        func isOptionalFalse() {
            let schema = Schema.string(constraints: [])

            #expect(schema.isOptional == false)
        }

        @Test("unwrapped returns inner schema for optional")
        func unwrappedReturnsInner() {
            let schema = Schema.optional(wrapped: .string(constraints: []))

            if case .string = schema.unwrapped {
                // Expected
            } else {
                Issue.record("Expected string schema after unwrap")
            }
        }

        @Test("unwrapped returns self for non-optional")
        func unwrappedReturnsSelf() {
            let schema = Schema.integer(constraints: [])

            if case .integer = schema.unwrapped {
                // Expected
            } else {
                Issue.record("Expected integer schema")
            }
        }

        @Test("unwrapped handles deeply nested optionals")
        func unwrappedDeeplyNested() {
            let schema = Schema.optional(wrapped: .optional(wrapped: .optional(wrapped: .boolean(constraints: []))))

            if case .boolean = schema.unwrapped {
                // Expected
            } else {
                Issue.record("Expected boolean schema after deep unwrap")
            }
        }

        @Test("typeName returns name for object")
        func typeNameObject() {
            let schema = Schema.object(name: "Person", description: nil, properties: [:])

            #expect(schema.typeName == "Person")
        }

        @Test("typeName returns name for anyOf")
        func typeNameAnyOf() {
            let schema = Schema.anyOf(name: "StringOrInt", description: nil, schemas: [])

            #expect(schema.typeName == "StringOrInt")
        }

        @Test("typeName returns name from wrapped optional")
        func typeNameOptionalWrapped() {
            let schema = Schema.optional(wrapped: .object(name: "Person", description: nil, properties: [:]))

            #expect(schema.typeName == "Person")
        }

        @Test("typeName returns nil for primitives")
        func typeNameNilForPrimitives() {
            #expect(Schema.string(constraints: []).typeName == nil)
            #expect(Schema.integer(constraints: []).typeName == nil)
            #expect(Schema.number(constraints: []).typeName == nil)
            #expect(Schema.boolean(constraints: []).typeName == nil)
            #expect(Schema.array(items: .string(constraints: []), constraints: []).typeName == nil)
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable")
    struct CodableTests {

        @Test("String schema round-trip")
        func stringSchemaRoundTrip() throws {
            let original = Schema.string(constraints: [.pattern("^test$")])
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Integer schema round-trip")
        func integerSchemaRoundTrip() throws {
            let original = Schema.integer(constraints: [.range(lowerBound: 0, upperBound: 100)])
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Number schema round-trip")
        func numberSchemaRoundTrip() throws {
            let original = Schema.number(constraints: [.range(lowerBound: 0.0, upperBound: 1.0)])
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Boolean schema round-trip")
        func booleanSchemaRoundTrip() throws {
            let original = Schema.boolean(constraints: [])
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Array schema round-trip")
        func arraySchemaRoundTrip() throws {
            let original = Schema.array(
                items: .string(constraints: []),
                constraints: [.count(lowerBound: 1, upperBound: 10)]
            )
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Object schema round-trip")
        func objectSchemaRoundTrip() throws {
            let original = Schema.object(
                name: "Person",
                description: "A person",
                properties: [
                    "name": Schema.Property(schema: .string(constraints: []), description: "Name"),
                    "age": Schema.Property(schema: .integer(constraints: []), description: "Age")
                ]
            )
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Optional schema round-trip")
        func optionalSchemaRoundTrip() throws {
            let original = Schema.optional(wrapped: .string(constraints: []))
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("AnyOf schema round-trip")
        func anyOfSchemaRoundTrip() throws {
            let original = Schema.anyOf(
                name: "StringOrInt",
                description: "Either type",
                schemas: [.string(constraints: []), .integer(constraints: [])]
            )
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Property round-trip")
        func propertyRoundTrip() throws {
            let original = Schema.Property(
                schema: .string(constraints: []),
                description: "A property",
                isRequired: false
            )
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.Property.self, from: encoded)

            #expect(original == decoded)
        }

        @Test("Complex nested schema round-trip")
        func complexNestedSchemaRoundTrip() throws {
            let original = Schema.object(
                name: "Root",
                description: "Complex type",
                properties: [
                    "items": Schema.Property(
                        schema: .array(
                            items: .object(
                                name: "Item",
                                description: nil,
                                properties: [
                                    "id": Schema.Property(schema: .integer(constraints: []), description: nil),
                                    "name": Schema.Property(schema: .optional(wrapped: .string(constraints: [])), description: nil, isRequired: false)
                                ]
                            ),
                            constraints: []
                        ),
                        description: "List of items"
                    )
                ]
            )
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Schema.self, from: encoded)

            #expect(original == decoded)
        }
    }

    // MARK: - Hashable Tests

    @Suite("Hashable")
    struct HashableTests {

        @Test("Schema is Hashable")
        func schemaHashable() {
            let schema1 = Schema.string(constraints: [])
            let schema2 = Schema.integer(constraints: [])
            let schema3 = Schema.string(constraints: [])

            var set: Set<Schema> = []
            set.insert(schema1)
            set.insert(schema2)
            set.insert(schema3)

            #expect(set.count == 2)
        }

        @Test("Equal schemas have equal hash values")
        func equalSchemasEqualHash() {
            let schema1 = Schema.object(name: "Test", description: "desc", properties: [:])
            let schema2 = Schema.object(name: "Test", description: "desc", properties: [:])

            #expect(schema1.hashValue == schema2.hashValue)
        }

        @Test("Complex schemas hash correctly")
        func complexSchemasHash() {
            let schema = Schema.anyOf(
                name: "Union",
                description: nil,
                schemas: [
                    .string(constraints: [.pattern("^a$")]),
                    .integer(constraints: [.range(lowerBound: 0, upperBound: 10)])
                ]
            )

            // Should not crash and should produce consistent hash
            let hash1 = schema.hashValue
            let hash2 = schema.hashValue
            #expect(hash1 == hash2)
        }
    }

    // MARK: - CustomStringConvertible Tests

    @Suite("Description")
    struct DescriptionTests {

        @Test("String schema description")
        func stringDescription() {
            let schema = Schema.string(constraints: [])
            #expect(schema.description == "String")
        }

        @Test("Integer schema description")
        func integerDescription() {
            let schema = Schema.integer(constraints: [])
            #expect(schema.description == "Int")
        }

        @Test("Number schema description")
        func numberDescription() {
            let schema = Schema.number(constraints: [])
            #expect(schema.description == "Double")
        }

        @Test("Boolean schema description")
        func booleanDescription() {
            let schema = Schema.boolean(constraints: [])
            #expect(schema.description == "Bool")
        }

        @Test("Array schema description")
        func arrayDescription() {
            let schema = Schema.array(items: .string(constraints: []), constraints: [])
            #expect(schema.description == "[String]")
        }

        @Test("Object schema description")
        func objectDescription() {
            let schema = Schema.object(name: "Person", description: nil, properties: [:])
            #expect(schema.description == "Person")
        }

        @Test("Optional schema description")
        func optionalDescription() {
            let schema = Schema.optional(wrapped: .string(constraints: []))
            #expect(schema.description == "String?")
        }

        @Test("AnyOf schema description")
        func anyOfDescription() {
            let schema = Schema.anyOf(name: "MyUnion", description: nil, schemas: [])
            #expect(schema.description == "MyUnion")
        }

        @Test("Nested array description")
        func nestedArrayDescription() {
            let schema = Schema.array(
                items: .array(items: .integer(constraints: []), constraints: []),
                constraints: []
            )
            #expect(schema.description == "[[Int]]")
        }
    }

    // MARK: - Equality Tests

    @Suite("Equality")
    struct EqualityTests {

        @Test("Same schemas are equal")
        func sameSchemasEqual() {
            let schema1 = Schema.string(constraints: [.pattern("^a$")])
            let schema2 = Schema.string(constraints: [.pattern("^a$")])

            #expect(schema1 == schema2)
        }

        @Test("Different schemas are not equal")
        func differentSchemasNotEqual() {
            let schema1 = Schema.string(constraints: [])
            let schema2 = Schema.integer(constraints: [])

            #expect(schema1 != schema2)
        }

        @Test("Same type different constraints not equal")
        func sameTypeDifferentConstraintsNotEqual() {
            let schema1 = Schema.string(constraints: [.pattern("^a$")])
            let schema2 = Schema.string(constraints: [.pattern("^b$")])

            #expect(schema1 != schema2)
        }

        @Test("Object schemas with different names not equal")
        func objectsDifferentNamesNotEqual() {
            let schema1 = Schema.object(name: "Person", description: nil, properties: [:])
            let schema2 = Schema.object(name: "User", description: nil, properties: [:])

            #expect(schema1 != schema2)
        }

        @Test("Object schemas with different properties not equal")
        func objectsDifferentPropertiesNotEqual() {
            let schema1 = Schema.object(
                name: "Test",
                description: nil,
                properties: ["a": Schema.Property(schema: .string(constraints: []), description: nil)]
            )
            let schema2 = Schema.object(
                name: "Test",
                description: nil,
                properties: ["b": Schema.Property(schema: .string(constraints: []), description: nil)]
            )

            #expect(schema1 != schema2)
        }
    }
}
