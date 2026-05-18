# Work Breakdown Structure

> 3단계 분해 / 각 항목 1~3일 단위

---

## 1. 기획·문서

### 1.1 비전·요구사항
- 1.1.1 비전 문서 작성 (`00-vision.md`)
- 1.1.2 사용자 시나리오 3개 정의
- 1.1.3 MoSCoW 요구사항 분류 (`01-requirements.md`)

### 1.2 일정·구조
- 1.2.1 WBS 작성 (`02-wbs.md`)
- 1.2.2 6주 일정 수립 (`04-schedule.md`)
- 1.2.3 리스크 목록 5개 작성

### 1.3 아키텍처 결정
- 1.3.1 ADR-001: 모바일 프레임워크 (Flutter)
- 1.3.2 ADR-002: 상태 관리 (Riverpod)
- 1.3.3 ADR-003: 로컬 DB (Hive)
- 1.3.4 ADR-004: AI API (Claude)

---

## 2. 환경·설계

### 2.1 개발 환경
- 2.1.1 GitHub 저장소 생성 및 브랜치 전략 수립
- 2.1.2 Flutter 프로젝트 스캐폴드 생성
- 2.1.3 pubspec.yaml 의존성 구성
- 2.1.4 `.env` / `.env.example` 구조 설정

### 2.2 아키텍처 설계
- 2.2.1 레이어 구조 확정 (ui/state/domain/data)
- 2.2.2 기능별 폴더 구조 생성
- 2.2.3 도메인 엔티티 정의 (5개)
- 2.2.4 `docs/architecture.md` 작성 (Mermaid 다이어그램 포함)

### 2.3 설정 문서
- 2.3.1 `docs/setup.md` 작성 (zero→run)
- 2.3.2 Hello World 빌드 성공 확인

---

## 3. 데이터 레이어

### 3.1 로컬 저장소
- 3.1.1 `HiveService` 초기화 (4개 Box)
- 3.1.2 `SessionInputLocalDatasource` (재사용 입력값)
- 3.1.3 `ReportLocalDatasource` (리포트 저장·로드)
- 3.1.4 `HistoryLocalDatasource` (목록 저장·삭제)

### 3.2 원격 서비스
- 3.2.1 `ClaudeApiService` (질문 생성·꼬리질문·피드백)
- 3.2.2 `GazeAnalyzer` (ML Kit FaceDetector 연동)
- 3.2.3 `CameraFrameConverter` (CameraImage → InputImage)

---

## 4. State 레이어

- 4.1 `SessionInputNotifier` (입력값 상태 + 로컬 저장)
- 4.2 `InterviewNotifier` (질문 진행, 타이머, 꼬리질문)
- 4.3 `GazeNotifier` (프레임 수집, 지표 계산)
- 4.4 `ReportNotifier` (리포트 생성, AI 실패 fallback)
- 4.5 `HistoryNotifier` (히스토리 목록, 삭제)

---

## 5. UI 레이어

### 5.1 세션 설정
- 5.1.1 `SessionSetupScreen` (유형 선택, 입력 폼, maxLength)
- 5.1.2 `SessionConfirmScreen` (미리보기 + 개인정보 안내)
- 5.1.3 `CameraPermissionScreen` (권한 요청·거부·영구거부)

### 5.2 면접 진행
- 5.2.1 `InterviewScreen` (질문 카드, 타이머, 답변 입력)
- 5.2.2 카메라 프리뷰 배지 + 프레임 스트리밍 연결
- 5.2.3 스켈레톤 로딩 UI (`_QuestionLoadingSkeleton`)
- 5.2.4 백그라운드 전환 타이머 정지·재개

### 5.3 리포트
- 5.3.1 `ReportScreen` (리포트 생성 + 렌더링)
- 5.3.2 `GazeMetricsCard` (파이차트 + 지표)
- 5.3.3 `GazeTrendChart` (최근 5회 추이 LineChart)
- 5.3.4 `ImprovementList` (개선 포인트 TOP3)

### 5.4 히스토리
- 5.4.1 `HistoryListScreen` (목록 + 전체 삭제 버튼)
- 5.4.2 `HistoryDetailScreen` (리포트 재열람)

### 5.5 공통
- 5.5.1 `ErrorDisplay` (에러 공통 위젯)

---

## 6. 테스트

- 6.1 `gaze_analyzer_test.dart` (1초 임계값, 응시율 공식, 품질 평가)
- 6.2 `session_input_notifier_test.dart` (isValid 조건)
- 6.3 `report_notifier_test.dart` (fallback 조건, 초기 상태)
- 6.4 `flutter test` 전체 통과 확인 (25/25)
- 6.5 `flutter analyze` 이슈 0 확인

---

## 7. 배포

- 7.1 `key.properties` + 키스토어 생성
- 7.2 Android APK 릴리즈 빌드
- 7.3 Firebase App Distribution 배포 (Could)
- 7.4 `pubspec.yaml` 버전 최종 확인 (`1.0.0+1`)
