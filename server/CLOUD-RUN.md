# example-vview-project에 실제 AI 서버 연결하기

> 보관 문서: 클라우드 배포는 취소되었으며 실행하지 않았습니다. 현재 실행 방법은 [로컬 AI 안내](../docs/LOCAL-AI.md)입니다. 아래 프로젝트 ID는 예시입니다.
> 보관 자료. 2026-11-11 사용자 요청으로 클라우드 배포는 진행하지 않는다. 현재 실행은 [개인 PC 모드](../docs/LOCAL-AI.md)를 사용하며 아래 프로젝트 권한·Secret Manager 작업이 필요하지 않다.

대상 프로젝트는 소유자가 확인한 `example-vview-project`이다. 서울 리전 `asia-northeast3`에 `v-view-ai`를 배포하는 계획을 준비했다. **현재 클라우드 배포는 실행하지 않았다.** Google Cloud CLI가 설치되어 있지 않아 Cloud Shell 경로를 제공한다.


## 1. 콘솔에서 준비할 값

[Firebase Authentication 사용자 목록](https://console.firebase.google.com/project/example-vview-project/authentication/users)에서 실제 앱으로 로그인할 테스트 계정의 UID를 확인한다. 로그인 계정의 이메일과 UID는 다르다.

[Secret Manager](https://console.cloud.google.com/security/secret-manager?project=example-vview-project)에 아래 비밀 두 개를 만든다. 각 첫 버전은 `1`, 사용 설정 상태여야 한다.

| 이름 | 비밀 값 |
|---|---|
| `v-view-openai-api-key` | OpenAI 프로젝트에서 발급한 서버 전용 API 키 |
| `v-view-allowed-firebase-uids` | 사용할 Firebase UID. 여러 개면 쉼표로 구분 |

실제 키·UID 목록을 저장소, 앱 설정 파일, 채팅에 붙여 넣지 않는다. 이미 같은 이름이 있으면 새 비밀을 만들지 않고 필요한 버전을 확인한다. `deploy/cloud-run.example.json`의 버전 번호를 해당 버전으로 바꾸거나, 별도 `deploy/cloud-run.local.json`을 만들고 아래 생성 명령에 경로를 전달한다. `latest` 대신 숫자 버전을 고정한다.

Google Cloud 결제 연결과 OpenAI API 이용 가능 상태가 필요하다. 배포 계정은 API 활성화, 서비스 계정 생성·사용, 프로젝트/비밀 IAM 변경, Cloud Build·Artifact Registry·Cloud Run 배포 권한이 있어야 한다. 실행용 서비스 계정에 관리자 권한을 부여하는 방식으로 해결하지 않는다.

## 2. 업로드할 소스 만들기

저장소 루트에서 Python 3.9 이상으로 실행한다.

```sh
python server/scripts/package-cloud-run.py
```

결과는 `v_view/build/deployment/v-view-cloud-run-source.zip`이다. 명시한 소스 17개만 넣으며 `.env`, 실제 비밀, 서비스 계정 키, `node_modules`, 로컬 배포 설정은 포함하지 않는다. 소스를 수정했다면 다시 만든다.

## 3. Cloud Shell에서 계획 검토 후 배포

[프로젝트 Cloud Shell](https://console.cloud.google.com/home/dashboard?project=example-vview-project&cloudshell=true)을 열고 위 ZIP을 업로드한다. 다음은 업로드한 위치에서 실행한다. Node.js 22 이상이 필요하다.

```sh
unzip v-view-cloud-run-source.zip
cd v-view-server
node --version
npm run cloud:plan
cat .deploy/plan.json
```

별도 설정을 사용한다면 `npm run cloud:plan -- deploy/cloud-run.local.json`으로 생성한다. 이 단계는 로컬 파일만 만들며 클라우드를 변경하지 않는다.

계획을 검토한 뒤 다음을 실행하면 **클라우드 리소스와 권한을 변경하고 빌드·배포 비용이 발생할 수 있다.**

```sh
bash .deploy/deploy-cloud-run.sh
```

스크립트가 수행하는 작업:

1. Cloud Run·Cloud Build·Artifact Registry·Secret Manager API 활성화.
2. 비밀 버전이 사용 설정 상태인지 확인. 비밀 값은 읽거나 출력하지 않음.
3. 전용 실행 계정 `v-view-ai-runtime` 생성 또는 재사용.
4. 실행 계정에 Firebase Auth 읽기 권한과 위 비밀 각각의 읽기 권한 부여.
5. 서버 소스 빌드, Cloud Run 배포, 앱에서 사용할 주소 출력.

Cloud Run 주소는 HTTP 접속을 허용하지만, AI 경로는 서버가 Firebase ID 토큰과 UID 허용 목록을 검사한다. Cloud Run IAM 로그인 토큰과 Firebase 사용자 토큰을 혼동하지 않는다. `/health`의 성공은 프로세스가 켜졌다는 뜻이며 Firebase·OpenAI 실제 연결 성공을 뜻하지 않는다.

최소 인스턴스 0, 최대 1, 동시 요청 2, 메모리 512MiB, 요청 제한 35초다. 이는 월 지출 상한이 아니다. 빌드·이미지 보관·비밀 저장에도 비용이 발생할 수 있다. 공개 서비스로 확대하기 전에는 공유 요청 제한과 비용 모니터링을 추가한다. 기본 Cloud Build 계정에 빌드 권한이 없다는 오류가 나면 해당 빌드 계정과 공식 소스 배포 권한 안내를 확인하고 필요한 권한만 부여한다.

## 4. 실제 앱 연결·확인

출력된 `AI_PROXY_URL=https://…run.app/v1` 값을 사용한다. 서버 키를 앱에 넣지 않는다.

```sh
cd v_view
flutter run --dart-define=AI_PROXY_URL=https://YOUR-SERVICE.run.app/v1
```

허용 UID의 계정으로 로그인한 뒤 질문 생성 → 마이크 답변 → 인식된 텍스트 확인·수정 → 제출 → 피드백 저장을 실제 휴대폰에서 확인한다. AI가 받는 것은 인식된 텍스트이며 음성 파일·억양·발음을 평가하지 않는다. 비허용 계정은 AI 요청이 거부되어야 한다. 본문·토큰·키를 로그에 출력하며 확인하지 않는다.

비밀 값을 바꾸면 새 버전 번호로 계획을 다시 생성해 재배포한다. 버전이 고정되어 있어 비밀에 새 버전을 추가하는 것만으로 실행 중 서비스가 바뀌지는 않는다.

## 확인된 범위

서버 단위·로컬 HTTP 테스트와 컨테이너의 상태 응답·미인증 거부는 별도로 기록한다. 실제 Firebase 사용자 인증, 비밀 읽기 권한, 과금 AI 호출, 휴대폰 마이크 입력은 클라우드와 기기에서 추가 확인해야 한다. 검증 결과는 [검증 기록](../docs/verification/README.md)에 정리한다.

공식 근거: [Cloud Run 소스 배포와 권한](https://docs.cloud.google.com/run/docs/deploying-source-code), [Cloud Run 비밀 설정](https://docs.cloud.google.com/run/docs/configuring/services/secrets), [Firebase Admin 기본 인증](https://firebase.google.com/docs/admin/setup), [Firebase 토큰 검증](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [Firebase Auth 읽기 역할](https://docs.cloud.google.com/iam/docs/roles-permissions/firebaseauth).
