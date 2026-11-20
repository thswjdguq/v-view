import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/interview/interview_provider.dart';

const _input = SessionInput(
  type: InterviewType.job,
  position: '개발자',
  company: '연습 회사',
  selfIntroduction: '프로젝트 경험을 소개합니다.',
);

class _ControlledApi extends Fake implements ClaudeApiService {
  final pending = <Completer<InterviewQuestion?>>[];

  @override
  Future<List<InterviewQuestion>> generateQuestions(SessionInput input) async =>
      [
        const InterviewQuestion(id: 'q1', text: '경험을 소개해주세요.', intent: '경험'),
        const InterviewQuestion(id: 'q2', text: '지원 동기는 무엇인가요?', intent: '동기'),
      ];

  @override
  Future<InterviewQuestion?> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
    List<QuestionAnswer> conversation = const [],
  }) {
    final completer = Completer<InterviewQuestion?>();
    pending.add(completer);
    return completer.future;
  }

  void completeFollowUps() {
    for (var i = 0; i < pending.length; i++) {
      if (!pending[i].isCompleted) {
        pending[i].complete(
          InterviewQuestion(
            id: 'follow-up-$i',
            text: '구체적인 사례를 말씀해주세요.',
            intent: '구체성',
            isFollowUp: true,
            parentQuestionId: 'q1',
          ),
        );
      }
    }
  }
}

void main() {
  late _ControlledApi api;
  late InterviewNotifier notifier;

  setUp(() async {
    api = _ControlledApi();
    notifier = InterviewNotifier(api);
    await notifier.start(_input);
  });

  tearDown(() => notifier.dispose());

  test('중복 제출은 답변을 덮어쓰거나 질문을 두 번 진행하지 않는다', () async {
    final first = notifier.nextQuestion('먼저 제출한 답변');
    final duplicate = notifier.nextQuestion('중복으로 제출한 답변');
    api.completeFollowUps();
    await Future.wait([first, duplicate]);

    expect(notifier.state.userAnswers['q1'], '먼저 제출한 답변');
    expect(notifier.state.questions.length, 3);
    expect(notifier.state.currentIndex, 1);
  });

  test('종료 후 도착한 꼬리질문은 면접을 다시 진행시키지 않는다', () async {
    final pending = notifier.nextQuestion('면접 답변');
    notifier.finish();
    api.completeFollowUps();
    await pending;

    expect(notifier.state.phase, InterviewPhase.finished);
    expect(notifier.state.questions.length, 2);
    expect(notifier.state.userAnswers['q1'], '면접 답변');
  });

  test('초기화 이전 요청의 응답은 새로운 세션 상태에 섞이지 않는다', () async {
    final pending = notifier.nextQuestion('이전 세션 답변');
    notifier.reset();
    api.completeFollowUps();
    await pending;

    expect(notifier.state.phase, InterviewPhase.idle);
    expect(notifier.state.questions, isEmpty);
    expect(notifier.state.userAnswers, isEmpty);
  });

  test('꼬리질문을 기다리다가 일시정지하면 응답 후에도 정지를 유지한다', () async {
    final pending = notifier.nextQuestion('면접 답변');
    notifier.pause();
    api.completeFollowUps();
    await pending;

    expect(notifier.state.phase, InterviewPhase.paused);
    expect(notifier.state.currentQuestion?.isFollowUp, isTrue);
  });

  test('타이머는 0초 아래로 내려가거나 경과 시간을 더하지 않는다', () {
    notifier.resetTimer(0);
    notifier.tickTimer();

    expect(notifier.state.timerSeconds, 0);
    expect(notifier.state.elapsedSeconds, 0);
  });

  test('질문별 답변 시간은 다음 질문으로 넘어가도 각각 유지된다', () async {
    notifier.tickTimer();
    notifier.tickTimer();
    await notifier.nextQuestion('');
    notifier.resetTimer(60);
    notifier.tickTimer();
    notifier.tickTimer();
    notifier.tickTimer();

    expect(notifier.state.answerDurations, {'q1': 2, 'q2': 3});
    expect(notifier.state.elapsedSeconds, 5);
    notifier.reset();
    expect(notifier.state.answerDurations, isEmpty);
  });
}
