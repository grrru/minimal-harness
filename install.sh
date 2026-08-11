#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
manifest_path="$script_dir/manifest.json"
dry_run=0
group_filter="all"
only_names=()

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run] [--group GROUP] [--only NAME]...

  --dry-run       Print every command instead of running it.
  --group GROUP   Install only the skills in GROUP (see manifest.json), or "all".
  --only NAME     Install only the named skill. Repeatable.

Upstream plugins are installed only for a full run or --group core; --only always
limits the run to local skills.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    dry_run=1
    shift
    ;;
  --group)
    if [[ $# -lt 2 ]]; then
      printf 'Missing value for --group\n' >&2
      exit 2
    fi
    group_filter="$2"
    shift 2
    ;;
  --only)
    if [[ $# -lt 2 ]]; then
      printf 'Missing value for --only\n' >&2
      exit 2
    fi
    only_names+=("$2")
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

command -v codex >/dev/null 2>&1 || {
  printf 'codex CLI is required.\n' >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  printf 'python3 is required to read the manifest and Codex plugin state.\n' >&2
  exit 1
}

command -v rsync >/dev/null 2>&1 || {
  printf 'rsync is required to update local skills safely.\n' >&2
  exit 1
}

[[ -f "$manifest_path" ]] || {
  printf 'Missing manifest: %s\n' "$manifest_path" >&2
  exit 1
}

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'

  if [[ "$dry_run" -eq 0 ]]; then
    "$@"
  fi
}

contains() {
  local needle="$1"
  shift

  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

has_marketplace() {
  local marketplace_json
  marketplace_json="$(codex plugin marketplace list --json 2>/dev/null)"
  [[ "$marketplace_json" == *"\"name\": \"$1\""* ]]
}

has_enabled_plugin() {
  codex plugin list --json 2>/dev/null |
    python3 -c '
import json
import sys

plugin_id = sys.argv[1]
plugins = json.load(sys.stdin).get("installed", [])
enabled = any(
    plugin.get("pluginId") == plugin_id and plugin.get("enabled") is True
    for plugin in plugins
)
raise SystemExit(0 if enabled else 1)
' "$1"
}

# Read the manifest once; every install decision below comes from these rows.
names=()
paths=()
groups=()

while IFS=$'\t' read -r manifest_name manifest_path_value manifest_group; do
  names+=("$manifest_name")
  paths+=("$manifest_path_value")
  groups+=("$manifest_group")
done < <(python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = json.load(handle)

for skill in manifest["skills"]:
    print("\t".join((skill["name"], skill["path"], skill["group"])))
PY
)

if [[ "${#names[@]}" -eq 0 ]]; then
  printf 'No skills are declared in %s\n' "$manifest_path" >&2
  exit 1
fi

if [[ "$group_filter" != "all" ]] && ! contains "$group_filter" "${groups[@]}"; then
  printf 'Unknown group: %s\n' "$group_filter" >&2
  exit 2
fi

for only_name in ${only_names[@]+"${only_names[@]}"}; do
  if ! contains "$only_name" "${names[@]}"; then
    printf 'Unknown skill: %s\n' "$only_name" >&2
    exit 2
  fi
done

install_plugins=1

if [[ "${#only_names[@]}" -gt 0 ]]; then
  install_plugins=0
elif [[ "$group_filter" != "all" && "$group_filter" != "core" ]]; then
  install_plugins=0
fi

if [[ "$install_plugins" -eq 1 ]]; then
  if has_marketplace "agent-skills"; then
    run codex plugin marketplace upgrade agent-skills
  else
    run codex plugin marketplace add addyosmani/agent-skills
  fi

  if ! has_enabled_plugin "agent-skills@agent-skills"; then
    run codex plugin add agent-skills@agent-skills
  else
    printf '= already installed and enabled: agent-skills@agent-skills\n'
  fi

  if ! has_enabled_plugin "build-web-apps@openai-curated"; then
    run codex plugin add build-web-apps@openai-curated
  else
    printf '= already installed and enabled: build-web-apps@openai-curated\n'
  fi

  if ! has_enabled_plugin "browser@openai-bundled"; then
    run codex plugin add browser@openai-bundled
  else
    printf '= already installed and enabled: browser@openai-bundled\n'
  fi
else
  printf '= skipping upstream plugins for this filtered run\n'
fi

codex_base_dir="${CODEX_HOME:-${HOME}/.codex}"
codex_skills_dir="$codex_base_dir/skills"
installed=0

for index in "${!names[@]}"; do
  skill_name="${names[$index]}"
  skill_path="${paths[$index]}"
  skill_group="${groups[$index]}"

  if [[ "$group_filter" != "all" && "$skill_group" != "$group_filter" ]]; then
    continue
  fi

  if [[ "${#only_names[@]}" -gt 0 ]] && ! contains "$skill_name" "${only_names[@]}"; then
    continue
  fi

  source_dir="$script_dir/$skill_path"
  target_dir="$codex_skills_dir/$skill_name"

  [[ -f "$source_dir/SKILL.md" ]] || {
    printf 'Missing local skill: %s\n' "$source_dir" >&2
    exit 1
  }

  [[ ! -L "$target_dir" ]] || {
    printf 'Refusing to overwrite symlink: %s\n' "$target_dir" >&2
    exit 1
  }

  run mkdir -p "$target_dir"
  run rsync -a --delete "$source_dir/" "$target_dir/"
  installed=$((installed + 1))
done

if [[ "$installed" -eq 0 ]]; then
  printf '\nNo skill matched the requested filters.\n' >&2
  exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf '\nDry run complete; no changes were made.\n'
else
  printf '\nInstalled %d local skill(s) into %s.\n' "$installed" "$codex_skills_dir"
  printf 'Open a new Codex task to load the updated skill list.\n'
fi
