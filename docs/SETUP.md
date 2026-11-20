# 실행 환경 설정

2026-11-11 변경 기준. 현재는 [개인 PC의 GPT 키로 실행](LOCAL-AI.md)한다. 앱 `.env` 자산·앱의 직접 키 사용은 하지 않는다.

## 개발 도구

- 기준: Flutter 3.38.9, Dart 3.10.8, Windows, Android SDK.
- 서버: Node.js 22 이상. 로컬 확인은 Node.js 24.14.0.
- Android 기기 또는 에뮬레이터. iOS는 macOS에서 별도 검증해야 한다.

## 포트폴리오 데모

```sh
cd v_view
flutter pub get
flutter run -t lib/main_demo.dart
```

Firebase·AI 키 없이 실행한다. 가상 리포트 2개와 샘플 질문·피드백을 사용하며 화면 상단에 DEMO를 표시한다.
카메라·마이크·외부 AI는 호출하지 않는다. 작성한 텍스트는 데모 전용 Hive 저장소에 남는다.
홈의 ‘샘플 기록 다시 넣기’는 사용자가 작성한 새 기록을 삭제하지 않고 샘플 2개를 복원한다.

이 개발 환경의 Android 에뮬레이터에서는 그래픽·시스템 UI 응답 지연이 있어 소프트웨어 렌더링으로 시각 검증했다. 같은 환경에서 검은 화면이 보이면 다음과 같이 확인할 수 있다. 실제 휴대폰의 일반 실행 검증과는 구분한다.

```sh
flutter run -t lib/main_demo.dart --enable-software-rendering --no-enable-impeller
```

## 실제 앱

현재 실행은 `server/`에서 `npm run local:setup` → `npm start`, 저장소 루트의 다른 창에서 `scripts/Run-LocalAndroid.ps1`이다. Firebase 로그인 없이 `main_local.dart`로 시작한다. 자세한 기기 연결과 오류 안내는 [로컬 AI](LOCAL-AI.md)를 따른다.

### 기존 Firebase 진입점 — 현재 사용하지 않음

1. Firebase 설정이 사용할 프로젝트와 일치하는지 확인한다. 다른 프로젝트라면 FlutterFire 도구로 다시 설정한다.
2. Firebase 이메일 인증을 활성화하고 테스트 계정을 만든다.
3. [중계 서버](../server/README.md)를 준비한다. API 키는 서버에만 설정한다.
4. 테스트 계정 UID를 서버 `ALLOWED_FIREBASE_UIDS`에 추가한다.
5. 다음 옵션으로 앱을 실행한다.

```sh
cd v_view
flutter run --dart-define=AI_PROXY_URL=https://YOUR-SERVER.example/v1
```

Firebase ID 토큰은 로그인 사용자에게서 매 요청 시 얻어 전달하며 서버에서 검증한다.
배포 앱은 HTTPS를 사용한다. 디버그 코드는 localhost·127.0.0.1·10.0.2.2의 HTTP 주소만 추가 허용하지만 플랫폼 자체의 HTTP 정책도 적용된다. 로컬 서버도 HTTPS 터널로 연결하는 방식을 권장한다.

## 오류 확인

| 안내 | 확인할 내용 |
|---|---|
| AI_PROXY_URL 미설정 | 실행 옵션 지정 후 앱을 다시 실행. hot reload만으로 빌드 설정은 바뀌지 않음 |
| 로그인 인증 실패 | 로그인 상태·Firebase 프로젝트·토큰 검증 설정 |
| 시범 운영 대상 계정 | 허용 목록 UID |
| 요청이 많음 | 시간당·동시 요청 제한. 기다린 뒤 재시도 |
| 음성 인식 불가 | 한국어 지원 서비스·인터넷·마이크 권한 |
| 시선 측정 불가 | 카메라 권한·조명·얼굴 검출 환경. 0점으로 해석하지 않음 |
| 서버 502/504 | 네트워크·키·제공자 상태·25초 제한. 키·토큰·프롬프트를 로그에 출력하지 않음 |

## 검증

```sh
cd v_view
flutter test --no-pub --reporter expanded
flutter analyze --no-pub
```

[기기 시연 순서](PORTFOLIO-READY.md)와 서버 테스트도 확인한다.
이전 앱 `.env`는 사용하지 않으며 `pubspec.yaml` 자산에 다시 추가하지 않는다.
