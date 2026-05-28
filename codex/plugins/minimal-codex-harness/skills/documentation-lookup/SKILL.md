---
name: documentation-lookup
description: Verify current library, framework, tool, API, or Codex behavior against primary documentation before answering or editing.
---

# Documentation Lookup

Use this when a task depends on current behavior outside the local repo.

## Sources

Prefer sources in this order:

1. Official docs or specifications
2. Official source repository or release notes
3. Maintainer-authored migration guides
4. Current package metadata
5. Secondary references only as fallback

Use Context7 or another docs MCP when configured. Use web search when MCP is unavailable or the topic is not covered.

## Flow

1. Identify the exact product, package, API, command, option, and version if possible.
2. Fetch primary docs before changing code or giving definitive guidance.
3. Compare docs against local installed versions and config files.
4. Call out conflicts between docs, local code, and package versions.
5. Keep examples minimal and matched to the verified version.

## Rules

- Do not rely on memory for version-sensitive API names, config keys, defaults, or deprecations.
- Redact secrets before sending queries to external tools.
- Cite exact docs or local file paths when the answer affects implementation.
- Label inference separately from sourced facts.

## Finish

Return the verified behavior, source references, implementation implication, and remaining uncertainty.
