---
name: harness
description: Minimal Codex harness workflow. Use when the user asks to use the local harness, wants structured implementation, or a task is broad enough to benefit from map -> edit -> review -> verify.
---

# Harness

Use the lightest workflow that will produce a reliable result.

## Default Flow

1. Decide whether the task is simple enough to do inline.
2. For unfamiliar or risky areas, ask `code-mapper` to trace the owning path first.
3. Implement the smallest scoped change directly in the main session.
4. Ask `reviewer` to inspect the changed surface when the risk justifies it.
5. Use `$verify` before signoff.

## When To Skip Agents

- One-file mechanical edits
- Obvious typo/config fixes
- Pure explanation or planning requests
- Cases where the user explicitly asks for inline-only work

## Quality Bar

- Prefer repo-native patterns over new abstractions.
- Keep edits scoped to the requested behavior.
- Run targeted checks before broad checks.
- Name residual risk when full verification is not possible.

## Finish

Return:

- what changed
- verification run
- caveats or remaining risk
