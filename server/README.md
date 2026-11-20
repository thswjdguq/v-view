# v-view AI 중계 서버

**2026-11-11 현재 사용 방식은 클라우드 배포 없는 로컬 PC 모드다.** `npm run local:setup`으로 PC의 키 설정을 준비하고 `npm start`로 실행한다. Firebase·서비스 계정·Secret Manager 설정은 필요하지 않다. [로컬 실행 안내](../docs/LOCAL-AI.md)를 먼저 따른다.

`npm start`는 `src/local.js`를 사용한다. 127.0.0.1 전용 수신·Origin/Host/접속 주소 검증·요청 제한을 적용한다. 키는 `.env.local` 또는 PC 환경변수에서만 읽으며 앱에 전달하지 않는다. 실제 API에서 키가 거부되면 민감한 오류 원문 대신 `api_key_invalid`로 안내한다.

아래 Firebase 설명은 보관 중인 별도 `src/index.js` 경로다. 필요할 때만 `npm run start:firebase`로 사용한다. 현재 로컬 앱 실행과 무관하며 클라우드 배포는 진행하지 않는다.

앱은 Firebase ID 토큰과 메시지만 전송한다. 서버에서 토큰·허용 사용자를 검증하고 고정된 OpenAI 모델에 전달한다. API 키는 서버 환경변수에서만 읽는다.

## 기존 Firebase 경로

이전 [Cloud Run 연결 안내](CLOUD-RUN.md)는 준비했던 계획의 보관 자료다.

Node.js 22 이상과 앱의 Firebase 프로젝트에 연결된 Admin 인증 환경이 필요하다.

```sh
cd server
npm ci --ignore-scripts --omit=optional
```

`.env.example`을 `.env`로 복사해 값을 설정한다. 실제 키·UID·서비스 계정 파일은 커밋하지 않는다.

| 환경변수 | 내용 |
|---|---|
| OPENAI_API_KEY | 서버 전용 OpenAI 키 |
| GOOGLE_CLOUD_PROJECT | 앱과 같은 Firebase 프로젝트 ID |
| ALLOWED_FIREBASE_UIDS | 허용 사용자 UID, 쉼표 구분. 비어 있으면 시작 실패 |
| GOOGLE_APPLICATION_CREDENTIALS | 필요한 경우 저장소 밖의 서비스 계정 파일 절대 경로. 클라우드에서는 서비스 계정 연결 사용 |
| PORT | 기본 8080 |

```sh
npm run start:firebase
```

`GET /health`는 프로세스 상태만 확인한다. Firebase·OpenAI 연결 확인은 아니다.
앱은 `AI_PROXY_URL=https://YOUR-SERVER.example/v1`로 연결한다.
`POST /v1/chat/completions`는 `Authorization: Bearer <Firebase ID token>`과 JSON messages를 받는다.

## 제한과 오류 처리

- `verifyIdToken(token, true)`로 토큰과 취소 여부 확인. 인증 에뮬레이터 우회 설정은 시작 시 거부.
- 허용 목록의 시범 사용자만 접근. 회원가입만으로 AI 사용 권한을 얻지 않음.
- 사용자당 시간당 30회, 동시 2회. 외부 요청 실패도 횟수에 포함하며 과금 호출을 자동 재시도하지 않음.
- JSON 본문 64KiB, 메시지 1~4개·합계 20,000자, system/user 역할만 허용.
- 서버가 `gpt-4o-mini`, 출력 최대 2,000 토큰으로 고정. 앱의 모델·스트리밍·출력 한도 설정 무시.
- 외부 요청 25초 제한. 내부·제공자 오류 원문과 인증 세부사항을 반환하지 않음.
- 필요한 응답 content만 반환하고 캐시 금지. 요청 본문·토큰·키는 로그로 출력하지 않음.

제한은 **프로세스 메모리 기준**이다. 재시작·다중 인스턴스에서는 통합 한도가 아니다. 공개 서비스 전에는 공유 저장소 기반 제한, 입구 요청 제한, 비용 예산·모니터링이 필요하다. 현재는 소수 허용 사용자 시연용이다.

## 검증과 의존성

```sh
npm test
npm audit --omit=dev --omit=optional
```

자동 테스트 29개는 로컬 HTTP에서 인증과 외부 AI를 대체한다. 별도의 수동 검증에서 실제 앱 요청 코드 → PC → OpenAI로 질문·꼬리질문·평가 총 3회를 확인했다. 실제 Firebase 연결은 검증하지 않았다.
사용하지 않는 Admin 선택 의존성 Firestore·Storage는 `.npmrc`로 제외한다. 2026-11-11 `npm audit --omit=dev --omit=optional --audit-level=high`에서 알려진 취약점 0건을 확인했다. 선택 의존성 전체의 결과를 뜻하지 않는다.

Dockerfile은 소스·의존성 정의만 복사하며 `.env`·서비스 계정 파일을 이미지에 넣지 않는다. 2026-11-11 Docker 빌드와 네트워크를 끈 컨테이너 내부에서 상태 응답 200·미인증 AI 요청 401·캐시 금지·일반 사용자 실행을 확인했다. 클라우드 배포는 아직 검증하지 않았다.
HTTPS 서버에 배포하고 키는 비밀 저장소로 주입한다. 비용이 발생하는 클라우드 작업은 이번 로컬 개발에서 수행하지 않았다.

근거: [OpenAI API 인증](https://developers.openai.com/api/reference/overview), [Firebase 토큰 검증](https://firebase.google.com/docs/auth/admin/verify-id-tokens).
