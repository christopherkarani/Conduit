// GuideMacroTests.swift
// ConduitMacrosTests
//
// Tests for the @Guide marker macro.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import ConduitMacros

// MARK: - GuideMacroTests

@Suite("Guide Macro Tests")
struct GuideMacroTests {

    // MARK: - Test Macros Registry

    private let testMacros: [String: Macro.Type] = [
        "Guide": GuideMacro.self,
    ]

    // MARK: - Peer Metadata Expansion Tests

    @Test("Guide macro with description expands metadata peer")
    func testGuideProducesMetadataPeer() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("A description")
                let value: Int
            }
            """,
            expandedSource: """
            struct Example {
                let value: Int
                private enum __conduitGuideMetadata_value {
                    static let description: String? = "A description"
                    static let rawGuides: [String] = []
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro with description and constraint expands metadata peer")
    func testGuideWithConstraint() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("Rating from 1 to 10", .range(1...10))
                let rating: Int
            }
            """,
            expandedSource: """
            struct Example {
                let rating: Int
                private enum __conduitGuideMetadata_rating {
                    static let description: String? = "Rating from 1 to 10"
                    static let rawGuides: [String] = [".range(1...10)"]
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro with multiple constraints expands metadata peer")
    func testGuideMultipleConstraints() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("Summary text", .minLength(10), .maxLength(500))
                let summary: String
            }
            """,
            expandedSource: """
            struct Example {
                let summary: String
                private enum __conduitGuideMetadata_summary {
                    static let description: String? = "Summary text"
                    static let rawGuides: [String] = [".minLength(10)", ".maxLength(500)"]
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro with anyOf constraint expands metadata peer")
    func testGuideWithAnyOfConstraint() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("Difficulty level", .anyOf(["easy", "medium", "hard"]))
                let difficulty: String
            }
            """,
            expandedSource: """
            struct Example {
                let difficulty: String
                private enum __conduitGuideMetadata_difficulty {
                    static let description: String? = "Difficulty level"
                    static let rawGuides: [String] = [".anyOf([\"easy\", \"medium\", \"hard\"])"]
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro on multiple properties expands one peer per property")
    func testGuideOnMultipleProperties() {
        assertMacroExpansion(
            """
            struct Recipe {
                @Guide("The recipe title")
                let title: String

                @Guide("Cooking time in minutes", .range(1...180))
                let cookingTime: Int

                @Guide("Difficulty level", .anyOf(["easy", "medium", "hard"]))
                let difficulty: String
            }
            """,
            expandedSource: """
            struct Recipe {
                let title: String
                private enum __conduitGuideMetadata_title {
                    static let description: String? = "The recipe title"
                    static let rawGuides: [String] = []
                }
                let cookingTime: Int
                private enum __conduitGuideMetadata_cookingTime {
                    static let description: String? = "Cooking time in minutes"
                    static let rawGuides: [String] = [".range(1...180)"]
                }
                let difficulty: String
                private enum __conduitGuideMetadata_difficulty {
                    static let description: String? = "Difficulty level"
                    static let rawGuides: [String] = [".anyOf([\"easy\", \"medium\", \"hard\"])"]
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro on optional property expands metadata peer")
    func testGuideOnOptionalProperty() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("An optional note")
                let note: String?
            }
            """,
            expandedSource: """
            struct Example {
                let note: String?
                private enum __conduitGuideMetadata_note {
                    static let description: String? = "An optional note"
                    static let rawGuides: [String] = []
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro on array property expands metadata peer")
    func testGuideOnArrayProperty() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("List of tags", .minItems(1), .maxItems(10))
                let tags: [String]
            }
            """,
            expandedSource: """
            struct Example {
                let tags: [String]
                private enum __conduitGuideMetadata_tags {
                    static let description: String? = "List of tags"
                    static let rawGuides: [String] = [".minItems(1)", ".maxItems(10)"]
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }
}
