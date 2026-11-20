import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/interview/interview_provider.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';
import 'package:v_view/ui/questions/question_list_screen.dart';
import 'package:v_view/state/app_mode_provider.dart';

class _RetryApi extends Fake implements ClaudeApiService {
  int requests = 0;

  @override
  Future<List<InterviewQuestion>> generateQuestions(SessionInput input) async {
    if (++requests == 1) throw Exception('연결 끊김');
    return [
      const InterviewQuestion(id: 'q1', text: '다시 생성한 질문', intent: '경험'),
      const InterviewQuestion(id: 'q2', text: '아직 공개하지 않을 질문', intent: '협업'),
    ];
  }

  @override
  Future<InterviewQuestion?> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
    List<QuestionAnswer> conversation = const [],
  }) async => null;
}

void main() {
  testWidgets('질문 생성 실패를 표시하고 같은 입력으로 다시 시도할 수 있다', (tester) async {
    final api = _RetryApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isDemoModeProvider.overrideWithValue(true),
          claudeApiServiceProvider.overrideWithValue(api),
          sessionInputProvider.overrideWith(
            (_) => SessionInputNotifier(
              const SessionInput(
                type: InterviewType.job,
                position: '개발자',
                company: '회사',
                selfIntroduction: '소개',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: QuestionListScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('질문 생성에 실패'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('다시 생성한 질문'), findsOneWidget);
    expect(find.text('아직 공개하지 않을 질문'), findsNothing);
    expect(find.text('전체 면접 시작하기'), findsNothing);
    await tester.enterText(find.byType(TextField), '내 역할을 설명한 답변');
    await tester.tap(find.text('다음 질문'));
    await tester.pumpAndSettle();
    expect(find.text('다시 생성한 질문'), findsNothing);
    expect(find.text('아직 공개하지 않을 질문'), findsOneWidget);
    expect(api.requests, 2);
    await tester.pumpWidget(const SizedBox());
  });
}
