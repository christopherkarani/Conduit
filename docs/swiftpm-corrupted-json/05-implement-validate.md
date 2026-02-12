Prompt:
You are a Swift 6.2 engineer. Implement the fix and validate with focused tests.

Goal:
Apply a targeted fix and confirm clean + incremental builds succeed.

Task BreakDown:
- Implement the minimal fix (file regeneration or code change).
- Run focused tests and confirm they pass.
- Run `swift build` clean and incremental.
- Verify corrupted JSON no longer appears.
- Confirm no regressions in related workflows.
