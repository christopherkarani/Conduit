// PartialToolCallTests.swift
// Conduit Tests
//
// Tests for PartialToolCall struct validation and behavior.

import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("PartialToolCall Tests")
struct PartialToolCallTests {

    // MARK: - Valid Initialization Tests

    @Suite("Valid Initialization")
    struct ValidInitializationTests {

        @Test("Creates partial tool call with valid parameters")
        func createsWithValidParameters() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "get_weather",
                index: 0,
                argumentsFragment: #"{"city": "SF"}"#
            )

            #expect(partial.id == "call_123")
            #expect(partial.toolName == "get_weather")
            #expect(partial.index == 0)
            #expect(partial.argumentsFragment == #"{"city": "SF"}"#)
        }

        @Test("Creates partial tool call with empty arguments fragment")
        func createsWithEmptyArgumentsFragment() {
            let partial = PartialToolCall(
                id: "call_abc",
                toolName: "simple_tool",
                index: 5,
                argumentsFragment: ""
            )

            #expect(partial.id == "call_abc")
            #expect(partial.toolName == "simple_tool")
            #expect(partial.index == 5)
            #expect(partial.argumentsFragment.isEmpty)
        }

        @Test("Creates partial tool call with single character id")
        func createsWithSingleCharacterId() {
            let partial = PartialToolCall(
                id: "x",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.id == "x")
        }

        @Test("Creates partial tool call with single character tool name")
        func createsWithSingleCharacterToolName() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "t",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.toolName == "t")
        }

        @Test("Creates partial tool call with long id")
        func createsWithLongId() {
            let longId = String(repeating: "a", count: 1000)
            let partial = PartialToolCall(
                id: longId,
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.id == longId)
        }

        @Test("Creates partial tool call with long tool name")
        func createsWithLongToolName() {
            let longName = String(repeating: "tool_", count: 200)
            let partial = PartialToolCall(
                id: "call_123",
                toolName: longName,
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.toolName == longName)
        }

        @Test("Creates partial tool call with complex arguments fragment")
        func createsWithComplexArgumentsFragment() {
            let complexFragment = #"{"nested": {"array": [1, 2, {"deep": true}]}, "string": "value"}"#
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "complex_tool",
                index: 0,
                argumentsFragment: complexFragment
            )

            #expect(partial.argumentsFragment == complexFragment)
        }
    }

    // MARK: - Index Boundary Tests

    @Suite("Index Boundary Tests")
    struct IndexBoundaryTests {

        @Test("Index 0 is valid (lower boundary)")
        func indexZeroIsValid() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.index == 0)
        }

        @Test("Index 100 is valid (upper boundary)")
        func indexHundredIsValid() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 100,
                argumentsFragment: "{}"
            )

            #expect(partial.index == 100)
        }

        @Test("Index 50 is valid (middle value)")
        func indexMiddleValueIsValid() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 50,
                argumentsFragment: "{}"
            )

            #expect(partial.index == 50)
        }

        @Test("Index 1 is valid (just above lower boundary)")
        func indexOneIsValid() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 1,
                argumentsFragment: "{}"
            )

            #expect(partial.index == 1)
        }

        @Test("Index 99 is valid (just below upper boundary)")
        func indexNinetyNineIsValid() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 99,
                argumentsFragment: "{}"
            )

            #expect(partial.index == 99)
        }

        // Note: The following preconditions cannot be runtime-tested because they cause crashes:
        // - index < 0 triggers precondition failure
        // - index > 100 triggers precondition failure
        // These preconditions are documented in PartialToolCall.init and should be enforced
        // by callers. The precondition messages are:
        // - "PartialToolCall index must be in range 0...100, got \(index)"
    }

    // MARK: - Precondition Documentation Tests

    @Suite("Precondition Documentation")
    struct PreconditionDocumentationTests {

        // Note: Preconditions cannot be easily tested at runtime because they cause crashes.
        // The following preconditions exist on PartialToolCall.init:
        //
        // 1. Empty id must trigger precondition failure:
        //    precondition(!id.isEmpty, "PartialToolCall id must not be empty")
        //
        // 2. Empty toolName must trigger precondition failure:
        //    precondition(!toolName.isEmpty, "PartialToolCall toolName must not be empty")
        //
        // 3. Index outside 0...100 must trigger precondition failure:
        //    precondition((0...100).contains(index), "PartialToolCall index must be in range 0...100, got \(index)")
        //
        // These tests document the expected behavior without being able to verify it at runtime.

        @Test("Non-empty id satisfies precondition")
        func nonEmptyIdSatisfiesPrecondition() {
            // This test verifies that a non-empty id does not trigger the precondition
            let partial = PartialToolCall(
                id: "valid_id",
                toolName: "tool",
                index: 0,
                argumentsFragment: ""
            )

            #expect(!partial.id.isEmpty)
        }

        @Test("Non-empty tool name satisfies precondition")
        func nonEmptyToolNameSatisfiesPrecondition() {
            // This test verifies that a non-empty toolName does not trigger the precondition
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "valid_tool",
                index: 0,
                argumentsFragment: ""
            )

            #expect(!partial.toolName.isEmpty)
        }

        @Test("Index within range satisfies precondition")
        func indexWithinRangeSatisfiesPrecondition() {
            // This test verifies that an index within 0...100 does not trigger the precondition
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 50,
                argumentsFragment: ""
            )

            #expect((0...100).contains(partial.index))
        }
    }

    // MARK: - Validating Initializer Tests

    @Suite("Validating Initializer")
    struct ValidatingInitializerTests {

        @Test("Validating init returns value for valid input")
        func validatingInitAcceptsValidInput() {
            let partial = PartialToolCall(
                validating: "call_123",
                toolName: "tool",
                index: 1,
                argumentsFragment: "{}"
            )

            #expect(partial != nil)
        }

        @Test("Validating init returns nil for empty id")
        func validatingInitRejectsEmptyId() {
            let partial = PartialToolCall(
                validating: "",
                toolName: "tool",
                index: 1,
                argumentsFragment: "{}"
            )

            #expect(partial == nil)
        }

        @Test("Validating init returns nil for empty tool name")
        func validatingInitRejectsEmptyToolName() {
            let partial = PartialToolCall(
                validating: "call_123",
                toolName: "",
                index: 1,
                argumentsFragment: "{}"
            )

            #expect(partial == nil)
        }

        @Test("Validating init returns nil for out-of-range index")
        func validatingInitRejectsInvalidIndex() {
            let partial = PartialToolCall(
                validating: "call_123",
                toolName: "tool",
                index: 101,
                argumentsFragment: "{}"
            )

            #expect(partial == nil)
        }
    }

    // MARK: - Equatable Conformance Tests

    @Suite("Equatable Conformance")
    struct EquatableConformanceTests {

        @Test("Equal partial tool calls are equal")
        func equalPartialToolCallsAreEqual() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "get_weather",
                index: 0,
                argumentsFragment: #"{"city": "SF"}"#
            )

            let partial2 = PartialToolCall(
                id: "call_123",
                toolName: "get_weather",
                index: 0,
                argumentsFragment: #"{"city": "SF"}"#
            )

            #expect(partial1 == partial2)
        }

        @Test("Partial tool calls with different ids are not equal")
        func differentIdsAreNotEqual() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            let partial2 = PartialToolCall(
                id: "call_456",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial1 != partial2)
        }

        @Test("Partial tool calls with different tool names are not equal")
        func differentToolNamesAreNotEqual() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "tool_a",
                index: 0,
                argumentsFragment: "{}"
            )

            let partial2 = PartialToolCall(
                id: "call_123",
                toolName: "tool_b",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial1 != partial2)
        }

        @Test("Partial tool calls with different indices are not equal")
        func differentIndicesAreNotEqual() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            let partial2 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 1,
                argumentsFragment: "{}"
            )

            #expect(partial1 != partial2)
        }

        @Test("Partial tool calls with different arguments fragments are not equal")
        func differentArgumentsFragmentsAreNotEqual() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: #"{"a": 1}"#
            )

            let partial2 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: #"{"b": 2}"#
            )

            #expect(partial1 != partial2)
        }

        @Test("Partial tool calls with empty vs non-empty arguments are not equal")
        func emptyVsNonEmptyArgumentsAreNotEqual() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: ""
            )

            let partial2 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial1 != partial2)
        }
    }

    // MARK: - Hashable Conformance Tests

    @Suite("Hashable Conformance")
    struct HashableConformanceTests {

        @Test("Equal partial tool calls have same hash")
        func equalPartialToolCallsHaveSameHash() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "get_weather",
                index: 5,
                argumentsFragment: #"{"key": "value"}"#
            )

            let partial2 = PartialToolCall(
                id: "call_123",
                toolName: "get_weather",
                index: 5,
                argumentsFragment: #"{"key": "value"}"#
            )

            #expect(partial1.hashValue == partial2.hashValue)
        }

        @Test("Partial tool call can be stored in Set")
        func canBeStoredInSet() {
            let partial1 = PartialToolCall(
                id: "call_1",
                toolName: "tool_a",
                index: 0,
                argumentsFragment: "{}"
            )

            let partial2 = PartialToolCall(
                id: "call_2",
                toolName: "tool_b",
                index: 1,
                argumentsFragment: "{}"
            )

            let partial3 = PartialToolCall(
                id: "call_1",
                toolName: "tool_a",
                index: 0,
                argumentsFragment: "{}"
            )

            var partialSet: Set<PartialToolCall> = []
            partialSet.insert(partial1)
            partialSet.insert(partial2)
            partialSet.insert(partial3) // Duplicate of partial1

            #expect(partialSet.count == 2)
            #expect(partialSet.contains(partial1))
            #expect(partialSet.contains(partial2))
        }

        @Test("Partial tool call can be used as dictionary key")
        func canBeUsedAsDictionaryKey() {
            let partial1 = PartialToolCall(
                id: "call_1",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            let partial2 = PartialToolCall(
                id: "call_2",
                toolName: "tool",
                index: 1,
                argumentsFragment: "{}"
            )

            var dictionary: [PartialToolCall: String] = [:]
            dictionary[partial1] = "first"
            dictionary[partial2] = "second"

            #expect(dictionary[partial1] == "first")
            #expect(dictionary[partial2] == "second")
            #expect(dictionary.count == 2)
        }

        @Test("Hashing is consistent across multiple calls")
        func hashingIsConsistent() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 42,
                argumentsFragment: #"{"data": "test"}"#
            )

            let hash1 = partial.hashValue
            let hash2 = partial.hashValue
            let hash3 = partial.hashValue

            #expect(hash1 == hash2)
            #expect(hash2 == hash3)
        }
    }

    // MARK: - Sendable Conformance Tests

    @Suite("Sendable Conformance")
    struct SendableConformanceTests {

        @Test("Partial tool call is Sendable")
        func isSendable() async {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            // This test verifies Sendable conformance by passing across actor boundary
            let result = await Task.detached {
                return partial.id
            }.value

            #expect(result == "call_123")
        }

        @Test("Partial tool call can be sent to async context")
        func canBeSentToAsyncContext() async {
            let partial = PartialToolCall(
                id: "call_async",
                toolName: "async_tool",
                index: 10,
                argumentsFragment: #"{"async": true}"#
            )

            let captured = await withCheckedContinuation { continuation in
                Task {
                    continuation.resume(returning: partial)
                }
            }

            #expect(captured == partial)
        }
    }

    // MARK: - Property Accessor Tests

    @Suite("Property Accessors")
    struct PropertyAccessorTests {

        @Test("id property returns correct value")
        func idPropertyReturnsCorrectValue() {
            let partial = PartialToolCall(
                id: "unique_id_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.id == "unique_id_123")
        }

        @Test("toolName property returns correct value")
        func toolNamePropertyReturnsCorrectValue() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "my_special_tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.toolName == "my_special_tool")
        }

        @Test("index property returns correct value")
        func indexPropertyReturnsCorrectValue() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 42,
                argumentsFragment: "{}"
            )

            #expect(partial.index == 42)
        }

        @Test("argumentsFragment property returns correct value")
        func argumentsFragmentPropertyReturnsCorrectValue() {
            let expectedFragment = #"{"location": "NYC", "units": "metric"}"#
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: expectedFragment
            )

            #expect(partial.argumentsFragment == expectedFragment)
        }

        @Test("All properties are immutable")
        func allPropertiesAreImmutable() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 5,
                argumentsFragment: "{}"
            )

            // This test documents that all properties are let constants
            // The struct uses 'let' for all properties, ensuring immutability
            // If any property were 'var', this test would need updating
            #expect(partial.id == "call_123")
            #expect(partial.toolName == "tool")
            #expect(partial.index == 5)
            #expect(partial.argumentsFragment == "{}")
        }
    }

    // MARK: - Edge Case Tests

    @Suite("Edge Cases")
    struct EdgeCaseTests {

        @Test("Arguments fragment with unicode characters")
        func argumentsFragmentWithUnicode() {
            let unicodeFragment = #"{"message": "Hello, \u4e16\u754c"}"#
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: unicodeFragment
            )

            #expect(partial.argumentsFragment == unicodeFragment)
        }

        @Test("Arguments fragment with newlines")
        func argumentsFragmentWithNewlines() {
            let fragmentWithNewlines = """
            {
                "key": "value",
                "nested": {
                    "inner": true
                }
            }
            """
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: fragmentWithNewlines
            )

            #expect(partial.argumentsFragment.contains("\n"))
        }

        @Test("Tool name with underscores and numbers")
        func toolNameWithUnderscoresAndNumbers() {
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "get_weather_v2_beta",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.toolName == "get_weather_v2_beta")
        }

        @Test("Id with special formatting")
        func idWithSpecialFormatting() {
            let partial = PartialToolCall(
                id: "call_abc-123_XYZ",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            #expect(partial.id == "call_abc-123_XYZ")
        }

        @Test("Arguments fragment with escaped quotes")
        func argumentsFragmentWithEscapedQuotes() {
            let fragmentWithEscapes = #"{"text": "He said \"Hello\""}"#
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: fragmentWithEscapes
            )

            #expect(partial.argumentsFragment == fragmentWithEscapes)
        }

        @Test("Arguments fragment representing incomplete JSON")
        func argumentsFragmentIncompleteJSON() {
            // PartialToolCall is designed to hold fragments, which may be incomplete JSON
            let incompleteJSON = #"{"city": "San Fran"#
            let partial = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: incompleteJSON
            )

            #expect(partial.argumentsFragment == incompleteJSON)
        }

        @Test("Multiple partial tool calls with same id but different indices")
        func multiplePartialsWithSameIdDifferentIndices() {
            let partial1 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 0,
                argumentsFragment: "{}"
            )

            let partial2 = PartialToolCall(
                id: "call_123",
                toolName: "tool",
                index: 1,
                argumentsFragment: "{}"
            )

            #expect(partial1 != partial2)
            #expect(partial1.id == partial2.id)
            #expect(partial1.index != partial2.index)
        }
    }
}
