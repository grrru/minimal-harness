---
name: verify
description: Persistent verification loop. Use when the user asks to test, verify, check regressions, or prove a change before signoff.
---

# Verify

Use this when completion depends on evidence, not just inspection.

## Loop

1. Define the verification target:
   - files, routes, APIs, commands, or user-visible surfaces affected
   - what would prove the requested behavior works
2. Run the smallest relevant repo-native check first.
3. If it fails, fix the concrete failure and rerun the narrow check.
4. Widen only when narrow checks pass or the change has broader blast radius.
5. For UI changes, verify the real rendered surface when a local runtime is practical.

## Priorities

- Existing tests beat ad hoc scripts.
- Targeted tests beat full-suite runs until the failing surface is clean.
- Runtime/browser checks complement automated tests; they do not replace them.
- Do not claim success if a required surface was not checked.

## Finish

Return:

- verification target
- commands or runtime checks run
- pass/fail result
- unverified surfaces or residual risk
