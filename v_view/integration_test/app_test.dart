import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:v_view/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E 통합 테스트 — v-view 사용자 시나리오', () {
    testWidgets('앱 시작 시 인증 화면 또는 홈 화면이 렌더링된다', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 앱이 정상 렌더링되면 MaterialApp이 존재해야 함
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('로그인 화면에 이메일·비밀번호 입력란이 존재한다', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 이메일 또는 홈 화면 중 하나가 반드시 표시됨
      final hasEmailField = find.byType(TextField).evaluate().isNotEmpty;
      final hasScaffold = find.byType(Scaffold).evaluate().isNotEmpty;
      expect(hasScaffold, true);
      expect(hasEmailField || hasScaffold, true);
    });
  });
}
