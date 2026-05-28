---
name: quality-gate
description: Run a final quality gate for changed code using repo-native format, lint, type, test, build, security, and diff review checks.
---

# Quality Gate

Use this before signoff, commit, PR, or release.

## Flow

1. Identify changed files and affected runtime surfaces.
2. Detect repo-native commands from package/config files.
3. Run the smallest meaningful checks first.
4. Fix concrete failures and rerun the failed check.
5. Widen checks when the blast radius justifies it.
6. Review the final diff for unrelated changes, secrets, and missing tests.

## Check Menu

Pick applicable checks:

- Format: repo formatter or check mode
- Lint: repo lint command
- Types: TypeScript, pyright, mypy, compiler checks
- Tests: targeted tests first, broader suite when needed
- Build: production build or compile
- Security: secrets scan, dependency audit, sensitive path review
- Runtime: browser/API/CLI smoke test for user-visible changes

## Report Shape

```text
Quality gate:
- Scope:
- Checks run:
- Passed:
- Failed:
- Not run:
- Residual risk:
```

Do not mark the task ready if a required check failed or was skipped without a reason.
