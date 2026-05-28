---
name: search-first
description: Research-before-coding workflow. Use before adding non-trivial functionality, dependencies, integrations, utilities, or abstractions that may already exist.
---

# Search First

Use this to avoid building custom code before checking existing options.

## Flow

1. Define the need in one sentence.
2. Search the current repo first with `rg` and existing docs/tests.
3. Check ecosystem options when relevant:
   - Node: package manager metadata, `package.json`, npm docs
   - Python: `pyproject.toml`, package docs, PyPI
   - Other stacks: official package/tool docs
4. Check available skills and MCP servers for an existing capability.
5. Compare candidates by fit, maintenance, docs, license, dependency cost, and integration risk.
6. Choose one:
   - Adopt: use existing package/tool directly
   - Wrap: add a thin local adapter
   - Build: write custom code only after the search fails or risk justifies it

## Rules

- State which channels were checked.
- Do not claim "nothing exists" for channels that were unavailable.
- Prefer small maintained tools over large dependencies for narrow needs.
- Prefer repo-native helpers over new dependencies when the repo already has a clear pattern.

## Finish

Return the selected path, rejected alternatives, and why the decision is appropriate for this repo.
