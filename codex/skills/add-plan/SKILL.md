---
name: add-plan
description: Add one task entry to an existing plan file after light investigation, without starting the work. Use when the user wants a task appended to PLAN.md, or invokes `$add-plan`.
---

# Add Plan

Add the task the user named to the plan file. Do not implement it.

## 1. Find the plan

Use `PLAN.md` if it exists; otherwise the most recently modified `PLAN_*.md`.
If there is no plan file, say so and stop, telling the user to run
`$make-a-plan` first.

## 2. Investigate lightly

Look at the codebase only as much as it takes to describe the entry properly —
related files, prerequisite tasks. Nothing more, and no implementation.

## 3. Interview

If anything about the entry is still open — scope, completion criteria,
dependencies, approach — resolve all of it with the user before writing.

- Ask in batches of at most four related questions, each with two to four
  labeled options, the recommended one first and marked `(recommended)`.
- Stop and wait for the reply before continuing.

## 4. Append the entry

Follow the plan file's existing format and task numbering. Append the entry at
the bottom of the section holding upcoming work, and leave every other part of
the file untouched.

Report the number and title of the added entry, then stop. Do not implement and
do not commit.
