// AnyCodableTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

@Suite("AnyCodable Tests")
struct AnyCodableTests {

    // MARK: - Value Cases

    @Test("Null value")
    func nullValue() {
        let value = AnyCodable(NSNull())
        #expect(value.value == .null)
        #expect(value.anyValue is NSNull)
    }

    @Test("Bool value")
    func boolValue() {
        let value = AnyCodable(true)
        #expect(value.value == .bool(true))
        #expect(value.anyValue as? Bool == true)
    }

    @Test("Int value")
    func intValue() {
        let value = AnyCodable(42)
        #expect(value.value == .int(42))
        #expect(value.anyValue as? Int == 42)
    }

    @Test("Double value")
    func doubleValue() {
        let value = AnyCodable(3.14)
        #expect(value.value == .double(3.14))
        #expect(value.anyValue as? Double == 3.14)
    }

    @Test("String value")
    func stringValue() {
        let value = AnyCodable("hello")
        #expect(value.value == .string("hello"))
        #expect(value.anyValue as? String == "hello")
    }

    @Test("Array value")
    func arrayValue() {
        let value = AnyCodable([1, 2, 3] as [Any])
        if case .array(let arr) = value.value {
            #expect(arr.count == 3)
        } else {
            Issue.record("Expected array value")
        }
    }

    @Test("Dictionary value")
    func dictionaryValue() {
        let value = AnyCodable(["key": "value"] as [String: Any])
        if case .object(let dict) = value.value {
            #expect(dict["key"]?.value == .string("value"))
        } else {
            Issue.record("Expected object value")
        }
    }

    @Test("Unsupported type falls back to null")
    func unsupportedType() {
        let value = AnyCodable(Date())
        #expect(value.value == .null)
    }

    // MARK: - Value Enum Init

    @Test("Init from Value enum")
    func initFromValueEnum() {
        let value = AnyCodable(value: .string("test"))
        #expect(value.value == .string("test"))
    }

    // MARK: - Codable Round-Trip

    @Test("Null round-trip")
    func nullRoundTrip() throws {
        let original = AnyCodable(value: .null)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value == .null)
    }

    @Test("Bool round-trip")
    func boolRoundTrip() throws {
        let original = AnyCodable(value: .bool(true))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value == .bool(true))
    }

    @Test("Int round-trip")
    func intRoundTrip() throws {
        let original = AnyCodable(value: .int(42))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value == .int(42))
    }

    @Test("Double round-trip")
    func doubleRoundTrip() throws {
        let original = AnyCodable(value: .double(3.14))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value == .double(3.14))
    }

    @Test("String round-trip")
    func stringRoundTrip() throws {
        let original = AnyCodable(value: .string("test"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
        #expect(decoded.value == .string("test"))
    }

    @Test("Array round-trip")
    func arrayRoundTrip() throws {
        let original = AnyCodable(value: .array([
            AnyCodable(value: .int(1)),
            AnyCodable(value: .string("two"))
        ]))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        if case .array(let arr) = decoded.value {
            #expect(arr.count == 2)
            #expect(arr[0].value == .int(1))
            #expect(arr[1].value == .string("two"))
        } else {
            Issue.record("Expected array value")
        }
    }

    @Test("Object round-trip")
    func objectRoundTrip() throws {
        let original = AnyCodable(value: .object([
            "name": AnyCodable(value: .string("test")),
            "count": AnyCodable(value: .int(5))
        ]))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        if case .object(let dict) = decoded.value {
            #expect(dict["name"]?.value == .string("test"))
            #expect(dict["count"]?.value == .int(5))
        } else {
            Issue.record("Expected object value")
        }
    }

    // MARK: - Nested Structures

    @Test("Nested arrays round-trip")
    func nestedArrays() throws {
        let inner = AnyCodable(value: .array([
            AnyCodable(value: .int(1)),
            AnyCodable(value: .int(2))
        ]))
        let original = AnyCodable(value: .array([inner]))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        if case .array(let outer) = decoded.value,
           case .array(let innerArr) = outer[0].value {
            #expect(innerArr.count == 2)
        } else {
            Issue.record("Expected nested array")
        }
    }

    // MARK: - Hashable

    @Test("Equal values have same hash")
    func hashEquality() {
        let a = AnyCodable(value: .string("test"))
        let b = AnyCodable(value: .string("test"))
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different values are unequal")
    func hashInequality() {
        let a = AnyCodable(value: .int(1))
        let b = AnyCodable(value: .int(2))
        #expect(a != b)
    }

    @Test("Can be used in a Set")
    func setUsage() {
        var set: Set<AnyCodable> = []
        set.insert(AnyCodable(value: .string("a")))
        set.insert(AnyCodable(value: .string("b")))
        set.insert(AnyCodable(value: .string("a")))
        #expect(set.count == 2)
    }
}
