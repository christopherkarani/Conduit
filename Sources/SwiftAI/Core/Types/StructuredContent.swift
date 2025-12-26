// StructuredContent.swift
// SwiftAI

import Foundation

// MARK: - StructuredContentError

/// Errors that can occur when working with structured content.
///
/// These errors provide detailed information about parsing and type conversion
/// failures when working with JSON-like structured data from LLM responses.
///
/// ## Usage
/// ```swift
/// do {
///     let value = try content.string
/// } catch let error as StructuredContentError {
///     switch error {
///     case .typeMismatch(let expected, let actual):
///         print("Expected \(expected), got \(actual)")
///     case .invalidJSON(let details):
///         print("Invalid JSON: \(details)")
///     case .invalidIntegerValue(let value):
///         print("Cannot convert \(value) to Int")
///     case .missingKey(let key):
///         print("Missing required key: \(key)")
///     }
/// }
/// ```
public enum StructuredContentError: Error, Sendable, LocalizedError, Equatable {
    /// Type mismatch when accessing structured content.
    ///
    /// Thrown when attempting to access content as a different type than stored.
    /// - Parameters:
    ///   - expected: The type that was requested.
    ///   - actual: The actual type of the content.
    case typeMismatch(expected: String, actual: String)

    /// Invalid JSON encountered during parsing.
    ///
    /// Thrown when JSON string or data cannot be parsed.
    /// - Parameter details: Description of what made the JSON invalid.
    case invalidJSON(String)

    /// Invalid integer value when converting from Double.
    ///
    /// Thrown when a number cannot be safely converted to Int (e.g., 3.14, Infinity).
    /// - Parameter value: The Double value that could not be converted.
    case invalidIntegerValue(Double)

    /// Missing key when accessing object properties.
    ///
    /// Thrown when attempting to access a key that does not exist in an object.
    /// - Parameter key: The key that was not found.
    case missingKey(String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .typeMismatch(let expected, let actual):
            return "Type mismatch: expected \(expected), but found \(actual)"
        case .invalidJSON(let details):
            return "Invalid JSON: \(details)"
        case .invalidIntegerValue(let value):
            return "Cannot convert \(value) to integer"
        case .missingKey(let key):
            return "Missing required key: '\(key)'"
        }
    }
}

// MARK: - StructuredContent

/// A JSON-like intermediate representation for LLM structured responses.
///
/// `StructuredContent` provides a type-safe way to work with structured data
/// returned by language models. It supports all JSON types (null, bool, number,
/// string, array, object) and provides convenient accessors with proper error handling.
///
/// ## Overview
///
/// Language models can return structured JSON responses when given a schema.
/// `StructuredContent` serves as the intermediate representation before the
/// response is decoded into your custom types.
///
/// ## Usage
///
/// ### Parsing JSON
/// ```swift
/// // From JSON string
/// let content = try StructuredContent(json: """
///     {"name": "Swift", "version": 6.0, "modern": true}
/// """)
///
/// // From JSON data
/// let data = jsonString.data(using: .utf8)!
/// let content = try StructuredContent(data: data)
/// ```
///
/// ### Accessing Values
/// ```swift
/// // Type-safe accessors throw on type mismatch
/// let name = try content.object?["name"]?.string  // "Swift"
/// let version = try content.object?["version"]?.double  // 6.0
/// let isModern = try content.object?["modern"]?.bool  // true
///
/// // Check for null
/// if content.isNull {
///     print("Value is null")
/// }
/// ```
///
/// ### Serialization
/// ```swift
/// let json = try content.toJSON()  // Compact JSON string
/// let data = try content.toData()  // UTF-8 encoded JSON data
/// ```
///
/// ## Thread Safety
///
/// `StructuredContent` is fully `Sendable` and can be safely shared across
/// actor boundaries and concurrent contexts.
public struct StructuredContent: Sendable, Equatable, Hashable {

    // MARK: - Kind

    /// The type and value of structured content.
    ///
    /// Represents all JSON-compatible value types.
    public enum Kind: Sendable, Equatable, Hashable {
        /// JSON null value.
        case null

        /// JSON boolean value.
        case bool(Bool)

        /// JSON number value (stored as Double for maximum precision).
        case number(Double)

        /// JSON string value.
        case string(String)

        /// JSON array of structured content values.
        case array([StructuredContent])

        /// JSON object with string keys and structured content values.
        case object([String: StructuredContent])

        /// The type name of this kind for error messages.
        internal var typeName: String {
            switch self {
            case .null: return "null"
            case .bool: return "bool"
            case .number: return "number"
            case .string: return "string"
            case .array: return "array"
            case .object: return "object"
            }
        }
    }

    // MARK: - Properties

    /// The kind (type and value) of this structured content.
    public let kind: Kind

    // MARK: - Initializers

    /// Creates structured content with a specific kind.
    ///
    /// - Parameter kind: The type and value of the content.
    public init(kind: Kind) {
        self.kind = kind
    }

    /// Creates structured content from a JSON string.
    ///
    /// ## Example
    /// ```swift
    /// let content = try StructuredContent(json: """
    ///     {"users": [{"name": "Alice"}, {"name": "Bob"}]}
    /// """)
    /// ```
    ///
    /// - Parameter json: A valid JSON string.
    /// - Throws: `StructuredContentError.invalidJSON` if parsing fails.
    public init(json: String) throws {
        guard let data = json.data(using: .utf8) else {
            throw StructuredContentError.invalidJSON("Unable to convert string to UTF-8 data")
        }
        try self.init(data: data)
    }

    /// Creates structured content from JSON data.
    ///
    /// ## Example
    /// ```swift
    /// let data = jsonString.data(using: .utf8)!
    /// let content = try StructuredContent(data: data)
    /// ```
    ///
    /// - Parameter data: UTF-8 encoded JSON data.
    /// - Throws: `StructuredContentError.invalidJSON` if parsing fails.
    public init(data: Data) throws {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            self = try StructuredContent.from(jsonObject: jsonObject)
        } catch let error as StructuredContentError {
            throw error
        } catch {
            throw StructuredContentError.invalidJSON(error.localizedDescription)
        }
    }

    // MARK: - Static Factory Methods

    /// Creates a null structured content.
    public static let null = StructuredContent(kind: .null)

    /// Creates a boolean structured content.
    ///
    /// - Parameter value: The boolean value.
    /// - Returns: Structured content containing the boolean.
    public static func bool(_ value: Bool) -> StructuredContent {
        StructuredContent(kind: .bool(value))
    }

    /// Creates a number structured content.
    ///
    /// - Parameter value: The numeric value.
    /// - Returns: Structured content containing the number.
    public static func number(_ value: Double) -> StructuredContent {
        StructuredContent(kind: .number(value))
    }

    /// Creates a number structured content from an integer.
    ///
    /// - Parameter value: The integer value.
    /// - Returns: Structured content containing the number.
    public static func number(_ value: Int) -> StructuredContent {
        StructuredContent(kind: .number(Double(value)))
    }

    /// Creates a string structured content.
    ///
    /// - Parameter value: The string value.
    /// - Returns: Structured content containing the string.
    public static func string(_ value: String) -> StructuredContent {
        StructuredContent(kind: .string(value))
    }

    /// Creates an array structured content.
    ///
    /// - Parameter values: The array of structured content values.
    /// - Returns: Structured content containing the array.
    public static func array(_ values: [StructuredContent]) -> StructuredContent {
        StructuredContent(kind: .array(values))
    }

    /// Creates an object structured content.
    ///
    /// - Parameter properties: The dictionary of string keys to structured content values.
    /// - Returns: Structured content containing the object.
    public static func object(_ properties: [String: StructuredContent]) -> StructuredContent {
        StructuredContent(kind: .object(properties))
    }

    // MARK: - Type-Safe Accessors

    /// Whether this content is null.
    public var isNull: Bool {
        if case .null = kind { return true }
        return false
    }

    /// The string value if this content is a string.
    ///
    /// - Throws: `StructuredContentError.typeMismatch` if not a string.
    public var string: String {
        get throws {
            guard case .string(let value) = kind else {
                throw StructuredContentError.typeMismatch(expected: "string", actual: kind.typeName)
            }
            return value
        }
    }

    /// The integer value if this content is a number.
    ///
    /// - Throws: `StructuredContentError.typeMismatch` if not a number.
    /// - Throws: `StructuredContentError.invalidIntegerValue` if the number cannot be
    ///   safely converted to an integer (e.g., has fractional part or is too large).
    public var int: Int {
        get throws {
            guard case .number(let value) = kind else {
                throw StructuredContentError.typeMismatch(expected: "number", actual: kind.typeName)
            }
            guard value.isFinite else {
                throw StructuredContentError.invalidIntegerValue(value)
            }
            guard value == value.rounded() else {
                throw StructuredContentError.invalidIntegerValue(value)
            }
            guard value >= Double(Int.min) && value <= Double(Int.max) else {
                throw StructuredContentError.invalidIntegerValue(value)
            }
            return Int(value)
        }
    }

    /// The double value if this content is a number.
    ///
    /// - Throws: `StructuredContentError.typeMismatch` if not a number.
    public var double: Double {
        get throws {
            guard case .number(let value) = kind else {
                throw StructuredContentError.typeMismatch(expected: "number", actual: kind.typeName)
            }
            return value
        }
    }

    /// The boolean value if this content is a boolean.
    ///
    /// - Throws: `StructuredContentError.typeMismatch` if not a boolean.
    public var bool: Bool {
        get throws {
            guard case .bool(let value) = kind else {
                throw StructuredContentError.typeMismatch(expected: "bool", actual: kind.typeName)
            }
            return value
        }
    }

    /// The array value if this content is an array.
    ///
    /// - Throws: `StructuredContentError.typeMismatch` if not an array.
    public var array: [StructuredContent] {
        get throws {
            guard case .array(let values) = kind else {
                throw StructuredContentError.typeMismatch(expected: "array", actual: kind.typeName)
            }
            return values
        }
    }

    /// The object value if this content is an object.
    ///
    /// - Throws: `StructuredContentError.typeMismatch` if not an object.
    public var object: [String: StructuredContent] {
        get throws {
            guard case .object(let properties) = kind else {
                throw StructuredContentError.typeMismatch(expected: "object", actual: kind.typeName)
            }
            return properties
        }
    }

    // MARK: - Object Key Access

    /// Accesses a value by key if this content is an object.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value for the key, or `nil` if the key doesn't exist.
    /// - Throws: `StructuredContentError.typeMismatch` if not an object.
    public func value(forKey key: String) throws -> StructuredContent? {
        let obj = try object
        return obj[key]
    }

    /// Accesses a required value by key if this content is an object.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value for the key.
    /// - Throws: `StructuredContentError.typeMismatch` if not an object.
    /// - Throws: `StructuredContentError.missingKey` if the key doesn't exist.
    public func requiredValue(forKey key: String) throws -> StructuredContent {
        let obj = try object
        guard let value = obj[key] else {
            throw StructuredContentError.missingKey(key)
        }
        return value
    }

    // MARK: - Serialization

    /// Converts this structured content to a JSON string.
    ///
    /// ## Example
    /// ```swift
    /// let content = StructuredContent.object([
    ///     "name": .string("Swift"),
    ///     "version": .number(6.0)
    /// ])
    /// let json = try content.toJSON()
    /// // {"name":"Swift","version":6}
    /// ```
    ///
    /// - Returns: A compact JSON string representation.
    /// - Throws: An error if serialization fails.
    public func toJSON() throws -> String {
        let jsonObject = toJSONObject()
        let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
        guard let string = String(data: data, encoding: .utf8) else {
            throw StructuredContentError.invalidJSON("Unable to convert data to UTF-8 string")
        }
        return string
    }

    /// Converts this structured content to JSON data.
    ///
    /// ## Example
    /// ```swift
    /// let content = StructuredContent.object(["key": .string("value")])
    /// let data = try content.toData()
    /// ```
    ///
    /// - Returns: UTF-8 encoded JSON data.
    /// - Throws: An error if serialization fails.
    public func toData() throws -> Data {
        let jsonObject = toJSONObject()
        return try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
    }

    // MARK: - Private Helpers

    /// Converts from a JSONSerialization object to StructuredContent.
    private static func from(jsonObject: Any) throws -> StructuredContent {
        if jsonObject is NSNull {
            return StructuredContent(kind: .null)
        }

        if let bool = jsonObject as? Bool {
            return StructuredContent(kind: .bool(bool))
        }

        if let number = jsonObject as? NSNumber {
            return StructuredContent(kind: .number(number.doubleValue))
        }

        if let string = jsonObject as? String {
            return StructuredContent(kind: .string(string))
        }

        if let array = jsonObject as? [Any] {
            let contents = try array.map { try from(jsonObject: $0) }
            return StructuredContent(kind: .array(contents))
        }

        if let dictionary = jsonObject as? [String: Any] {
            var properties: [String: StructuredContent] = [:]
            for (key, value) in dictionary {
                properties[key] = try from(jsonObject: value)
            }
            return StructuredContent(kind: .object(properties))
        }

        throw StructuredContentError.invalidJSON("Unsupported JSON type: \(type(of: jsonObject))")
    }

    /// Converts to a JSONSerialization-compatible object.
    private func toJSONObject() -> Any {
        switch kind {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .number(let value):
            // Use Int if the value is a whole number for cleaner output
            if value.isFinite && value == value.rounded() && value >= Double(Int.min) && value <= Double(Int.max) {
                return Int(value)
            }
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map { $0.toJSONObject() }
        case .object(let properties):
            var dict: [String: Any] = [:]
            for (key, value) in properties {
                dict[key] = value.toJSONObject()
            }
            return dict
        }
    }
}

// MARK: - Codable

extension StructuredContent: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.kind = .null
            return
        }

        // Try decoding in order of specificity
        if let bool = try? container.decode(Bool.self) {
            self.kind = .bool(bool)
            return
        }

        if let number = try? container.decode(Double.self) {
            self.kind = .number(number)
            return
        }

        if let string = try? container.decode(String.self) {
            self.kind = .string(string)
            return
        }

        if let array = try? container.decode([StructuredContent].self) {
            self.kind = .array(array)
            return
        }

        if let object = try? container.decode([String: StructuredContent].self) {
            self.kind = .object(object)
            return
        }

        throw DecodingError.typeMismatch(
            StructuredContent.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unable to decode StructuredContent"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch kind {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let properties):
            try container.encode(properties)
        }
    }
}

// MARK: - ExpressibleByLiterals

extension StructuredContent: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.kind = .null
    }
}

extension StructuredContent: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.kind = .bool(value)
    }
}

extension StructuredContent: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.kind = .number(Double(value))
    }
}

extension StructuredContent: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.kind = .number(value)
    }
}

extension StructuredContent: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.kind = .string(value)
    }
}

extension StructuredContent: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: StructuredContent...) {
        self.kind = .array(elements)
    }
}

extension StructuredContent: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, StructuredContent)...) {
        var properties: [String: StructuredContent] = [:]
        for (key, value) in elements {
            properties[key] = value
        }
        self.kind = .object(properties)
    }
}

// MARK: - CustomStringConvertible

extension StructuredContent: CustomStringConvertible {
    public var description: String {
        (try? toJSON()) ?? "StructuredContent(\(kind.typeName))"
    }
}

// MARK: - CustomDebugStringConvertible

extension StructuredContent: CustomDebugStringConvertible {
    public var debugDescription: String {
        "StructuredContent(\(kind))"
    }
}
