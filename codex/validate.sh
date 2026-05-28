#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$ROOT_DIR/plugins/minimal-codex-harness"
MARKETPLACE_FILE="$ROOT_DIR/.agents/plugins/marketplace.json"
ECC_ADOPTION_FILE="$ROOT_DIR/optional/ecc/adoption.json"
ECC_INVENTORY_FILE="$ROOT_DIR/optional/ecc/inventory.json"
ECC_LOCK_FILE="$ROOT_DIR/optional/ecc/upstream.lock"

json_check() {
  node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$1" >/dev/null
}

json_check "$PLUGIN_DIR/.codex-plugin/plugin.json"
json_check "$PLUGIN_DIR/.mcp.json"
json_check "$PLUGIN_DIR/.app.json"
json_check "$MARKETPLACE_FILE"
json_check "$ECC_ADOPTION_FILE"
json_check "$ECC_INVENTORY_FILE"
json_check "$ECC_LOCK_FILE"

node - "$MARKETPLACE_FILE" <<'EOF'
const fs = require('fs');
const marketplace = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const entry = marketplace.plugins?.find(plugin => plugin.name === 'minimal-codex-harness');
if (!entry) {
  throw new Error('marketplace missing minimal-codex-harness entry');
}
if (entry.source?.path !== './plugins/minimal-codex-harness') {
  throw new Error(`unexpected marketplace source.path: ${entry.source?.path}`);
}
EOF

node - "$ROOT_DIR" "$ECC_ADOPTION_FILE" "$ECC_INVENTORY_FILE" "$ECC_LOCK_FILE" <<'EOF'
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const adoptionPath = process.argv[3];
const inventoryPath = process.argv[4];
const lockPath = process.argv[5];
const adoption = JSON.parse(fs.readFileSync(adoptionPath, 'utf8'));
const inventory = JSON.parse(fs.readFileSync(inventoryPath, 'utf8'));
const lock = JSON.parse(fs.readFileSync(lockPath, 'utf8'));

const skillSet = new Set(inventory.skills || []);
const commandSet = new Set(inventory.commands || []);
const mcpSet = new Set(inventory.mcp_servers || []);
const hookSet = new Set((inventory.hook_bundles || []).map((entry) => entry.name));

if (inventory.counts?.skills !== (inventory.skills || []).length) {
  throw new Error('ECC inventory skill count mismatch');
}
if (inventory.counts?.commands !== (inventory.commands || []).length) {
  throw new Error('ECC inventory command count mismatch');
}
if (inventory.counts?.mcp_servers !== (inventory.mcp_servers || []).length) {
  throw new Error('ECC inventory MCP count mismatch');
}
if (inventory.counts?.hook_bundles !== (inventory.hook_bundles || []).length) {
  throw new Error('ECC inventory hook count mismatch');
}

if (lock.commit !== inventory.upstream?.commit) {
  throw new Error('ECC lock commit does not match inventory');
}
if (lock.version !== inventory.upstream?.version) {
  throw new Error('ECC lock version does not match inventory');
}

for (const entry of adoption.included || []) {
  if (!entry.name || !entry.type || !entry.upstream_path || !entry.target || !entry.mode || !entry.reason) {
    throw new Error(`incomplete ECC included entry: ${entry.name || '<unnamed>'}`);
  }
  if (entry.type === 'skill' && !skillSet.has(entry.name)) {
    throw new Error(`ECC included skill missing from inventory: ${entry.name}`);
  }
  if (entry.type === 'command' && !commandSet.has(entry.name)) {
    throw new Error(`ECC included command missing from inventory: ${entry.name}`);
  }
  const target = path.join(root, entry.target);
  if (!fs.existsSync(target)) {
    throw new Error(`missing ECC-adapted target for ${entry.name}: ${entry.target}`);
  }
}

const candidateChecks = [
  ['skills', skillSet],
  ['commands', commandSet],
  ['mcp_servers', mcpSet],
  ['hooks', hookSet],
];

for (const [bucket, validNames] of candidateChecks) {
  for (const entry of adoption.candidates?.[bucket] || []) {
    if (!entry.name || !entry.upstream_path || !entry.reason) {
      throw new Error(`incomplete ECC ${bucket} candidate entry: ${entry.name || '<unnamed>'}`);
    }
    if (!validNames.has(entry.name)) {
      throw new Error(`ECC ${bucket} candidate missing from inventory: ${entry.name}`);
    }
  }
}
EOF

for agent_name in code-mapper reviewer docs-researcher; do
  grep -Fq "[agents.$agent_name]" "$ROOT_DIR/templates/config.agents.toml" || {
    printf 'templates/config.agents.toml: missing [agents.%s]\n' "$agent_name" >&2
    exit 1
  }
done

for agent_file in "$ROOT_DIR"/agents/*.toml; do
  grep -Eq '^name[[:space:]]*=' "$agent_file" || {
    printf '%s: missing name\n' "$agent_file" >&2
    exit 1
  }
  grep -Eq '^description[[:space:]]*=' "$agent_file" || {
    printf '%s: missing description\n' "$agent_file" >&2
    exit 1
  }
  grep -Eq '^developer_instructions[[:space:]]*=' "$agent_file" || {
    printf '%s: missing developer_instructions\n' "$agent_file" >&2
    exit 1
  }
done

for skill_file in "$PLUGIN_DIR"/skills/*/SKILL.md; do
  head -n 1 "$skill_file" | grep -qx -- '---' || {
    printf '%s: missing YAML frontmatter\n' "$skill_file" >&2
    exit 1
  }
done

printf 'codex harness validation passed\n'
