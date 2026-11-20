import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/data/remote/gaze/gaze_analyzer.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/gaze/gaze_provider.dart';
import 'package:v_view/state/interview/interview_provider.dart';
import 'package:v_view/state/interview/speech_provider.dart';
import 'package:v_view/state/report/report_provider.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';
import 'package:v_view/ui/interview/interview_screen.dart';
import 'package:v_view/services/speech_service.dart';

import '../../support/fake_speech_recognizer.dart';

class _Api extends Fake implements ClaudeApiService {
  String? lastAnswer;

  @override
  Future<InterviewQuestion?> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
    List<QuestionAnswer> conversation = const [],
  }) async {
    lastAnswer = userAnswer;
    return null;
  }
}

class _Analyzer extends Fake implements GazeAnalyzer {
  @override
  GazeMetrics computeMetrics(List<GazeFrame> frames) => GazeMetrics.empty;
}

class _ReportRepo extends Fake implements ReportLocalDatasource {}

class _HistoryRepo extends Fake implements HistoryLocalDatasource {}

class _PendingReport extends ReportNotifier {
  _PendingReport(ClaudeApiService api)
    : super(api, _ReportRepo(), _HistoryRepo());

  List<QuestionAnswer>? capturedAnswers;
  GazeMetrics? capturedGaze;

  @override
  Future<void> generate({
    required InterviewType interviewType,
    required String position,
    required String company,
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
    required int totalDurationSeconds,
  }) {
    capturedAnswers = qaList;
    capturedGaze = gazeMetrics;
    return Completer<void>().future;
  }
}

class _ReadyInterview extends InterviewNotifier {
  _ReadyInterview(super.api, SessionInput input) {
    startPrepared(input, const [
      InterviewQuestion(id: 'q1', text: '경험을 소개해주세요.', intent: '경험'),
      InterviewQuestion(id: 'q2', text: '지원 동기는 무엇인가요?', intent: '동기'),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var cameraRequests = 0;

  setUp(() {
    cameraRequests = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (_) async {
        cameraRequests++;
        return <Map<String, dynamic>>[];
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (_) async => false,
    );
  });

  Future<ProviderContainer> openInterview(
    WidgetTester tester, {
    FakeSpeechRecognizer? recognizer,
    _Api? api,
    int preparationSeconds = 0,
    bool cameraEnabled = true,
  }) async {
    final apiService = api ?? _Api();
    final input = SessionInput(
      type: InterviewType.job,
      position: '개발자',
      company: '회사',
      selfIntroduction: '소개',
      preparationSeconds: preparationSeconds,
      cameraEnabled: cameraEnabled,
    );
    final speech = SpeechService(
      recognizer: recognizer ?? (FakeSpeechRecognizer()..available = false),
    );
    final container = ProviderContainer(
      overrides: [
        speechServiceProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(speech.dispose()));
          return speech;
        }),
        interviewProvider.overrideWith(
          (_) => _ReadyInterview(apiService, input),
        ),
        gazeProvider.overrideWith((_) => GazeNotifier(_Analyzer())),
        reportProvider.overrideWith((_) => _PendingReport(apiService)),
        sessionInputProvider.overrideWith((_) => SessionInputNotifier(input)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: InterviewScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('시간 만료는 자동 제출 없이 답변을 보존하며 연장과 직접 제출을 선택한다', (tester) async {
    final container = await openInterview(tester);
    await tester.enterText(find.byType(TextField), '시간 종료 전에 작성한 답변');
    container.read(interviewProvider.notifier).resetTimer(1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(
      container.read(interviewProvider).userAnswers['q1'],
      '시간 종료 전에 작성한 답변',
    );
    expect(container.read(interviewProvider).currentQuestion?.id, 'q1');
    expect(find.text('답변 시간이 끝났어요'), findsOneWidget);
    await tester.ensureVisible(find.text('30초 더 답변하기'));
    await tester.tap(find.text('30초 더 답변하기'));
    await tester.pump();
    expect(container.read(interviewProvider).timerSeconds, 30);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '시간 종료 전에 작성한 답변',
    );
    await tester.tap(find.text('다음 질문'));
    await tester.pumpAndSettle();
    expect(container.read(interviewProvider).currentQuestion?.id, 'q2');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('카메라 끔은 카메라를 호출하지 않고 준비 시간 동안 답변 입력·측정을 기다린다', (tester) async {
    final container = await openInterview(
      tester,
      preparationSeconds: 15,
      cameraEnabled: false,
    );
    expect(cameraRequests, 0);
    expect(find.textContaining('카메라 없이 연습 중'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(container.read(interviewProvider).timerSeconds, 120);
    expect(container.read(interviewProvider).preparationSecondsRemaining, 10);
    expect(container.read(gazeProvider).isRunning, isFalse);
    await tester.tap(find.text('바로 답변 시작'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(interviewProvider).elapsedSeconds, 1);
    expect(container.read(gazeProvider).isRunning, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('빈 답변은 확인 후에만 건너뛰며 취소하면 같은 질문에 머문다', (tester) async {
    final api = _Api();
    final container = await openInterview(tester, api: api);
    await tester.tap(find.text('다음 질문'));
    await tester.pumpAndSettle();
    expect(find.text('아직 답변이 없어요'), findsOneWidget);
    expect(container.read(interviewProvider).currentIndex, 0);
    await tester.tap(find.text('계속 답변하기'));
    await tester.pumpAndSettle();
    expect(container.read(interviewProvider).currentIndex, 0);
    await tester.tap(find.text('다음 질문'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('질문 건너뛰기'));
    await tester.pumpAndSettle();
    expect(container.read(interviewProvider).currentIndex, 1);
    expect(api.lastAnswer, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('음성 인식 중지 응답을 기다리는 동안에도 작성한 답변을 보존한다', (tester) async {
    final stopped = Completer<void>();
    final recognizer = FakeSpeechRecognizer()..stopGate = stopped;
    final container = await openInterview(tester, recognizer: recognizer);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    recognizer.recognize('인식 종료 전 보존할 답변');
    await tester.pump();
    await tester.tap(find.text('다음 질문'));
    await tester.pump();
    final savedBeforeStop = container.read(interviewProvider).userAnswers['q1'];
    stopped.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    expect(savedBeforeStop, '인식 종료 전 보존할 답변');
  });

  testWidgets('시간 만료로 마이크를 멈출 때 마지막 인식 문장도 보존하고 자동 평가하지 않는다', (tester) async {
    final gate = Completer<void>();
    final recognizer = FakeSpeechRecognizer()..stopGate = gate;
    final api = _Api();
    final container = await openInterview(
      tester,
      recognizer: recognizer,
      api: api,
      cameraEnabled: false,
    );
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    recognizer.recognize('말한 답변');
    await tester.pump();
    container.read(interviewProvider.notifier).resetTimer(1);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(interviewProvider).userAnswers['q1'], '말한 답변');
    recognizer.recognize('말한 답변 마지막 문장', finalResult: true);
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(container.read(interviewProvider).userAnswers['q1'], '말한 답변 마지막 문장');
    expect(container.read(interviewProvider).currentIndex, 0);
    expect(api.lastAnswer, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('큰 글자·키보드 상태에서도 준비와 시간 연장을 사용할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = await openInterview(
      tester,
      preparationSeconds: 15,
      cameraEnabled: false,
    );
    await tester.ensureVisible(find.text('바로 답변 시작'));
    await tester.tap(find.text('바로 답변 시작'));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '키보드로 정리한 답변');
    container.read(interviewProvider.notifier).resetTimer(1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.ensureVisible(find.text('30초 더 답변하기'));
    await tester.pump();
    await tester.tap(find.text('30초 더 답변하기'));
    await tester.pump();
    expect(container.read(interviewProvider).timerSeconds, 30);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('마이크 답변은 화면과 제출 답변을 거쳐 AI 리포트 입력으로 전달된다', (tester) async {
    final recognizer = FakeSpeechRecognizer();
    final api = _Api();
    final container = await openInterview(
      tester,
      recognizer: recognizer,
      api: api,
    );
    await tester.enterText(find.byType(TextField), '기존 답변');
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    recognizer.recognize('마이크로 설명한 경험', finalResult: true);
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '기존 답변 마이크로 설명한 경험',
    );
    await tester.tap(find.text('다음 질문'));
    await tester.pump();
    await tester.pump();
    expect(api.lastAnswer, '기존 답변 마이크로 설명한 경험');
    await tester.enterText(find.byType(TextField), '추가 답변');
    await tester.tap(find.text('답변 제출'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final report = container.read(reportProvider.notifier) as _PendingReport;
    expect(report.capturedAnswers!.first.userAnswer, '기존 답변 마이크로 설명한 경험');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('인식 불가여도 마이크 버튼과 실패 안내가 표시된다', (tester) async {
    await openInterview(tester);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('음성 인식을 사용할 수 없어요'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('인식 오류가 발생하면 안내하고 마이크를 다시 켤 수 있다', (tester) async {
    final recognizer = FakeSpeechRecognizer();
    await openInterview(tester, recognizer: recognizer);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    recognizer.fail('error_network');
    await tester.pump();

    expect(find.textContaining('네트워크'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    expect(recognizer.listening, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('카메라 없이 직접 종료하면 답변과 미측정 이유를 리포트에 전달한다', (tester) async {
    final container = await openInterview(tester, cameraEnabled: false);
    await tester.enterText(find.byType(TextField), '마지막으로 작성 중인 답변');
    await tester.tap(find.text('종료').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '종료'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      container.read(interviewProvider).userAnswers['q1'],
      '마지막으로 작성 중인 답변',
    );
    expect(container.read(interviewProvider).phase, InterviewPhase.finished);
    final report = container.read(reportProvider.notifier) as _PendingReport;
    expect(report.capturedGaze!.quality, GazeQuality.unavailable);
    expect(report.capturedGaze!.qualityNote, contains('카메라를 끄고'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('일시정지 후 재개하면 남은 시간이 초기화되지 않는다', (tester) async {
    final container = await openInterview(tester);
    container.read(interviewProvider.notifier).resetTimer(37);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.tap(find.text('재개'));
    await tester.pump();

    expect(container.read(interviewProvider).timerSeconds, 37);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
}
