# Review Command

Run a code review on recent changes or specified files.

## Usage

```
/project:review
/project:review {file_or_directory}
```

## Process

1. Identify scope of review:
   - If no argument: review recent git changes
   - If argument provided: review specified path
2. Invoke code-reviewer agent
3. Run automated checks (SwiftLint)
4. Perform manual review against checklist
5. Generate review report
6. Return summary with findings

## Arguments

- `$ARGUMENTS`: Optional file path or directory. Defaults to recent changes.

## Review Scope

- **No args**: `git diff HEAD~1` (recent changes)
- **File path**: Review specific file
- **Directory**: Review all Swift files in directory

## Checks Performed

1. **SwiftLint**: Style and convention violations
2. **Code Quality**: Readability, simplicity, DRY
3. **Swift Conventions**: Naming, access control, optionals
4. **Concurrency**: Sendable, actor isolation, async/await
5. **Documentation**: Public API doc comments
6. **API Design**: Progressive disclosure, consistency

## Output

Review findings categorized by severity:
- **Critical**: Must fix before merge
- **Warning**: Should fix
- **Suggestion**: Consider improving

Report saved to `.claude/artifacts/reviews/review-{timestamp}.md`

## Example

```
/project:review Sources/SwiftAI/Core/

Code Review Summary
-------------------
Scope: Sources/SwiftAI/Core/

Critical: 0
Warnings: 2
Suggestions: 5

Warnings:
1. Missing Sendable conformance in StreamBuffer.swift:42
2. Force unwrap in Message.swift:78

Full report: .claude/artifacts/reviews/review-20251216.md
```
