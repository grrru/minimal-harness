---
name: make-a-plan
description: Investigate a task, interview the user about whatever the investigation cannot settle, write a PLAN_<slug>.md master document, then work through its tasks in order. Use when the user asks for a plan before implementation, or invokes `$make-a-plan`.
---

# Make a Plan

Plan the task the user named, write the plan down, then execute it.

## 1. Investigate

Read `git status` and `git log`, plus the files, symbols, tests, and config
related to the task, to establish the current state.

## 2. Interview

Whatever the investigation does not settle comes from the user, never from a
guess: problem definition, goals and non-goals, approach, scope, constraints,
test strategy, priority. Keep asking until nothing is open.

- Ask in batches of at most four related questions, each with two to four
  labeled options, the recommended one first and marked `(recommended)`.
- Stop and wait for the reply before continuing. Never fill a gap with an
  assumption.

## 3. Write the plan

Write `PLAN_<slug>.md` in the current directory, where `<slug>` is two to four
lowercase kebab-case words. Ask before overwriting an existing file.

Write it so this file alone is enough to resume after a session reset:

- Background, problem, goals, non-goals, constraints
- Approach and the reasoning behind it
- Task list — `T1`, `T2`, ... each with status `[ ] TODO`, `[→] IN_PROGRESS`,
  or `[x] DONE`
- How each task is verified
- Last updated date

## 4. Execute

Report the plan path and task list, then ask whether to start with T1. Once
confirmed, take tasks strictly in order: set the task `[→] IN_PROGRESS` →
implement → verify → mark `[x] DONE` and update the progress log and date →
commit following the commit conventions of the repository being worked on (its
`AGENTS.md`) → next task.

When verification fails, find the cause and reimplement rather than moving on.
The plan file always reflects the real state.
