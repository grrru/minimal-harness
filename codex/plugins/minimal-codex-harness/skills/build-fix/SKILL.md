---
name: build-fix
description: Diagnose and fix build, typecheck, compile, or lint failures incrementally with minimal scoped changes.
---

# Build Fix

Use this when a build, typecheck, compile, or lint command fails.

## Flow

1. Detect the project toolchain from repo files and scripts.
2. Run the smallest relevant failing command.
3. Capture the first useful error group, not the whole log.
4. Read the owning file and related type/config definitions.
5. Fix one cause at a time with the smallest change.
6. Rerun the same command after each fix.
7. Widen to broader checks only after the narrow failure is clean.

## Common Commands

- Node/TypeScript: `npm run build`, `npm run typecheck`, `npx tsc --noEmit`
- Python: `pytest`, `ruff check .`, `pyright .`, `python -m compileall -q .`
- Go: `go test ./...`, `go build ./...`
- Rust: `cargo test`, `cargo build`, `cargo clippy`
- Java/Kotlin: `./gradlew test`, `./gradlew build`, `mvn test`

Use repo scripts when available instead of inventing commands.

## Guardrails

Stop and report when:

- The same error survives three focused attempts.
- A fix requires architecture changes beyond a build repair.
- Missing dependencies require network install approval.
- A proposed fix weakens lint/type/test config instead of fixing code.

## Finish

Return the failing command, root cause, files changed, command reruns, and remaining failures.
