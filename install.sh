#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
manifest_path="$script_dir/manifest.json"
dry_run=0
group_filter="all"
host_filter="all"
only_names=()
tui_mode="auto"

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run] [--tui|--no-tui] [--host HOST] [--group GROUP]
                  [--only NAME]...

  --dry-run       Print every command instead of running it.
  --host HOST     Install only the items for HOST (codex, aside), or "all".
  --group GROUP   Install only the items in GROUP (see manifest.json), or "all".
  --only NAME     Install only the named skill or plugin. Repeatable.
  --tui           Force the interactive picker. Fails without a terminal.
  --no-tui        Never open the picker; install exactly what the flags select.

Local skills and upstream Codex plugins are both manifest entries, so every
flag and every picker row treats them alike. Group "upstream" holds the plugins.

With no filter flags on a terminal, the picker opens preselected with everything.
Filter flags preselect the picker instead of bypassing it, so
`--host aside --tui` opens it with only the Aside skills checked.

Each skill installs into the skills directory of its host:

  codex   ${CODEX_SKILLS_DIR:-${CODEX_HOME:-$HOME/.codex}/skills}
  aside   ${ASIDE_SKILLS_DIR:-${ASIDE_HOME:-$HOME/.aside}/u/0/skills/user}

Plugins install through `codex plugin add`, which the codex CLI must be on PATH
for.
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
  --tui)
    tui_mode="force"
    shift
    ;;
  --no-tui)
    tui_mode="off"
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
# Skills and upstream plugins share one list so the filters, the picker, and the
# install loop treat them the same way.
kinds=()
names=()
refs=()
extras=()
hosts=()
groups=()

while IFS=$'\x1f' read -r row_kind row_name row_ref row_extra row_host row_group; do
  kinds+=("$row_kind")
  names+=("$row_name")
  refs+=("$row_ref")
  extras+=("$row_extra")
  hosts+=("$row_host")
  groups+=("$row_group")
done < <(python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = json.load(handle)

for skill in manifest["skills"]:
    print("\x1f".join(("skill", skill["name"], skill["path"], "", skill["host"], skill["group"])))

for plugin in manifest.get("plugins", []):
    # extra carries the marketplace to add when Codex does not already ship it.
    print("\x1f".join((
        "plugin",
        plugin["name"],
        plugin["id"],
        plugin.get("marketplace_add", ""),
        plugin["host"],
        plugin["group"],
    )))
PY
)

if [[ "${#names[@]}" -eq 0 ]]; then
  printf 'Nothing is declared in %s\n' "$manifest_path" >&2
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
    printf 'Unknown skill or plugin: %s\n' "$only_name" >&2
    exit 2
  fi
done

codex_skills_dir="${CODEX_SKILLS_DIR:-${CODEX_HOME:-${HOME}/.codex}/skills}"
aside_skills_dir="${ASIDE_SKILLS_DIR:-${ASIDE_HOME:-${HOME}/.aside}/u/0/skills/user}"

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

# The flags select; the picker, when it runs, edits that selection. Everything
# downstream reads only selected[] and install_plugins.
selected=()
filters_used=0

if [[ "$host_filter" != "all" || "$group_filter" != "all" || "${#only_names[@]}" -gt 0 ]]; then
  filters_used=1
fi

for index in "${!names[@]}"; do
  keep=1

  if [[ "$host_filter" != "all" && "${hosts[$index]}" != "$host_filter" ]]; then
    keep=0
  fi

  if [[ "$group_filter" != "all" && "${groups[$index]}" != "$group_filter" ]]; then
    keep=0
  fi

  if [[ "${#only_names[@]}" -gt 0 ]] && ! contains "${names[$index]}" "${only_names[@]}"; then
    keep=0
  fi

  selected+=("$keep")
done

# The section a row is filed under in the picker: its host for a skill, and
# "upstream" for a plugin, which installs through the codex CLI rather than into
# a skills directory.
sections=()

for index in "${!names[@]}"; do
  if [[ "${kinds[$index]}" == "plugin" ]]; then
    sections+=("upstream")
  else
    sections+=("${hosts[$index]}")
  fi
done

# ---------------------------------------------------------------- picker ----

use_tui=0

case "$tui_mode" in
force)
  if [[ ! -t 0 || ! -t 1 ]]; then
    printf '%s\n' '--tui needs an interactive terminal.' >&2
    exit 2
  fi
  use_tui=1
  ;;
auto)
  if [[ -t 0 && -t 1 ]]; then
    use_tui=1
  fi
  ;;
off) ;;
esac

tui_cursor=0
tui_rows=0

tui_leave() {
  printf '\033[?25h\033[?1049l'
}

tui_key() {
  local key rest
  IFS= read -rsn1 key 2>/dev/null || {
    printf 'quit'
    return
  }

  case "$key" in
  $'\033')
    rest=""
    IFS= read -rsn2 -t 0.05 rest 2>/dev/null || true
    case "$rest" in
    '[A') printf 'up' ;;
    '[B') printf 'down' ;;
    *) printf 'quit' ;;
    esac
    ;;
  "") printf 'enter' ;;
  " ") printf 'space' ;;
  *) printf '%s' "$key" ;;
  esac
}

tui_count_selected() {
  local total=0 index
  for index in "${!names[@]}"; do
    total=$((total + selected[index]))
  done
  printf '%d' "$total"
}

tui_section_header() {
  case "$1" in
  upstream) printf '  \033[1mupstream\033[0m \033[2m→ codex plugin add\033[0m\n' ;;
  *) printf '  \033[1m%s\033[0m \033[2m→ %s\033[0m\n' "$1" "$(host_skills_dir "$1")" ;;
  esac
}

tui_render() {
  local index section current_section="" marker pointer detail

  printf '\033[H\033[2J'
  printf '  \033[1mminimal-harness\033[0m — installer\n'
  printf '  \033[2m%d of %d items selected%s\033[0m\n\n' \
    "$(tui_count_selected)" "${#names[@]}" \
    "$([[ "$dry_run" -eq 1 ]] && printf ' · dry run')"

  for index in "${!names[@]}"; do
    section="${sections[$index]}"

    if [[ "$section" != "$current_section" ]]; then
      [[ -z "$current_section" ]] || printf '\n'
      current_section="$section"
      tui_section_header "$section"
    fi

    if [[ "${selected[$index]}" -eq 1 ]]; then
      marker='x'
    else
      marker=' '
    fi

    if [[ "$index" -eq "$tui_cursor" ]]; then
      pointer='❯'
    else
      pointer=' '
    fi

    if [[ "${kinds[$index]}" == "plugin" ]]; then
      detail="${refs[$index]}"
    else
      detail="${groups[$index]}"
    fi

    printf '  %s [%s] %-26s \033[2m%s\033[0m\n' \
      "$pointer" "$marker" "${names[$index]}" "$detail"
  done

  printf '\n  \033[2m↑/↓ move · space toggle · a all · n none · d dry run · enter install · q quit\033[0m\n'
}

run_tui() {
  tui_rows="${#names[@]}"

  # Start on the first preselected row, so a filtered run opens on what it
  # selected rather than on a row the filter excluded.
  local start
  for start in "${!names[@]}"; do
    if [[ "${selected[$start]}" -eq 1 ]]; then
      tui_cursor="$start"
      break
    fi
  done

  trap tui_leave EXIT INT TERM
  printf '\033[?1049h\033[?25l'

  local key index

  while true; do
    tui_render
    key="$(tui_key)"

    case "$key" in
    up) tui_cursor=$(((tui_cursor - 1 + tui_rows) % tui_rows)) ;;
    k) tui_cursor=$(((tui_cursor - 1 + tui_rows) % tui_rows)) ;;
    down) tui_cursor=$(((tui_cursor + 1) % tui_rows)) ;;
    j) tui_cursor=$(((tui_cursor + 1) % tui_rows)) ;;
    space) selected[tui_cursor]=$((1 - selected[tui_cursor])) ;;
    a)
      for index in "${!names[@]}"; do
        selected[index]=1
      done
      ;;
    n)
      for index in "${!names[@]}"; do
        selected[index]=0
      done
      ;;
    d) dry_run=$((1 - dry_run)) ;;
    enter)
      if [[ "$(tui_count_selected)" -eq 0 ]]; then
        continue
      fi
      break
      ;;
    q)
      tui_leave
      trap - EXIT INT TERM
      printf 'Cancelled; nothing was installed.\n'
      exit 130
      ;;
    esac
  done

  tui_leave
  trap - EXIT INT TERM
}

if [[ "$use_tui" -eq 1 ]]; then
  run_tui
elif [[ "$filters_used" -eq 0 && "$tui_mode" == "auto" ]]; then
  printf '= no terminal detected; installing everything\n'
fi

# --------------------------------------------------------------- install ----

# Fail before touching anything if a selected plugin has no CLI to install it.
for index in "${!names[@]}"; do
  if [[ "${selected[$index]}" -eq 1 && "${kinds[$index]}" == "plugin" ]]; then
    command -v codex >/dev/null 2>&1 || {
      printf 'codex CLI is required to install the upstream plugins.\n' >&2
      exit 1
    }
    break
  fi
done

install_plugin() {
  local plugin_id="$1" marketplace_add="$2" marketplace

  marketplace="${plugin_id##*@}"

  if [[ -n "$marketplace_add" ]]; then
    if has_marketplace "$marketplace"; then
      run codex plugin marketplace upgrade "$marketplace"
    else
      run codex plugin marketplace add "$marketplace_add"
    fi
  fi

  if has_enabled_plugin "$plugin_id"; then
    printf '= already installed and enabled: %s\n' "$plugin_id"
    return
  fi

  run codex plugin add "$plugin_id"
}

installed=0
installed_plugins=0
installed_dirs=()

for index in "${!names[@]}"; do
  if [[ "${selected[$index]}" -eq 0 ]]; then
    continue
  fi

  if [[ "${kinds[$index]}" == "plugin" ]]; then
    install_plugin "${refs[$index]}" "${extras[$index]}"
    installed_plugins=$((installed_plugins + 1))
    continue
  fi

  skill_name="${names[$index]}"
  skill_host="${hosts[$index]}"

  source_dir="$script_dir/${refs[$index]}"
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

if [[ "$installed" -eq 0 && "$installed_plugins" -eq 0 ]]; then
  printf '\nNothing matched the requested filters.\n' >&2
  exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf '\nDry run complete; no changes were made.\n'
elif [[ "$installed" -eq 0 ]]; then
  printf '\nInstalled %d upstream plugin(s); no local skill was selected.\n' "$installed_plugins"
else
  printf '\nInstalled %d local skill(s) into:\n' "$installed"
  printf '  %s\n' ${installed_dirs[@]+"${installed_dirs[@]}"}

  if [[ "$installed_plugins" -gt 0 ]]; then
    printf 'Installed %d upstream plugin(s).\n' "$installed_plugins"
  fi

  printf 'Restart the host (new Codex task, or reload Aside) to load the updated skill list.\n'
fi
