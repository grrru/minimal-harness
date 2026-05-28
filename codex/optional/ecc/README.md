# ECC Optional Upstream

ECC is tracked as an optional upstream, not installed wholesale.

Use this area to decide which ECC surfaces should be adapted into the local Codex harness one at a time. ECC is treated as a material warehouse, not as a required dependency.

Local ECC clones live outside git:

```text
upstream/ECC/
```

Fetch when needed:

```sh
./codex/install.sh --fetch-ecc --list-ecc
```

`--fetch-ecc` clones ECC when `upstream/ECC` is missing. If it already exists, the installer only runs `git fetch --tags --prune origin`; it does not pull, checkout, or overwrite local changes.

Used by itself, `--fetch-ecc` only prepares the upstream clone and exits. Combined with selected ECC install flags, it fetches first and then continues installation.

The active Codex-native harness stays in:

```text
codex/plugins/minimal-codex-harness/skills/
```

## Policy

- Do not vendor the whole ECC plugin by default.
- Prefer small Codex-native adaptations over verbatim copies.
- Keep each adopted skill focused, short, and useful without ECC runtime hooks.
- Avoid ECC global Git hooks, broad config merges, and always-on MCP expansion.
- Record every decision in `adoption.json`.
- Keep `inventory.json` and `upstream.lock` as the upstream snapshot evidence.

## Adoption Flow

1. Inspect the ECC upstream file.
2. Decide whether it is general enough for this harness.
3. Adapt it into `codex/plugins/minimal-codex-harness/skills/<name>/SKILL.md`, or install it explicitly as a raw selected item with `install.sh`.
4. Add or update the entry in `adoption.json`.
5. Run:

```sh
./codex/validate.sh
./codex/install.sh --dry-run --yes
```

## Explicit Selected Install

To install only selected raw/shared ECC material into a separate local plugin:

```sh
./codex/install.sh \
  --fetch-ecc \
  --ecc-source upstream/ECC \
  --with-ecc-skill tdd-workflow \
  --with-ecc-mcp context7
```

This creates `~/.codex/plugins/ecc-selected` and adds a personal marketplace entry. MCP definitions are copied disabled by default.

Hooks are not enabled automatically. They can be staged for audit:

```sh
./codex/install.sh --ecc-source upstream/ECC --stage-ecc-hook memory-persistence
```

## Status Buckets

- `included`: user-maintained list of ECC material adopted into the active plugin. Starts empty.
- `candidate`: worth considering later.
- `skip`: intentionally not part of the minimal Codex harness.

Use this for a quick snapshot:

```sh
./codex/install.sh --list-ecc
```
