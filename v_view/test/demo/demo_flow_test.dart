import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/demo/demo_api_service.dart';
import 'package:v_view/demo/demo_app.dart';
import 'package:v_view/demo/demo_fixtures.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/history/session_history.dart';
import 'package:v_view/state/interview/interview_provider.dart';
import 'package:v_view/state/report/report_provider.dart';

void main() {
  late Directory directory;
  Future<void> open() async {
    for (final name in ['sessions', 'reports', 'history', 'session_input']) {
      await Hive.openBox<Map>(name);
    }
    await Hive.openBox('settings');
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vview_demo_test_');
    Hive.init(directory.path);
    await open();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('질문·답변·리포트 저장이 실제 상태와 Hive를 통해 이어지고 재열람된다', () async {
    final api = DemoApiService();
    final interview = InterviewNotifier(api);
    final report = ReportNotifier(
      api,
      ReportLocalDatasource(),
      HistoryLocalDatasource(),
      feedbackIsAi: false,
    );
    addTearDown(interview.dispose);
    addTearDown(report.dispose);
    await interview.start(demoInput);
    expect(interview.state.questions.length, demoInput.questionCount);
    interview.submitAnswer('프로젝트에서 오류를 재현하고 원인을 찾아 상태 초기화 순서를 수정했습니다.');
    final question = interview.state.questions.first;
    await report.generate(
      interviewType: demoInput.type,
      position: demoInput.position,
      company: demoInput.company,
      qaList: [
        QuestionAnswer(
          question: question,
          userAnswer: interview.state.userAnswers[question.id]!,
          answerDurationSeconds: 12,
        ),
      ],
      gazeMetrics: GazeMetrics.empty,
      totalDurationSeconds: 12,
    );
    final id = report.state.report!.id;
    expect(report.state.report!.isAiFeedbackAvailable, isFalse);
    expect(report.state.phase, ReportPhase.done);
    await Hive.close();
    await open();
    expect(HistoryLocalDatasource().loadAll().single.id, id);
    expect(
      ReportLocalDatasource().load(id)!.qaList.single.userAnswer,
      contains('상태 초기화'),
    );
  });

  test('샘플 기록을 초기화 없이 중복 생성하지 않는다', () async {
    await seedDemoData();
    await seedDemoData();
    expect(HistoryLocalDatasource().loadAll(), hasLength(2));
    expect(
      ReportLocalDatasource().load('demo-current')!.isAiFeedbackAvailable,
      isFalse,
    );
  });

  test('품질 필드가 없는 과거 기록은 정상 측정으로 단정하지 않는다', () async {
    await seedDemoData();
    final box = Hive.box<Map>('history');
    final legacy = Map.of(box.get('demo-current')!)..remove('gazeQuality');
    await box.put('demo-current', legacy);
    final item = HistoryLocalDatasource().loadAll().first;
    expect(item.gazeQuality, GazeQuality.reference);
  });

  testWidgets('데모임을 표시하고 샘플 리포트의 비교 수치를 연다', (tester) async {
    await tester.runAsync(seedDemoData);
    await tester.pumpWidget(const ProviderScope(child: DemoApp()));
    await tester.pumpAndSettle();
    expect(find.textContaining('실제 AI 평가가 아닙니다'), findsOneWidget);
    await tester.tap(find.text('샘플 리포트 보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('지난 연습과 비교'));
    expect(find.text('+33.3%p'), findsOneWidget);
    expect(find.text('샘플 피드백'), findsOneWidget);
    expect(find.textContaining('AI 연결이'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기록에서도 측정 불가를 응시율 0%로 오해하지 않게 표시한다', (tester) async {
    await tester.runAsync(() async {
      await HistoryLocalDatasource().save(
        SessionHistoryItem(
          id: 'unavailable',
          createdAt: DateTime(2026, 11, 5),
          interviewType: demoInput.type,
          position: '측정 없는 연습',
          company: demoInput.company,
          gazeRate: 0,
          gazeQuality: GazeQuality.unavailable,
          distractionCount: 0,
          totalQuestions: 1,
          totalDurationSeconds: 10,
        ),
      );
    });
    await tester.pumpWidget(const ProviderScope(child: DemoApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연습 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.text('측정 불가'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.byTooltip('계정'), findsNothing);
  });

  testWidgets('부모 ProviderScope가 있어도 데모 질문 생성은 실제 서버 설정을 읽지 않는다', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DemoApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('샘플 질문으로 연습하기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('프로젝트 문제를 소개'), findsOneWidget);
    expect(find.textContaining('AI_PROXY_URL'), findsNothing);
  });
}
