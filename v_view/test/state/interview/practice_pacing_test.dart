import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/interview/interview_draft.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/interview/interview_provider.dart';

class _Api extends Fake implements ClaudeApiService {
  @override
  Future<InterviewQuestion?> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
    List<QuestionAnswer> conversation = const [],
  }) async => null;
}

const _input = SessionInput(
  type: InterviewType.job,
  position: '개발',
  company: '가상 회사',
  resumeSummary: '프로젝트 경험',
  preparationSeconds: 15,
  cameraEnabled: false,
);
const _questions = [
  InterviewQuestion(id: 'q1', text: '경험은?', intent: '경험'),
  InterviewQuestion(id: 'q2', text: '역할은?', intent: '기여'),
];

void main() {
  test('준비 시간이 끝나야 답변 시간과 답변 소요 시간을 차감한다', () {
    final notifier = InterviewNotifier(_Api())
      ..startPrepared(_input, _questions);
    addTearDown(notifier.dispose);
    for (var i = 0; i < 15; i++) {
      notifier.tickTimer();
    }
    expect(notifier.state.isPreparing, isFalse);
    expect(notifier.state.timerSeconds, 120);
    expect(notifier.state.elapsedSeconds, 0);
    notifier.tickTimer();
    expect(notifier.state.timerSeconds, 119);
    expect(notifier.state.answerDurations['q1'], 1);
  });
  test('생각할 시간은 답변 시간에 합산하지 않고 다음 질문에서 다시 제공한다', () async {
    final notifier = InterviewNotifier(_Api())
      ..startPrepared(_input, _questions);
    addTearDown(notifier.dispose);
    for (var i = 0; i < 5; i++) {
      notifier.tickTimer();
    }
    expect(notifier.state.preparationSecondsRemaining, 10);
    expect(notifier.state.timerSeconds, 120);
    expect(notifier.state.elapsedSeconds, 0);
    expect(notifier.state.answerDurations, isEmpty);
    notifier.beginAnswer();
    notifier.tickTimer();
    expect(notifier.state.answerDurations['q1'], 1);
    await notifier.nextQuestion('본인 경험 답변');
    expect(notifier.state.currentQuestion!.id, 'q2');
    expect(notifier.state.preparationSecondsRemaining, 15);
    expect(notifier.state.timerSeconds, 120);
  });
  test('시간 만료에서 제출 없이 머물며 연장 중에도 기존 답변을 유지한다', () {
    final notifier = InterviewNotifier(_Api())
      ..startPrepared(_input.copyWith(preparationSeconds: 0), _questions);
    addTearDown(notifier.dispose);
    notifier.submitAnswer('작성 중인 답변');
    notifier.resetTimer(1);
    notifier.tickTimer();
    notifier.tickTimer();
    expect(notifier.state.currentIndex, 0);
    expect(notifier.state.isAnswerTimeUp, isTrue);
    notifier.extendAnswerTime();
    expect(notifier.state.timerSeconds, 30);
    expect(notifier.state.userAnswers['q1'], '작성 중인 답변');
    notifier.tickTimer();
    expect(notifier.state.answerDurations['q1'], 2);
  });
  test('준비 중 일시정지·재개방에서도 남은 준비 시간과 카메라 선택을 복구한다', () {
    final notifier = InterviewNotifier(_Api())
      ..startPrepared(_input, _questions);
    addTearDown(notifier.dispose);
    notifier.tickTimer();
    notifier.pause();
    notifier.tickTimer();
    expect(notifier.state.preparationSecondsRemaining, 14);
    final draft = InterviewDraft(
      sessionId: 'saved',
      input: _input,
      questions: _questions,
      currentIndex: 0,
      answers: const {},
      durations: const {},
      timerSeconds: 120,
      elapsedSeconds: 0,
      savedAt: DateTime(2026, 11, 17),
      preparationSecondsRemaining: 14,
    );
    final restored = InterviewDraft.fromMap(draft.toMap());
    expect(restored.input.cameraEnabled, isFalse);
    notifier.restoreDraft(restored);
    expect(notifier.state.phase, InterviewPhase.paused);
    expect(notifier.state.preparationSecondsRemaining, 14);
    notifier.resume();
    notifier.tickTimer();
    expect(notifier.state.preparationSecondsRemaining, 13);
    expect(notifier.state.timerSeconds, 120);
    final old = draft.toMap()..remove('preparationSecondsRemaining');
    (old['input'] as Map)
      ..remove('preparationSeconds')
      ..remove('cameraEnabled');
    expect(InterviewDraft.fromMap(old).preparationSecondsRemaining, 0);
    expect(InterviewDraft.fromMap(old).input.cameraEnabled, isTrue);
  });
}
