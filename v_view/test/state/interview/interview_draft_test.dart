import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:v_view/data/local/interview_draft_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/interview/interview_provider.dart';

class _Api extends Fake implements ClaudeApiService {
  int calls = 0;
  @override
  Future<List<InterviewQuestion>> generateQuestions(SessionInput input) async {
    calls++;
    return const [
      InterviewQuestion(id: 'q1', text: '어떤 문제를 해결했나요?', intent: '경험 확인'),
    ];
  }
}

const input = SessionInput(
  type: InterviewType.job,
  position: '개발자',
  company: '가상 회사',
  selfIntroduction: '연습용 소개',
  education: '컴퓨터공학',
  essays: [ApplicationEssay(question: '지원 동기는?', answer: '앱의 사용성을 개선하고 싶습니다.')],
  questionCount: 1,
  timerMinutes: 3,
);
void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vview_draft_');
    Hive.init(directory.path);
    await Hive.openBox<Map>('sessions');
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('작성 중 답변·타이머·지원 정보를 저장하고 재실행 후 AI 호출 없이 복구한다', () async {
    final api = _Api();
    final store = InterviewDraftDatasource();
    final first = InterviewNotifier(api, draftStore: store);
    await first.start(input);
    first.submitAnswer('아직 작성 중인 답변');
    first.resetTimer(87);
    first.tickTimer();
    await first.flushDraft();
    first.dispose();
    await Hive.close();
    await Hive.openBox<Map>('sessions');
    final draft = store.load()!;
    expect(draft.input.timerMinutes, 3);
    expect(draft.input.education, '컴퓨터공학');
    expect(draft.input.essayAt(0).answer, '앱의 사용성을 개선하고 싶습니다.');
    final second = InterviewNotifier(api, draftStore: store);
    addTearDown(second.dispose);
    second.restoreDraft(draft);
    expect(second.state.phase, InterviewPhase.paused);
    expect(second.state.userAnswers['q1'], '아직 작성 중인 답변');
    expect(second.state.timerSeconds, 86);
    expect(second.state.elapsedSeconds, 1);
    expect(api.calls, 1);
  });
  test('완료된 세션의 임시 기록만 정리하며 새 세션 기록은 지우지 않는다', () async {
    final store = InterviewDraftDatasource();
    final notifier = InterviewNotifier(_Api(), draftStore: store);
    addTearDown(notifier.dispose);
    await notifier.start(input);
    await notifier.flushDraft();
    final old = notifier.state.sessionId!;
    notifier.reset();
    await notifier.start(input);
    notifier.submitAnswer('새 답변');
    await notifier.flushDraft();
    await notifier.completeDraft(old);
    expect(store.load()!.answers['q1'], '새 답변');
    await notifier.completeDraft(notifier.state.sessionId!);
    expect(store.load(), isNull);
  });
  test('임시 저장 실패는 답변을 지우지 않고 오류를 표시한다', () async {
    final notifier = InterviewNotifier(_Api(), draftStore: _BrokenStore());
    addTearDown(notifier.dispose);
    await notifier.start(input);
    notifier.submitAnswer('보호할 답변');
    await notifier.flushDraft();
    expect(notifier.state.userAnswers['q1'], '보호할 답변');
    expect(notifier.state.draftSaveError, isNotNull);
  });
  test('준비 중 저장·재개방하면 학교·여러 자격·카메라 선택과 남은 준비 시간을 복구한다', () async {
    final api = _Api();
    final store = InterviewDraftDatasource();
    final first = InterviewNotifier(api, draftStore: store);
    await first.start(
      input.copyWith(
        school: '충남대학교',
        certificates: ['정보처리기사', 'SQLD'],
        preparationSeconds: 15,
        cameraEnabled: false,
      ),
    );
    first.tickTimer();
    first.pause();
    await first.flushDraft();
    first.dispose();
    await Hive.close();
    await Hive.openBox<Map>('sessions');
    final saved = store.load()!;
    final second = InterviewNotifier(api, draftStore: store);
    addTearDown(second.dispose);
    second.restoreDraft(saved);
    expect(second.state.preparationSecondsRemaining, 14);
    expect(saved.input.school, '충남대학교');
    expect(saved.input.certificationNames, ['정보처리기사', 'SQLD']);
    expect(saved.input.cameraEnabled, isFalse);
    expect(api.calls, 1);
  });
  test('손상된 임시 기록은 앱 시작을 막지 않는다', () async {
    await Hive.box<Map>(
      'sessions',
    ).put('active_interview', {'version': 1, 'bad': 'data'});
    expect(InterviewDraftDatasource().load(), isNull);
  });
}

class _BrokenStore extends InterviewDraftDatasource {
  @override
  Future<void> save(dynamic draft) async =>
      throw const FileSystemException('disk full');
}
