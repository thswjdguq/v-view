import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/interview/interview_provider.dart';

// Fake API — 네트워크 없이 결정론적 응답 반환
class _FakeApiService extends Fake implements ClaudeApiService {
  @override
  Future<List<InterviewQuestion>> generateQuestions(SessionInput input) async => [
        const InterviewQuestion(id: 'q1', text: '자기소개를 해주세요.', intent: '기본 소개'),
        const InterviewQuestion(id: 'q2', text: '지원 동기를 말씀해주세요.', intent: '직무 이해'),
      ];

  @override
  Future<InterviewQuestion> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
  }) async =>
      const InterviewQuestion(
        id: 'fu1',
        text: '더 구체적으로 설명해주세요.',
        intent: '심층 확인',
        isFollowUp: true,
      );

  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) async =>
      [];
}

ProviderContainer makeContainer() => ProviderContainer(
      overrides: [
        claudeApiServiceProvider.overrideWithValue(_FakeApiService()),
      ],
    );

const _testInput = SessionInput(
  type: InterviewType.job,
  position: '백엔드 개발자',
  company: '카카오',
  selfIntroduction: '저는 3년차 개발자입니다.',
);

void main() {
  group('InterviewState 헬퍼 속성', () {
    test('questions 비어있으면 currentQuestion은 null', () {
      const state = InterviewState();
      expect(state.currentQuestion, isNull);
    });

    test('currentQuestion은 currentIndex 위치 질문 반환', () {
      const q1 = InterviewQuestion(id: 'q1', text: 'Q1', intent: 'i1');
      const q2 = InterviewQuestion(id: 'q2', text: 'Q2', intent: 'i2');
      const state = InterviewState(questions: [q1, q2], currentIndex: 1);
      expect(state.currentQuestion?.id, 'q2');
    });

    test('isLastQuestion — 단일 질문 인덱스 0에서 true', () {
      const q = InterviewQuestion(id: 'q1', text: 'Q1', intent: 'i1');
      const state = InterviewState(questions: [q], currentIndex: 0);
      expect(state.isLastQuestion, true);
    });

    test('isLastQuestion — 마지막이 아닐 때 false', () {
      const q1 = InterviewQuestion(id: 'q1', text: 'Q1', intent: 'i1');
      const q2 = InterviewQuestion(id: 'q2', text: 'Q2', intent: 'i2');
      const state = InterviewState(questions: [q1, q2], currentIndex: 0);
      expect(state.isLastQuestion, false);
    });

    test('copyWith — 변경 필드만 갱신, 나머지 유지', () {
      const original = InterviewState(timerSeconds: 90, elapsedSeconds: 30);
      final updated = original.copyWith(timerSeconds: 89);
      expect(updated.timerSeconds, 89);
      expect(updated.elapsedSeconds, 30);
    });
  });

  group('InterviewNotifier — 초기 상태', () {
    test('초기 phase는 idle', () {
      final c = makeContainer();
      expect(c.read(interviewProvider).phase, InterviewPhase.idle);
    });

    test('초기 timerSeconds는 120', () {
      final c = makeContainer();
      expect(c.read(interviewProvider).timerSeconds, 120);
    });

    test('초기 elapsedSeconds는 0', () {
      final c = makeContainer();
      expect(c.read(interviewProvider).elapsedSeconds, 0);
    });

    test('초기 questions는 비어있다', () {
      final c = makeContainer();
      expect(c.read(interviewProvider).questions, isEmpty);
    });
  });

  group('InterviewNotifier — 상태 전환', () {
    test('pause()는 phase를 paused로 변경', () {
      final c = makeContainer();
      c.read(interviewProvider.notifier).pause();
      expect(c.read(interviewProvider).phase, InterviewPhase.paused);
    });

    test('pause() 후 resume()은 phase를 inProgress로 복원', () {
      final c = makeContainer();
      c.read(interviewProvider.notifier).pause();
      c.read(interviewProvider.notifier).resume();
      expect(c.read(interviewProvider).phase, InterviewPhase.inProgress);
    });

    test('finish()는 phase를 finished로 변경', () {
      final c = makeContainer();
      c.read(interviewProvider.notifier).finish();
      expect(c.read(interviewProvider).phase, InterviewPhase.finished);
    });
  });

  group('InterviewNotifier — 타이머', () {
    test('resetTimer는 timerSeconds를 지정값으로 설정', () {
      final c = makeContainer();
      c.read(interviewProvider.notifier).resetTimer(60);
      expect(c.read(interviewProvider).timerSeconds, 60);
    });

    test('tickTimer — timerSeconds 1 감소, elapsedSeconds 1 증가', () {
      final c = makeContainer();
      c.read(interviewProvider.notifier).resetTimer(30);
      c.read(interviewProvider.notifier).tickTimer();
      final state = c.read(interviewProvider);
      expect(state.timerSeconds, 29);
      expect(state.elapsedSeconds, 1);
    });

    test('tickTimer 3회 연속 — 누적 3초 경과', () {
      final c = makeContainer();
      c.read(interviewProvider.notifier).resetTimer(100);
      final n = c.read(interviewProvider.notifier);
      n.tickTimer();
      n.tickTimer();
      n.tickTimer();
      final state = c.read(interviewProvider);
      expect(state.timerSeconds, 97);
      expect(state.elapsedSeconds, 3);
    });
  });

  group('InterviewNotifier — API 연동 (Fake)', () {
    test('start() 후 phase가 inProgress, 질문 2개 로드', () async {
      final c = makeContainer();
      await c.read(interviewProvider.notifier).start(_testInput);
      final state = c.read(interviewProvider);
      expect(state.phase, InterviewPhase.inProgress);
      expect(state.questions.length, 2);
      expect(state.currentIndex, 0);
    });

    test('start() 후 첫 질문 id는 q1', () async {
      final c = makeContainer();
      await c.read(interviewProvider.notifier).start(_testInput);
      expect(c.read(interviewProvider).currentQuestion?.id, 'q1');
    });

    test('submitAnswer()는 currentQuestion의 답변을 userAnswers에 저장', () async {
      final c = makeContainer();
      await c.read(interviewProvider.notifier).start(_testInput);
      final qId = c.read(interviewProvider).currentQuestion!.id;
      c.read(interviewProvider.notifier).submitAnswer('저의 답변입니다.');
      expect(c.read(interviewProvider).userAnswers[qId], '저의 답변입니다.');
    });

    test('nextQuestion(비어있지않은답변) — 꼬리 질문 삽입 후 isFollowUp=true', () async {
      final c = makeContainer();
      await c.read(interviewProvider.notifier).start(_testInput);
      await c.read(interviewProvider.notifier).nextQuestion('내 답변');
      final state = c.read(interviewProvider);
      expect(state.questions.length, 3); // q1 + fu1 + q2
      expect(state.currentQuestion?.isFollowUp, true);
    });

    test('nextQuestion(빈답변) — 꼬리 질문 없이 다음 질문으로 이동', () async {
      final c = makeContainer();
      await c.read(interviewProvider.notifier).start(_testInput);
      await c.read(interviewProvider.notifier).nextQuestion('');
      final state = c.read(interviewProvider);
      expect(state.questions.length, 2); // 꼬리 질문 미삽입
      expect(state.currentIndex, 1);
    });
  });
}
