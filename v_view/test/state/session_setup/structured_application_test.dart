import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:v_view/data/local/session/session_input_local_datasource.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/session_setup/session_setup_provider.dart';

void main() {
  test('지원자 정보와 자소서 문항별 질문·답변이 서로 덮어쓰이지 않는다', () {
    final notifier = SessionInputNotifier(null);
    addTearDown(notifier.dispose);
    notifier.setPosition('앱 개발자');
    notifier.setCompany('가상 회사');
    notifier.setAge('26');
    notifier.setEducation('컴퓨터공학 졸업 예정');
    notifier.setCertifications('정보처리기사');
    notifier.setEssayQuestion(0, '문제를 해결한 경험은 무엇인가요?');
    notifier.setEssayAnswer(0, '중복 제출을 재현하고 수정했습니다.');
    notifier.setEssayAnswer(1, '역할을 나눠 협업했습니다.');
    expect(notifier.isValid, isTrue);
    expect(notifier.state.essayAt(0).question, '문제를 해결한 경험은 무엇인가요?');
    expect(notifier.state.essayAt(0).answer, '중복 제출을 재현하고 수정했습니다.');
    expect(notifier.state.essayAt(1).answer, '역할을 나눠 협업했습니다.');
    expect(notifier.state.age, '26');
    expect(notifier.state.applicationContext.containsKey('name'), isFalse);
  });
  test('나이·학력·자격증 없이도 이력서 요약으로 시작할 수 있다', () {
    final notifier = SessionInputNotifier(null);
    addTearDown(notifier.dispose);
    notifier.setPosition('개발자');
    notifier.setCompany('가상 회사');
    expect(notifier.isValid, isFalse);
    notifier.setResumeSummary('Flutter 프로젝트의 화면과 상태 관리를 맡았습니다.');
    expect(notifier.isValid, isTrue);
    expect(notifier.state.age, isEmpty);
  });
  test('새 입력은 저장·재개방해도 문항·프로필·진행 옵션이 유지되고 기존 형식도 읽는다', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vview_application_',
    );
    Hive.init(directory.path);
    await Hive.openBox<Map>('session_input');
    try {
      final value = SessionInput(
        type: InterviewType.job,
        position: '개발',
        company: '가상 회사',
        age: '26',
        education: '학사',
        school: '충남대학교',
        certifications: '정보처리기사',
        certificates: const ['정보처리기사', '직접 입력 자격, 2급'],
        resumeSummary: '프로젝트 경험',
        essays: const [
          ApplicationEssay(question: '지원 동기는?', answer: '사용자 경험을 개선하고 싶습니다.'),
        ],
        questionCount: 5,
        timerMinutes: 3,
        preparationSeconds: 30,
        cameraEnabled: false,
      );
      final store = SessionInputLocalDatasource();
      await store.save(value);
      await Hive.close();
      await Hive.openBox<Map>('session_input');
      final restored = store.load()!;
      expect(restored.essayAt(0).answer, '사용자 경험을 개선하고 싶습니다.');
      expect(restored.certifications, '정보처리기사');
      expect(restored.timerMinutes, 3);
      expect(restored.questionCount, 5);
      expect(restored.school, '충남대학교');
      expect(restored.certificationNames, ['정보처리기사', '직접 입력 자격, 2급']);
      expect(restored.preparationSeconds, 30);
      expect(restored.cameraEnabled, isFalse);
      await Hive.box<Map>('session_input').put('last_input', {
        'type': 0,
        'position': '개발',
        'company': '회사',
        'selfIntroduction': '이전 소개',
      });
      expect(store.load()!.selfIntroduction, '이전 소개');
      expect(store.load()!.questionCount, 3);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
}
