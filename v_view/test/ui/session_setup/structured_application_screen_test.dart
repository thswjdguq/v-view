import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';
import 'package:v_view/ui/session_setup/session_setup_screen.dart';
import 'package:v_view/ui/session_setup/session_confirm_screen.dart';

void main() {
  testWidgets('작은 화면과 큰 글자에서도 모든 입력 구역과 확인 버튼에 접근한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionInputProvider.overrideWith((_) => SessionInputNotifier(null)),
        ],
        child: const MaterialApp(home: SessionSetupScreen()),
      ),
    );
    for (final label in ['학력 (선택)', '자소서 질문 1', '자소서 답변 2', '자소서 답변 3']) {
      await tester.ensureVisible(find.byKey(ValueKey(label)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text('설정 확인하기'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('설정 확인하기').hitTestable(), findsOneWidget);
  });
  testWidgets('이름 없이 지원자 정보와 문항 1·2·3을 편집하고 확인 화면에 전달한다', (tester) async {
    final notifier = SessionInputNotifier(
      const SessionInput(
        type: InterviewType.job,
        position: '앱 개발',
        company: '가상 회사',
        certifications: '정보처리기사',
      ),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionInputProvider.overrideWith((_) => notifier)],
        child: const MaterialApp(home: SessionSetupScreen()),
      ),
    );
    expect(find.byKey(const ValueKey('이름')), findsNothing);
    for (final entry in {
      '나이 (선택)': '26',
      '학력 (선택)': '컴퓨터공학 졸업 예정',
      '자소서 질문 1': '어떤 문제를 해결했나요?',
      '자소서 답변 1': '중복 저장을 재현하고 수정했습니다.',
      '자소서 답변 2': '팀원과 역할을 나눴습니다.',
    }.entries) {
      final field = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('자소서 질문 3')), findsOneWidget);
    expect(find.byKey(const ValueKey('자소서 답변 3')), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('설정 확인하기'));
    await tester.tap(find.text('설정 확인하기'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionConfirmScreen), findsOneWidget);
    expect(find.textContaining('어떤 문제를 해결했나요?'), findsOneWidget);
    expect(find.textContaining('팀원과 역할을 나눴습니다.'), findsOneWidget);
    expect(notifier.state.education, '컴퓨터공학 졸업 예정');
    expect(notifier.state.essayAt(2).answer, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('입력 내용 초기화'));
    await tester.tap(find.text('입력 내용 초기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초기화'));
    await tester.pumpAndSettle();
    expect(notifier.state.hasApplicationMaterial, isFalse);
    expect(notifier.state.age, isEmpty);
    final answer = find.byKey(const ValueKey('자소서 답변 1'));
    await tester.ensureVisible(answer);
    expect(tester.widget<TextFormField>(answer).initialValue, isEmpty);
    expect(find.text('중복 저장을 재현하고 수정했습니다.'), findsNothing);
  });
}
