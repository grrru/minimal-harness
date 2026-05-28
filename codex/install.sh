#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$ROOT_DIR/plugins/minimal-codex-harness"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"

DRY_RUN=0
YES=0
SKIP_PLUGIN=0
SKIP_CONFIG=0
SKIP_AGENTS=0
SKIP_SKILLS=0
SKIP_AGENTS_MD=0
LIST_ECC=0
FETCH_ECC=0
ECC_SOURCE=""
ECC_SKILLS=()
ECC_MCPS=()
ECC_HOOKS=()
ECC_REPOSITORY="https://github.com/affaan-m/ECC.git"

BEGIN_MARKER="<!-- minimal-codex-harness:begin -->"
END_MARKER="<!-- minimal-codex-harness:end -->"
CONFIG_BEGIN_MARKER="# minimal-codex-harness:begin"
CONFIG_END_MARKER="# minimal-codex-harness:end"

usage() {
  cat <<'EOF'
Usage: codex/install.sh [options]

Options:
  --dry-run          Show planned writes without changing files.
  --yes             Skip confirmation.
  --skip-plugin     Do not install the plugin bundle or personal marketplace entry.
  --skip-config     Do not merge ~/.codex/config.toml agent registrations.
  --skip-agents     Do not install ~/.codex/agents files.
  --skip-skills     Do not install ~/.agents/skills files.
  --skip-agents-md  Do not merge ~/.codex/AGENTS.md.
  --list-ecc        Show the ECC upstream inventory/adoption summary and exit.
  --fetch-ecc       Clone ECC into ../upstream/ECC if missing, or git fetch it
                    if it already exists. Used alone, fetches and exits.
                    With ECC selection flags, fetches before selected install.
  --ecc-source PATH Use a local ECC clone for selected ECC material.
                    Defaults to ../upstream/ECC when an ECC option is used.
  --with-ecc-skill NAME
                    Add one ECC skill to a separate ecc-selected plugin.
                    Repeat or pass comma-separated names.
  --with-ecc-mcp NAME
                    Add one ECC MCP server definition to ecc-selected.
                    Definitions are copied disabled by default.
  --stage-ecc-hook NAME
                    Stage one ECC hook bundle in ecc-selected without enabling it.
                    Supported names depend on the ECC clone, e.g. runtime,
                    memory-persistence.
  -h, --help        Show this help.
EOF
}

add_ecc_skill_values() {
  local item values
  IFS=',' read -ra values <<<"$1"
  for item in "${values[@]}"; do
    [[ -n "$item" ]] && ECC_SKILLS+=("$item")
  done
}

add_ecc_mcp_values() {
  local item values
  IFS=',' read -ra values <<<"$1"
  for item in "${values[@]}"; do
    [[ -n "$item" ]] && ECC_MCPS+=("$item")
  done
}

add_ecc_hook_values() {
  local item values
  IFS=',' read -ra values <<<"$1"
  for item in "${values[@]}"; do
    [[ -n "$item" ]] && ECC_HOOKS+=("$item")
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN=1
    shift
    ;;
  --yes)
    YES=1
    shift
    ;;
  --skip-plugin)
    SKIP_PLUGIN=1
    shift
    ;;
  --skip-config)
    SKIP_CONFIG=1
    shift
    ;;
  --skip-agents)
    SKIP_AGENTS=1
    shift
    ;;
  --skip-skills)
    SKIP_SKILLS=1
    shift
    ;;
  --skip-agents-md)
    SKIP_AGENTS_MD=1
    shift
    ;;
  --list-ecc)
    LIST_ECC=1
    shift
    ;;
  --fetch-ecc)
    FETCH_ECC=1
    shift
    ;;
  --ecc-source)
    [[ $# -ge 2 ]] || {
      echo "--ecc-source requires a path" >&2
      exit 1
    }
    ECC_SOURCE="$2"
    shift 2
    ;;
  --ecc-source=*)
    ECC_SOURCE="${1#*=}"
    shift
    ;;
  --with-ecc-skill)
    [[ $# -ge 2 ]] || {
      echo "--with-ecc-skill requires a name" >&2
      exit 1
    }
    add_ecc_skill_values "$2"
    shift 2
    ;;
  --with-ecc-skill=*)
    add_ecc_skill_values "${1#*=}"
    shift
    ;;
  --with-ecc-mcp)
    [[ $# -ge 2 ]] || {
      echo "--with-ecc-mcp requires a name" >&2
      exit 1
    }
    add_ecc_mcp_values "$2"
    shift 2
    ;;
  --with-ecc-mcp=*)
    add_ecc_mcp_values "${1#*=}"
    shift
    ;;
  --stage-ecc-hook)
    [[ $# -ge 2 ]] || {
      echo "--stage-ecc-hook requires a name" >&2
      exit 1
    }
    add_ecc_hook_values "$2"
    shift 2
    ;;
  --stage-ecc-hook=*)
    add_ecc_hook_values "${1#*=}"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

timestamp="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="$CODEX_HOME/backups/minimal-codex-harness/$timestamp"

log() {
  printf '[minimal-codex-harness] %s\n' "$1"
}

relative_home() {
  case "$1" in
  "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
  *) printf '%s' "$1" ;;
  esac
}

ensure_parent() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would create directory $(relative_home "$(dirname "$1")")"
  else
    mkdir -p "$(dirname "$1")"
  fi
}

backup_path_for() {
  local target="$1"
  local rel
  case "$target" in
  "$HOME"/*) rel="${target#"$HOME"/}" ;;
  *) rel="external/$(basename "$target")" ;;
  esac
  printf '%s/%s' "$BACKUP_DIR" "$rel"
}

backup_existing() {
  local target="$1"
  [[ -e "$target" ]] || return 0
  local backup
  backup="$(backup_path_for "$target")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would back up $(relative_home "$target") -> $(relative_home "$backup")"
  else
    mkdir -p "$(dirname "$backup")"
    cp -R "$target" "$backup"
  fi
}

install_dir() {
  local source="$1"
  local target="$2"
  if [[ -d "$target" ]] && diff -qr "$source" "$target" >/dev/null 2>&1; then
    log "skip $(relative_home "$target")"
    return 0
  fi
  log "install $(relative_home "$target")"
  backup_existing "$target"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    rm -rf "$target"
    mkdir -p "$(dirname "$target")"
    cp -R "$source" "$target"
  fi
}

install_file() {
  local source="$1"
  local target="$2"
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    log "skip $(relative_home "$target")"
    return 0
  fi
  log "install $(relative_home "$target")"
  backup_existing "$target"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    ensure_parent "$target"
    cp "$source" "$target"
  fi
}

merge_agents_md() {
  local template="$ROOT_DIR/templates/AGENTS.md"
  local target="$CODEX_HOME/AGENTS.md"
  local block next
  block="$(mktemp)"
  next="$(mktemp)"
  {
    printf '%s\n' "$BEGIN_MARKER"
    cat "$template"
    printf '%s\n' "$END_MARKER"
  } >"$block"

  if [[ ! -f "$target" ]]; then
    cp "$block" "$next"
  elif grep -Fq "$BEGIN_MARKER" "$target"; then
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v block="$block" '
      $0 == begin {
        while ((getline line < block) > 0) print line
        in_block = 1
        next
      }
      in_block && $0 == end {
        in_block = 0
        next
      }
      !in_block { print }
    ' "$target" >"$next"
  else
    {
      cat "$target"
      printf '\n\n'
      cat "$block"
    } >"$next"
  fi

  if [[ -f "$target" ]] && cmp -s "$target" "$next"; then
    log "skip $(relative_home "$target")"
  else
    log "merge $(relative_home "$target")"
    backup_existing "$target"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      ensure_parent "$target"
      cp "$next" "$target"
    fi
  fi

  rm -f "$block" "$next"
}

merge_codex_config() {
  local snippet="$ROOT_DIR/templates/config.agents.toml"
  local target="$CODEX_HOME/config.toml"
  local block next
  block="$(mktemp)"
  next="$(mktemp)"
  {
    printf '%s\n' "$CONFIG_BEGIN_MARKER"
    cat "$snippet"
    printf '%s\n' "$CONFIG_END_MARKER"
  } >"$block"

  if [[ -f "$target" ]] && ! grep -Fq "$CONFIG_BEGIN_MARKER" "$target"; then
    if grep -Eq '^[[:space:]]*\[agents\.("code-mapper"|"reviewer"|"docs-researcher"|code-mapper|reviewer|docs-researcher)\][[:space:]]*$' "$target"; then
      log "skip $(relative_home "$target") agent registration; existing agent table found"
      rm -f "$block" "$next"
      return 0
    fi
  fi

  if [[ ! -f "$target" ]]; then
    cp "$block" "$next"
  elif grep -Fq "$CONFIG_BEGIN_MARKER" "$target"; then
    awk -v begin="$CONFIG_BEGIN_MARKER" -v end="$CONFIG_END_MARKER" -v block="$block" '
      $0 == begin {
        while ((getline line < block) > 0) print line
        in_block = 1
        next
      }
      in_block && $0 == end {
        in_block = 0
        next
      }
      !in_block { print }
    ' "$target" >"$next"
  else
    {
      cat "$target"
      printf '\n\n'
      cat "$block"
    } >"$next"
  fi

  if [[ -f "$target" ]] && cmp -s "$target" "$next"; then
    log "skip $(relative_home "$target")"
  else
    log "merge $(relative_home "$target")"
    backup_existing "$target"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      ensure_parent "$target"
      cp "$next" "$target"
    fi
  fi

  rm -f "$block" "$next"
}

personal_plugin_source_path() {
  local target="$1"
  case "$target" in
  "$HOME"/*) printf './%s' "${target#"$HOME"/}" ;;
  *) printf '%s' "$target" ;;
  esac
}

merge_personal_marketplace() {
  local target="$AGENTS_HOME/plugins/marketplace.json"
  local plugin_target="$CODEX_HOME/plugins/minimal-codex-harness"
  local source_path
  source_path="$(personal_plugin_source_path "$plugin_target")"

  log "merge $(relative_home "$target")"
  backup_existing "$target"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would add marketplace entry minimal-codex-harness -> $source_path"
    return 0
  fi

  ensure_parent "$target"
  node - "$target" "$source_path" <<'EOF'
const fs = require('fs');

const target = process.argv[2];
const sourcePath = process.argv[3];
let marketplace = {
  name: 'personal',
  interface: { displayName: 'Personal' },
  plugins: [],
};

if (fs.existsSync(target)) {
  marketplace = JSON.parse(fs.readFileSync(target, 'utf8'));
}

if (!marketplace.name) {
  marketplace.name = 'personal';
}
if (!marketplace.interface || typeof marketplace.interface !== 'object') {
  marketplace.interface = { displayName: 'Personal' };
}
if (!Array.isArray(marketplace.plugins)) {
  marketplace.plugins = [];
}

const entry = {
  name: 'minimal-codex-harness',
  source: {
    source: 'local',
    path: sourcePath,
  },
  policy: {
    installation: 'AVAILABLE',
    authentication: 'ON_INSTALL',
  },
  category: 'Productivity',
};

const index = marketplace.plugins.findIndex(plugin => plugin.name === entry.name);
if (index === -1) {
  marketplace.plugins.push(entry);
} else {
  marketplace.plugins[index] = {
    ...marketplace.plugins[index],
    ...entry,
    policy: entry.policy,
    source: entry.source,
  };
}

fs.writeFileSync(target, `${JSON.stringify(marketplace, null, 2)}\n`);
EOF
}

join_csv() {
  local IFS=,
  printf '%s' "$*"
}

selected_ecc_count() {
  printf '%s' "$((${#ECC_SKILLS[@]} + ${#ECC_MCPS[@]} + ${#ECC_HOOKS[@]}))"
}

default_ecc_source() {
  printf '%s' "$ROOT_DIR/../upstream/ECC"
}

list_ecc_inventory() {
  node - "$ROOT_DIR/optional/ecc/inventory.json" "$ROOT_DIR/optional/ecc/adoption.json" <<'EOF'
const fs = require('fs');

const inventory = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const adoption = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));

const included = adoption.included || [];
const candidates = adoption.candidates || {};

console.log('ECC upstream snapshot');
console.log(`  repo: ${inventory.upstream.repository}`);
console.log(`  version: ${inventory.upstream.version}`);
console.log(`  commit: ${inventory.upstream.commit}`);
console.log(`  checked_at: ${inventory.upstream.checked_at}`);
console.log('');
console.log('Surfaces');
for (const [name, count] of Object.entries(inventory.counts)) {
console.log(`  ${name}: ${count}`);
}
if (included.length > 0) {
  console.log('');
  console.log('Included ECC material');
  for (const entry of included) {
    console.log(`  ${entry.type}:${entry.name} -> ${entry.target}`);
  }
}
console.log('');
console.log('Candidate buckets');
for (const [bucket, values] of Object.entries(candidates)) {
  console.log(`  ${bucket}: ${(values || []).map((entry) => entry.name).join(', ')}`);
}
EOF
}

resolve_ecc_source_path() {
  local source="$ECC_SOURCE"
  if [[ -z "$source" ]]; then
    source="$(default_ecc_source)"
  fi
  printf '%s' "$source"
}

fetch_ecc_source() {
  [[ "$FETCH_ECC" -eq 1 ]] || return 0

  local source
  source="$(resolve_ecc_source_path)"

  if [[ -d "$source/.git" ]]; then
    log "fetch ECC upstream at $source"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would run: git -C $source fetch --tags --prune origin"
    else
      git -C "$source" fetch --tags --prune origin
    fi
    return 0
  fi

  if [[ -e "$source" ]]; then
    echo "ECC source exists but is not a git clone: $source" >&2
    exit 1
  fi

  log "clone ECC upstream to $source"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would run: git clone $ECC_REPOSITORY $source"
  else
    mkdir -p "$(dirname "$source")"
    git clone "$ECC_REPOSITORY" "$source"
  fi
}

resolve_ecc_source() {
  local source
  source="$(resolve_ecc_source_path)"
  if [[ ! -d "$source" ]]; then
    echo "ECC source not found: $source" >&2
    echo "Clone it first or pass --fetch-ecc: git clone $ECC_REPOSITORY upstream/ECC" >&2
    exit 1
  fi
  if [[ ! -f "$source/.codex-plugin/plugin.json" ]]; then
    echo "ECC source is missing .codex-plugin/plugin.json: $source" >&2
    exit 1
  fi
  (cd "$source" && pwd)
}

merge_ecc_selected_marketplace() {
  local target="$AGENTS_HOME/plugins/marketplace.json"
  local plugin_target="$CODEX_HOME/plugins/ecc-selected"
  local source_path
  source_path="$(personal_plugin_source_path "$plugin_target")"

  log "merge $(relative_home "$target")"
  backup_existing "$target"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would add marketplace entry ecc-selected -> $source_path"
    return 0
  fi

  ensure_parent "$target"
  node - "$target" "$source_path" <<'EOF'
const fs = require('fs');

const target = process.argv[2];
const sourcePath = process.argv[3];
let marketplace = {
  name: 'personal',
  interface: { displayName: 'Personal' },
  plugins: [],
};

if (fs.existsSync(target)) {
  marketplace = JSON.parse(fs.readFileSync(target, 'utf8'));
}

if (!marketplace.name) {
  marketplace.name = 'personal';
}
if (!marketplace.interface || typeof marketplace.interface !== 'object') {
  marketplace.interface = { displayName: 'Personal' };
}
if (!Array.isArray(marketplace.plugins)) {
  marketplace.plugins = [];
}

const entry = {
  name: 'ecc-selected',
  source: {
    source: 'local',
    path: sourcePath,
  },
  policy: {
    installation: 'AVAILABLE',
    authentication: 'ON_INSTALL',
  },
  category: 'Productivity',
};

const index = marketplace.plugins.findIndex(plugin => plugin.name === entry.name);
if (index === -1) {
  marketplace.plugins.push(entry);
} else {
  marketplace.plugins[index] = {
    ...marketplace.plugins[index],
    ...entry,
    policy: entry.policy,
    source: entry.source,
  };
}

fs.writeFileSync(target, `${JSON.stringify(marketplace, null, 2)}\n`);
EOF
}

install_ecc_selected_plugin() {
  [[ "$(selected_ecc_count)" -gt 0 ]] || return 0

  local ecc_source target skills_csv mcps_csv hooks_csv
  if [[ "$DRY_RUN" -eq 1 && "$FETCH_ECC" -eq 1 && ! -d "$(resolve_ecc_source_path)" ]]; then
    ecc_source="$(resolve_ecc_source_path)"
  else
    ecc_source="$(resolve_ecc_source)"
  fi
  target="$CODEX_HOME/plugins/ecc-selected"
  skills_csv=""
  mcps_csv=""
  hooks_csv=""
  [[ "${#ECC_SKILLS[@]}" -gt 0 ]] && skills_csv="$(join_csv "${ECC_SKILLS[@]}")"
  [[ "${#ECC_MCPS[@]}" -gt 0 ]] && mcps_csv="$(join_csv "${ECC_MCPS[@]}")"
  [[ "${#ECC_HOOKS[@]}" -gt 0 ]] && hooks_csv="$(join_csv "${ECC_HOOKS[@]}")"

  log "install $(relative_home "$target") from ECC selections"
  log "ECC source=$ecc_source"
  backup_existing "$target"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    [[ -n "$skills_csv" ]] && log "would include ECC skills: $skills_csv"
    [[ -n "$mcps_csv" ]] && log "would include ECC MCP definitions disabled by default: $mcps_csv"
    [[ -n "$hooks_csv" ]] && log "would stage ECC hooks without enabling: $hooks_csv"
    merge_ecc_selected_marketplace
    return 0
  fi

  rm -rf "$target"
  mkdir -p "$target"

  node - "$ecc_source" "$target" "$skills_csv" "$mcps_csv" "$hooks_csv" <<'EOF'
const fs = require('fs');
const path = require('path');

const [source, target, skillsCsv, mcpsCsv, hooksCsv] = process.argv.slice(2);
const split = (value) => value.split(',').map((item) => item.trim()).filter(Boolean);
const skills = split(skillsCsv);
const mcps = split(mcpsCsv);
const hooks = split(hooksCsv);

function copyRecursive(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.cpSync(from, to, { recursive: true });
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

for (const skill of skills) {
  const from = path.join(source, 'skills', skill);
  if (!fs.existsSync(path.join(from, 'SKILL.md'))) {
    throw new Error(`ECC skill not found: ${skill}`);
  }
  copyRecursive(from, path.join(target, 'skills', skill));
}

if (mcps.length) {
  const mcpFile = path.join(source, '.mcp.json');
  if (!fs.existsSync(mcpFile)) {
    throw new Error('ECC .mcp.json not found');
  }
  const upstream = JSON.parse(fs.readFileSync(mcpFile, 'utf8')).mcpServers || {};
  const selected = {};
  for (const name of mcps) {
    if (!upstream[name]) {
      throw new Error(`ECC MCP server not found: ${name}`);
    }
    selected[name] = { ...upstream[name], enabled: false };
  }
  writeJson(path.join(target, '.mcp.json'), { mcpServers: selected });
}

if (hooks.length) {
  const stagedRoot = path.join(target, 'hooks', 'staged');
  fs.mkdirSync(stagedRoot, { recursive: true });
  for (const name of hooks) {
    if (name === 'runtime') {
      const hooksFile = path.join(source, 'hooks', 'hooks.json');
      if (!fs.existsSync(hooksFile)) {
        throw new Error('ECC runtime hooks not found');
      }
      copyRecursive(hooksFile, path.join(stagedRoot, 'runtime', 'hooks.json'));
      const readme = path.join(source, 'hooks', 'README.md');
      if (fs.existsSync(readme)) {
        copyRecursive(readme, path.join(stagedRoot, 'runtime', 'README.md'));
      }
      continue;
    }
    const from = path.join(source, 'hooks', name);
    if (!fs.existsSync(from)) {
      throw new Error(`ECC hook bundle not found: ${name}`);
    }
    copyRecursive(from, path.join(stagedRoot, name));
  }
  fs.writeFileSync(
    path.join(target, 'hooks', 'README.md'),
    [
      '# ECC Hook Staging',
      '',
      'These hook files were copied from ECC for audit and adaptation only.',
      'They are not referenced from plugin.json and are not enabled by this installer.',
      'Enable hooks only after checking the commands, environment variables, and Codex hook compatibility.',
      '',
    ].join('\n'),
  );
}

const manifest = {
  name: 'ecc-selected',
  version: '0.1.0',
  description: 'Explicitly selected ECC material installed for Codex.',
  author: {
    name: 'affaan-m/ECC and local agents harness',
  },
  homepage: 'https://github.com/affaan-m/ECC',
  repository: 'https://github.com/affaan-m/ECC',
  license: 'MIT',
  interface: {
    displayName: 'ECC Selected',
    shortDescription: 'Selected ECC skills and MCP definitions for Codex.',
    longDescription: 'A local Codex plugin generated by the agents harness from explicitly selected ECC upstream material.',
    developerName: 'agents repo',
    category: 'Productivity',
    capabilities: ['Read', 'Write'],
    defaultPrompt: [
      'Use ECC Selected only when the user requests one of the selected ECC workflows.',
      'Treat staged ECC hooks as inactive reference material unless explicitly adapted and enabled.',
    ],
  },
};

if (skills.length) {
  manifest.skills = './skills/';
}
if (mcps.length) {
  manifest.mcpServers = './.mcp.json';
}

writeJson(path.join(target, '.codex-plugin', 'plugin.json'), manifest);
fs.writeFileSync(
  path.join(target, 'README.md'),
  [
    '# ECC Selected',
    '',
    'Generated by `codex/install.sh` from a local ECC clone.',
    '',
    `Skills: ${skills.length ? skills.join(', ') : 'none'}`,
    `MCP servers: ${mcps.length ? mcps.join(', ') : 'none'} (disabled by default)`,
    `Hook bundles: ${hooks.length ? hooks.join(', ') : 'none'} (staged only)`,
    '',
  ].join('\n'),
);
EOF

  merge_ecc_selected_marketplace
}

if [[ "$LIST_ECC" -eq 1 ]]; then
  fetch_ecc_source
  list_ecc_inventory
  exit 0
fi

if [[ "$FETCH_ECC" -eq 1 && "$(selected_ecc_count)" -eq 0 ]]; then
  fetch_ecc_source
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "dry-run complete; no files changed"
  else
    log "fetch-ecc complete"
  fi
  exit 0
fi

log "CODEX_HOME=$(relative_home "$CODEX_HOME")"
log "AGENTS_HOME=$(relative_home "$AGENTS_HOME")"
log "backup dir=$(relative_home "$BACKUP_DIR")"

if [[ "$DRY_RUN" -eq 0 && "$YES" -eq 0 ]]; then
  printf 'Install minimal Codex harness? [y/N] '
  read -r answer
  case "$answer" in
  y | Y | yes | YES) ;;
  *)
    log "cancelled"
    exit 0
    ;;
  esac
fi

fetch_ecc_source

if [[ "$SKIP_AGENTS_MD" -eq 0 ]]; then
  merge_agents_md
fi

if [[ "$SKIP_PLUGIN" -eq 0 ]]; then
  install_dir "$PLUGIN_DIR" "$CODEX_HOME/plugins/minimal-codex-harness"
  merge_personal_marketplace
fi

if [[ "$SKIP_CONFIG" -eq 0 ]]; then
  merge_codex_config
fi

if [[ "$SKIP_AGENTS" -eq 0 ]]; then
  for agent_file in "$ROOT_DIR"/agents/*.toml; do
    [[ -e "$agent_file" ]] || continue
    install_file "$agent_file" "$CODEX_HOME/agents/$(basename "$agent_file")"
  done
fi

if [[ "$SKIP_SKILLS" -eq 0 ]]; then
  for skill_dir in "$PLUGIN_DIR"/skills/*; do
    [[ -d "$skill_dir" ]] || continue
    install_dir "$skill_dir" "$AGENTS_HOME/skills/$(basename "$skill_dir")"
  done
fi

install_ecc_selected_plugin

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run complete; no files changed"
else
  log "install complete; restart Codex to reload config, plugins, agents, and skills"
fi
