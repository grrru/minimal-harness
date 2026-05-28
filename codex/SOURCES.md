# Sources

This harness is a local composition, not a wholesale copy of one upstream setup.

Influences:

- OpenAI Codex docs for config, skills, custom agents, and plugin layout.
- `Yeachan-Heo/oh-my-codex` for the idea of separating plugin surfaces from an optional runtime.
- `dgk-dev/dgk-gpt` for safe installer behavior: managed blocks, dry-run, and preserving existing user setup.
- `VoltAgent/awesome-codex-subagents` for Codex-native agent shape and role boundaries.
- `howells/arc` for workflow skills as the primary user-facing surface.
- `affaan-m/ECC` as an optional upstream material warehouse. The current snapshot is tracked in `codex/optional/ecc/inventory.json` and `codex/optional/ecc/upstream.lock`; selected adaptations should be recorded by the user in `codex/optional/ecc/adoption.json`.

Design choices:

- No global Git hooks.
- No default MCP startup.
- No pinned model names in custom agents.
- No `danger-full-access` defaults.
- Only a small managed `config.toml` block for custom agent registration; no profile, provider, MCP, or notification merge.
- Plugin bundle is the source of truth for skills; the installer mirrors from `codex/plugins/minimal-codex-harness/skills`.
- Installer also copies the plugin bundle to `~/.codex/plugins/minimal-codex-harness` and adds a personal marketplace entry so Codex can discover the plugin without mixing Codex assets into the repository root.
- ECC additions are tracked in `codex/optional/ecc/adoption.json` so workflows can be added one at a time instead of installing ECC wholesale.
- Raw/shared ECC material can be installed only with explicit `install.sh` selection flags into the separate `ecc-selected` plugin. MCP entries are disabled by default, and hook bundles are staged for audit rather than enabled.
