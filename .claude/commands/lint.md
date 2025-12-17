# Lint Command

Run SwiftLint on the codebase.

## Usage

```
/project:lint
/project:lint {path}
/project:lint --fix
```

## Process

1. Run swiftlint on specified path or Sources/
2. Capture warnings and errors
3. Report findings by severity
4. Optionally auto-fix correctable issues

## Arguments

- `$ARGUMENTS`: Optional path or `--fix` flag

## Commands

```bash
# Lint all sources
swiftlint lint Sources/

# Lint with strict mode (warnings as errors)
swiftlint lint --strict Sources/

# Auto-fix correctable issues
swiftlint lint --fix Sources/

# Lint specific path
swiftlint lint Sources/SwiftAI/Core/
```

## Output

```
SwiftLint Results
-----------------
Path: Sources/

Errors: 0
Warnings: 3

Warnings:
1. line_length (Sources/SwiftAI/Core/Types/Message.swift:42)
   Line should be 120 characters or less; currently 125

2. trailing_whitespace (Sources/SwiftAI/Providers/MLX/MLXProvider.swift:78)
   Lines should not have trailing whitespace

3. identifier_name (Sources/SwiftAI/Core/Errors/AIError.swift:15)
   Variable name 'x' should be 4 characters or more

Run with --fix to auto-correct fixable issues
```

## SwiftLint Configuration

Ensure `.swiftlint.yml` exists in project root:

```yaml
disabled_rules:
  - todo

opt_in_rules:
  - empty_count
  - explicit_init

line_length:
  warning: 120
  error: 150

excluded:
  - .build
  - Package.swift
```
