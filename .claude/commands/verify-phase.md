# Verify Phase Command

Verify that the current implementation phase meets all acceptance criteria.

## Usage

```
/project:verify-phase
/project:verify-phase {phase_number}
```

## Process

1. Identify current or specified phase
2. Invoke the implementation-checker agent
3. Run all quality gates (build, test, lint, docs)
4. Check all deliverables exist
5. Verify each acceptance criterion
6. Generate verification report
7. Report status: PASSED, PASSED WITH WARNINGS, or FAILED

## Arguments

- `$ARGUMENTS`: Optional phase number. If not provided, determines current phase from progress.

## Quality Gates

The following must pass for phase approval:

1. **Compilation**: `swift build` without errors
2. **Tests**: `swift test` all passing
3. **Lint**: `swiftlint lint --strict` clean
4. **Documentation**: All public APIs documented

## Output

The implementation-checker agent will:
- Generate report in `.claude/artifacts/reports/phase-{n}-verification.md`
- Return summary with pass/fail counts
- List any blockers that must be addressed

## Example

```
/project:verify-phase 3

Phase 3 Verification Summary
----------------------------
Status: ✅ PASSED

Quality Gates: 4/4
Deliverables: 5/5  
Acceptance Criteria: 8/8

Recommendation: Proceed to Phase 4

Full report: .claude/artifacts/reports/phase-3-verification.md
```
