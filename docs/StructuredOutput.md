# Structured Output

Generate type-safe responses using the `@Generable` macro. Get Swift types directly from LLM responses instead of parsing JSON manually.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [The @Generable Macro](#the-generable-macro)
- [The @Guide Attribute](#the-guide-attribute)
- [Constraints Reference](#constraints-reference)
- [Streaming Structured Output](#streaming-structured-output)
- [Nested Types](#nested-types)
- [Optional Properties](#optional-properties)
- [Arrays](#arrays)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

---

## Overview

Structured output transforms LLM responses into strongly-typed Swift values:

**Without Structured Output:**
```swift
let response = try await provider.generate("Create a recipe", model: model)
// response is just String - need to parse JSON manually
let json = try JSONDecoder().decode(Recipe.self, from: response.data(using: .utf8)!)
```

**With Structured Output:**
```swift
let recipe = try await provider.generate(
    "Create a recipe",
    returning: Recipe.self,
    model: model
)
// recipe is Recipe - fully typed!
print(recipe.title)       // "Chocolate Chip Cookies"
print(recipe.cookingTime) // 25
```

### How It Works

1. The `@Generable` macro generates a JSON schema from your type
2. The schema is sent to the LLM with your prompt
3. The LLM generates valid JSON matching the schema
4. Conduit parses the JSON into your Swift type

---

## Quick Start

### Define a Generable Type

```swift
import Conduit

@Generable
struct Recipe {
    @Guide("The recipe name")
    let title: String

    @Guide("Cooking time in minutes", .range(1...180))
    let cookingTime: Int

    @Guide("List of ingredients needed")
    let ingredients: [String]
}
```

### Generate a Response

```swift
let provider = AnthropicProvider(apiKey: "sk-ant-...")

let recipe = try await provider.generate(
    "Create a recipe for chocolate chip cookies",
    returning: Recipe.self,
    model: .claudeSonnet45
)

print(recipe.title)        // "Classic Chocolate Chip Cookies"
print(recipe.cookingTime)  // 25
print(recipe.ingredients)  // ["flour", "butter", "chocolate chips", ...]
```

---

## The @Generable Macro

The `@Generable` macro automatically generates:

- `static var schema: Schema` - JSON schema for the LLM
- `struct Partial` - For streaming partial responses
- `init(from: StructuredContent)` - Deserialization
- `var generableContent: StructuredContent` - Serialization

### Basic Usage

```swift
@Generable
struct Person {
    let name: String
    let age: Int
    let email: String
}
```

### Supported Types

| Swift Type | Schema Type |
|------------|-------------|
| `String` | string |
| `Int` | integer |
| `Double` | number |
| `Bool` | boolean |
| `[T]` (Array) | array |
| `T?` (Optional) | nullable |
| Nested `@Generable` | object |

---

## The @Guide Attribute

Use `@Guide` to add descriptions and constraints that help the LLM generate accurate responses:

### Description Only

```swift
@Generable
struct Product {
    @Guide("The product name")
    let name: String

    @Guide("Price in USD")
    let price: Double
}
```

### With Constraints

```swift
@Generable
struct User {
    @Guide("Username in lowercase letters, numbers, and underscores", .pattern("^[a-z0-9_]+$"))
    let username: String

    @Guide("User's age", .range(0...150))
    let age: Int
}
```

### Why Descriptions Matter

Good descriptions guide the LLM:

```swift
// Vague - LLM might not understand format
let date: String

// Clear - LLM knows what to generate
@Guide("Date in ISO 8601 format (YYYY-MM-DD)")
let date: String
```

---

## Constraints Reference

### String Constraints

| Constraint | Description | Example |
|------------|-------------|---------|
| `.pattern(_:)` | Regex pattern | `.pattern("^[A-Z]{2}\\d{4}$")` |
| `.anyOf(_:)` | Enum values | `.anyOf(["red", "green", "blue"])` |
| `.constant(_:)` | Fixed value | `.constant("v2")` |

```swift
@Generable
struct Ticket {
    @Guide("Ticket ID", .pattern("^TKT-\\d{6}$"))
    let id: String

    @Guide("Priority level", .anyOf(["low", "medium", "high", "critical"]))
    let priority: String

    @Guide("Schema version marker", .constant("v2"))
    let description: String
}
```

### Integer Constraints

| Constraint | Description | Example |
|------------|-------------|---------|
| `.range(_:)` | Value range | `.range(1...100)` |
| `.minimum(_:)` | Minimum value | `.minimum(0)` |
| `.maximum(_:)` | Maximum value | `.maximum(1000)` |

```swift
@Generable
struct Rating {
    @Guide("Score from 1 to 5", .range(1...5))
    let score: Int

    @Guide("Positive review count", .minimum(0))
    let positiveCount: Int
}
```

### Double Constraints

| Constraint | Description | Example |
|------------|-------------|---------|
| `.range(_:)` | Value range | `.range(0.0...1.0)` |
| `.minimum(_:)` | Minimum value | `.minimum(0.0)` |
| `.maximum(_:)` | Maximum value | `.maximum(100.0)` |

```swift
@Generable
struct Measurement {
    @Guide("Temperature in Celsius", .range(-50.0...50.0))
    let temperature: Double

    @Guide("Humidity percentage", .range(0.0...100.0))
    let humidity: Double
}
```

### Array Constraints

| Constraint | Description | Example |
|------------|-------------|---------|
| `.count(_:)` | Exact count | `.count(3)` |
| `.minimumCount(_:)` | Minimum items | `.minimumCount(1)` |
| `.maximumCount(_:)` | Maximum items | `.maximumCount(10)` |
| `.element(_:)` | Element constraint | `.element(.range(0...100))` |

```swift
@Generable
struct Quiz {
    @Guide("Exactly 5 questions", .count(5))
    let questions: [String]

    @Guide("1-10 answers", .minimumCount(1), .maximumCount(10))
    let answers: [String]

    @Guide("Scores 0-100", .element(.range(0...100)))
    let scores: [Int]
}
```

---

## Streaming Structured Output

Get progressive updates as the response generates:

### Basic Streaming

```swift
@Generable
struct Article {
    let title: String
    let summary: String
    let sections: [String]
}

let stream = provider.stream(
    "Write an article about Swift",
    returning: Article.self,
    model: .claudeSonnet45
)

for try await partial in stream {
    // Properties become available as they're generated
    if let title = partial.title {
        print("Title: \(title)")
    }
    if let summary = partial.summary {
        print("Summary: \(summary)")
    }
}

// Get final complete result
let article = try await stream.collect()
```

### SwiftUI Integration

```swift
struct ArticleView: View {
    @State private var title: String?
    @State private var summary: String?

    var body: some View {
        VStack {
            if let title {
                Text(title).font(.headline)
            }
            if let summary {
                Text(summary)
            }
        }
        .task {
            await generateArticle()
        }
    }

    func generateArticle() async {
        let stream = provider.stream(
            "Write about SwiftUI",
            returning: Article.self,
            model: model
        )

        do {
            let result = try await stream.reduceOnMain { partial in
                self.title = partial.title
                self.summary = partial.summary
            }
            // Final result available
        } catch {
            // Handle error
        }
    }
}
```

---

## Nested Types

Compose complex structures with nested Generable types:

```swift
@Generable
struct Address {
    @Guide("Street address")
    let street: String

    @Guide("City name")
    let city: String

    @Guide("ZIP/Postal code")
    let zipCode: String
}

@Generable
struct Person {
    @Guide("Full name")
    let name: String

    @Guide("Home address")
    let address: Address

    @Guide("Work address (if applicable)")
    let workAddress: Address?
}

// Usage
let person = try await provider.generate(
    "Create a fictional person with home and work addresses",
    returning: Person.self,
    model: model
)

print(person.name)
print(person.address.city)
print(person.workAddress?.city)
```

### Arrays of Nested Types

```swift
@Generable
struct Team {
    @Guide("Team name")
    let name: String

    @Guide("Team members")
    let members: [Person]
}
```

---

## Optional Properties

Use optionals for fields that might not always be present:

```swift
@Generable
struct MovieReview {
    @Guide("Movie title")
    let title: String

    @Guide("Rating from 1-10", .range(1...10))
    let rating: Int

    @Guide("Review text (optional)")
    let review: String?

    @Guide("Spoiler warning")
    let containsSpoilers: Bool?
}
```

### Default Values

Swift default values are not supported in `@Generable`. Use optionals instead:

```swift
// Don't do this
@Generable
struct Config {
    let timeout: Int = 30  // Won't work as expected
}

// Do this instead
@Generable
struct Config {
    @Guide("Timeout in seconds (defaults to 30 if not specified)")
    let timeout: Int?
}
```

---

## Arrays

### Simple Arrays

```swift
@Generable
struct Playlist {
    @Guide("Playlist name")
    let name: String

    @Guide("Song titles")
    let songs: [String]
}
```

### Constrained Arrays

```swift
@Generable
struct TopPicks {
    @Guide("Top 5 recommendations", .count(5))
    let recommendations: [String]

    @Guide("At least 3 reasons", .minimumCount(3))
    let reasons: [String]
}
```

### Arrays of Complex Types

```swift
@Generable
struct MenuItem {
    let name: String
    let price: Double
    let vegetarian: Bool
}

@Generable
struct Menu {
    @Guide("Restaurant name")
    let restaurant: String

    @Guide("Available dishes", .minimumCount(1))
    let items: [MenuItem]
}
```

---

## Best Practices

### 1. Write Clear Descriptions

```swift
// Good - specific and clear
@Guide("User's birth date in YYYY-MM-DD format")
let birthDate: String

// Bad - vague
@Guide("Date")
let birthDate: String
```

### 2. Use Constraints Appropriately

```swift
// Good - prevents invalid data
@Guide("Rating", .range(1...5))
let rating: Int

// Bad - allows any integer
let rating: Int
```

### 3. Keep Types Focused

```swift
// Good - single responsibility
@Generable struct OrderSummary { ... }
@Generable struct CustomerInfo { ... }

// Bad - too many concerns
@Generable struct EverythingAboutOrder {
    // 20+ fields...
}
```

### 4. Use Enums via anyOf

```swift
@Guide("Status", .anyOf(["pending", "approved", "rejected"]))
let status: String
```

### 5. Validate After Generation

```swift
let result = try await provider.generate(prompt, returning: Order.self, model: model)

// Additional validation
guard result.total > 0 else {
    throw ValidationError.invalidTotal
}
```

---

## Common Patterns

### Enum-like Strings

```swift
@Generable
struct Task {
    @Guide("Priority level", .anyOf(["low", "medium", "high"]))
    let priority: String

    @Guide("Current status", .anyOf(["todo", "in_progress", "done"]))
    let status: String
}
```

### Classification

```swift
@Generable
struct Classification {
    @Guide("Category", .anyOf(["spam", "ham", "promotional"]))
    let category: String

    @Guide("Confidence score 0-1", .range(0.0...1.0))
    let confidence: Double
}

let result = try await provider.generate(
    "Classify this email: '\(emailText)'",
    returning: Classification.self,
    model: model
)
```

### Extraction

```swift
@Generable
struct ContactInfo {
    @Guide("Full name if mentioned")
    let name: String?

    @Guide("Email address if found")
    let email: String?

    @Guide("Phone number if found")
    let phone: String?
}

let info = try await provider.generate(
    "Extract contact information from: '\(text)'",
    returning: ContactInfo.self,
    model: model
)
```

### Summarization

```swift
@Generable
struct Summary {
    @Guide("One-line summary up to 100 characters", .pattern("^.{1,100}$"))
    let headline: String

    @Guide("Key points", .minimumCount(3), .maximumCount(5))
    let keyPoints: [String]

    @Guide("Sentiment", .anyOf(["positive", "negative", "neutral"]))
    let sentiment: String
}
```

---

## Troubleshooting

### "Failed to parse response"

The LLM generated invalid JSON. Try:

1. Add clearer `@Guide` descriptions
2. Simplify the type structure
3. Use a more capable model

### Missing Required Fields

If the LLM omits required fields:

1. Make the field optional: `let field: String?`
2. Add a clearer description
3. Include the field name in your prompt

### Invalid Constraint Values

If values violate constraints:

1. The constraint might be too restrictive
2. Add the constraint to the description too
3. Example: `@Guide("Score 1-5", .range(1...5))`

### Complex Types Failing

For complex nested types:

1. Break into smaller types
2. Test each type independently
3. Use simpler models for simple types

---

## Next Steps

- [Tool Calling](ToolCalling.md) - Use `@Generable` for tool arguments
- [Streaming](Streaming.md) - Stream structured output
- [Providers](Providers/README.md) - Provider-specific structured output support
