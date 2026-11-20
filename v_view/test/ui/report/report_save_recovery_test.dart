import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/data/remote/gaze/gaze_analyzer.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/history/session_history.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/state/gaze/gaze_provider.dart';
import 'package:v_view/state/history/history_provider.dart';
import 'package:v_view/state/interview/interview_provider.dart';
import 'package:v_view/state/report/report_provider.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';
import 'package:v_view/ui/report/report_screen.dart';

class _Api extends Fake implements ClaudeApiService {
  int calls = 0;
  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) async {
    calls++;
    return const [
      ImprovementPoint(
        title: '구체적인 역할 설명',
        description: '직접 수정한 부분과 확인한 결과를 함께 설명해 보세요.',
        evidenceMetric: '첫 번째 답변의 상태 관리 경험',
      ),
    ];
  }
}

class _Reports extends Fake implements ReportLocalDatasource {
  int attempts = 0;
  final records = <String, SessionReport>{};
  Completer<void>? gate;
  @override
  Future<void> save(SessionReport report) async {
    attempts++;
    if (attempts == 1) throw const FileSystemException('disk full');
    await gate?.future;
    records[report.id] = report;
  }

  @override
  SessionReport? load(String id) => records[id];
}

class _History extends Fake implements HistoryLocalDatasource {
  final records = <String, SessionHistoryItem>{};
  @override
  List<SessionHistoryItem> loadAll() => records.values.toList();
  @override
  Future<void> save(SessionHistoryItem item) async => records[item.id] = item;
}

class _Interview extends InterviewNotifier {
  _Interview(super.api) {
    state = const InterviewState(
      phase: InterviewPhase.finished,
      questions: [
        InterviewQuestion(id: 'q1', text: '해결한 문제는 무엇인가요?', intent: '경험 확인'),
      ],
      userAnswers: {'q1': '상태 관리 오류를 재현하고 중복 제출을 막았습니다.'},
      answerDurations: {'q1': 27},
      elapsedSeconds: 31,
    );
  }
}

class _Analyzer extends Fake implements GazeAnalyzer {
  @override
  GazeMetrics computeMetrics(List<GazeFrame> frames) => GazeMetrics.empty;
}

Future<void> _open(
  WidgetTester tester,
  _Api api,
  _Reports reports,
  _History history, {
  bool largeText = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportProvider.overrideWith(
          (_) => ReportNotifier(api, reports, history),
        ),
        interviewProvider.overrideWith((_) => _Interview(api)),
        gazeProvider.overrideWith((_) => GazeNotifier(_Analyzer())),
        historyProvider.overrideWith((_) => HistoryNotifier(history)),
        sessionInputProvider.overrideWith((_) => SessionInputNotifier(null)),
      ],
      child: MaterialApp(
        builder: largeText
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              )
            : null,
        home: const ReportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('저장 재시도는 AI를 다시 호출하지 않고 원래 리포트 하나를 저장한다', (tester) async {
    final api = _Api();
    final reports = _Reports();
    final history = _History();
    await _open(tester, api, reports, history);
    expect(api.calls, 1);
    await tester.tap(find.textContaining(RegExp(r'^(저장 )?다시 시도$')));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(reports.records, hasLength(1));
    expect(history.records.keys, reports.records.keys);
    expect(find.text('기록에 자동 저장됐어요'), findsOneWidget);
  });

  testWidgets('저장 실패 중에도 답변과 피드백을 보고 리포트를 복사할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _open(tester, _Api(), _Reports(), _History(), largeText: true);
    expect(find.text('기록에 자동 저장됐어요'), findsNothing);
    expect(find.byTooltip('답변 포함 리포트 복사'), findsOneWidget);
    final question = find.text('Q1. 해결한 문제는 무엇인가요?');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.text('상태 관리 오류를 재현하고 중복 제출을 막았습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('답변 포함 리포트 복사'));
    await tester.pumpAndSettle();
    expect(copied, contains('상태 관리 오류를 재현하고 중복 제출을 막았습니다.'));
    expect(copied, contains('구체적인 역할 설명'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장 재시도 대기 중 중복 저장을 막고 완료 전 성공을 표시하지 않는다', (tester) async {
    final api = _Api();
    final reports = _Reports();
    final history = _History();
    await _open(tester, api, reports, history);
    reports.gate = Completer<void>();
    await tester.tap(find.textContaining(RegExp(r'^(저장 )?다시 시도$')));
    await tester.pump();
    expect(find.text('기록에 자동 저장됐어요'), findsNothing);
    expect(find.text('기록을 저장하고 있어요'), findsOneWidget);
    expect(api.calls, 1);
    expect(reports.attempts, 2);
    expect(history.records, isEmpty);
    reports.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('기록에 자동 저장됐어요'), findsOneWidget);
    expect(reports.attempts, 2);
  });
}
