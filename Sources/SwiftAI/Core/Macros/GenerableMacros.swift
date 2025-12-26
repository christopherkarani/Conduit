// GenerableMacros.swift
// SwiftAI
//
// Public macro declarations for structured output generation.
// These macros mirror Apple's FoundationModels API from iOS 26.

// MARK: - @Generable Macro

/// A macro that generates `Generable` protocol conformance for structs.
///
/// Apply `@Generable` to a struct to enable it as a structured output type
/// for language model generation. The macro generates:
///
/// - A `schema` static property describing the type structure
/// - A `Partial` nested type for streaming responses
/// - An `init(from:)` initializer for parsing structured content
/// - A `generableContent` property for serialization
///
/// ## Basic Usage
///
/// ```swift
/// @Generable
/// struct WeatherReport {
///     let temperature: Int
///     let conditions: String
///     let humidity: Double
/// }
///
/// // Use with any provider
/// let report = try await provider.generate(
///     prompt: "What's the weather?",
///     returning: WeatherReport.self
/// )
/// ```
///
/// ## With Property Guides
///
/// Use `@Guide` to add descriptions and constraints to properties:
///
/// ```swift
/// @Generable
/// struct Recipe {
///     @Guide("The recipe title")
///     let title: String
///
///     @Guide("Cooking time in minutes", .range(1...180))
///     let cookingTime: Int
///
///     @Guide("Difficulty level", .anyOf(["easy", "medium", "hard"]))
///     let difficulty: String
///
///     @Guide("List of ingredients")
///     let ingredients: [String]
/// }
/// ```
///
/// ## Supported Property Types
///
/// - **Primitives**: `String`, `Int`, `Double`, `Bool`
/// - **Optionals**: `String?`, `Int?`, etc.
/// - **Arrays**: `[String]`, `[Int]`, etc.
/// - **Nested**: Other `@Generable` types
///
/// ## Thread Safety
///
/// Generated types are `Sendable` and safe for concurrent use.
///
/// ## Manual Conformance
///
/// For environments without macro support, you can manually conform to
/// `Generable`. See `Generable` protocol documentation for details.
///
/// - Note: This macro mirrors Apple's `@Generable` from FoundationModels (iOS 26+),
///   enabling the same API pattern for cloud providers and older iOS versions.
@attached(member, names: named(schema), named(Partial), named(init(from:)), named(generableContent))
@attached(extension, conformances: Generable)
public macro Generable() = #externalMacro(module: "SwiftAIMacros", type: "GenerableMacro")

// MARK: - @Guide Macro

/// A macro that adds description and constraints to a property in a `@Generable` struct.
///
/// Use `@Guide` to provide additional context to language models about how to
/// generate values for a property. The description and constraints are included
/// in the schema sent to the model.
///
/// ## Basic Usage
///
/// ```swift
/// @Generable
/// struct Person {
///     @Guide("The person's full name")
///     let name: String
///
///     @Guide("Age in years", .range(0...150))
///     let age: Int
/// }
/// ```
///
/// ## Available Constraints
///
/// Different constraint types are available for different property types:
///
/// ### String Constraints
/// - `.pattern(_:)` - Regular expression pattern
/// - `.anyOf(_:)` - Enumerated allowed values
/// - `.minLength(_:)` - Minimum string length
/// - `.maxLength(_:)` - Maximum string length
///
/// ### Numeric Constraints (Int/Double)
/// - `.range(_:)` - Closed range of allowed values
/// - `.minimum(_:)` - Minimum value
/// - `.maximum(_:)` - Maximum value
///
/// ### Array Constraints
/// - `.count(_:)` - Exact element count
/// - `.minimumCount(_:)` - Minimum elements
/// - `.maximumCount(_:)` - Maximum elements
///
/// ## Multiple Constraints
///
/// You can apply multiple constraints to a single property:
///
/// ```swift
/// @Generable
/// struct Password {
///     @Guide("User password", .minLength(8), .maxLength(128), .pattern(".*[A-Z].*"))
///     let password: String
/// }
/// ```
///
/// ## Without Description
///
/// If you only need constraints without a description, pass `nil`:
///
/// ```swift
/// @Guide(nil, .range(1...100))
/// let score: Int
/// ```
///
/// - Parameter description: A natural language description of the property
///   that helps the language model understand what value to generate.
/// - Parameter constraints: Zero or more constraints that validate the generated value.
@attached(peer)
public macro Guide(_ description: String?, _ constraints: Any...) = #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")

/// Convenience overload for `@Guide` with just a description.
@attached(peer)
public macro Guide(_ description: String) = #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")
