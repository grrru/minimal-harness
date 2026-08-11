---
name: create-commit
description: Create a Git commit with a conventional prefix, a concise noun-phrase subject, and an issue suffix. Use only when the user explicitly invokes `$create-commit` and provides or confirms the commit scope and issue number.
---

# Create Commit

Run this workflow only for an explicit `$create-commit` invocation. Do not run
it implicitly for ordinary code changes or a generic request to commit.

- Require an issue number. If it is missing or ambiguous, ask before changing
  the index or creating a commit.
- Inspect `git status`, the staged diff, and the unstaged diff. Stage only the
  files in the confirmed scope; never blindly use `git add -A`.
- Choose one prefix: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`,
  `build`, `ci`, `perf`, or `revert`. Ask when the change type is ambiguous.
- Write the subject as a concise noun phrase in the repository's language. Do
  not use an imperative, sentence-ending verb, or trailing period.
- Use exactly this format: `<prefix>: <noun phrase> (#<issue_num>)`.

Examples:

```text
feat: 로그인 기능 추가 (#42)
fix: 만료 토큰 처리 (#107)
chore: 설치 스크립트 정리 (#12)
```

Before committing, recheck the staged diff for scope and secrets. Run relevant
project checks when available, then execute `git commit -m "..."`. Do not amend,
push, rebase, merge, or otherwise rewrite history unless explicitly requested.
Report the resulting commit hash, message, and file scope.
