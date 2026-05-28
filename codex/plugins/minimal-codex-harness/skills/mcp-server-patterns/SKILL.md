---
name: mcp-server-patterns
description: Design, implement, or review MCP servers, tools, resources, prompts, transports, schemas, and Codex plugin MCP packaging.
---

# MCP Server Patterns

Use this when building or maintaining MCP capabilities.

## Surface Choice

Before implementing an MCP server, decide whether the capability belongs in:

- AGENTS.md: always-on project instruction
- Skill: repeatable workflow or expert guidance
- MCP: external data/action surface that benefits from typed tools
- CLI/script: deterministic local operation that does not need model mediation

Use MCP when the model needs structured access to external systems, reusable tools, resources, prompts, or authenticated APIs.

## Design Rules

1. Keep tools narrow and schema-first.
2. Use clear descriptions that include side effects and approval expectations.
3. Validate input with a schema library such as Zod for TypeScript servers.
4. Return deterministic shapes with summaries, structured data, and actionable errors.
5. Prefer idempotent operations or explicit dry-run modes for writes.
6. Keep transport-specific code separate from business logic.
7. Pin SDK versions and verify current API signatures against official docs.

## Codex Plugin Packaging

For plugin-bundled MCP:

- Put the server definitions in plugin root `.mcp.json`.
- Point `.codex-plugin/plugin.json` at it with `mcpServers`.
- Leave heavy or credentialed MCP servers disabled by default unless the plugin is explicitly operational.
- Document required environment variables and auth scopes.

## Finish

Return the chosen surface, tool/resource schema, side effects, auth needs, and verification command.
