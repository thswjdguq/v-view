import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/report/report_provider.dart';

class _Api extends Fake implements ClaudeApiService {
  int calls = 0;
  Completer<List<ImprovementPoint>>? gate;
  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) {
    calls++;
    return gate?.future ??
        Future.value(const [
          ImprovementPoint(
            title: '구체화',
            description: '역할과 결과를 덧붙여 보세요.',
            evidenceMetric: '저장된 첫 번째 답변',
          ),
        ]);
  }
}

class _Store extends Fake implements ReportLocalDatasource {
  SessionReport? report;
  bool fail = false;
  @override
  SessionReport? load(String id) => report?.id == id ? report : null;
  @override
  Future<void> save(SessionReport value) async {
    if (fail) throw const FileSystemException('disk');
    report = value;
  }
}

class _History extends Fake implements HistoryLocalDatasource {}

SessionReport fixture() => SessionReport(
  id: 'saved',
  createdAt: DateTime(2026, 11, 16),
  interviewType: InterviewType.job,
  gazeMetrics: GazeMetrics.empty,
  qaList: const [
    QuestionAnswer(
      question: InterviewQuestion(id: 'q1', text: '경험을 알려주세요.', intent: '경험'),
      userAnswer: '오류를 재현하고 수정했습니다.',
      answerDurationSeconds: 20,
    ),
  ],
  totalQuestions: 1,
  totalDurationSeconds: 25,
  improvementPoints: const [],
  isAiFeedbackAvailable: false,
);
void main() {
  test('저장 답변을 재평가해 동일 기록에 반영하고 이미 평가한 기록은 중복 호출하지 않는다', () async {
    final api = _Api();
    final store = _Store()..report = fixture();
    final notifier = ReportNotifier(api, store, _History());
    addTearDown(notifier.dispose);
    await notifier.retryFeedback('saved');
    await notifier.retryFeedback('saved');
    expect(api.calls, 1);
    expect(store.report!.isAiFeedbackAvailable, isTrue);
    expect(store.report!.createdAt, DateTime(2026, 11, 16));
    expect(store.report!.qaList.single.answerDurationSeconds, 20);
  });
  test('평가 후 저장만 실패하면 새 AI 호출 없이 결과 저장을 재시도한다', () async {
    final api = _Api();
    final store = _Store()
      ..report = fixture()
      ..fail = true;
    final notifier = ReportNotifier(api, store, _History());
    addTearDown(notifier.dispose);
    await notifier.retryFeedback('saved');
    expect(notifier.state.feedbackRetries['saved']!.hasPendingSave, isTrue);
    store.fail = false;
    await notifier.retryFeedback('saved');
    expect(api.calls, 1);
    expect(store.report!.isAiFeedbackAvailable, isTrue);
  });
  test('진행 중 중복 평가를 막고 평가 중 삭제된 기록을 되살리지 않는다', () async {
    final api = _Api()..gate = Completer<List<ImprovementPoint>>();
    final store = _Store()..report = fixture();
    final notifier = ReportNotifier(api, store, _History());
    addTearDown(notifier.dispose);
    final pending = notifier.retryFeedback('saved');
    await notifier.retryFeedback('saved');
    store.report = null;
    api.gate!.complete(const []);
    await pending;
    expect(api.calls, 1);
    expect(store.report, isNull);
    expect(notifier.state.feedbackRetries['saved']!.errorMessage, isNotNull);
  });
}
