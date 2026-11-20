import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/ui/history/widgets/delete_record_dialog.dart';

Future<void> openDialog(
  WidgetTester tester,
  Future<void> Function() remove, {
  bool largeText = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(largeText ? 1.8 : 1)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showRecordDeletionDialog(
              context,
              title: '기록 삭제',
              description: '질문·답변과 리포트를 함께 삭제해요.',
              onDelete: remove,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('삭제가 끝날 때까지 버튼을 잠그고 완료 후 닫는다', (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await openDialog(tester, () {
      calls++;
      return pending.future;
    });
    await tester.tap(find.text('삭제'));
    await tester.pump();
    expect(find.text('삭제 중...'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('실패 안내를 표시하고 재시도가 성공하면 닫는다', (tester) async {
    var calls = 0;
    await openDialog(tester, () async {
      if (++calls == 1) throw StateError('disk');
    });
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('삭제를 마치지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('좁은 화면과 큰 글자에서 삭제·취소를 사용할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openDialog(tester, () async {}, largeText: true);
    expect(find.text('삭제').hitTestable(), findsOneWidget);
    expect(find.text('취소').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });
}
