import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/history/session_history.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/report_comparison.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/history/history_provider.dart';
import 'package:v_view/state/report/report_provider.dart';
import 'package:v_view/state/report/report_comparison_provider.dart';

class _Api extends Fake implements ClaudeApiService {}

class _HistoryStore extends Fake implements HistoryLocalDatasource {
  _HistoryStore(this.items);
  final List<SessionHistoryItem> items;
  @override
  List<SessionHistoryItem> loadAll() => items;
}

class _Reports extends Fake implements ReportLocalDatasource {
  _Reports(this.reports);
  final Map<String, SessionReport> reports;
  @override
  SessionReport? load(String id) => reports[id];
}

SessionReport _report(
  String id,
  int day, {
  bool complete = true,
  int seconds = 45,
  double gaze = 82,
  GazeQuality quality = GazeQuality.normal,
}) => SessionReport(
  id: id,
  createdAt: DateTime(2026, 11, day),
  interviewType: InterviewType.job,
  gazeMetrics: GazeMetrics(
    gazeRate: gaze,
    distractionCount: 0,
    totalDistractionSeconds: 0,
    maxDistractionSeconds: 0,
    quality: quality,
  ),
  qaList: [
    QuestionAnswer(
      question: const InterviewQuestion(id: 'q1', text: 'Q1', intent: '경험'),
      userAnswer: '답변',
      answerDurationSeconds: seconds,
    ),
    QuestionAnswer(
      question: const InterviewQuestion(id: 'q2', text: 'Q2', intent: '경험'),
      userAnswer: complete ? '답변' : ' ',
      answerDurationSeconds: seconds,
    ),
  ],
  totalQuestions: 2,
  totalDurationSeconds: seconds * 2,
  improvementPoints: const [],
);

SessionHistoryItem _item(
  String id,
  int day, {
  String company = '회사',
  String position = '개발자',
}) => SessionHistoryItem(
  id: id,
  createdAt: DateTime(2026, 11, day),
  interviewType: InterviewType.job,
  position: position,
  company: company,
  gazeRate: 82,
  distractionCount: 0,
  totalQuestions: 2,
  totalDurationSeconds: 90,
);

void main() {
  test('완료율은 퍼센트 포인트, 시간은 답변한 질문의 평균으로 비교한다', () {
    final comparison = ReportComparison(
      current: _report('current', 3),
      previous: _report('previous', 2, complete: false, seconds: 30, gaze: 70),
    );
    expect(comparison.completionChange, 50);
    expect(comparison.gazeChange, 12);
    expect(comparison.averageAnswerSecondsChange, 15);
  });

  test('측정 불가와 참고용 응시율은 이전 기록과 수치 비교하지 않는다', () {
    for (final quality in [GazeQuality.unavailable, GazeQuality.reference]) {
      final comparison = ReportComparison(
        current: _report('current', 3, quality: quality),
        previous: _report('previous', 2),
      );
      expect(comparison.gazeChange, isNull);
    }
  });

  test('답변 시간 기록이 없으면 0초 향상으로 표시하지 않는다', () {
    final comparison = ReportComparison(
      current: _report('current', 3),
      previous: _report('previous', 2, seconds: 0),
    );
    expect(comparison.averageAnswerSecondsChange, isNull);
  });

  test('같은 유형·직무·회사의 더 오래된 기록 중 가장 최근 결과만 선택한다', () {
    final current = _report('current', 3);
    final history = _HistoryStore([
      _item('old', 1),
      _item('other-company', 2, company: '다른 회사'),
      _item('future', 4),
      _item('previous', 2),
      _item('current', 3),
      _item('other-position', 2, position: '디자이너'),
    ]);
    final reports = _Reports({
      for (final id in [
        'old',
        'previous',
        'future',
        'other-company',
        'other-position',
      ])
        id: _report(
          id,
          id == 'old'
              ? 1
              : id == 'future'
              ? 4
              : 2,
        ),
    });
    final container = ProviderContainer(
      overrides: [
        historyProvider.overrideWith((_) => HistoryNotifier(history)),
        reportProvider.overrideWith(
          (_) => ReportNotifier(_Api(), reports, history),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(reportComparisonProvider(current))?.previous.id,
      'previous',
    );
  });

  test('이전 상세 기록이 없거나 현재 메타데이터가 없으면 비교를 만들지 않는다', () {
    final history = _HistoryStore([_item('previous', 2)]);
    final container = ProviderContainer(
      overrides: [
        historyProvider.overrideWith((_) => HistoryNotifier(history)),
        reportProvider.overrideWith(
          (_) => ReportNotifier(_Api(), _Reports({}), history),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(reportComparisonProvider(_report('current', 3))),
      isNull,
    );
  });

  test('삭제된 이전 상세 기록은 건너뛰고 더 오래된 유효 기록을 비교한다', () {
    final history = _HistoryStore([
      _item('current', 3),
      _item('missing', 2),
      _item('old', 1),
    ]);
    final container = ProviderContainer(
      overrides: [
        historyProvider.overrideWith((_) => HistoryNotifier(history)),
        reportProvider.overrideWith(
          (_) => ReportNotifier(
            _Api(),
            _Reports({'old': _report('old', 1)}),
            history,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container
          .read(reportComparisonProvider(_report('current', 3)))
          ?.previous
          .id,
      'old',
    );
  });
}
