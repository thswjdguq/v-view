import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:v_view/data/local/history/history_local_datasource.dart';
import 'package:v_view/data/local/report/report_local_datasource.dart';
import 'package:v_view/data/local/record_deletion_datasource.dart';
import 'package:v_view/demo/demo_fixtures.dart';
import 'package:v_view/state/history/history_provider.dart';

class _ControlledReports extends ReportLocalDatasource {
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<void> deleteMany(Iterable<String> ids) async {
    await gate?.future;
    if (fail) throw const FileSystemException('disk error');
    await super.deleteMany(ids);
  }
}

class _ControlledHistory extends HistoryLocalDatasource {
  bool fail = true;
  @override
  Future<void> deleteMany(Iterable<String> ids) async {
    if (fail) throw const FileSystemException('disk error');
    await super.deleteMany(ids);
  }
}

void main() {
  late Directory directory;
  late HistoryNotifier notifier;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vview_delete_test_');
    Hive.init(directory.path);
    await Hive.openBox<Map>('history');
    await Hive.openBox<Map>('reports');
    await Hive.openBox('settings');
    await seedDemoData();
    notifier = HistoryNotifier(HistoryLocalDatasource());
  });
  tearDown(() async {
    notifier.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('한 기록을 삭제하면 목록과 상세 답변 모두 없어지고 다른 기록은 남는다', () async {
    await Future.sync(() => notifier.delete('demo-current'));
    expect(Hive.box<Map>('history').containsKey('demo-current'), isFalse);
    expect(Hive.box<Map>('reports').containsKey('demo-current'), isFalse);
    expect(ReportLocalDatasource().load('demo-previous'), isNotNull);
    expect(notifier.state.map((item) => item.id), ['demo-previous']);
  });

  test('전체 삭제는 목록에서 고아가 된 상세 리포트도 정리한다', () async {
    await Hive.box<Map>('history').delete('demo-previous');
    notifier.load();
    await Future.sync(notifier.deleteAll);
    expect(Hive.box<Map>('reports').isEmpty, isTrue);
    expect(Hive.box<Map>('history').isEmpty, isTrue);
    expect(notifier.state, isEmpty);
  });

  test('상세 저장소 쓰기가 끝나기 전에는 목록에서 삭제 성공을 표시하지 않는다', () async {
    final reports = _ControlledReports()..gate = Completer<void>();
    notifier.dispose();
    notifier = HistoryNotifier(
      HistoryLocalDatasource(),
      deletions: RecordDeletionDatasource(HistoryLocalDatasource(), reports),
    );
    final pending = notifier.delete('demo-current');
    expect(notifier.state, hasLength(2));
    reports.gate!.complete();
    await pending;
    expect(notifier.state, hasLength(1));
  });

  test('상세 삭제 실패 시 기록을 유지하고 다시 시도할 수 있다', () async {
    final reports = _ControlledReports()..fail = true;
    notifier.dispose();
    notifier = HistoryNotifier(
      HistoryLocalDatasource(),
      deletions: RecordDeletionDatasource(HistoryLocalDatasource(), reports),
    );
    await expectLater(
      notifier.delete('demo-current'),
      throwsA(isA<FileSystemException>()),
    );
    expect(notifier.state, hasLength(2));
    expect(ReportLocalDatasource().load('demo-current'), isNotNull);
    reports.fail = false;
    await notifier.delete('demo-current');
    expect(ReportLocalDatasource().load('demo-current'), isNull);
  });

  test('상세만 삭제되고 요약 삭제가 실패해도 재시도로 나머지를 정리한다', () async {
    final history = _ControlledHistory();
    notifier.dispose();
    notifier = HistoryNotifier(
      history,
      deletions: RecordDeletionDatasource(history, ReportLocalDatasource()),
    );
    await expectLater(
      notifier.delete('demo-current'),
      throwsA(isA<FileSystemException>()),
    );
    expect(ReportLocalDatasource().load('demo-current'), isNull);
    expect(Hive.box<Map>('history').containsKey('demo-current'), isTrue);
    history.fail = false;
    await notifier.delete('demo-current');
    expect(Hive.box<Map>('history').containsKey('demo-current'), isFalse);
  });

  test('전체 삭제를 시작한 뒤 새로 저장된 기록은 삭제 대상에 섞이지 않는다', () async {
    final reports = _ControlledReports()..gate = Completer<void>();
    final history = HistoryLocalDatasource();
    final deletion = RecordDeletionDatasource(history, reports);
    final pending = deletion.deleteAll();
    final newReport = Map.of(Hive.box<Map>('reports').get('demo-current')!)
      ..['id'] = 'new-record';
    final newHistory = Map.of(Hive.box<Map>('history').get('demo-current')!)
      ..['id'] = 'new-record';
    await Hive.box<Map>('reports').put('new-record', newReport);
    await Hive.box<Map>('history').put('new-record', newHistory);
    reports.gate!.complete();
    await pending;
    expect(history.loadAll().single.id, 'new-record');
    expect(ReportLocalDatasource().load('new-record'), isNotNull);
  });

  test('동시에 두 삭제 요청이 저장 작업을 겹쳐 쓰지 않는다', () async {
    final reports = _ControlledReports()..gate = Completer<void>();
    final deletion = RecordDeletionDatasource(
      HistoryLocalDatasource(),
      reports,
    );
    final first = deletion.delete('demo-current');
    await expectLater(deletion.deleteAll(), throwsStateError);
    reports.gate!.complete();
    await first;
    expect(ReportLocalDatasource().load('demo-previous'), isNotNull);
  });

  test('없는 기록 삭제는 안전하게 끝나며 저장소 재개방 후에도 삭제 상태를 유지한다', () async {
    await notifier.delete('missing');
    await notifier.delete('demo-current');
    await Hive.close();
    await Hive.openBox<Map>('history');
    await Hive.openBox<Map>('reports');
    await Hive.openBox('settings');
    expect(HistoryLocalDatasource().loadAll().single.id, 'demo-previous');
    expect(ReportLocalDatasource().load('demo-current'), isNull);
  });
}
