# Phase Command

Start working on a specific implementation phase of SwiftAI.

## Usage

```
/project:phase {phase_number}
```

## Process

1. Read the implementation plan from `.claude/artifacts/planning/implementation-plan.md`
2. Load phase {phase_number} task list from `.claude/artifacts/planning/phase-{phase_number}-tasks.md`
3. If task list doesn't exist, use the planning-agent to create it
4. Display phase objective, deliverables, and acceptance criteria
5. Begin work on the first incomplete task

## Arguments

- `$ARGUMENTS`: The phase number (1-15)

## Steps

1. **Load Phase**: Read phase details and tasks
2. **Check Prerequisites**: Verify previous phases are complete
3. **Create Task List**: If not exists, invoke planning-agent
4. **Start Implementation**: Begin with first task

## Invocation

Use the planning-agent to analyze Phase $ARGUMENTS:
- Read the API specification for relevant sections
- Create detailed task list if not exists
- Identify dependencies and risks

Then begin implementation following the task order.
