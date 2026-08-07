# Minimal Codex Harness

외부 스킬을 복제해 관리하지 않고, 원본 marketplace에서 설치하는 작은 Codex 디자인 하네스입니다.

핵심 흐름은 다음과 같습니다.

```text
frontend-design
  → ImageGen + Build Web Apps
  → Browser 우선 검증 / Playwright 폴백
```

## 구성

- [Addy Osmani agent-skills](https://github.com/addyosmani/agent-skills): upstream Codex marketplace에서 설치·업데이트
- `build-web-apps`: OpenAI curated marketplace에서 설치
- `browser`: OpenAI bundled marketplace에서 설치
- `imagegen`: Codex 내장 스킬 사용
- `frontend-design`: 공식 Codex marketplace가 없어 고정된 upstream 버전을 포함
- `greenfield-web-design`: 위 도구를 연결하는 로컬 진입 스킬
- `gh-investigate-link`: GitHub 링크를 읽기 전용 `gh` 명령으로 조사하는 로컬 스킬
- `create-commit`: 명시 호출 시 이슈 연결 규칙에 맞춰 커밋을 생성하는 로컬 스킬

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

스크립트는 upstream 플러그인을 Codex 명령으로 설치하고, 로컬 스킬 네 개를
`${CODEX_HOME:-$HOME/.codex}/skills` 아래에 복사합니다. 완료 후 새 Codex 작업을
열어야 새 스킬 목록이 반영됩니다.

## 사용

디자인 원본이 없는 새 웹 UI 작업에서 다음처럼 시작합니다.

```text
$greenfield-web-design 이 제품 아이디어를 반응형 웹 앱으로 설계하고 구현해줘.
```

스킬은 `frontend-design`으로 시각 방향을 정하고, ImageGen과 Build Web Apps로
콘셉트 및 구현을 진행한 뒤 Browser로 검증합니다. Browser를 사용할 수 없을 때만
Build Web Apps의 Playwright 폴백을 사용합니다.

GitHub 링크를 조사할 때는 다음처럼 시작합니다.

```text
$gh-investigate-link 이 GitHub PR 링크의 변경 내용과 실패한 체크 원인을 조사해줘.
```

커밋을 만들 때는 반드시 스킬을 명시적으로 호출합니다.

```text
$create-commit 이슈 42번으로 현재 변경사항을 커밋해줘.
```

## 소스 정책

marketplace가 관리하는 구성의 설치 출처와 vendored 파일의 고정 버전은
[`SOURCES.lock.json`](SOURCES.lock.json)에 구분해 기록합니다. `frontend-design`의
Apache-2.0 전문은 스킬 디렉터리의 `LICENSE.txt`에 그대로 보존합니다.
