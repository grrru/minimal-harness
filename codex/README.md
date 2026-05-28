# Minimal Codex Harness

Small, safe Codex setup for day-to-day use.

This harness is intentionally smaller than ECC or oh-my-codex. It gives Codex a few reusable workflows, read-only specialist agents, and a local plugin bundle without changing global Git hooks or broad MCP/profile config.

The `codex/` directory is the Codex package root. This keeps room for sibling harnesses such as `claude/` at the repository root.

## Layout

```text
codex/
  .agents/plugins/marketplace.json     # Codex marketplace for this package root
  plugins/minimal-codex-harness/       # plugin source of truth
    .codex-plugin/plugin.json
    skills/
    .mcp.json
    .app.json
  agents/                              # direct-install custom agent layers
  templates/                           # AGENTS.md and config snippets
  optional/ecc/                        # ECC inventory, lock, and adoption decisions
  install.sh
  validate.sh
```

## Contents

- `agents/` - three Codex-native custom agents:
  - `code-mapper`: read-only execution path and ownership mapping
  - `reviewer`: read-only correctness/security/regression review
  - `docs-researcher`: read-only documentation-backed API checks
- `plugins/minimal-codex-harness/` - local Codex plugin bundle and source of truth for skills:
  - `$harness`: map -> implement -> review -> verify workflow
  - `$search-first`: research before writing custom functionality
  - `$documentation-lookup`: primary-docs lookup for current APIs and tools
  - `$mcp-server-patterns`: MCP server and plugin packaging guidance
  - `$security-review`: concrete security review workflow
  - `$build-fix`: incremental build/type/lint failure repair
  - `$quality-gate`: final repo-native verification gate
  - `$verify`: persistent verification loop
  - `$tdd-lite`: small red-green-refactor loop
- `.agents/plugins/marketplace.json` - Codex marketplace metadata for this package root.
- `optional/ecc/` - ECC upstream inventory, lockfile, and adoption decisions for adding selected workflows one at a time.
- `install.sh` - direct installer for the parts that are useful immediately.

## Install

Preview first:

```sh
./codex/install.sh --dry-run
```

Install:

```sh
./codex/install.sh
```

The installer writes from the plugin bundle:

- `~/.codex/plugins/minimal-codex-harness`
- `~/.agents/plugins/marketplace.json` personal marketplace entry
- `~/.codex/config.toml` managed agent registration block only
- `~/.codex/AGENTS.md` managed block only
- `~/.codex/agents/*.toml`
- `~/.agents/skills/*`

It does not install plugin cache entries, enable MCP servers, enable hooks, change profiles/providers, or change Git config. The direct skill mirror keeps the harness usable immediately; the personal marketplace entry makes the plugin visible from Codex plugin surfaces after restart.

When ECC selection flags are used, the installer creates a separate `ecc-selected` plugin under `~/.codex/plugins/ecc-selected`. This keeps selected raw ECC material separate from the Codex-native `minimal-codex-harness` plugin.

Useful ECC options:

```sh
./codex/install.sh --list-ecc
./codex/install.sh --fetch-ecc --list-ecc
./codex/install.sh --ecc-source upstream/ECC --with-ecc-skill tdd-workflow
./codex/install.sh --ecc-source upstream/ECC --with-ecc-mcp context7
./codex/install.sh --ecc-source upstream/ECC --stage-ecc-hook memory-persistence
```

## Use

Restart Codex after installation, then invoke skills explicitly when useful:

```text
$harness implement this small feature with review and verification
$search-first find whether this integration should use an existing package
$documentation-lookup verify the current API before editing
$build-fix fix this typecheck failure incrementally
$quality-gate check the changed surface before signoff
$verify check the changed surface before signoff
$tdd-lite build this behavior test-first
```

You can also delegate explicitly:

```text
Have code-mapper trace the affected flow before editing.
Have reviewer inspect this diff for correctness and missing tests.
Have docs-researcher verify the framework API this change depends on.
```

## Plugin Bundle

The plugin bundle is the source of truth. The direct installer only mirrors plugin skills to the current stable user skill location and installs the custom agents.

The repo-local marketplace lives at:

```text
codex/.agents/plugins/marketplace.json
```

The plugin currently bundles skills and optional disabled MCP definitions. Hooks are documented but not enabled by default.

Because this repository keeps Codex assets under `codex/`, Codex will not auto-discover this source marketplace when the repository root is the working directory. The installer copies the plugin into `~/.codex/plugins/minimal-codex-harness` and writes a personal marketplace entry at `~/.agents/plugins/marketplace.json`.

When installed through Codex's plugin UI, Codex copies the plugin into its plugin cache and loads the installed copy. When using `codex/install.sh`, the script bypasses plugin cache and writes the currently useful pieces directly to Codex's global locations.

## ECC Optional Upstream

ECC is tracked as an upstream source, not installed wholesale. Fetch it locally when you want to inspect or select material:

```text
upstream/ECC/
```

```sh
./codex/install.sh --fetch-ecc --list-ecc
```

`--fetch-ecc` clones `https://github.com/affaan-m/ECC.git` into `upstream/ECC` when missing. If the clone already exists, it runs `git fetch --tags --prune origin` only; it does not pull, checkout, or overwrite local changes.

Used by itself, `--fetch-ecc` only prepares `upstream/ECC` and exits. When combined with `--with-ecc-skill`, `--with-ecc-mcp`, or `--stage-ecc-hook`, it fetches first and then continues the selected install.

The snapshot and adoption decisions are recorded in:

```text
codex/optional/ecc/inventory.json
codex/optional/ecc/adoption.json
codex/optional/ecc/upstream.lock
```

Entries are grouped as `included`, `candidate`, or `skip`. To add another ECC workflow, adapt one candidate into `plugins/minimal-codex-harness/skills/`, or install it explicitly into `ecc-selected`.

MCP definitions copied from ECC are disabled by default. Hook bundles are staged only and are not referenced from plugin manifests until a Codex-specific adapter has been reviewed.

## Verify

```sh
./codex/validate.sh
```

This checks JSON manifests, required agent TOML keys, and skill frontmatter using Bash and Node.
