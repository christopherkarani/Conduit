Prompt:
You are a Swift 6.2 engineer. Identify the malformed JSON file written by SwiftPM or tooling.

Goal:
Pinpoint the corrupted JSON source, its last write time, and the writer.

Task BreakDown:
- Inspect `.swiftpm/configuration/*.json`.
- Inspect `.swiftpm/metadata/*.json`.
- Inspect `Package.resolved`.
- Inspect SwiftPM build artifacts that may include JSON.
- Identify the exact malformed file and its invalid segment.
- Determine the last writer (tool, command, timestamp).
