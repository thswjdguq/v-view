import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/demo/demo_fixtures.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/report/report_export.dart';

SessionReport fixture({GazeMetrics? gaze, List<QuestionAnswer>? qa}) {
  final sample = demoReport(previous: false);
  return SessionReport(
    id: sample.id,
    createdAt: sample.createdAt,
    interviewType: sample.interviewType,
    gazeMetrics: gaze ?? sample.gazeMetrics,
    qaList: qa ?? sample.qaList,
    totalQuestions: sample.totalQuestions,
    totalDurationSeconds: sample.totalDurationSeconds,
    improvementPoints: sample.improvementPoints,
    isAiFeedbackAvailable: false,
  );
}

void main() {
  test('내 답변·질문 의도·시간과 피드백 근거를 함께 내보낸다', () {
    final report = fixture();
    final text = formatReportForExport(report);
    expect(text, contains(report.qaList.first.userAnswer));
    expect(text, contains(report.qaList.first.question.intent));
    expect(text, contains('답변 시간: 42초'));
    expect(text, contains(report.improvementPoints.first.evidenceMetric));
    expect(text, contains('3 / 3개 (100.0%)'));
    expect(text, isNot(contains('총점')));
  });
  test('측정 불가를 0%나 분산 0회로 내보내지 않는다', () {
    final text = formatReportForExport(fixture(gaze: GazeMetrics.empty));
    expect(text, contains('화면 응시율: 측정 불가'));
    expect(text, isNot(contains('응시율: 0')));
    expect(text, isNot(contains('시선 분산: 0회')));
  });
  test('참고 품질과 AI 대체 안내의 출처를 구분한다', () {
    final text = formatReportForExport(
      fixture(
        gaze: const GazeMetrics(
          gazeRate: 45,
          distractionCount: 1,
          totalDistractionSeconds: 2,
          maxDistractionSeconds: 2,
          quality: GazeQuality.reference,
          qualityNote: '얼굴 검출 부족',
        ),
      ),
    );
    expect(text, contains('45.0% (참고용)'));
    expect(text, contains('얼굴 검출 부족'));
    expect(text, contains('지표 기반 안내'));
  });
  test('빈 질문 목록과 미작성 답변을 역량 점수로 만들지 않는다', () {
    final empty = formatReportForExport(fixture(qa: []));
    expect(empty, contains('0 / 0개 (0.0%)'));
    expect(empty, isNot(contains('NaN')));
    final partial = formatReportForExport(
      fixture(
        qa: const [
          QuestionAnswer(
            question: InterviewQuestion(id: 'q', text: '질문', intent: '의도'),
            userAnswer: '   ',
            answerDurationSeconds: 0,
          ),
        ],
      ),
    );
    expect(partial, contains('미작성'));
    expect(partial, contains('시간 기록 없음'));
  });
  test('데모 표시를 유지하고 답변 속 코드 블록이 문서 구조를 깨지 않게 한다', () {
    const answer = '분석한 코드입니다.\n```dart\nprint("hi");\n```\n# 이것도 답변입니다.';
    final text = formatReportForExport(
      fixture(
        qa: const [
          QuestionAnswer(
            question: InterviewQuestion(id: 'q', text: '질문', intent: '의도'),
            userAnswer: answer,
            answerDurationSeconds: 5,
          ),
        ],
      ),
      isDemo: true,
    );
    expect(text, contains('DEMO'));
    expect(text, contains('실제 AI 평가가 아닙니다'));
    expect(text, contains('````\n$answer\n````'));
  });
}
