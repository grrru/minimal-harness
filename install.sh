#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dry_run=0

usage() {
  printf 'Usage: %s [--dry-run]\n' "${0##*/}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    dry_run=1
    shift
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
  printf 'python3 is required to inspect Codex plugin state.\n' >&2
  exit 1
}

command -v rsync >/dev/null 2>&1 || {
  printf 'rsync is required to update local skills safely.\n' >&2
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

codex_base_dir="${CODEX_HOME:-${HOME}/.codex}"
codex_skills_dir="$codex_base_dir/skills"

for skill_name in frontend-design greenfield-web-design; do
  source_dir="$script_dir/skills/$skill_name"
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
done

if [[ "$dry_run" -eq 1 ]]; then
  printf '\nDry run complete; no changes were made.\n'
else
  printf '\nInstalled upstream plugins and local design skills.\n'
  printf 'Open a new Codex task to load the updated skill list.\n'
fi
