import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/interview/interview_provider.dart';

const input = SessionInput(
  type: InterviewType.job,
  position: '개발',
  company: '가상 회사',
  selfIntroduction: '연습',
);

class _Api extends Fake implements ClaudeApiService {
  int calls = 0;
  bool ask = true;
  bool repeat = false;
  final contexts = <List<QuestionAnswer>>[];
  @override
  Future<List<InterviewQuestion>> generateQuestions(
    SessionInput input,
  ) async => const [
    InterviewQuestion(id: 'q1', text: '프로젝트에서 맡은 역할은 무엇인가요?', intent: '기여 확인'),
    InterviewQuestion(id: 'q2', text: '지원 동기는 무엇인가요?', intent: '동기 확인'),
  ];
  @override
  Future<InterviewQuestion?> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
    List<QuestionAnswer> conversation = const [],
  }) async {
    calls++;
    contexts.add(conversation);
    return ask
        ? InterviewQuestion(
            id: 'fu$calls',
            text: repeat ? '어떤 결과를 확인했나요?' : '확인이 필요한 항목 $calls 는 무엇인가요?',
            intent: '추가 확인',
            isFollowUp: true,
            parentQuestionId: question.id,
          )
        : null;
  }
}

void main() {
  test('횟수 제한 대신 답변별 판단으로 세 번째 이후 추가 질문도 허용한다', () async {
    final api = _Api();
    final notifier = InterviewNotifier(api);
    addTearDown(notifier.dispose);
    await notifier.start(input);
    for (var i = 0; i < 4; i++) {
      await notifier.nextQuestion('아직 확인이 필요한 답변 $i');
    }
    expect(api.calls, 4);
    expect(notifier.state.currentQuestion!.id, 'fu4');
    expect(api.contexts.last.length, 4);
    expect(api.contexts.last.first.userAnswer, '아직 확인이 필요한 답변 0');
  });
  test('충분하다고 판단되면 기본 질문으로 이동하고 공백에는 추가 요청을 하지 않는다', () async {
    final api = _Api()..ask = false;
    final notifier = InterviewNotifier(api);
    addTearDown(notifier.dispose);
    await notifier.start(input);
    await notifier.nextQuestion('짧지만 질문에 충분히 답했습니다.');
    expect(notifier.state.currentQuestion!.id, 'q2');
    await notifier.nextQuestion('   ');
    expect(api.calls, 1);
    expect(notifier.state.phase, InterviewPhase.finished);
  });
  test('동일한 추가 질문을 다시 삽입하지 않는다', () async {
    final api = _Api()..repeat = true;
    final notifier = InterviewNotifier(api);
    addTearDown(notifier.dispose);
    await notifier.start(input);
    await notifier.nextQuestion('결과를 더 설명할 수 있습니다.');
    await notifier.nextQuestion('이미 이 질문에 답했습니다.');
    expect(notifier.state.currentQuestion!.id, 'q2');
    expect(notifier.state.questions.where((q) => q.isFollowUp), hasLength(1));
  });
  test('사용자가 추가 질문을 건너뛰면 AI 요청 없이 다음 기본 질문으로 이동한다', () async {
    final api = _Api();
    final notifier = InterviewNotifier(api);
    addTearDown(notifier.dispose);
    await notifier.start(input);
    await notifier.nextQuestion('기여를 설명했습니다.');
    await notifier.nextBaseQuestion('이 답변까지 기록하고 넘어갑니다.');
    expect(api.calls, 1);
    expect(notifier.state.currentQuestion!.id, 'q2');
    expect(notifier.state.userAnswers['fu1'], '이 답변까지 기록하고 넘어갑니다.');
  });
}
