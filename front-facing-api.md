# Conduit Front-Facing API (Current)

## Default Module: `Conduit`
The default import is intentionally minimal and facade-first.

```swift
import Conduit
```

### Public Surface
- `RunOptions`
- `Model`
- `ToolSetBuilder`
- `Provider`
- `Conduit`
- `Session`
- `conduitVersion`

`Model` supports both repo-backed MLX identifiers via `.mlx(...)` and local filesystem paths via `.mlxLocal(...)`.
The advanced surface also exposes current latest model aliases such as `gpt5_4`, `claudeOpus46`, `kimiK2ThinkingTurbo`, and `minimaxM2_5`.

### Facade Examples

```swift
import Conduit

let app = Conduit(.openAI(apiKey: apiKey))
let session = try app.session(model: .openAI("gpt-4o-mini")) {
    $0.run { run in
        run.maxTokens = 300
        run.temperature = 0.2
    }
}

let text = try await session.run("Summarize this PR.")
```

```swift
let app = Conduit(.huggingFace(token: hfToken))
let image = try await app.images.generate(
    prompt: "A minimalist poster of a robot",
    config: .square1024
)

// Local MLX directory
let local = Conduit(.mlx())
let localSession = try local.session(model: .mlxLocal("/Users/me/models/Llama-3.2-1B-Instruct-4bit"))
```

### Expert Escape Hatches (Facade)
`Provider` options are intentionally small by default, with an optional expert closure:

```swift
let app = Conduit(.openAI(apiKey: key, expert: { raw in
    raw.headers["X-Debug"] = "1"
}))
```

## Advanced Module: `ConduitAdvanced`
Use this when you need direct provider actors/protocols and full low-level controls.

```swift
import ConduitAdvanced
```

### Examples of advanced-only usage
- Direct provider actors (`OpenAIProvider`, `AnthropicProvider`, `MLXProvider`, etc.)
- Provider/protocol-level integrations
- Lower-level config and runtime controls

## Package Products
- `Conduit` (minimal facade)
- `ConduitAdvanced` (full implementation surface)
- `ConduitMacros` (macros)
