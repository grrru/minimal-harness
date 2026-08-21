# AGENTS.md

Repository rules for working on this harness. This repo packages Codex skills;
it is not a Codex host itself.

## Layout

`manifest.json` is the single source of truth for what gets installed. A skill
that is not listed there is invisible to `install.sh`, no matter where its
directory sits.

The top level is split by host, because each host reads skills from a different
directory and expects a different skill format:

- `codex/skills/` — host `codex`, group `core`. Local skills that define the harness.
- `codex/vendor/` — host `codex`, group `vendor`. Upstream snapshots. Do not edit
  them here; change the upstream repository, then refresh the snapshot and the
  pinned commit in `SOURCES.lock.json`.
- `aside/skills/` — host `aside`, group `aside`. Skills for the Aside browser
  agent, installed into the Aside profile, not into Codex.

Adding a Codex skill means three things, all in the same commit: the directory
with `SKILL.md`, an `agents/openai.yaml`, and a `manifest.json` entry. An Aside
skill is the directory with `SKILL.md` plus the manifest entry — no
`agents/openai.yaml`; `install.sh` fails the run if a non-Codex skill carries one.

## Skill authoring

- Write skill bodies in English, including ported skills whose source is Korean.
- Frontmatter carries `name` and `description` only. Claude-specific keys
  (`allowed_tools`, `disable-model-invocation`) do not apply to Codex and are
  dropped when porting.
- `agents/openai.yaml` (Codex only) sets `interface.display_name`,
  `short_description`, and `default_prompt`. Skills that must never fire on their
  own also set `policy.allow_implicit_invocation: false`.
- Aside skills carry no companion file. Their frontmatter may add `icon` and
  `autoInject.keywords` on top of `name` and `description`.
- Codex has no `AskUserQuestion`, no `Skill` tool, and no subagents. A skill
  that needs a decision from the user presents labeled options as text and
  waits for a reply; it never fans work out to parallel agents.
- Record every ported or vendored skill in `SOURCES.lock.json` with its source
  and whether it was modified.

## Verification

Changes to `install.sh` or `manifest.json` are verified before commit:

```sh
./install.sh --dry-run
CODEX_HOME="$(mktemp -d)" ./install.sh --only <codex-skill>  # then diff -rq against the source
ASIDE_SKILLS_DIR="$(mktemp -d)" ./install.sh --host aside    # then diff -rq against the source
```

Installation uses `rsync --delete`, so it replaces a same-named skill already
present in the host's skills directory.

## Commits

- Commit only when the user asks. Stage files explicitly; never `git add -A`.
- Use the `create-commit` skill's convention. Subject lines are English.
- Check whether `README.md` and this file need updating in the same commit.
