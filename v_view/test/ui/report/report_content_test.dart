import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/report/report_provider.dart';
import 'package:v_view/state/auth/auth_provider.dart';
import 'package:v_view/state/gaze/gaze_provider.dart';
import 'package:v_view/state/history/history_provider.dart';
import 'package:v_view/state/interview/interview_provider.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';
import 'package:v_view/data/remote/gaze/gaze_analyzer.dart';
import 'package:v_view/domain/history/session_history.dart';
import 'package:v_view/ui/history/history_detail_screen.dart';
import 'package:v_view/ui/history/history_list_screen.dart';
import 'package:v_view/ui/report/report_screen.dart';
import 'package:v_view/ui/session_setup/session_setup_screen.dart';

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
        title: '새 AI 평가',
        description: '본인 역할과 결과를 구체화해 보세요.',
        evidenceMetric: '저장한 첫 답변',
      ),
    ];
  }
}

class _HistoryStore extends Fake implements HistoryLocalDatasource {
  _HistoryStore([this.items = const []]);
  final List<SessionHistoryItem> items;
  @override
  List<SessionHistoryItem> loadAll() => items;
}

class _Analyzer extends Fake implements GazeAnalyzer {
  @override
  GazeMetrics computeMetrics(List<GazeFrame> frames) => GazeMetrics.empty;
}

class _ReadyReport extends ReportNotifier {
  _ReadyReport(this.fixture)
    : super(_Api(), _ReportStore(fixture), _HistoryStore());
  final SessionReport fixture;

  @override
  Future<void> generate({
    required InterviewType interviewType,
    required String position,
    required String company,
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
    required int totalDurationSeconds,
  }) async {
    state = ReportState(phase: ReportPhase.done, report: fixture);
  }
}

class _GeneratingReport extends ReportNotifier {
  _GeneratingReport(SessionReport previous)
    : super(_Api(), _ReportStore(previous), _HistoryStore()) {
    state = ReportState(phase: ReportPhase.done, report: previous);
  }

  @override
  Future<void> generate({
    required InterviewType interviewType,
    required String position,
    required String company,
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
    required int totalDurationSeconds,
  }) {
    state = const ReportState(phase: ReportPhase.generating);
    return Completer<void>().future;
  }
}

class _ReportStore extends Fake implements ReportLocalDatasource {
  _ReportStore(this.report, [this.previous]);
  SessionReport report;
  final SessionReport? previous;
  @override
  Future<void> save(SessionReport value) async {
    report = value;
  }

  @override
  SessionReport? load(String id) => id == report.id
      ? report
      : id == previous?.id
      ? previous
      : null;
}

SessionReport _report({
  String id = 'saved-report',
  DateTime? createdAt,
  GazeQuality quality = GazeQuality.normal,
  bool aiAvailable = true,
  bool empty = false,
}) => SessionReport(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 11, 3, 10),
  interviewType: InterviewType.job,
  gazeMetrics: GazeMetrics(
    gazeRate: quality == GazeQuality.unavailable ? 0 : 82,
    distractionCount: 2,
    totalDistractionSeconds: 4,
    maxDistractionSeconds: 3,
    quality: quality,
    qualityNote: quality == GazeQuality.reference ? '얼굴 감지 표본이 부족해요.' : null,
  ),
  qaList: empty
      ? []
      : const [
          QuestionAnswer(
            question: InterviewQuestion(
              id: 'q1',
              text: '자기소개를 해주세요.',
              intent: '경험 전달',
            ),
            userAnswer: '프로젝트에서 상태 관리 문제를 해결했습니다.',
            answerDurationSeconds: 12,
          ),
          QuestionAnswer(
            question: InterviewQuestion(
              id: 'q2',
              text: '지원 동기를 알려주세요.',
              intent: '동기 확인',
            ),
            userAnswer: '   ',
            answerDurationSeconds: 31,
          ),
        ],
  totalQuestions: empty ? 0 : 2,
  totalDurationSeconds: empty ? 0 : 43,
  improvementPoints: const [
    ImprovementPoint(
      title: '사례 구체화',
      description: '역할과 결과를 함께 설명해 보세요.',
      evidenceMetric: '첫 번째 답변',
    ),
    ImprovementPoint(
      title: '응시 유지',
      description: '카메라를 바라보는 시간을 늘려 보세요.',
      evidenceMetric: '응시율 82%',
    ),
  ],
  isAiFeedbackAvailable: aiAvailable,
);

Future<void> _pumpReport(
  WidgetTester tester,
  SessionReport report, {
  bool largeText = false,
  SessionReport? previous,
  _Api? api,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reportProvider.overrideWith(
          (ref) => ReportNotifier(
            api ?? _Api(),
            _ReportStore(report, previous),
            _HistoryStore(),
          ),
        ),
        historyProvider.overrideWith(
          (_) => HistoryNotifier(
            _HistoryStore([
              for (final item in [report, ?previous])
                SessionHistoryItem(
                  id: item.id,
                  createdAt: item.createdAt,
                  interviewType: item.interviewType,
                  position: '개발자',
                  company: '회사',
                  gazeRate: item.gazeMetrics.gazeRate,
                  distractionCount: item.gazeMetrics.distractionCount,
                  totalQuestions: item.totalQuestions,
                  totalDurationSeconds: item.totalDurationSeconds,
                ),
            ]),
          ),
        ),
        interviewProvider.overrideWith((_) => InterviewNotifier(api ?? _Api())),
        sessionInputProvider.overrideWith((_) => SessionInputNotifier(null)),
        gazeProvider.overrideWith((_) => GazeNotifier(_Analyzer())),
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
        home: const HistoryDetailScreen(reportId: 'saved-report'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpNewReport(
  WidgetTester tester, {
  bool largeText = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        reportProvider.overrideWith((ref) => _ReadyReport(_report())),
        interviewProvider.overrideWith((ref) => InterviewNotifier(_Api())),
        gazeProvider.overrideWith((ref) => GazeNotifier(_Analyzer())),
        historyProvider.overrideWith((ref) => HistoryNotifier(_HistoryStore())),
        sessionInputProvider.overrideWith((ref) => SessionInputNotifier(null)),
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const ReportScreen()),
              ),
              child: const Text('리포트 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('리포트 열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('새 리포트의 첫 화면에 이전 세션 피드백을 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportProvider.overrideWith((_) => _GeneratingReport(_report())),
          interviewProvider.overrideWith((_) => InterviewNotifier(_Api())),
          gazeProvider.overrideWith((_) => GazeNotifier(_Analyzer())),
          historyProvider.overrideWith((_) => HistoryNotifier(_HistoryStore())),
          sessionInputProvider.overrideWith((_) => SessionInputNotifier(null)),
        ],
        child: const MaterialApp(home: ReportScreen()),
      ),
    );
    expect(find.text('사례 구체화'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('저장 리포트에서 이전 연습을 불러와 실제 변화량을 표시한다', (tester) async {
    await _pumpReport(
      tester,
      _report(),
      previous: _report(
        id: 'previous',
        createdAt: DateTime(2026, 11, 2),
        empty: true,
      ),
    );
    await tester.ensureVisible(find.text('지난 연습과 비교'));
    expect(find.text('+50.0%p'), findsOneWidget);
    expect(find.textContaining('11월 2일'), findsOneWidget);
  });

  testWidgets('신규 리포트의 고정 하단 버튼은 좁은 화면과 큰 글자에서도 사용할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpNewReport(tester, largeText: true);
    expect(tester.takeException(), isNull);
    expect(find.text('다시 연습하기').hitTestable(), findsOneWidget);
    expect(find.text('기록 보기').hitTestable(), findsOneWidget);
  });

  testWidgets('완료율은 공백 답변을 제외하고 실제 답변 수로 표시한다', (tester) async {
    await _pumpReport(tester, _report());
    expect(find.text('답변 완료율'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 / 2개 답변'), findsOneWidget);
    expect(find.text('총점'), findsNothing);
  });

  testWidgets('측정 불가를 응시율 0점으로 표시하지 않는다', (tester) async {
    await _pumpReport(tester, _report(quality: GazeQuality.unavailable));
    expect(find.text('측정 불가'), findsWidgets);
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('질문을 펼치면 내 답변과 기록한 답변 시간을 확인할 수 있다', (tester) async {
    await _pumpReport(tester, _report());
    final question = find.text('Q1. 자기소개를 해주세요.');
    await tester.ensureVisible(question);
    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.text('프로젝트에서 상태 관리 문제를 해결했습니다.'), findsOneWidget);
    expect(find.text('답변 시간 12초'), findsOneWidget);
  });

  testWidgets('AI 실패 피드백은 지표 기반임을 표시하고 모든 개선 근거를 제공한다', (tester) async {
    await _pumpReport(tester, _report(aiAvailable: false));
    expect(find.text('지표 기반 피드백'), findsOneWidget);
    expect(find.text('사례 구체화'), findsOneWidget);
    expect(find.text('응시 유지'), findsOneWidget);
    expect(find.text('근거: 첫 번째 답변'), findsOneWidget);
    expect(find.text('근거: 응시율 82%'), findsOneWidget);
  });

  testWidgets('질문이 없는 리포트도 완료율을 0으로 표시한다', (tester) async {
    await _pumpReport(tester, _report(empty: true));
    expect(find.text('0 / 0개 답변'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.textContaining('NaN'), findsNothing);
  });

  testWidgets('좁은 화면과 큰 글자에서 리포트가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpReport(
      tester,
      _report(quality: GazeQuality.reference),
      largeText: true,
    );
    expect(find.text('참고용'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('새 리포트도 저장 리포트와 같은 실제 지표를 표시한다', (tester) async {
    await _pumpNewReport(tester);
    expect(find.text('답변 완료율'), findsOneWidget);
    expect(find.text('1 / 2개 답변'), findsOneWidget);
    expect(find.text('총점 '), findsNothing);
    expect(find.text('기록에 자동 저장됐어요'), findsOneWidget);
  });

  testWidgets('다시 연습하기는 세션 설정으로 이동한다', (tester) async {
    await _pumpNewReport(tester);
    await tester.tap(find.text('다시 연습하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionSetupScreen), findsOneWidget);
  });

  testWidgets('기록 보기는 실제 기록 목록으로 이동한다', (tester) async {
    await _pumpNewReport(tester);
    await tester.tap(find.text('기록 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryListScreen), findsOneWidget);
  });

  testWidgets('저장한 답변의 평가 재시도로 같은 상세 화면과 복사 대상을 갱신한다', (tester) async {
    final api = _Api();
    await _pumpReport(tester, _report(aiAvailable: false), api: api);
    final retry = find.text('저장한 답변으로 AI 평가 받기');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('새 AI 평가'), findsOneWidget);
    expect(find.text('AI 피드백'), findsOneWidget);
    expect(api.calls, 1);
    expect(find.text('저장한 답변으로 AI 평가 받기'), findsNothing);
  });

  testWidgets('같은 질문으로 재연습하면 이전 답변·개선 목표를 확인하고 새 답변을 작성한다', (tester) async {
    await _pumpReport(tester, _report());
    final practice = find.text('피드백 보며 같은 질문으로 연습');
    await tester.ensureVisible(practice);
    await tester.tap(practice);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final reference = find.text('이전 답변·개선 목표');
    expect(reference, findsOneWidget);
    await tester.ensureVisible(reference);
    await tester.tap(reference);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('프로젝트에서 상태 관리 문제를 해결했습니다.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
