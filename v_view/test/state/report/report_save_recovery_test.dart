import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/history/session_history.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/report/report_provider.dart';

const _answers = [
  QuestionAnswer(
    question: InterviewQuestion(
      id: 'q1',
      text: '해결한 문제는 무엇인가요?',
      intent: '경험 확인',
    ),
    userAnswer: '중복 제출 오류를 재현하고 수정했습니다.',
    answerDurationSeconds: 27,
  ),
];
const _feedback = [
  ImprovementPoint(
    title: '검증 결과 설명',
    description: '재현 조건과 확인한 결과를 덧붙여 보세요.',
    evidenceMetric: '첫 번째 답변',
  ),
];

class _Api extends Fake implements ClaudeApiService {
  _Api({this.queued = false});
  final bool queued;
  int calls = 0;
  final requests = <Completer<List<ImprovementPoint>>>[];
  @override
  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) {
    calls++;
    if (!queued) return Future.value(_feedback);
    final request = Completer<List<ImprovementPoint>>();
    requests.add(request);
    return request.future;
  }
}

class _Reports extends ReportLocalDatasource {
  int calls = 0;
  final failAt = <int>{};
  final gates = <int, Completer<void>>{};
  @override
  Future<void> save(SessionReport report) async {
    final call = ++calls;
    await gates[call]?.future;
    if (failAt.contains(call)) throw const FileSystemException('disk full');
    await super.save(report);
  }
}

class _History extends HistoryLocalDatasource {
  int calls = 0;
  final failAt = <int>{};
  @override
  Future<void> save(SessionHistoryItem item) async {
    final call = ++calls;
    if (failAt.contains(call)) throw const FileSystemException('disk full');
    await super.save(item);
  }
}

Future<void> _generate(
  ReportNotifier notifier, {
  int seconds = 31,
  List<QuestionAnswer> answers = _answers,
}) => notifier.generate(
  interviewType: InterviewType.job,
  position: '앱 개발자',
  company: '가상 회사',
  qaList: answers,
  gazeMetrics: GazeMetrics.empty,
  totalDurationSeconds: seconds,
);

void main() {
  late Directory directory;
  late _Api api;
  late _Reports reports;
  late _History history;
  ReportNotifier makeNotifier() {
    final notifier = ReportNotifier(api, reports, history);
    addTearDown(() {
      if (notifier.mounted) notifier.dispose();
    });
    return notifier;
  }

  Future<void> openBoxes() async {
    Hive.init(directory.path);
    await Hive.openBox<Map>('history');
    await Hive.openBox<Map>('reports');
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vview_report_recovery_');
    await openBoxes();
    api = _Api();
    reports = _Reports();
    history = _History();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('상세 저장 실패 후 같은 ID·답변·AI 피드백으로 저장하고 재열람한다', () async {
    reports.failAt.add(1);
    final notifier = makeNotifier();
    await _generate(notifier);
    expect(notifier.state.phase, ReportPhase.error);
    final original = notifier.state.report!;
    expect(original.qaList.single.userAnswer, _answers.single.userAnswer);
    expect(original.isAiFeedbackAvailable, isTrue);
    await notifier.retrySave();
    expect(api.calls, 1);
    expect(notifier.state.phase, ReportPhase.done);
    expect(notifier.state.report!.id, original.id);
    expect(history.loadAll(), hasLength(1));
    await Hive.close();
    await openBoxes();
    final saved = reports.load(original.id)!;
    expect(saved.createdAt, original.createdAt);
    expect(saved.qaList.single.answerDurationSeconds, 27);
    expect(saved.improvementPoints.single.title, _feedback.single.title);
    expect(history.loadAll().single.position, '앱 개발자');
    expect(history.loadAll().single.company, '가상 회사');
  });

  test('상세만 저장된 부분 실패는 재시도로 요약을 복구하고 고아·중복을 만들지 않는다', () async {
    history.failAt.add(1);
    final notifier = makeNotifier();
    await _generate(notifier);
    final id = notifier.state.report!.id;
    expect(reports.storedIds, [id]);
    expect(history.storedIds, isEmpty);
    await notifier.retrySave();
    await notifier.retrySave();
    expect(api.calls, 1);
    expect(reports.calls, 2);
    expect(reports.storedIds, [id]);
    expect(history.storedIds, [id]);
  });

  test('재시도 진행 중의 중복 요청과 완료 뒤 재시도는 추가 쓰기를 하지 않는다', () async {
    reports.failAt.add(1);
    reports.gates[2] = Completer<void>();
    final notifier = makeNotifier();
    await _generate(notifier);
    final retry = notifier.retrySave();
    await notifier.retrySave();
    expect(notifier.state.phase, ReportPhase.saving);
    expect(reports.calls, 2);
    expect(history.calls, 0);
    reports.gates[2]!.complete();
    await retry;
    await notifier.retrySave();
    expect(reports.calls, 2);
    expect(api.calls, 1);
    expect(notifier.state.phase, ReportPhase.done);
  });

  test('새 세션 시작 뒤 도착한 이전 AI 응답은 저장하거나 새 오류를 덮어쓰지 않는다', () async {
    api = _Api(queued: true);
    reports.failAt.add(1);
    final notifier = makeNotifier();
    final old = _generate(notifier);
    final current = _generate(notifier, seconds: 99);
    api.requests[1].complete(_feedback);
    await current;
    final id = notifier.state.report!.id;
    api.requests[0].complete(_feedback);
    await old;
    expect(reports.calls, 1);
    expect(notifier.state.report!.id, id);
    await notifier.retrySave();
    expect(history.loadAll().single.totalDurationSeconds, 99);
    expect(reports.storedIds, [id]);
    expect(api.calls, 2);
  });

  test('이전 저장 완료가 새 세션의 저장 실패 내용과 재시도 대상을 바꾸지 않는다', () async {
    reports.gates[1] = Completer<void>();
    reports.failAt.add(2);
    final notifier = makeNotifier();
    final old = _generate(notifier);
    await Future<void>.delayed(Duration.zero);
    final oldId = notifier.state.report!.id;
    await _generate(notifier, seconds: 99);
    final currentId = notifier.state.report!.id;
    reports.gates[1]!.complete();
    await old;
    expect(notifier.state.phase, ReportPhase.error);
    expect(notifier.state.report!.id, currentId);
    await notifier.retrySave();
    expect(notifier.state.report!.id, currentId);
    expect(reports.storedIds.toSet(), {oldId, currentId});
    expect(history.storedIds.toSet(), {oldId, currentId});
    expect(api.calls, 2);
  });

  test('대기 중 입력 목록이 변경돼도 시작 시점의 답변을 저장한다', () async {
    api = _Api(queued: true);
    final notifier = makeNotifier();
    final answers = _answers.toList();
    final pending = _generate(notifier, answers: answers);
    answers.clear();
    api.requests.single.complete(_feedback);
    await pending;
    expect(
      notifier.state.report!.qaList.single.userAnswer,
      _answers.single.userAnswer,
    );
    expect(notifier.state.report!.totalQuestions, 1);
  });

  test('처리 객체를 닫은 뒤 도착한 AI 응답은 디스크에 쓰지 않는다', () async {
    api = _Api(queued: true);
    final notifier = makeNotifier();
    final pending = _generate(notifier);
    notifier.dispose();
    api.requests.single.complete(_feedback);
    await pending;
    expect(reports.calls, 0);
    expect(history.calls, 0);
  });
}
