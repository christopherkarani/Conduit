// AnthropicInputSchemaResolutionTests.swift
// Conduit
//
// Tests for AnthropicProvider.resolveSchemaRoot — the helper that
// dereferences `$ref` through `$defs` when a `GenerationSchema`'s root
// uses the named-DynamicGenerationSchema encoding (the standard shape
// produced by Tool.toAnthropicFormat() and Swarm's
// ConduitToolSchemaConverter).

#if CONDUIT_TRAIT_ANTHROPIC
import Testing
import Foundation
@testable import ConduitAdvanced

@Suite("Anthropic input_schema $ref resolution")
struct AnthropicInputSchemaResolutionTests {

    @Test("returns the dict unchanged when there is no \\$ref")
    func passThroughForFlatRoot() {
        let dict: [String: Any] = [
            "type": "object",
            "properties": ["name": ["type": "string"]],
            "required": ["name"]
        ]

        let resolved = AnthropicProvider.resolveSchemaRoot(dict)

        #expect(resolved["type"] as? String == "object")
        #expect((resolved["required"] as? [String])?.contains("name") == true)
    }

    @Test("dereferences \\$ref into \\$defs and returns the referenced object")
    func dereferencesRefIntoDefs() {
        let dict: [String: Any] = [
            "$ref": "#/$defs/MyTool",
            "$defs": [
                "MyTool": [
                    "type": "object",
                    "properties": [
                        "label": [
                            "type": "string",
                            "description": "The thing to look up."
                        ]
                    ],
                    "required": ["label"],
                    "additionalProperties": false
                ]
            ]
        ]

        let resolved = AnthropicProvider.resolveSchemaRoot(dict)

        #expect(resolved["type"] as? String == "object")
        let required = resolved["required"] as? [String]
        #expect(required == ["label"])
        let properties = resolved["properties"] as? [String: [String: Any]]
        #expect(properties?["label"]?["type"] as? String == "string")
        #expect(resolved["additionalProperties"] as? Bool == false)
    }

    @Test("falls back to original dict on malformed \\$ref")
    func fallsBackOnMalformedRef() {
        let dict: [String: Any] = [
            "$ref": "https://example.com/foreign-ref",
            "$defs": [
                "MyTool": ["type": "object"]
            ],
            "type": "object",
            "properties": [:]
        ]

        let resolved = AnthropicProvider.resolveSchemaRoot(dict)

        #expect(resolved["type"] as? String == "object", "must return original dict so downstream code still has the type field")
        #expect(resolved["$ref"] as? String == "https://example.com/foreign-ref")
    }

    @Test("falls back to original dict when \\$defs is missing")
    func fallsBackWhenDefsMissing() {
        let dict: [String: Any] = [
            "$ref": "#/$defs/Missing",
            "type": "object"
        ]

        let resolved = AnthropicProvider.resolveSchemaRoot(dict)

        #expect(resolved["$ref"] as? String == "#/$defs/Missing")
        #expect(resolved["type"] as? String == "object")
    }

    @Test("falls back to original dict when referenced name is not in \\$defs")
    func fallsBackWhenReferenceUnresolved() {
        let dict: [String: Any] = [
            "$ref": "#/$defs/NotPresent",
            "$defs": [
                "Other": ["type": "object"]
            ]
        ]

        let resolved = AnthropicProvider.resolveSchemaRoot(dict)

        #expect((resolved["$defs"] as? [String: [String: Any]])?["Other"] != nil)
    }

    /// End-to-end shape check: build a real `GenerationSchema` from a
    /// `DynamicGenerationSchema` with a named root (the shape Conduit's
    /// own `Tool` API and Swarm's `ConduitToolSchemaConverter` emit)
    /// and verify that `resolveSchemaRoot` recovers the inner schema
    /// with its `properties` and `required` fields. Without this fix,
    /// the top-level dict has no `properties` or `required` and
    /// Anthropic gets an empty `input_schema`.
    @Test("dereferences GenerationSchema named-root encoding produced by toJSONSchema()")
    func dereferencesRealGenerationSchemaShape() throws {
        let stringSchema = DynamicGenerationSchema(type: String.self)
        let intSchema = DynamicGenerationSchema(type: Int.self)
        let root = DynamicGenerationSchema(
            name: "ExplainGistConcept",
            description: "Tool parameters for explain_gist_concept",
            properties: [
                DynamicGenerationSchema.Property(
                    name: "label",
                    description: "The gist type label.",
                    schema: stringSchema,
                    isOptional: false
                ),
                DynamicGenerationSchema.Property(
                    name: "limit",
                    description: "Optional truncation cap.",
                    schema: intSchema,
                    isOptional: true
                )
            ]
        )
        let schema = try GenerationSchema(root: root, dependencies: [])
        let raw = schema.toJSONSchema()

        // Sanity: the raw shape really IS $ref-rooted with $defs.
        #expect(raw["$ref"] != nil, "Test premise broken: GenerationSchema with named root no longer emits $ref")
        #expect(raw["properties"] == nil, "Test premise broken: top-level should have no properties before resolution")

        let resolved = AnthropicProvider.resolveSchemaRoot(raw)
        let properties = resolved["properties"] as? [String: [String: Any]]
        let required = resolved["required"] as? [String]

        #expect(properties?["label"]?["type"] as? String == "string")
        #expect(properties?["limit"]?["type"] as? String == "integer")
        #expect(required?.contains("label") == true)
        #expect(required?.contains("limit") == false)
    }

    // MARK: - Nested $ref resolution (PR #57 Codex feedback)

    /// When the resolved root contains property-level `$ref`s pointing
    /// at sibling `$defs` entries, those refs must be inlined too —
    /// otherwise `convertToPropertySchema` (which has no `$defs` table
    /// to follow) falls back to `string` and the model gets the wrong
    /// input schema for nested objects/enums.
    @Test("inlines nested \\$refs that point at sibling \\$defs entries")
    func inlinesNestedRefs() {
        let dict: [String: Any] = [
            "$ref": "#/$defs/Root",
            "$defs": [
                "Root": [
                    "type": "object",
                    "properties": [
                        "user": ["$ref": "#/$defs/User"],
                        "color": ["$ref": "#/$defs/Color"]
                    ],
                    "required": ["user"]
                ],
                "User": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "integer"],
                        "email": ["type": "string"]
                    ],
                    "required": ["id"]
                ],
                "Color": [
                    "type": "string",
                    "enum": ["red", "green", "blue"]
                ]
            ]
        ]

        let resolved = AnthropicProvider.resolveSchemaRoot(dict)

        let properties = resolved["properties"] as? [String: [String: Any]]
        let user = properties?["user"]
        #expect(user?["type"] as? String == "object", "nested object \\$ref must be inlined, not left as {\"$ref\":...}")
        let userProps = user?["properties"] as? [String: [String: Any]]
        #expect(userProps?["id"]?["type"] as? String == "integer")
        #expect((user?["required"] as? [String])?.contains("id") == true)

        let color = properties?["color"]
        #expect(color?["type"] as? String == "string", "nested enum \\$ref must be inlined")
        #expect(color?["enum"] as? [String] == ["red", "green", "blue"])
    }

    /// Items-of-array refs are a real shape (`[T]` where `T` is a
    /// named schema dependency). They must also inline.
    @Test("inlines \\$refs that appear inside `items`")
    func inlinesRefsInArrayItems() {
        let dict: [String: Any] = [
            "$ref": "#/$defs/Root",
            "$defs": [
                "Root": [
                    "type": "object",
                    "properties": [
                        "tags": [
                            "type": "array",
                            "items": ["$ref": "#/$defs/Tag"]
                        ]
                    ]
                ],
                "Tag": [
                    "type": "string",
                    "enum": ["urgent", "blocked"]
                ]
            ]
        ]

        let resolved = AnthropicProvider.resolveSchemaRoot(dict)
        let properties = resolved["properties"] as? [String: [String: Any]]
        let tags = properties?["tags"]
        let items = tags?["items"] as? [String: Any]
        #expect(items?["type"] as? String == "string")
        #expect(items?["enum"] as? [String] == ["urgent", "blocked"])
    }

    /// A self-referential `$ref` (e.g. tree node) must not recurse
    /// forever. The cycle-breaker leaves the inner `$ref` in place;
    /// downstream property conversion will fall back to `string` for
    /// that node, which is the same behavior as before this PR — but
    /// the rest of the schema is still resolved correctly.
    @Test("breaks ref cycles instead of recursing forever")
    func breaksRefCycles() {
        let dict: [String: Any] = [
            "$ref": "#/$defs/Node",
            "$defs": [
                "Node": [
                    "type": "object",
                    "properties": [
                        "value": ["type": "string"],
                        "child": ["$ref": "#/$defs/Node"]
                    ]
                ]
            ]
        ]

        // Should return without hanging.
        let resolved = AnthropicProvider.resolveSchemaRoot(dict)
        let properties = resolved["properties"] as? [String: [String: Any]]
        #expect(properties?["value"]?["type"] as? String == "string")
        // Cycle-broken node still has the unresolved $ref — acceptable.
        #expect(properties?["child"]?["$ref"] as? String == "#/$defs/Node")
    }
}
#endif
