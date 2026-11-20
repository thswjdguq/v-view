# 개발에 적용한 Agent Skills

2026-11-03 GitHub 공개 API 조회 기준. 스타 수는 인기도의 참고값이며 품질·안전성을 보장하지 않는다.

| 출처 | 조회한 스타 수 | 고정한 커밋 |
|---|---:|---|
| [obra/superpowers](https://github.com/obra/superpowers) | 311,270 | `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b` |
| [flutter/agent-plugins](https://github.com/flutter/agent-plugins) | 3,141 | `6f5b7b84846ebda117437f700d4be94cfb67efb6` |

프로젝트의 `.agents/skills/`에 다음 지침만 선택 설치했다. 전역 설정이나 MCP 서버는 추가하지 않았다.

| 스킬 | 이번 개발에서의 용도 |
|---|---|
| `systematic-debugging` | 실제 실패를 재현하고 데이터 흐름에서 원인을 찾은 후 수정 |
| `test-driven-development` | 사용자 동작과 상태 문제를 먼저 실패하는 테스트로 작성 |
| `verification-before-completion` | 분석·테스트·화면 확인 결과를 근거로 완료 여부 보고 |
| `dart-add-unit-test` | 중복 제출, 늦은 API 응답, 시간 집계와 저장 상태 검증 |
| `flutter-add-widget-test` | 답변 보존, 재개, 리포트 상태, 작은 화면과 재시도 동작 검증 |

## 적용 경계

- 저장소 AGENTS.md의 보호 파일·기능 범위·보안 규칙을 우선한다.
- 스킬에 특정 모델의 metadata가 있어도 실행 모델을 바꾸지 않는다.
- 원격 설치 스크립트를 파이프로 실행하지 않고, 기본 제공 skill-installer로 고정 커밋의 폴더를 다운로드했다.
- 외부 스킬의 참조 코드와 테스트 예시는 프로젝트에 맞는 경우만 적용한다. 앱 의존성을 자동으로 추가하지 않는다.
- 설치된 지침을 이번 작업에서 직접 읽고 적용했다. 다음 턴부터 스킬로 사용할 수 있고, 목록에 표시되지 않으면 Codex를 다시 시작한다.

## 출처와 라이선스

- Superpowers: MIT. 원문은 `.agents/skills/UPSTREAM-LICENSE-superpowers.txt`.
- Flutter Agent Plugins: BSD-3-Clause. 원문은 `.agents/skills/UPSTREAM-LICENSE-flutter.txt`.
- [OpenAI 공식 스킬 안내](https://learn.chatgpt.com/docs/build-skills?product=breeze): 저장소별 `.agents/skills` 로딩과 설치 후 인식 방식.

이 문서는 도구 설치 이력이다. 앱의 실제 개선과 검증 결과는 코드·테스트·실행 산출물로 확인한다.
