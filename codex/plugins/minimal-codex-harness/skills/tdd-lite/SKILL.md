---
name: tdd-lite
description: Lightweight red-green-refactor loop. Use when the user asks for TDD, test-first work, regression tests, or a behavior-preserving fix with test coverage.
---

# TDD Lite

Use one vertical slice at a time.

## Loop

1. Identify one observable behavior.
2. Write or update one test that fails for the right reason.
3. Implement the smallest code change to pass it.
4. Refactor only while green.
5. Repeat for the next behavior.

## Test Rules

- Test public behavior, not private implementation.
- Prefer integration-style tests already used by the repo.
- Avoid speculative tests for imagined future behavior.
- Do not write all tests first and all implementation later.

## Finish

Return:

- behavior covered
- tests added or changed
- checks run
- remaining behaviors not covered
