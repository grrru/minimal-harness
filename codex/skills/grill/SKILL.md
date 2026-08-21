---
name: grill
description: Interview the user relentlessly about a plan or design until both sides understand it the same way. Use only when the user invokes `$grill` explicitly.
---

# Grill

Interview the user about every aspect of this plan until the two of you
understand it the same way. Walk down each branch of the design tree and
resolve the dependencies between decisions one at a time.

If a question can be answered by reading the codebase, read the codebase
instead of asking.

## Asking

Codex has no structured question tool, so conduct the interview in the
transcript itself.

- Ask in batches of at most four related questions.
- Give each question two to four concrete options with short labels. Do not ask
  for open-ended prose.
- Put the option you recommend first and mark its label `(recommended)`.
- Say that the user may answer with something outside the options.
- Stop after each batch and wait for the reply. Never answer your own question,
  assume a default, or move to the next branch unanswered — that is the failure
  mode this skill exists to prevent.
