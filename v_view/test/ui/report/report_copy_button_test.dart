import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/demo/demo_fixtures.dart';
import 'package:v_view/ui/report/widgets/report_copy_button.dart';

void main() {
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            ReportCopyButton(report: demoReport(previous: false), isDemo: true),
          ],
        ),
      ),
    ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  testWidgets('복사한 내용에 답변·근거·데모 표시가 포함된다', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await mount(tester);
    await tester.tap(find.byTooltip('답변 포함 리포트 복사'));
    await tester.pumpAndSettle();
    expect(copied, contains('DEMO'));
    expect(
      copied,
      contains(demoReport(previous: false).qaList.first.userAnswer),
    );
    expect(copied, contains('근거:'));
    expect(find.text('질문·답변과 피드백을 복사했어요.'), findsOneWidget);
  });
  testWidgets('복사 대기 중 중복 요청을 막는다', (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          calls++;
          await gate.future;
        }
        return null;
      },
    );
    await mount(tester);
    await tester.tap(find.byTooltip('답변 포함 리포트 복사'));
    await tester.pump();
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('클립보드 오류 뒤 다시 복사할 수 있다', (tester) async {
    var fails = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData' && fails) {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      },
    );
    await mount(tester);
    await tester.tap(find.byTooltip('답변 포함 리포트 복사'));
    await tester.pumpAndSettle();
    expect(find.text('복사하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    fails = false;
    await tester.tap(find.byTooltip('답변 포함 리포트 복사'));
    await tester.pumpAndSettle();
    expect(find.text('질문·답변과 피드백을 복사했어요.'), findsOneWidget);
  });
}
