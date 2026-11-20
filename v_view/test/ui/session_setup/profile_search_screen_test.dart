import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/domain/session_setup/profile_catalog.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/session_setup/profile_catalog_provider.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';
import 'package:v_view/ui/session_setup/widgets/profile_selection_field.dart';

const certificates = [
  ProfileCatalogEntry(name: '정보처리기사'),
  ProfileCatalogEntry(name: '정보처리산업기사'),
  ProfileCatalogEntry(name: 'SQL 개발자(SQLD)', aliases: ['SQLD']),
];
void main() {
  Future<SessionInputNotifier> open(
    WidgetTester tester, {
    bool failure = false,
    bool large = false,
  }) async {
    if (large) {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    final notifier = SessionInputNotifier(
      const SessionInput(
        type: InterviewType.job,
        position: '개발',
        company: '가상 회사',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionInputProvider.overrideWith((_) => notifier),
          profileCatalogProvider.overrideWith((ref, type) async {
            if (failure) throw const FormatException('fixture');
            return type == ProfileCatalogType.certification
                ? certificates
                : const [
                    ProfileCatalogEntry(
                      name: '충남대학교',
                      detail: '대전광역시 · 대학교',
                      aliases: ['충남대'],
                    ),
                  ];
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    ProfileSelectionField(type: ProfileCatalogType.school),
                    SizedBox(height: 20),
                    ProfileSelectionField(
                      type: ProfileCatalogType.certification,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('정보 검색에서 여러 종목을 선택하고 완료해야 칩과 실제 입력에 반영된다', (tester) async {
    final notifier = await open(tester);
    await tester.tap(find.byKey(const ValueKey('search-certifications')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-search-query')),
      '정보',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('정보처리기사'));
    await tester.pump();
    await tester.tap(find.text('정보처리산업기사'));
    await tester.pump();
    expect(notifier.state.certificationNames, isEmpty);
    await tester.tap(find.text('선택 완료 (2개)'));
    await tester.pumpAndSettle();
    expect(notifier.state.certificationNames, ['정보처리기사', '정보처리산업기사']);
    expect(find.byType(InputChip), findsNWidgets(2));
    await tester.tap(find.byTooltip('정보처리기사 삭제'));
    await tester.pumpAndSettle();
    expect(notifier.state.certificationNames, ['정보처리산업기사']);
    await tester.tap(find.byKey(const ValueKey('search-certifications')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-search-query')),
      '정보',
    );
    await tester.pump();
    await tester.tap(find.text('정보처리기사'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(notifier.state.certificationNames, ['정보처리산업기사']);
  });
  testWidgets('학교 검색 선택과 목록에 없는 학교 직접 추가를 모두 지원한다', (tester) async {
    final notifier = await open(tester);
    await tester.tap(find.byKey(const ValueKey('search-school')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-search-query')),
      '충남대',
    );
    await tester.pump();
    await tester.tap(find.text('충남대학교'));
    await tester.pumpAndSettle();
    expect(notifier.state.school, '충남대학교');
    await tester.tap(find.byKey(const ValueKey('search-school')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-search-query')),
      '가상외국대학교',
    );
    await tester.pump();
    await tester.tap(find.text('“가상외국대학교” 직접 추가'));
    await tester.pumpAndSettle();
    expect(notifier.state.school, '가상외국대학교');
  });
  testWidgets('목록 로딩 실패와 큰 글자·키보드에서도 직접 입력한 자격을 추가한다', (tester) async {
    final notifier = await open(tester, failure: true, large: true);
    await tester.tap(find.byKey(const ValueKey('search-certifications')));
    await tester.pumpAndSettle();
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-search-query')),
      '직접 입력 자격',
    );
    await tester.pumpAndSettle();
    expect(find.text('목록 다시 불러오기'), findsOneWidget);
    await tester.ensureVisible(find.text('“직접 입력 자격” 직접 추가'));
    await tester.tap(find.text('“직접 입력 자격” 직접 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택 완료 (1개)'));
    await tester.pumpAndSettle();
    expect(notifier.state.certificationNames, ['직접 입력 자격']);
    expect(tester.takeException(), isNull);
  });
}
