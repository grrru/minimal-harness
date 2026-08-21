# Minimal Codex Harness

외부 스킬을 복제해 관리하지 않고, 원본 marketplace에서 설치하는 작은 Codex 디자인 하네스입니다.

핵심 흐름은 다음과 같습니다.

```text
frontend-design
  → ImageGen + Build Web Apps
  → Browser 우선 검증 / Playwright 폴백
```

## 구성

marketplace가 설치하는 upstream 구성입니다. `imagegen` 을 뺀 나머지는
`manifest.json` 의 `plugins` 항목이라, 로컬 스킬과 똑같이 개별 선택됩니다
(그룹 `upstream`).

- [Addy Osmani agent-skills](https://github.com/addyosmani/agent-skills): upstream Codex marketplace에서 설치·업데이트
- `build-web-apps`: OpenAI curated marketplace에서 설치
- `browser`: OpenAI bundled marketplace에서 설치
- `imagegen`: Codex 내장 스킬 사용 (설치 대상 아님)

이 저장소가 관리하는 스킬은 **호스트별 최상위 디렉토리** 아래에 둡니다. 어떤
스킬이 어느 호스트·그룹에 속하는지는 [`manifest.json`](manifest.json)이 단독으로
정하며, `install.sh`는 이 파일만 보고 설치합니다.

```text
codex/
  skills/   # group: core   — 하네스를 이루는 로컬 스킬
  vendor/   # group: vendor — upstream 스냅샷, 이 저장소에서 수정하지 않음
aside/
  skills/   # group: aside  — Aside 브라우저 에이전트용 스킬
```

호스트마다 설치 위치와 스킬 형식이 다릅니다.

| 호스트 | 설치 위치 | 스킬 형식 |
|--------|-----------|-----------|
| `codex` | `${CODEX_SKILLS_DIR:-${CODEX_HOME:-~/.codex}/skills}` | `SKILL.md` + `agents/openai.yaml` |
| `aside` | `${ASIDE_SKILLS_DIR:-${ASIDE_HOME:-~/.aside}/u/0/skills/user}` | `SKILL.md` 만 (`icon`, `autoInject` frontmatter 지원) |

| 스킬 | 그룹 | 발동 | 설명 |
|------|------|------|------|
| `greenfield-web-design` | core | 자동 | upstream 도구를 연결하는 로컬 진입 스킬 |
| `gh-investigate-link` | core | 자동 | GitHub 링크를 읽기 전용 `gh` 명령으로 조사 |
| `create-commit` | core | `$create-commit` | 이슈 연결 규칙에 맞춰 커밋 생성 |
| `grill` | core | `$grill` | 계획을 인터뷰로 스트레스 테스트 |
| `make-a-plan` | core | `$make-a-plan` | 조사·인터뷰 후 `PLAN_<slug>.md` 를 쓰고 순서대로 실행 |
| `add-plan` | core | `$add-plan` | 기존 계획 파일에 태스크 항목만 추가 (구현하지 않음) |
| `follow-plan` | core | `$follow-plan` | 계획 파일의 태스크를 구현 → 검증 → 커밋 순으로 하나씩 완결 |
| `translate-page-ko` | aside | 자동 | 영문 웹 페이지를 원문 유지한 채 한국어 병기 번역 |
| `frontend-design` | vendor | 자동 | 공식 Codex marketplace가 없어 고정한 upstream 버전 |

계획·커밋 스킬 5종은 `policy.allow_implicit_invocation: false` 라 이름을 직접
불러야만 뜹니다. 평상시 계획·구현 흐름은 `agent-skills` 의 `interview-me`,
`planning-and-task-breakdown`, `incremental-implementation` 이 맡고, 이 저장소의
규약(단일 `PLAN_<slug>.md`, 이슈 번호가 붙는 커밋)이 필요할 때만 명시 호출로
넘어옵니다. upstream 스킬은 `agents/openai.yaml` 이 없어 전부 자동 발동이므로,
이렇게 두지 않으면 같은 요청에서 어느 쪽이 뜰지 보장되지 않습니다.

기존 ECC 스냅샷, custom agent, MCP, hook, AGENTS.md 주입 기능은 포함하지 않습니다.

## 설치

터미널에서 그냥 실행하면 설치할 항목을 고르는 화면이 뜹니다.

```sh
./install.sh
```

```text
  minimal-harness — installer
  12 of 12 items selected

  codex → ~/.codex/skills
  ❯ [x] create-commit              core
    [x] gh-investigate-link        core
    ...
  aside → ~/.aside/u/0/skills/user
    [x] translate-page-ko          aside

  upstream → codex plugin add
    [x] agent-skills               agent-skills@agent-skills
    [x] build-web-apps             build-web-apps@openai-curated
    [x] browser                    browser@openai-bundled

  ↑/↓ move · space toggle · a all · n none · d dry run · enter install · q quit
```

`d` 로 dry run을 켜면 실행할 명령만 출력하고 아무것도 바꾸지 않습니다. `q` 는
아무것도 설치하지 않고 나갑니다.

터미널이 아닌 곳(CI, 파이프)에서는 화면 없이 곧바로 전체 설치로 넘어갑니다.
`--no-tui` 로 이 동작을 명시할 수 있고, `--tui` 는 반대로 강제합니다.

스크립트는 upstream 플러그인을 Codex 명령으로 설치하고, manifest 의 로컬 스킬을
각 스킬의 호스트 디렉토리로 복사합니다. 완료 후 새 Codex 작업을 열거나 Aside를
새로고침해야 새 스킬 목록이 반영됩니다.

일부만 설치할 때는 호스트·그룹·이름으로 범위를 좁힙니다. 필터는 화면을
건너뛰는 게 아니라 **초기 선택 상태를 정합니다** — `--host aside --tui` 는 Aside
스킬만 체크된 상태로 화면을 엽니다. 플러그인도 같은 필터를 받으므로
`--only browser` 면 그 플러그인 하나만 설치합니다.

```sh
./install.sh --no-tui --dry-run
./install.sh --host aside
./install.sh --group core        # 로컬 core 스킬만, 플러그인 제외
./install.sh --group upstream    # 플러그인만
./install.sh --only browser
```

설치는 `rsync --delete` 로 디렉터리를 통째로 맞추므로, 같은 이름의 스킬이 이미
호스트의 스킬 디렉토리에 있으면 이 저장소의 내용으로 대체됩니다.

## 사용

디자인 원본이 없는 새 웹 UI 작업에서 다음처럼 시작합니다.

```text
$greenfield-web-design 이 제품 아이디어를 반응형 웹 앱으로 설계하고 구현해줘.
```

스킬은 `frontend-design`으로 시각 방향을 정하고, ImageGen과 Build Web Apps로
콘셉트 및 구현을 진행한 뒤 Browser로 검증합니다. Browser를 사용할 수 없을 때만
Build Web Apps의 Playwright 폴백을 사용합니다.

읽고 있는 영문 페이지를 한국어로 병기 번역할 때는 다음처럼 시작합니다.

```text
$translate-page-ko 이 페이지를 원문 그대로 두고 한국어 번역을 아래에 붙여줘.
```

GitHub 링크를 조사할 때는 다음처럼 시작합니다.

```text
$gh-investigate-link 이 GitHub PR 링크의 변경 내용과 실패한 체크 원인을 조사해줘.
```

커밋을 만들 때는 반드시 스킬을 명시적으로 호출합니다.

```text
$create-commit 이슈 42번으로 현재 변경사항을 커밋해줘.
```

계획 스킬 세 개는 한 벌로 동작합니다. `make-a-plan` 이 `PLAN_<slug>.md` 를 만들고,
나머지 둘은 `PLAN.md` 또는 가장 최근 `PLAN_*.md` 를 찾아 이어받습니다.

```text
$grill 이 설계를 만들기 전에 집요하게 캐물어줘.
$make-a-plan 이 작업을 계획으로 만들고 순서대로 진행해줘.
$add-plan 계획에 이 태스크만 추가해줘.
$follow-plan 계획대로 다음 태스크를 진행해줘.
```

## 소스 정책

marketplace가 관리하는 구성의 설치 출처와 vendored 파일의 고정 버전은
[`SOURCES.lock.json`](SOURCES.lock.json)에 구분해 기록합니다. `frontend-design`의
Apache-2.0 전문은 스킬 디렉터리의 `LICENSE.txt`에 그대로 보존합니다.

`codex/vendor/` 의 스냅샷은 이 저장소에서 고치지 않습니다. 수정이 필요하면
upstream 에 먼저 반영한 뒤 스냅샷을 갱신하고 `SOURCES.lock.json` 의 고정 커밋을
함께 올립니다.
