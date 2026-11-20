import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/local/session/profile_catalog_datasource.dart';
import 'package:v_view/domain/session_setup/profile_catalog.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('정보 검색은 기사·산업기사·기능사를 구분하고 띄어쓰기와 약칭을 허용한다', () async {
    final entries = await ProfileCatalogDatasource().load(
      ProfileCatalogType.certification,
    );
    final result = searchProfileCatalog(entries, '정보');
    expect(
      result.map((e) => e.name),
      containsAll(['정보처리기사', '정보처리산업기사', '정보처리기능사']),
    );
    expect(result.take(3).map((e) => e.name), [
      '정보처리기사',
      '정보처리산업기사',
      '정보처리기능사',
    ]);
    expect(searchProfileCatalog(entries, '정보 처리 기사').first.name, '정보처리기사');
    expect(searchProfileCatalog(entries, '정처기').first.name, '정보처리기사');
  });
  test('대학·전문대학은 학교명·지역·약칭으로 검색된다', () async {
    final entries = await ProfileCatalogDatasource().load(
      ProfileCatalogType.school,
    );
    expect(
      searchProfileCatalog(entries, '서울대').map((e) => e.name),
      contains('서울대학교'),
    );
    expect(
      searchProfileCatalog(entries, '충남').map((e) => e.name),
      contains('충남대학교'),
    );
    expect(entries.any((e) => e.detail.contains('전문대학')), isTrue);
  });
  test('여러 자격증을 중복 없이 선택·삭제하고 이전 문자열도 유지한다', () {
    final notifier = SessionInputNotifier(
      const SessionInput(
        type: InterviewType.job,
        position: '개발',
        company: '회사',
        certifications: '정보처리기사, SQLD\n정보처리기사',
      ),
    );
    addTearDown(notifier.dispose);
    expect(notifier.state.certificationNames, ['정보처리기사', 'SQLD']);
    notifier.setCertificationNames([
      '정보처리기사',
      '정보 처리 기사',
      '정보처리산업기사',
      '직접 입력한 자격',
    ]);
    notifier.setSchool('충남대학교');
    final restored = SessionInput.fromMap(notifier.state.toMap());
    expect(restored.certificationNames, ['정보처리기사', '정보처리산업기사', '직접 입력한 자격']);
    expect(restored.school, '충남대학교');
    expect(restored.applicationContext['profile']['school'], '충남대학교');
    expect(
      restored.applicationContext['profile']['certifications'],
      contains('직접 입력한 자격'),
    );
    notifier.setCertificationNames(
      restored.certificationNames.where((v) => v != '정보처리기사').toList(),
    );
    expect(notifier.state.certificationNames, ['정보처리산업기사', '직접 입력한 자격']);
  });
}
