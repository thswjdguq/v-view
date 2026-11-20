import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/ui/interview/widgets/interview_camera_panel.dart';

void main() {
  testWidgets('카메라 미리보기는 요청했을 때만 생성되고 다시 숨길 수 있다', (tester) async {
    var previewBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InterviewCameraPanel(
            previewBuilder: (_) {
              previewBuilds++;
              return const ColoredBox(
                color: Colors.green,
                child: Text('미리보기 영상'),
              );
            },
          ),
        ),
      ),
    );
    expect(previewBuilds, 0);
    await tester.tap(find.byTooltip('카메라 미리보기 보기'));
    await tester.pumpAndSettle();
    expect(find.text('미리보기 영상'), findsOneWidget);
    await tester.tap(find.byTooltip('카메라 미리보기 숨기기'));
    await tester.pumpAndSettle();
    expect(find.text('미리보기 영상'), findsNothing);
  });

  testWidgets('작은 화면과 큰 글자에서도 미리보기 버튼을 사용할 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: InterviewCameraPanel(previewBuilder: (_) => const SizedBox()),
        ),
      ),
    );
    await tester.tap(find.byTooltip('카메라 미리보기 보기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('카메라 미리보기 숨기기').hitTestable(), findsOneWidget);
  });
}
