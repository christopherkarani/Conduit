# Test Command

Run the SwiftAI test suite.

## Usage

```
/project:test
/project:test {filter}
```

## Process

1. Run swift test with optional filter
2. Capture output
3. Parse results
4. Report pass/fail summary
5. If failures, suggest fixes

## Arguments

- `$ARGUMENTS`: Optional test filter (e.g., "MessageTests", "MessageTests/testCreateUser")

## Commands

```bash
# Run all tests
swift test

# Run filtered tests
swift test --filter "$ARGUMENTS"

# Run with verbose output
swift test -v

# Run parallel
swift test --parallel
```

## Output

```
Test Results
------------
Total: 45
Passed: 43
Failed: 2
Skipped: 0

Failures:
1. MLXProviderTests/testGeneration
   - Expected non-empty response
   - Location: Tests/SwiftAITests/Providers/MLXProviderTests.swift:42

2. StreamingTests/testCancellation
   - Timeout waiting for cancellation
   - Location: Tests/SwiftAITests/Core/StreamingTests.swift:89

Suggestion: Use debug-agent to investigate failures
```

## Example

```
/project:test MessageTests

Running: swift test --filter MessageTests

Test Results
------------
Total: 8
Passed: 8
Failed: 0

All tests passed ✅
```
