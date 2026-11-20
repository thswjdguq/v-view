# 빌드·배포 가이드

2026-11-11 기준. 사용자 요청으로 AI 서버를 클라우드에 배포하지 않는다. 현재는 [PC의 GPT 키로 로컬 실행](LOCAL-AI.md)한다. 앱에는 API 키를 넣지 않는다.

## 포트폴리오 데모

```sh
cd v_view
flutter pub get
flutter build apk --debug -t lib/main_demo.dart
```

결과 `build/app/outputs/flutter-apk/app-debug.apk`를 `v-view-portfolio-demo-debug.apk`로 복사해 보관한다. 실제 앱 빌드도 같은 출력 파일을 덮어쓰기 때문이다. 현재 최신 데모는 해당 별도 이름으로 보관했다. 데모는 로그인·카메라·마이크·외부 AI 없이 가상 질문과 피드백을 제공한다. 화면의 DEMO 표시를 유지한다.

## 실제 AI 앱

현재 사용할 설치 파일은 아래 로컬 모드다.

```sh
cd v_view
flutter build apk --debug -t lib/main_local.dart
```

결과를 `v-view-local-ai-debug.apk`로 보관한다. PC의 `npm start`와 Android의 `adb reverse tcp:8080 tcp:8080` 연결이 필요하다. 상세 실행 절차와 포트 변경은 [로컬 AI 안내](LOCAL-AI.md)를 따른다. 이 경로는 Android 디버그용이며 릴리즈 앱에 키를 넣어 배포하지 않는다.

### 기존 Firebase 경로 — 현재 사용하지 않음

Cloud Run 배포 후 출력한 주소를 사용한다. 아래 주소는 교체할 예시다.

```sh
cd v_view
flutter build apk --debug --dart-define=AI_PROXY_URL=https://YOUR-SERVICE.run.app/v1
```

서버 주소가 없는 실제 앱 빌드는 설정 안내를 표시한다. 빌드 성공만으로 실제 AI 연결이 확인되는 것은 아니다. Firebase 허용 계정 로그인과 휴대폰 음성 입력·피드백 저장은 별도로 확인한다. `.env`는 앱 자산에 포함하지 않으며 기존 앱 폴더의 키도 사용하지 않는다.

## 공개 배포 준비

```sh
flutter build apk --release --dart-define=AI_PROXY_URL=https://YOUR-SERVICE.run.app/v1
flutter build appbundle --release --dart-define=AI_PROXY_URL=https://YOUR-SERVICE.run.app/v1
```

릴리즈 서명용 `android/key.properties`, 키스토어와 비밀번호는 저장소 밖에서 관리한다. 기존 서명 파일의 존재만으로 공개 배포 준비가 끝났다고 판단하지 않는다. 최신 코드의 릴리즈 서명·스토어 심사·App Distribution 배포는 이번 검증 범위에 포함하지 않았다. 이전에 생성된 릴리즈 APK를 이번 결과로 사용하지 않는다.

iOS는 macOS와 Xcode에서 권한 설명·실제 기기 음성 인식·Firebase 설정을 확인하고 빌드한다. 이번 Windows 환경에서는 iOS 실행을 검증하지 않았다.

## 비밀과 검증

API 키와 허용 UID 목록은 서버의 Secret Manager 참조로 전달한다. CI나 Flutter 빌드에서 API 키를 앱 `.env`로 만드는 절차는 사용하지 않는다. 서비스 계정 JSON을 APK나 서버 이미지에 복사하지 않는다.

- 저장 복구 개선 후 Flutter 테스트 147개와 정적 분석 통과: 2026-11-11 확인. 로컬 경로 후속 검증은 검증 기록의 마지막 절 참고.
- 서버 테스트 19개와 Docker 실행 확인: 2026-11-11 확인.
- 데모 APK와 실제 앱 진입점의 디버그 APK에서 `.env` 제외 확인.
- 로컬 모드의 실제 GPT 질문·꼬리질문·평가 호출은 확인. 실제 Firebase 인증·휴대폰 마이크·클라우드 배포는 미검증.

정확한 조건과 시연 화면은 [검증 기록](verification/README.md), 공개 전에 필요한 항목은 [포트폴리오 준비](PORTFOLIO-READY.md)를 따른다.
