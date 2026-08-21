---
name: follow-plan
description: Read the plan file and work through its tasks in order, completing each one implement → verify → commit before starting the next. Use when the user asks to proceed with an existing plan, or invokes `$follow-plan`.
---

# Follow Plan

## 1. Read the plan

Use `PLAN.md` if it exists; otherwise the most recently modified `PLAN_*.md`.
If there is no plan file, say so and stop, telling the user to run
`$make-a-plan` first.

Read the whole file and work out the unfinished tasks, their order and
dependencies, and each one's scope and completion criteria.

## 2. One task at a time

Never interleave tasks. Each task completes implement → verify → commit before
the next one starts. Do not commit a task whose verification has not passed,
and do not start a task while the previous one is uncommitted.

### 2-1. Prepare

Read the related files — definitions, callers, tests, config. Then list what
the plan leaves open: design direction, library or API choice, scope
boundaries, naming, file placement, error handling policy. Ask before
implementing, not after.

- Ask in batches of at most four related questions, each with two to four
  labeled options, the recommended one first and marked `(recommended)`.
- Stop and wait for the reply. Skip the question only when the plan already
  answers it or there is genuinely nothing to decide.
- Write settled decisions into the plan file using the format in section 3.

### 2-2. Implement

Work in small, safe steps.

- Write the test first, for a new behavior as much as for a bug fix. Watch it
  fail for the right reason, then write the smallest code that passes it.
- Keep the tree building. Every step you stop at compiles and leaves the
  existing tests green; a task is never parked mid-refactor.
- Put an unfinished feature behind a flag that defaults to off, rather than
  shipping a half-wired path on the default one.

Diagnose and fix problems yourself before asking the user. Never reach for an
unsafe bypass such as `--no-verify`.

### 2-3. Verify

Run the project's tests and build, then check the task's completion criteria
directly — the success path and a failure or boundary path. On failure, find
the cause, fix it, and verify again; involve the user only when it cannot be
resolved.

This is a checkpoint: any failure sends you back to 2-2.

### 2-4. Commit

Commit as soon as verification passes, following the commit conventions of the
repository being worked on (its `AGENTS.md`).

- Mark the task done in the plan file and update its progress log first.
- Check whether `AGENTS.md` or `README.md` need updating for this change.
- Stage files explicitly. Never `git add -A`.

## 3. Recording design decisions

Record significant decisions in the plan file:

```markdown
### Design decision: <title>
- **Date**: YYYY-MM-DD
- **Decision**: what was chosen
- **Why**: the reasoning, including trade-offs
- **Alternatives**: what else was considered
```

## 4. Final report

When every task is done, report the completed tasks, the significant design
decisions, and anything still needing the user's attention.
