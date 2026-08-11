# Minimal Codex Harness

외부 스킬을 복제해 관리하지 않고, 원본 marketplace에서 설치하는 작은 Codex 디자인 하네스입니다.

핵심 흐름은 다음과 같습니다.

```text
frontend-design
  → ImageGen + Build Web Apps
  → Browser 우선 검증 / Playwright 폴백
```

## 구성

marketplace가 설치하는 upstream 구성입니다.

- [Addy Osmani agent-skills](https://github.com/addyosmani/agent-skills): upstream Codex marketplace에서 설치·업데이트
- `build-web-apps`: OpenAI curated marketplace에서 설치
- `browser`: OpenAI bundled marketplace에서 설치
- `imagegen`: Codex 내장 스킬 사용

이 저장소가 관리하는 스킬은 `codex/` 아래에 그룹별로 둡니다. 어떤 스킬이 어느
그룹에 속하는지는 [`manifest.json`](manifest.json)이 단독으로 정하며,
`install.sh`는 이 파일만 보고 설치합니다.

```text
codex/
  skills/   # group: core   — 하네스를 이루는 로컬 스킬
  aside/    # group: aside  — 하네스 흐름과 무관하지만 함께 관리하는 스킬
  vendor/   # group: vendor — upstream 스냅샷, 이 저장소에서 수정하지 않음
```

| 스킬 | 그룹 | 설명 |
|------|------|------|
| `greenfield-web-design` | core | upstream 도구를 연결하는 로컬 진입 스킬 |
| `gh-investigate-link` | core | GitHub 링크를 읽기 전용 `gh` 명령으로 조사 |
| `create-commit` | core | 명시 호출 시 이슈 연결 규칙에 맞춰 커밋 생성 |
| `grill` | core | 만들기 전에 계획을 인터뷰로 스트레스 테스트 |
| `make-a-plan` | core | 조사·인터뷰 후 `PLAN_<slug>.md` 를 쓰고 순서대로 실행 |
| `add-plan` | core | 기존 계획 파일에 태스크 항목만 추가 (구현하지 않음) |
| `follow-plan` | core | 계획 파일의 태스크를 구현 → 검증 → 커밋 순으로 하나씩 완결 |
| `translate-page-ko` | aside | 영문 웹 페이지를 원문 유지한 채 한국어 병기 번역 |
| `frontend-design` | vendor | 공식 Codex marketplace가 없어 고정한 upstream 버전 |

기존 TUI, ECC 스냅샷, custom agent, MCP, hook, AGENTS.md 주입 기능은 포함하지 않습니다.

## 설치

먼저 실행할 명령을 확인합니다.

```sh
./install.sh --dry-run
```

설치 또는 업데이트합니다.

```sh
./install.sh
```

스크립트는 upstream 플러그인을 Codex 명령으로 설치하고, manifest 의 로컬 스킬을
`${CODEX_HOME:-$HOME/.codex}/skills` 아래에 복사합니다. 완료 후 새 Codex 작업을
열어야 새 스킬 목록이 반영됩니다.

일부만 설치할 때는 그룹이나 이름으로 범위를 좁힙니다. 두 플래그 모두 upstream
플러그인 설치를 건너뛰고 로컬 스킬만 다룹니다(`--group core` 는 제외).

```sh
./install.sh --group aside
./install.sh --only create-commit
```

설치는 `rsync --delete` 로 디렉터리를 통째로 맞추므로, 같은 이름의 스킬이 이미
`~/.codex/skills` 에 있으면 이 저장소의 내용으로 대체됩니다.

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
