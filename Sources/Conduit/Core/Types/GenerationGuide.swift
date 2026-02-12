import struct Foundation.Decimal
import class Foundation.NSDecimalNumber

/// Guides that control how values are generated.
indirect enum _GenerationGuideConstraint: Sendable {
    case unsupported
    case stringPattern(String)
    case stringAnyOf([String])
    case stringConstant(String)
    case numberMinimum(Double)
    case numberMaximum(Double)
    case numberRange(minimum: Double, maximum: Double)
    case arrayMinimumCount(Int)
    case arrayMaximumCount(Int)
    case arrayCount(Int)
    case arrayCountRange(minimum: Int, maximum: Int)
    case arrayElement(_GenerationGuideConstraint)
}

public struct GenerationGuide<Value>: Sendable {
    let constraint: _GenerationGuideConstraint

    /// Creates a no-op guide.
    ///
    /// This preserves source compatibility for callers that construct guide
    /// values dynamically and append them conditionally.
    public init() {
        self.constraint = .unsupported
    }

    init(constraint: _GenerationGuideConstraint) {
        self.constraint = constraint
    }
}

// MARK: - String Guides

extension GenerationGuide where Value == String {

    /// Enforces that the string follows the pattern.
    public static func pattern(_ pattern: String) -> GenerationGuide<String> {
        GenerationGuide<String>(constraint: .stringPattern(pattern))
    }

    /// Enforces that the string be precisely the given value.
    public static func constant(_ value: String) -> GenerationGuide<String> {
        GenerationGuide<String>(constraint: .stringConstant(value))
    }

    /// Enforces that the string be one of the provided values.
    public static func anyOf(_ values: [String]) -> GenerationGuide<String> {
        precondition(!values.isEmpty, "GenerationGuide.anyOf must contain at least one value")
        return GenerationGuide<String>(constraint: .stringAnyOf(values))
    }

    /// Enforces that the string follows the pattern.
    public static func pattern<Output>(_ regex: Regex<Output>) -> GenerationGuide<String> {
        if #available(macOS 15.0, iOS 18.0, visionOS 2.0, *) {
            if let pattern = regex._literalPattern {
                return GenerationGuide<String>(constraint: .stringPattern(pattern))
            }
        }
        return GenerationGuide<String>(constraint: .unsupported)
    }
}

// MARK: - Int Guides

extension GenerationGuide where Value == Int {

    /// Enforces a minimum value.
    ///
    /// Use a `minimum` generation guide --- whose bounds are inclusive --- to ensure the model produces
    /// a value greater than or equal to some minimum value. For example, you can specify that all characters
    /// in your game start at level 1:
    ///
    /// ```swift
    /// @Generable
    /// struct struct GameCharacter {
    ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
    ///     var name: String
    ///
    ///     @Guide(description: "A level for the character", .minimum(1))
    ///     var level: Int
    /// }
    /// ```
    public static func minimum(_ value: Int) -> GenerationGuide<Int> {
        GenerationGuide<Int>(constraint: .numberMinimum(Double(value)))
    }

    /// Enforces a maximum value.
    ///
    /// Use a `maximum` generation guide --- whose bounds are inclusive --- to ensure the model produces
    /// a value less than or equal to some maximum value. For example, you can specify that the highest level
    /// a character in your game can achieve is 100:
    ///
    /// ```swift
    /// @Generable
    /// struct struct GameCharacter {
    ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
    ///     var name: String
    ///
    ///     @Guide(description: "A level for the character", .maximum(100))
    ///     var level: Int
    /// }
    /// ```
    public static func maximum(_ value: Int) -> GenerationGuide<Int> {
        GenerationGuide<Int>(constraint: .numberMaximum(Double(value)))
    }

    /// Enforces values fall within a range.
    ///
    /// Use a `range` generation guide --- whose bounds are inclusive --- to ensure the model produces a
    /// value that falls within a range. For example, you can specify that the level of characters in your game
    /// are between 1 and 100:
    ///
    /// ```swift
    /// @Generable
    /// struct struct GameCharacter {
    ///     @Guide(description: "A creative name appropriate for a fantasy RPG character")
    ///     var name: String
    ///
    ///     @Guide(description: "A level for the character", .range(1...100))
    ///     var level: Int
    /// }
    /// ```
    public static func range(_ range: ClosedRange<Int>) -> GenerationGuide<Int> {
        GenerationGuide<Int>(
            constraint: .numberRange(minimum: Double(range.lowerBound), maximum: Double(range.upperBound))
        )
    }
}

// MARK: - Float Guides

extension GenerationGuide where Value == Float {

    /// Enforces a minimum value.
    ///
    /// The bounds are inclusive.
    public static func minimum(_ value: Float) -> GenerationGuide<Float> {
        GenerationGuide<Float>(constraint: .numberMinimum(Double(value)))
    }

    /// Enforces a maximum value.
    ///
    /// The bounds are inclusive.
    public static func maximum(_ value: Float) -> GenerationGuide<Float> {
        GenerationGuide<Float>(constraint: .numberMaximum(Double(value)))
    }

    /// Enforces values fall within a range.
    public static func range(_ range: ClosedRange<Float>) -> GenerationGuide<Float> {
        GenerationGuide<Float>(
            constraint: .numberRange(minimum: Double(range.lowerBound), maximum: Double(range.upperBound))
        )
    }
}

// MARK: - Decimal Guides

extension GenerationGuide where Value == Decimal {

    /// Enforces a minimum value.
    ///
    /// The bounds are inclusive.
    public static func minimum(_ value: Decimal) -> GenerationGuide<Decimal> {
        GenerationGuide<Decimal>(
            constraint: .numberMinimum(NSDecimalNumber(decimal: value).doubleValue)
        )
    }

    /// Enforces a maximum value.
    ///
    /// The bounds are inclusive.
    public static func maximum(_ value: Decimal) -> GenerationGuide<Decimal> {
        GenerationGuide<Decimal>(
            constraint: .numberMaximum(NSDecimalNumber(decimal: value).doubleValue)
        )
    }

    /// Enforces values fall within a range.
    public static func range(_ range: ClosedRange<Decimal>) -> GenerationGuide<Decimal> {
        GenerationGuide<Decimal>(
            constraint: .numberRange(
                minimum: NSDecimalNumber(decimal: range.lowerBound).doubleValue,
                maximum: NSDecimalNumber(decimal: range.upperBound).doubleValue
            )
        )
    }
}

// MARK: - Double Guides

extension GenerationGuide where Value == Double {

    /// Enforces a minimum value.
    /// The bounds are inclusive.
    public static func minimum(_ value: Double) -> GenerationGuide<Double> {
        GenerationGuide<Double>(constraint: .numberMinimum(value))
    }

    /// Enforces a maximum value.
    /// The bounds are inclusive.
    public static func maximum(_ value: Double) -> GenerationGuide<Double> {
        GenerationGuide<Double>(constraint: .numberMaximum(value))
    }

    /// Enforces values fall within a range.
    public static func range(_ range: ClosedRange<Double>) -> GenerationGuide<Double> {
        GenerationGuide<Double>(
            constraint: .numberRange(minimum: range.lowerBound, maximum: range.upperBound)
        )
    }
}

// MARK: - Array Guides

extension GenerationGuide {

    /// Enforces a minimum number of elements in the array.
    ///
    /// The bounds are inclusive.
    public static func minimumCount<Element>(_ count: Int) -> GenerationGuide<[Element]>
    where Value == [Element] {
        precondition(count >= 0, "GenerationGuide.minimumCount cannot be negative")
        return GenerationGuide<[Element]>(constraint: .arrayMinimumCount(count))
    }

    /// Enforces a maximum number of elements in the array.
    ///
    /// The bounds are inclusive.
    public static func maximumCount<Element>(_ count: Int) -> GenerationGuide<[Element]>
    where Value == [Element] {
        precondition(count >= 0, "GenerationGuide.maximumCount cannot be negative")
        return GenerationGuide<[Element]>(constraint: .arrayMaximumCount(count))
    }

    /// Enforces that the number of elements in the array fall within a closed range.
    public static func count<Element>(_ range: ClosedRange<Int>) -> GenerationGuide<[Element]>
    where Value == [Element] {
        precondition(range.lowerBound >= 0, "GenerationGuide.count range cannot be negative")
        return GenerationGuide<[Element]>(
            constraint: .arrayCountRange(minimum: range.lowerBound, maximum: range.upperBound)
        )
    }

    /// Enforces that the array has exactly a certain number elements.
    public static func count<Element>(_ count: Int) -> GenerationGuide<[Element]>
    where Value == [Element] {
        precondition(count >= 0, "GenerationGuide.count cannot be negative")
        return GenerationGuide<[Element]>(constraint: .arrayCount(count))
    }

    /// Enforces a guide on the elements within the array.
    public static func element<Element>(_ guide: GenerationGuide<Element>) -> GenerationGuide<
        [Element]
    >
    where Value == [Element] {
        GenerationGuide<[Element]>(constraint: .arrayElement(guide.constraint))
    }
}

// MARK: - Never Array Guides

extension GenerationGuide where Value == [Never] {

    /// Enforces a minimum number of elements in the array.
    ///
    /// Bounds are inclusive.
    ///
    /// - Warning: This overload is only used for macro expansion. Don't call `GenerationGuide<[Never]>.minimumCount(_:)` on your own.
    public static func minimumCount(_ count: Int) -> GenerationGuide<Value> {
        GenerationGuide<Value>(constraint: .arrayMinimumCount(count))
    }

    /// Enforces a maximum number of elements in the array.
    ///
    /// Bounds are inclusive.
    ///
    /// - Warning: This overload is only used for macro expansion. Don't call `GenerationGuide<[Never]>.maximumCount(_:)` on your own.
    public static func maximumCount(_ count: Int) -> GenerationGuide<Value> {
        GenerationGuide<Value>(constraint: .arrayMaximumCount(count))
    }

    /// Enforces that the number of elements in the array fall within a closed range.
    ///
    /// - Warning: This overload is only used for macro expansion. Don't call `GenerationGuide<[Never]>.count(_:)` on your own.
    public static func count(_ range: ClosedRange<Int>) -> GenerationGuide<Value> {
        GenerationGuide<Value>(
            constraint: .arrayCountRange(minimum: range.lowerBound, maximum: range.upperBound)
        )
    }

    /// Enforces that the array has exactly a certain number elements.
    ///
    /// - Warning: This overload is only used for macro expansion. Don't call `GenerationGuide<[Never]>.count(_:)` on your own.
    public static func count(_ count: Int) -> GenerationGuide<Value> {
        GenerationGuide<Value>(constraint: .arrayCount(count))
    }
}
