import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/history/session_history.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/report/report_provider.dart';

class _UnavailableApi extends Fake implements ClaudeApiService {
  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) async => throw Exception('AI 요청 실패');
}

class _DelayedReportRepo extends Fake implements ReportLocalDatasource {
  final saved = Completer<void>();

  @override
  Future<void> save(SessionReport report) => saved.future;
}

class _HistoryRepo extends Fake implements HistoryLocalDatasource {
  @override
  Future<void> save(SessionHistoryItem item) async {}
}

class _FailingReportRepo extends Fake implements ReportLocalDatasource {
  @override
  Future<void> save(SessionReport report) async {
    throw Exception('저장 공간 오류');
  }
}

class _QueuedApi extends Fake implements ClaudeApiService {
  final requests = <Completer<List<ImprovementPoint>>>[];

  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) {
    final request = Completer<List<ImprovementPoint>>();
    requests.add(request);
    return request.future;
  }
}

Future<void> _generate(ReportNotifier notifier) => notifier.generate(
  interviewType: InterviewType.job,
  position: '개발자',
  company: '회사',
  qaList: const [],
  gazeMetrics: GazeMetrics.empty,
  totalDurationSeconds: 0,
);

void main() {
  test('이전 리포트 응답이 늦게 와도 최신 세션의 리포트를 덮어쓰지 않는다', () async {
    final api = _QueuedApi();
    final repo = _DelayedReportRepo()..saved.complete();
    final notifier = ReportNotifier(api, repo, _HistoryRepo());
    addTearDown(notifier.dispose);
    final first = _generate(notifier);
    final latest = notifier.generate(
      interviewType: InterviewType.job,
      position: '새 세션',
      company: '회사',
      qaList: const [],
      gazeMetrics: GazeMetrics.empty,
      totalDurationSeconds: 20,
    );
    api.requests[1].complete([]);
    await latest;
    api.requests[0].complete([]);
    await first;

    expect(notifier.state.report?.totalDurationSeconds, 20);
  });

  test('로컬 저장이 완료되기 전에는 리포트 완료 상태를 표시하지 않는다', () async {
    final repo = _DelayedReportRepo();
    final notifier = ReportNotifier(_UnavailableApi(), repo, _HistoryRepo());
    addTearDown(notifier.dispose);
    final generating = _generate(notifier);
    await Future<void>.delayed(Duration.zero);

    final phaseBeforeSave = notifier.state.phase;
    repo.saved.complete();
    await generating;
    expect(phaseBeforeSave, ReportPhase.saving);
    expect(notifier.state.phase, ReportPhase.done);
  });

  test('저장 실패는 완료 메시지 대신 재시도 가능한 오류 상태로 전환한다', () async {
    final notifier = ReportNotifier(
      _UnavailableApi(),
      _FailingReportRepo(),
      _HistoryRepo(),
    );
    addTearDown(notifier.dispose);

    await _generate(notifier);
    expect(notifier.state.phase, ReportPhase.error);
    expect(notifier.state.errorMessage, isNotEmpty);
  });

  test('시선 측정 불가 시 fallback은 낮은 응시율 평가 대신 측정 안내를 준다', () async {
    final repo = _DelayedReportRepo()..saved.complete();
    final notifier = ReportNotifier(_UnavailableApi(), repo, _HistoryRepo());
    addTearDown(notifier.dispose);

    await _generate(notifier);
    final report = notifier.state.report!;
    expect(report.isAiFeedbackAvailable, isFalse);
    expect(report.improvementPoints.first.title, '시선 측정 환경 확인');
    expect(
      report.improvementPoints.first.description,
      isNot(contains('현재 응시율')),
    );
  });
}
