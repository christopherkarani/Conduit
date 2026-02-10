# AGENTS.md

## Repo Rules
- Never commit docs created for planning. If confused, ask which new `.md` files should be committed.

## Corrections From Recent Sessions (2026)
- Plans must match the actual package layout, targets, and paths (e.g., `WaxCore`/`Wax`) and the Swift Testing framework (`Testing`). Avoid legacy names like `MemvidCore` or `XCTest` unless explicitly requested.
- When updating docs/examples, ensure API names reflect current Conduit types (e.g., `GeneratedContent`, `GenerationSchema`, `Tool`, `Transcript`) and remove legacy `StructuredContent`/`Schema`/`AITool` wording.
- Before editing Conduit, confirm you are in the real repo path (not `.build/checkouts`) and within writable roots; set `workdir` to the repo root before changes.
- If referencing external specs or legacy docs, cross-check with current implementation to avoid mismatches.

## Repo Workflows (Verified)
- Build: `swift build`
- Full test suite: `swift test`
- Documentation examples only: `swift test --filter DocumentationExamplesTests`
- Text embedding cache tests: `swift test --filter TextEmbeddingCacheTests`
- JsonRepair tests: `swift test --filter JsonRepairTests`
- Anthropic integration tests (skips without key): `swift test --filter AnthropicIntegrationTests`
- Anthropic integration tests (live): `ANTHROPIC_API_KEY=sk-ant-... swift test --filter AnthropicIntegrationTests`
