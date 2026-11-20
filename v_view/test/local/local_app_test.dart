import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/local/local_ai_app.dart';
import 'package:v_view/state/app_mode_provider.dart';
import 'package:v_view/state/interview/interview_provider.dart';
import 'package:v_view/state/report/report_provider.dart';
import 'package:v_view/ui/home/home_screen.dart';
import 'package:v_view/ui/history/history_list_screen.dart';
import 'package:v_view/ui/session_setup/session_setup_screen.dart';
import 'package:v_view/ui/interview/interview_screen.dart';
import 'package:v_view/data/local/interview_draft_datasource.dart';

class _Api extends Fake implements ClaudeApiService {
  bool connected = true;
  @override
  Future<bool> checkLocalConnection() async => connected;
  int questions = 0;
  @override
  Future<List<InterviewQuestion>> generateQuestions(SessionInput input) async {
    questions++;
    return const [
      InterviewQuestion(id: 'q1', text: '문제 해결 경험을 알려주세요.', intent: '경험 확인'),
    ];
  }

  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) async => const [
    ImprovementPoint(
      title: '역할 설명',
      description: '구체적인 역할과 결과를 설명해 보세요.',
      evidenceMetric: '첫 번째 답변',
    ),
  ];
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vview_local_app_');
    Hive.init(directory.path);
    for (final name in ['history', 'reports', 'session_input', 'sessions']) {
      await Hive.openBox<Map>(name);
    }
    await Hive.openBox('settings');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  Future<void> open(
    WidgetTester tester, {
    bool largeText = false,
    _Api? api,
  }) async {
    await tester.binding.setSurfaceSize(
      largeText ? const Size(320, 740) : const Size(390, 844),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LocalAiApp(
        api: api ?? _Api(),
        textScaler: largeText ? const TextScaler.linear(1.6) : null,
      ),
    );
    // Allow the initial connection check to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('PC 연결이 끊어지면 기존 화면을 유지하고 연결 안내를 표시한다', (tester) async {
    final api = _Api()..connected = false;
    await open(tester, api: api);
    await tester.tap(find.text('연습'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('PC 연결 확인 필요'), findsOneWidget);
    expect(find.textContaining('USB 연결'), findsOneWidget);
  });

  testWidgets('앱 재시작 뒤 임시 기록에서 작성 중 답변과 남은 시간을 복구한다', (tester) async {
    final api = _Api();
    const input = SessionInput(
      type: InterviewType.job,
      position: '개발자',
      company: '가상 회사',
      selfIntroduction: '연습',
    );
    await tester.runAsync(() async {
      final previous = InterviewNotifier(
        api,
        draftStore: InterviewDraftDatasource(),
      );
      await previous.start(input);
      previous.submitAnswer('이어서 작성할 답변');
      previous.resetTimer(87);
      await previous.flushDraft();
      previous.dispose();
    });
    await open(tester, api: api);
    expect(find.text('연습 이어하기'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('연습 이어하기'));
      await Hive.box<Map>('session_input').flush();
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('면접이 일시정지되었습니다.'), findsOneWidget);
    final restored = ProviderScope.containerOf(
      tester.element(find.byType(InterviewScreen)),
    );
    expect(restored.read(interviewProvider).timerSeconds, 87);
    expect(restored.read(interviewProvider).userAnswers['q1'], '이어서 작성할 답변');
    expect(api.questions, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Firebase 초기화·로그인 없이 실제 로컬 연습 화면으로 시작한다', (tester) async {
    await open(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byTooltip('로컬 모드 안내'), findsOneWidget);
    expect(find.text('면접 시작하기'), findsOneWidget);
    expect(find.text('로그인'), findsNothing);
    expect(Hive.box<Map>('history').isEmpty, isTrue);
    await tester.tap(find.text('연습'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionSetupScreen), findsOneWidget);
  });
  testWidgets('로컬 계정 안내와 기록 화면에서 Firebase 로그아웃을 호출하지 않는다', (tester) async {
    await open(tester);
    await tester.tap(find.text('마이'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('로그아웃'), findsNothing);
    expect(find.textContaining('PC에서 AI를 실행'), findsOneWidget);
    await tester.tapAt(const Offset(180, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('기록').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HistoryListScreen), findsOneWidget);
    expect(find.byTooltip('로그아웃'), findsNothing);
    await tester.pumpAndSettle();
  });
  testWidgets('로컬 상태는 샘플 대신 주입한 실제 API와 기록 저장으로 연결된다', (tester) async {
    final api = _Api();
    await open(tester, api: api);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(isDemoModeProvider), isFalse);
    const input = SessionInput(
      type: InterviewType.job,
      position: '개발',
      company: '가상 회사',
      selfIntroduction: '테스트 소개',
    );
    await container.read(interviewProvider.notifier).start(input);
    final question = container.read(interviewProvider).questions.single;
    expect(api.questions, 1);
    expect(container.read(demoAnswerProvider(question)), isNull);
    await tester.runAsync(
      () => container
          .read(reportProvider.notifier)
          .generate(
            interviewType: input.type,
            position: input.position,
            company: input.company,
            qaList: [
              QuestionAnswer(
                question: question,
                userAnswer: '중복 제출을 수정했습니다.',
                answerDurationSeconds: 10,
              ),
            ],
            gazeMetrics: GazeMetrics.empty,
            totalDurationSeconds: 10,
          ),
    );
    expect(
      container.read(reportProvider).report!.isAiFeedbackAvailable,
      isTrue,
    );
    expect(Hive.box<Map>('history').length, 1);
  });
  testWidgets('작은 화면·큰 글자에서도 로컬 홈이 넘치지 않는다', (tester) async {
    await open(tester, largeText: true);
    expect(tester.takeException(), isNull);
  });
}
