import '../data/local/hive_service.dart';
import '../data/local/history/history_local_datasource.dart';
import '../data/local/report/report_local_datasource.dart';
import '../domain/gaze/gaze_metrics.dart';
import '../domain/history/session_history.dart';
import '../domain/interview/interview_question.dart';
import '../domain/report/session_report.dart';
import '../domain/session_setup/session_input.dart';

const demoInput = SessionInput(
  type: InterviewType.job,
  position: '프론트엔드 개발자',
  company: '샘플 회사',
  selfIntroduction: '가상 지원 정보입니다. Flutter 앱에서 입력·상태 관리·로컬 저장 흐름을 구현했습니다.',
);

SessionReport demoReport({required bool previous}) {
  const questions = [
    InterviewQuestion(
      id: 'sample1',
      text: '프로젝트에서 해결한 문제를 소개해주세요.',
      intent: '문제 해결 과정',
    ),
    InterviewQuestion(
      id: 'sample2',
      text: '상태 관리 도구를 선택한 이유는 무엇인가요?',
      intent: '설계 판단',
    ),
    InterviewQuestion(
      id: 'sample3',
      text: '수정 결과는 어떻게 검증했나요?',
      intent: '검증 방법',
    ),
  ];
  return SessionReport(
    id: previous ? 'demo-previous' : 'demo-current',
    createdAt: DateTime(2026, 11, previous ? 2 : 3, 10),
    interviewType: InterviewType.job,
    gazeMetrics: GazeMetrics(
      gazeRate: previous ? 68 : 82,
      distractionCount: previous ? 4 : 2,
      totalDistractionSeconds: previous ? 10 : 4,
      maxDistractionSeconds: previous ? 4 : 2,
      qualityNote: '화면 구성을 보여주기 위한 가상 측정값입니다.',
    ),
    qaList: [
      QuestionAnswer(
        question: questions[0],
        userAnswer: '새 면접에서 이전 질문이 남는 문제를 재현하고 Provider 초기화 시점을 수정했습니다.',
        answerDurationSeconds: previous ? 30 : 42,
      ),
      QuestionAnswer(
        question: questions[1],
        userAnswer: '화면과 상태를 분리하고 테스트에서 외부 의존성을 대체하기 위해 선택했습니다.',
        answerDurationSeconds: previous ? 28 : 35,
      ),
      QuestionAnswer(
        question: questions[2],
        userAnswer: previous
            ? ''
            : '늦은 API 응답과 중복 제출을 테스트하고 실제 화면에서 결과를 확인했습니다.',
        answerDurationSeconds: previous ? 0 : 38,
      ),
    ],
    totalQuestions: 3,
    totalDurationSeconds: previous ? 58 : 115,
    isAiFeedbackAvailable: false,
    improvementPoints: const [
      ImprovementPoint(
        title: '검증 결과를 답변에 연결해보세요',
        description: '문제·원인·수정·검증을 연결하는 방법을 보여주는 샘플 안내입니다. 실제 사용자 평가 결과가 아닙니다.',
        evidenceMetric: '가상 프로젝트 답변 예시',
      ),
    ],
  );
}

String buildDemoAnswer(InterviewQuestion question, InterviewType type) {
  if (question.isFollowUp) {
    return '가상 답변 예시입니다. 제가 맡은 부분은 문제를 재현하는 입력 순서를 정리하고, 이전 상태가 남는 조건을 찾는 일이었습니다. 초기화 위치를 바꾼 뒤 같은 순서로 다시 실행하고 회귀 테스트로 결과를 확인하는 과정을 설명하겠습니다.';
  }
  if (type == InterviewType.university) {
    return '가상 답변 예시입니다. 전공 탐구 활동에서 작은 프로그램을 만들어 입력 조건에 따라 결과가 달라지는 이유를 조사했다고 가정했습니다. 먼저 문제를 작은 단계로 나누고 자료를 찾아 가설을 세운 뒤, 여러 입력으로 확인한 과정과 더 공부하고 싶은 내용을 설명하겠습니다.';
  }
  if (type == InterviewType.personality || question.text.contains('팀')) {
    return '가상 답변 예시입니다. 팀에서 구현 방향에 대한 의견이 달랐던 상황을 가정했습니다. 각 제안의 장단점을 기록하고 공통 목표와 일정에 맞춰 비교했습니다. 제가 담당한 검증 결과를 공유하고 함께 결정한 과정에서 배운 점을 설명하겠습니다.';
  }
  if (question.text.contains('기술')) {
    return '가상 답변 예시입니다. 화면과 면접 진행 상태를 분리하고 테스트에서 외부 서비스를 대체하기 위해 Riverpod을 선택했다고 가정했습니다. 단순한 화면 내부 상태 관리와 비교해 여러 화면이 같은 데이터를 다루는 요구에 적합한지 확인했고, 기술 선택의 장점과 관리 비용을 함께 설명하겠습니다.';
  }
  if (question.text.contains('검증') || question.text.contains('올바른지')) {
    return '가상 답변 예시입니다. 먼저 오류가 발생하는 입력과 순서를 테스트로 재현했다고 가정했습니다. 수정 후 정상 경로뿐 아니라 중복 제출과 늦은 응답도 확인했습니다. 마지막으로 실제 화면에서 답변을 저장하고 앱을 다시 열어 같은 내용이 보이는지 확인하는 검증 과정을 설명하겠습니다.';
  }
  return '가상 답변 예시입니다. 새 면접을 시작했는데 이전 질문이 남는 상황을 가정했습니다. 재현 순서를 정리하고 화면 이동과 상태의 수명이 다르다는 원인을 찾았습니다. 새 연습을 시작할 때 상태를 초기화하도록 바꾼 뒤, 같은 순서의 테스트와 화면 확인으로 결과를 검증하는 과정을 설명하겠습니다.';
}

Future<void> seedDemoData({bool restoreSamples = false}) async {
  if (!restoreSamples && HiveService.settingsBox.get('demo_seed_v1') == true) {
    return;
  }
  for (final previous in [true, false]) {
    final report = demoReport(previous: previous);
    await ReportLocalDatasource().save(report);
    await HistoryLocalDatasource().save(
      SessionHistoryItem(
        id: report.id,
        createdAt: report.createdAt,
        interviewType: report.interviewType,
        position: demoInput.position,
        company: demoInput.company,
        gazeRate: report.gazeMetrics.gazeRate,
        gazeQuality: report.gazeMetrics.quality,
        distractionCount: report.gazeMetrics.distractionCount,
        totalQuestions: report.totalQuestions,
        totalDurationSeconds: report.totalDurationSeconds,
      ),
    );
  }
  await HiveService.settingsBox.put('demo_seed_v1', true);
}
