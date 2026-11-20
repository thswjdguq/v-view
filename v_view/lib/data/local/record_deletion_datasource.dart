import 'history/history_local_datasource.dart';
import 'report/report_local_datasource.dart';

/// 두 저장소의 삭제가 모두 끝난 경우에만 호출자에게 성공을 반환한다.
/// Hive의 서로 다른 box 쓰기는 단일 트랜잭션이 아니므로 실패 시 재시도한다.
class RecordDeletionDatasource {
  RecordDeletionDatasource(this._history, this._reports);
  final HistoryLocalDatasource _history;
  final ReportLocalDatasource _reports;
  bool _running = false;

  Future<void> delete(String id) => _deleteIds([id]);

  Future<void> deleteAll() =>
      _deleteIds({..._history.storedIds, ..._reports.storedIds}.toList());

  Future<void> _deleteIds(List<String> ids) async {
    if (_running) throw StateError('기록 삭제가 진행 중입니다.');
    _running = true;
    try {
      // 답변이 포함된 상세를 먼저 지워 중간 실패 시 민감한 본문이 남지 않게 한다.
      await _reports.deleteMany(ids);
      await _history.deleteMany(ids);
    } finally {
      _running = false;
    }
  }
}
