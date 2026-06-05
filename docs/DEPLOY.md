# 빌드 및 배포 가이드

---

## Android APK 빌드

### 디버그 빌드 (테스트용)

```bash
cd v_view
flutter build apk --debug
# 출력: build/app/outputs/flutter-apk/app-debug.apk
```

### 릴리즈 빌드

```bash
flutter build apk --release
# 출력: build/app/outputs/flutter-apk/app-release.apk
```

### App Bundle (Google Play 권장)

```bash
flutter build appbundle --release
# 출력: build/app/outputs/bundle/release/app-release.aab
```

---

## Android 서명 설정 (릴리즈 배포 시)

### 1. 키스토어 생성 (이미 완료 — `android/app/v-view-release.jks`)

```bash
keytool -genkeypair \
  -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -keystore android/app/v-view-release.jks \
  -storepass <비밀번호> -keypass <비밀번호> \
  -dname "CN=vview, OU=dev, O=vview, L=Seoul, ST=Seoul, C=KR"
```

### 2. key.properties 설정

`v_view/android/key.properties` (`.gitignore`에 포함 — 절대 커밋 금지):
```properties
storePassword=<비밀번호>
keyPassword=<비밀번호>
keyAlias=upload
storeFile=app/v-view-release.jks
```

### 3. build.gradle.kts — 자동 적용

`android/app/build.gradle.kts`에 이미 반영됨. `key.properties`가 존재하면 릴리즈 서명이 자동 활성화됩니다.

---

## iOS 빌드 (macOS 필요)

```bash
# IPA 빌드
flutter build ios --release

# Xcode에서 Archive → Distribute App
open v_view/ios/Runner.xcworkspace
```

---

## Firebase App Distribution (테스트 배포)

### 1. Firebase CLI 설치

```bash
npm install -g firebase-tools
firebase login
```

### 2. Firebase 프로젝트 연결

```bash
cd v_view
flutterfire configure
```

### 3. 배포

```bash
# APK 빌드 후 배포
flutter build apk --release

firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app <FIREBASE_APP_ID> \
  --groups "테스터그룹" \
  --release-notes "v-view 테스트 빌드"
```

---

## 환경 변수 관리 (배포 시 주의)

`.env` 파일은 **절대 커밋하지 않는다**.

배포 빌드 시 CI/CD 환경에서 주입:
```bash
# GitHub Actions 예시
echo "OPENAI_API_KEY=${{ secrets.OPENAI_API_KEY }}" > v_view/.env
flutter build apk --release
```

---

## 빌드 체크리스트

배포 전 확인 사항:

- [x] `flutter analyze` — 이슈 없음 (확인 완료)
- [x] `flutter test` — 전체 통과 (45개)
- [x] `.env`에 실제 API 키 설정 (`.env`는 미커밋)
- [x] `pubspec.yaml` 버전 번호 업데이트 (`1.0.0+1`)
- [x] AndroidManifest.xml 권한 확인 (CAMERA, INTERNET, RECORD_AUDIO)
- [x] 릴리즈 서명 적용 (`android/app/v-view-release.jks` + `key.properties`)
- [ ] Firebase App Distribution 배포
