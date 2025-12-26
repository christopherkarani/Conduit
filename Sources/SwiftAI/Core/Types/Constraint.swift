// Constraint.swift
// SwiftAI
//
// Created for SwiftAI structured output generation.

import Foundation

// MARK: - Constraint

/// A type-safe constraint that can be applied to specific types during generation.
///
/// Constraints provide validation rules and guidance for language model generation.
/// They are used in conjunction with `Schema` to define acceptable values for
/// generated content.
///
/// ## Overview
///
/// Constraints are type-safe and can only be applied to compatible types:
///
/// - `Constraint<String>`: Pattern matching, constant values, enumerated options
/// - `Constraint<Int>`: Numeric ranges with minimum/maximum bounds
/// - `Constraint<Double>`: Floating-point ranges with minimum/maximum bounds
/// - `Constraint<[Element]>`: Array count limits and element constraints
///
/// ## Usage with @Guide Macro
///
/// The most common way to use constraints is with the `@Guide` macro:
///
/// ```swift
/// @Generable
/// struct Product {
///     @Guide(description: "SKU identifier", .pattern("[A-Z]{3}-\\d{4}"))
///     let sku: String
///
///     @Guide(description: "Price in USD", .range(0.01...9999.99))
///     let price: Double
///
///     @Guide(description: "Stock quantity", .minimum(0))
///     let quantity: Int
/// }
/// ```
///
/// ## Usage with Schema
///
/// Constraints can also be applied directly to schemas:
///
/// ```swift
/// let emailSchema = Schema.string(constraints: [])
///     .withConstraint(.pattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"))
///
/// let ageSchema = Schema.integer(constraints: [])
///     .withConstraint(.range(0...150))
/// ```
///
/// ## Thread Safety
///
/// `Constraint` is `Sendable` and safe to use across actor boundaries.
///
/// - SeeAlso: `Schema`, `Generable`, `Guide`
public struct Constraint<Value>: Sendable, Equatable {

    /// The internal payload containing the actual constraint data.
    internal let payload: ConstraintPayload

    /// Internal initializer with payload.
    init(payload: ConstraintPayload) {
        self.payload = payload
    }

    /// Internal initializer with constraint kind.
    init(kind: ConstraintKind) {
        self.payload = .this(kind)
    }
}

// MARK: - Internal Types

/// The constraint payload - either constrains this value or sub-values in collections.
enum ConstraintPayload: Sendable, Equatable {
    /// Constrains this value directly.
    case this(ConstraintKind)

    /// Constrains sub-values (for collections like arrays).
    indirect case sub(AnyConstraint)
}

/// The internal representation of constraint types.
public enum ConstraintKind: Sendable, Equatable {
    /// A constraint applicable to strings.
    case string(StringConstraint)

    /// A constraint applicable to integers.
    case int(IntConstraint)

    /// A constraint applicable to doubles.
    case double(DoubleConstraint)

    /// A constraint applicable to booleans.
    case boolean(BoolConstraint)

    /// A constraint applicable to arrays.
    case array(ArrayConstraint)
}

/// A type-erased constraint for internal use.
///
/// Used to represent constraints within `ConstraintPayload.sub` because
/// enums cannot have generic parameters.
struct AnyConstraint: Sendable, Equatable {

    /// The internal payload.
    let payload: ConstraintPayload

    /// Creates a type-erased constraint from a typed constraint.
    init<Value>(_ constraint: Constraint<Value>) {
        self.payload = constraint.payload
    }

    /// Creates a type-erased constraint from a payload.
    init(payload: ConstraintPayload) {
        self.payload = payload
    }

    /// Creates a type-erased constraint from a constraint kind.
    init(kind: ConstraintKind) {
        self.payload = .this(kind)
    }
}

// MARK: - String Constraints

extension Constraint where Value == String {

    /// Requires the string to match a regular expression pattern.
    ///
    /// The pattern should be a valid regular expression. The language model
    /// will be instructed to generate strings that match this pattern.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Email pattern
    /// @Guide(description: "Email address", .pattern("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"))
    /// let email: String
    ///
    /// // Phone number pattern
    /// @Guide(description: "US phone number", .pattern("^\\d{3}-\\d{3}-\\d{4}$"))
    /// let phone: String
    /// ```
    ///
    /// - Parameter regex: A regular expression pattern string
    /// - Returns: A string constraint requiring the pattern to match
    public static func pattern(_ regex: String) -> Constraint<String> {
        Constraint(kind: .string(.pattern(regex)))
    }

    /// Requires the string to be exactly the specified value.
    ///
    /// Useful for fixed fields that should always have the same value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "API version", .constant("v2"))
    /// let apiVersion: String
    /// ```
    ///
    /// - Parameter value: The exact string value required
    /// - Returns: A string constraint requiring an exact match
    public static func constant(_ value: String) -> Constraint<String> {
        Constraint(kind: .string(.constant(value)))
    }

    /// Requires the string to be one of the specified options.
    ///
    /// Useful for enum-like string fields with a fixed set of valid values.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Current weather", .anyOf(["sunny", "cloudy", "rainy", "snowy"]))
    /// let conditions: String
    ///
    /// @Guide(description: "Priority level", .anyOf(["low", "medium", "high", "critical"]))
    /// let priority: String
    /// ```
    ///
    /// - Parameter options: Array of valid string options
    /// - Returns: A string constraint requiring one of the specified values
    public static func anyOf(_ options: [String]) -> Constraint<String> {
        Constraint(kind: .string(.anyOf(options)))
    }

    /// Sets a minimum length for the string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Username", .minLength(3))
    /// let username: String
    /// ```
    ///
    /// - Parameter length: The minimum number of characters required
    /// - Returns: A string constraint with minimum length
    public static func minLength(_ length: Int) -> Constraint<String> {
        Constraint(kind: .string(.minLength(length)))
    }

    /// Sets a maximum length for the string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Tweet", .maxLength(280))
    /// let tweet: String
    /// ```
    ///
    /// - Parameter length: The maximum number of characters allowed
    /// - Returns: A string constraint with maximum length
    public static func maxLength(_ length: Int) -> Constraint<String> {
        Constraint(kind: .string(.maxLength(length)))
    }
}

// MARK: - Integer Constraints

extension Constraint where Value == Int {

    /// Sets a minimum value for the integer.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Stock quantity", .minimum(0))
    /// let quantity: Int
    ///
    /// @Guide(description: "Adult age", .minimum(18))
    /// let age: Int
    /// ```
    ///
    /// - Parameter value: The minimum allowed value (inclusive)
    /// - Returns: An integer constraint with a lower bound
    public static func minimum(_ value: Int) -> Constraint<Int> {
        Constraint(kind: .int(.range(lowerBound: value, upperBound: nil)))
    }

    /// Sets a maximum value for the integer.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Percentage", .maximum(100))
    /// let percent: Int
    ///
    /// @Guide(description: "Items per page", .maximum(50))
    /// let pageSize: Int
    /// ```
    ///
    /// - Parameter value: The maximum allowed value (inclusive)
    /// - Returns: An integer constraint with an upper bound
    public static func maximum(_ value: Int) -> Constraint<Int> {
        Constraint(kind: .int(.range(lowerBound: nil, upperBound: value)))
    }

    /// Constrains the integer to be within a specific range.
    ///
    /// Both bounds are inclusive.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Human age", .range(0...150))
    /// let age: Int
    ///
    /// @Guide(description: "Month number", .range(1...12))
    /// let month: Int
    /// ```
    ///
    /// - Parameter range: The allowed range (inclusive bounds)
    /// - Returns: An integer constraint with both bounds
    public static func range(_ range: ClosedRange<Int>) -> Constraint<Int> {
        Constraint(kind: .int(.range(lowerBound: range.lowerBound, upperBound: range.upperBound)))
    }
}

// MARK: - Double Constraints

extension Constraint where Value == Double {

    /// Sets a minimum value for the number.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Price", .minimum(0.0))
    /// let price: Double
    ///
    /// @Guide(description: "Rating", .minimum(0.0))
    /// let rating: Double
    /// ```
    ///
    /// - Parameter value: The minimum allowed value (inclusive)
    /// - Returns: A number constraint with a lower bound
    public static func minimum(_ value: Double) -> Constraint<Double> {
        Constraint(kind: .double(.range(lowerBound: value, upperBound: nil)))
    }

    /// Sets a maximum value for the number.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Discount percentage", .maximum(1.0))
    /// let discount: Double
    ///
    /// @Guide(description: "Temperature in Celsius", .maximum(100.0))
    /// let boilingPoint: Double
    /// ```
    ///
    /// - Parameter value: The maximum allowed value (inclusive)
    /// - Returns: A number constraint with an upper bound
    public static func maximum(_ value: Double) -> Constraint<Double> {
        Constraint(kind: .double(.range(lowerBound: nil, upperBound: value)))
    }

    /// Constrains the number to be within a specific range.
    ///
    /// Both bounds are inclusive.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Probability", .range(0.0...1.0))
    /// let probability: Double
    ///
    /// @Guide(description: "GPS latitude", .range(-90.0...90.0))
    /// let latitude: Double
    /// ```
    ///
    /// - Parameter range: The allowed range (inclusive bounds)
    /// - Returns: A number constraint with both bounds
    public static func range(_ range: ClosedRange<Double>) -> Constraint<Double> {
        Constraint(kind: .double(.range(lowerBound: range.lowerBound, upperBound: range.upperBound)))
    }
}

// MARK: - Array Constraints

extension Constraint {

    /// Enforces that the array has exactly a certain number of elements.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "RGB color values", .count(3))
    /// let rgb: [Int]
    ///
    /// @Guide(description: "GPS coordinates", .count(2))
    /// let coordinates: [Double]
    /// ```
    ///
    /// - Parameter count: The exact number of elements required
    /// - Returns: An array constraint with exact count
    public static func count<Element>(_ count: Int) -> Constraint<[Element]>
    where Value == [Element] {
        Constraint(kind: .array(.count(lowerBound: count, upperBound: count)))
    }

    /// Enforces a minimum number of elements in the array.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "At least one ingredient", .minimumCount(1))
    /// let ingredients: [String]
    /// ```
    ///
    /// - Parameter count: The minimum number of elements (inclusive)
    /// - Returns: An array constraint with minimum count
    public static func minimumCount<Element>(_ count: Int) -> Constraint<[Element]>
    where Value == [Element] {
        Constraint(kind: .array(.count(lowerBound: count, upperBound: nil)))
    }

    /// Enforces a maximum number of elements in the array.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Guide(description: "Top 5 results", .maximumCount(5))
    /// let topResults: [String]
    /// ```
    ///
    /// - Parameter count: The maximum number of elements (inclusive)
    /// - Returns: An array constraint with maximum count
    public static func maximumCount<Element>(_ count: Int) -> Constraint<[Element]>
    where Value == [Element] {
        Constraint(kind: .array(.count(lowerBound: nil, upperBound: count)))
    }

    /// Applies a constraint to each element in the array.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Each score must be between 0 and 100
    /// @Guide(description: "Test scores", .element(.range(0...100)))
    /// let scores: [Int]
    ///
    /// // Each tag must match a pattern
    /// @Guide(description: "Hashtags", .element(.pattern("^#[a-zA-Z0-9]+$")))
    /// let tags: [String]
    /// ```
    ///
    /// - Parameter constraint: The constraint to apply to each element
    /// - Returns: An array constraint that applies to elements
    public static func element<Element>(_ constraint: Constraint<Element>) -> Constraint<[Element]>
    where Value == [Element] {
        Constraint(payload: .sub(AnyConstraint(constraint)))
    }
}

// MARK: - Array Constraints for Never Type (Macro Support)

extension Constraint where Value == [Never] {

    /// Enforces a minimum number of elements in the array.
    ///
    /// - Warning: This overload is only used for macro expansion.
    ///   Do not call `Constraint<[Never]>.minimumCount(_:)` directly.
    public static func minimumCount(_ count: Int) -> Constraint<Value> {
        Constraint(kind: .array(.count(lowerBound: count, upperBound: nil)))
    }

    /// Enforces a maximum number of elements in the array.
    ///
    /// - Warning: This overload is only used for macro expansion.
    ///   Do not call `Constraint<[Never]>.maximumCount(_:)` directly.
    public static func maximumCount(_ count: Int) -> Constraint<Value> {
        Constraint(kind: .array(.count(lowerBound: nil, upperBound: count)))
    }

    /// Enforces that the number of elements in the array falls within a closed range.
    ///
    /// Bounds are inclusive.
    ///
    /// - Warning: This overload is only used for macro expansion.
    ///   Do not call `Constraint<[Never]>.count(_:)` directly.
    public static func count(_ range: ClosedRange<Int>) -> Constraint<Value> {
        Constraint(kind: .array(.count(lowerBound: range.lowerBound, upperBound: range.upperBound)))
    }

    /// Enforces that the array has exactly a certain number of elements.
    ///
    /// - Warning: This overload is only used for macro expansion.
    ///   Do not call `Constraint<[Never]>.count(_:)` directly.
    public static func count(_ count: Int) -> Constraint<Value> {
        Constraint(kind: .array(.count(lowerBound: count, upperBound: count)))
    }
}

// MARK: - Constraint Type Definitions

/// Constraints that can be applied to array values.
///
/// These constraints control the size and structure of generated arrays.
public enum ArrayConstraint: Sendable, Equatable {

    /// Constrains the number of elements in the array.
    ///
    /// - Parameters:
    ///   - lowerBound: The minimum number of elements (nil for no minimum)
    ///   - upperBound: The maximum number of elements (nil for no maximum)
    case count(lowerBound: Int?, upperBound: Int?)
}

/// Constraints that can be applied to boolean values.
///
/// Currently a placeholder for future boolean-specific constraints.
public enum BoolConstraint: Sendable, Equatable {}

/// Constraints that can be applied to string values.
///
/// These constraints control the format and content of generated strings.
public enum StringConstraint: Sendable, Equatable {

    /// Requires the string to match a regular expression pattern.
    ///
    /// The language model will be instructed to generate strings
    /// that conform to this pattern.
    case pattern(String)

    /// Requires the string to be exactly the specified value.
    ///
    /// Useful for fixed fields that should always have the same value.
    case constant(String)

    /// Requires the string to be one of the specified options.
    ///
    /// Useful for enum-like string fields with a fixed set of valid values.
    case anyOf([String])

    /// Requires the string to have at least the specified length.
    ///
    /// - Parameter length: The minimum number of characters required.
    case minLength(Int)

    /// Requires the string to have at most the specified length.
    ///
    /// - Parameter length: The maximum number of characters allowed.
    case maxLength(Int)
}

/// Constraints that can be applied to integer values.
///
/// These constraints control the range of generated integers.
public enum IntConstraint: Sendable, Equatable {

    /// Constrains the integer to be within a specific range.
    ///
    /// - Parameters:
    ///   - lowerBound: The minimum value (nil for no minimum)
    ///   - upperBound: The maximum value (nil for no maximum)
    case range(lowerBound: Int?, upperBound: Int?)
}

/// Constraints that can be applied to floating-point values.
///
/// These constraints control the range of generated numbers.
public enum DoubleConstraint: Sendable, Equatable {

    /// Constrains the number to be within a specific range.
    ///
    /// - Parameters:
    ///   - lowerBound: The minimum value (nil for no minimum)
    ///   - upperBound: The maximum value (nil for no maximum)
    case range(lowerBound: Double?, upperBound: Double?)
}

// MARK: - StringConstraint Codable & Hashable

extension StringConstraint: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case values
        case length
    }

    private enum ConstraintType: String, Codable {
        case pattern
        case constant
        case anyOf
        case minLength
        case maxLength
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConstraintType.self, forKey: .type)

        switch type {
        case .pattern:
            let value = try container.decode(String.self, forKey: .value)
            self = .pattern(value)
        case .constant:
            let value = try container.decode(String.self, forKey: .value)
            self = .constant(value)
        case .anyOf:
            let values = try container.decode([String].self, forKey: .values)
            self = .anyOf(values)
        case .minLength:
            let length = try container.decode(Int.self, forKey: .length)
            self = .minLength(length)
        case .maxLength:
            let length = try container.decode(Int.self, forKey: .length)
            self = .maxLength(length)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .pattern(let value):
            try container.encode(ConstraintType.pattern, forKey: .type)
            try container.encode(value, forKey: .value)
        case .constant(let value):
            try container.encode(ConstraintType.constant, forKey: .type)
            try container.encode(value, forKey: .value)
        case .anyOf(let values):
            try container.encode(ConstraintType.anyOf, forKey: .type)
            try container.encode(values, forKey: .values)
        case .minLength(let length):
            try container.encode(ConstraintType.minLength, forKey: .type)
            try container.encode(length, forKey: .length)
        case .maxLength(let length):
            try container.encode(ConstraintType.maxLength, forKey: .type)
            try container.encode(length, forKey: .length)
        }
    }
}

extension StringConstraint: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .pattern(let value):
            hasher.combine("pattern")
            hasher.combine(value)
        case .constant(let value):
            hasher.combine("constant")
            hasher.combine(value)
        case .anyOf(let values):
            hasher.combine("anyOf")
            hasher.combine(values)
        case .minLength(let length):
            hasher.combine("minLength")
            hasher.combine(length)
        case .maxLength(let length):
            hasher.combine("maxLength")
            hasher.combine(length)
        }
    }
}

// MARK: - IntConstraint Codable & Hashable

extension IntConstraint: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case lowerBound
        case upperBound
    }

    private enum ConstraintType: String, Codable {
        case range
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConstraintType.self, forKey: .type)

        switch type {
        case .range:
            let lowerBound = try container.decodeIfPresent(Int.self, forKey: .lowerBound)
            let upperBound = try container.decodeIfPresent(Int.self, forKey: .upperBound)
            self = .range(lowerBound: lowerBound, upperBound: upperBound)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .range(let lowerBound, let upperBound):
            try container.encode(ConstraintType.range, forKey: .type)
            try container.encodeIfPresent(lowerBound, forKey: .lowerBound)
            try container.encodeIfPresent(upperBound, forKey: .upperBound)
        }
    }
}

extension IntConstraint: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .range(let lowerBound, let upperBound):
            hasher.combine("range")
            hasher.combine(lowerBound)
            hasher.combine(upperBound)
        }
    }
}

// MARK: - DoubleConstraint Codable & Hashable

extension DoubleConstraint: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case lowerBound
        case upperBound
    }

    private enum ConstraintType: String, Codable {
        case range
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConstraintType.self, forKey: .type)

        switch type {
        case .range:
            let lowerBound = try container.decodeIfPresent(Double.self, forKey: .lowerBound)
            let upperBound = try container.decodeIfPresent(Double.self, forKey: .upperBound)
            self = .range(lowerBound: lowerBound, upperBound: upperBound)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .range(let lowerBound, let upperBound):
            try container.encode(ConstraintType.range, forKey: .type)
            try container.encodeIfPresent(lowerBound, forKey: .lowerBound)
            try container.encodeIfPresent(upperBound, forKey: .upperBound)
        }
    }
}

extension DoubleConstraint: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .range(let lowerBound, let upperBound):
            hasher.combine("range")
            hasher.combine(lowerBound)
            hasher.combine(upperBound)
        }
    }
}

// MARK: - BoolConstraint Codable & Hashable

extension BoolConstraint: Codable {
    public init(from decoder: Decoder) throws {
        // Empty enum - no cases to decode
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "BoolConstraint has no cases to decode"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        // Empty enum - nothing to encode
    }
}

extension BoolConstraint: Hashable {
    public func hash(into hasher: inout Hasher) {
        // Empty enum - nothing to hash
    }
}

// MARK: - ArrayConstraint Codable & Hashable

extension ArrayConstraint: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case lowerBound
        case upperBound
    }

    private enum ConstraintType: String, Codable {
        case count
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConstraintType.self, forKey: .type)

        switch type {
        case .count:
            let lowerBound = try container.decodeIfPresent(Int.self, forKey: .lowerBound)
            let upperBound = try container.decodeIfPresent(Int.self, forKey: .upperBound)
            self = .count(lowerBound: lowerBound, upperBound: upperBound)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .count(let lowerBound, let upperBound):
            try container.encode(ConstraintType.count, forKey: .type)
            try container.encodeIfPresent(lowerBound, forKey: .lowerBound)
            try container.encodeIfPresent(upperBound, forKey: .upperBound)
        }
    }
}

extension ArrayConstraint: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .count(let lowerBound, let upperBound):
            hasher.combine("count")
            hasher.combine(lowerBound)
            hasher.combine(upperBound)
        }
    }
}
