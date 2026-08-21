#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
manifest_path="$script_dir/manifest.json"
dry_run=0
group_filter="all"
host_filter="all"
only_names=()

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run] [--host HOST] [--group GROUP] [--only NAME]...

  --dry-run       Print every command instead of running it.
  --host HOST     Install only the skills for HOST (codex, aside), or "all".
  --group GROUP   Install only the skills in GROUP (see manifest.json), or "all".
  --only NAME     Install only the named skill. Repeatable.

Each skill installs into the skills directory of its host:

  codex   ${CODEX_SKILLS_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}
  aside   ${ASIDE_SKILLS_DIR:-${ASIDE_HOME:-$HOME/.aside}/u/0/skills/user}

Upstream Codex plugins are installed only for a full run or --group core; --only
always limits the run to local skills.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    dry_run=1
    shift
    ;;
  --host)
    if [[ $# -lt 2 ]]; then
      printf 'Missing value for --host\n' >&2
      exit 2
    fi
    host_filter="$2"
    shift 2
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
hosts=()
groups=()

while IFS=$'\t' read -r manifest_name manifest_path_value manifest_host manifest_group; do
  names+=("$manifest_name")
  paths+=("$manifest_path_value")
  hosts+=("$manifest_host")
  groups+=("$manifest_group")
done < <(python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = json.load(handle)

for skill in manifest["skills"]:
    print("\t".join((skill["name"], skill["path"], skill["host"], skill["group"])))
PY
)

if [[ "${#names[@]}" -eq 0 ]]; then
  printf 'No skills are declared in %s\n' "$manifest_path" >&2
  exit 1
fi

if [[ "$host_filter" != "all" ]] && ! contains "$host_filter" "${hosts[@]}"; then
  printf 'Unknown host: %s\n' "$host_filter" >&2
  exit 2
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
elif [[ "$host_filter" != "all" && "$host_filter" != "codex" ]]; then
  install_plugins=0
fi

if [[ "$install_plugins" -eq 1 ]]; then
  command -v codex >/dev/null 2>&1 || {
    printf 'codex CLI is required to install the upstream plugins.\n' >&2
    exit 1
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
else
  printf '= skipping upstream plugins for this filtered run\n'
fi

codex_skills_dir="${CODEX_SKILLS_DIR:-${CODEX_HOME:-${HOME}/.codex}/skills}"
aside_skills_dir="${ASIDE_SKILLS_DIR:-${ASIDE_HOME:-${HOME}/.aside}/u/0/skills/user}"
installed=0
installed_dirs=()

host_skills_dir() {
  case "$1" in
  codex) printf '%s' "$codex_skills_dir" ;;
  aside) printf '%s' "$aside_skills_dir" ;;
  *)
    printf 'Unknown host in manifest: %s\n' "$1" >&2
    exit 1
    ;;
  esac
}

for index in "${!names[@]}"; do
  skill_name="${names[$index]}"
  skill_path="${paths[$index]}"
  skill_host="${hosts[$index]}"
  skill_group="${groups[$index]}"

  if [[ "$host_filter" != "all" && "$skill_host" != "$host_filter" ]]; then
    continue
  fi

  if [[ "$group_filter" != "all" && "$skill_group" != "$group_filter" ]]; then
    continue
  fi

  if [[ "${#only_names[@]}" -gt 0 ]] && ! contains "$skill_name" "${only_names[@]}"; then
    continue
  fi

  source_dir="$script_dir/$skill_path"
  target_root="$(host_skills_dir "$skill_host")"
  target_dir="$target_root/$skill_name"

  [[ -f "$source_dir/SKILL.md" ]] || {
    printf 'Missing local skill: %s\n' "$source_dir" >&2
    exit 1
  }

  [[ ! -L "$target_dir" ]] || {
    printf 'Refusing to overwrite symlink: %s\n' "$target_dir" >&2
    exit 1
  }

  # Codex reads agents/openai.yaml; Aside has no such file and would ship it as dead weight.
  if [[ "$skill_host" != "codex" && -e "$source_dir/agents/openai.yaml" ]]; then
    printf 'Skill %s targets host %s but carries a Codex agents/openai.yaml\n' "$skill_name" "$skill_host" >&2
    exit 1
  fi

  run mkdir -p "$target_dir"
  run rsync -a --delete "$source_dir/" "$target_dir/"
  installed=$((installed + 1))

  if ! contains "$target_root" ${installed_dirs[@]+"${installed_dirs[@]}"}; then
    installed_dirs+=("$target_root")
  fi
done

if [[ "$installed" -eq 0 ]]; then
  printf '\nNo skill matched the requested filters.\n' >&2
  exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf '\nDry run complete; no changes were made.\n'
else
  printf '\nInstalled %d local skill(s) into:\n' "$installed"
  printf '  %s\n' ${installed_dirs[@]+"${installed_dirs[@]}"}
  printf 'Restart the host (new Codex task, or reload Aside) to load the updated skill list.\n'
fi
