import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_view/demo/demo_app.dart';
import 'package:v_view/state/interview/interview_provider.dart';
import 'package:v_view/ui/interview/interview_screen.dart';

Future<void> startDemo(WidgetTester tester) async {
  await tester.pumpWidget(const DemoApp());
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('샘플 질문으로 연습하기'),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('샘플 질문으로 연습하기'));
  await tester.pumpAndSettle();
  expect(find.byType(InterviewScreen), findsOneWidget);
  expect(find.text('전체 면접 시작하기'), findsNothing);
}

void main() {
  testWidgets('샘플 답변을 채운 뒤 사용자가 수정할 수 있다', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await startDemo(tester);
    await tester.tap(find.text('샘플 답변 넣기'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, contains('가상'));
    expect(field.controller!.text.length, greaterThan(80));
    await tester.enterText(find.byType(TextField), '직접 수정한 답변');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '직접 수정한 답변',
    );
  });
  testWidgets('이미 쓴 답변을 샘플로 덮어쓰지 않는다', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await startDemo(tester);
    await tester.enterText(find.byType(TextField), '직접 작성한 내용');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '샘플 답변 넣기'))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '직접 작성한 내용',
    );
  });
  testWidgets('다음 질문에서 새 샘플을 제공하고 이전 답변을 보존한다', (tester) async {
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await startDemo(tester);
    await tester.tap(find.text('샘플 답변 넣기'));
    await tester.pump();
    final first = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    await tester.tap(find.text('다음 질문'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.tap(find.text('샘플 답변 넣기'));
    await tester.pump();
    final second = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    expect(second, isNot(first));
    expect(second, contains('기술'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InterviewScreen)),
    );
    expect(
      container.read(interviewProvider).userAnswers.values,
      contains(first),
    );
  });

  testWidgets('작은 휴대폰과 큰 글자에서도 질문·답변·제출을 사용할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await startDemo(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('샘플 답변 넣기').hitTestable(), findsOneWidget);
    expect(find.text('다음 질문').hitTestable(), findsOneWidget);
  });

  testWidgets('큰 글자와 화면 키보드가 함께 있어도 답변과 제출 버튼에 접근한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await startDemo(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '키보드로 작성한 답변');
    await tester.ensureVisible(find.text('다음 질문'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '키보드로 작성한 답변',
    );
    expect(find.text('다음 질문').hitTestable(), findsOneWidget);
  });
}
