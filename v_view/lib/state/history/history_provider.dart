import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/history/session_history.dart';
import '../../data/local/history/history_local_datasource.dart';
import '../../data/local/report/report_local_datasource.dart';
import '../../data/local/record_deletion_datasource.dart';

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<SessionHistoryItem>>((ref) {
      return HistoryNotifier(HistoryLocalDatasource());
    });

class HistoryNotifier extends StateNotifier<List<SessionHistoryItem>> {
  final HistoryLocalDatasource _datasource;
  final RecordDeletionDatasource _deletions;

  HistoryNotifier(this._datasource, {RecordDeletionDatasource? deletions})
    : _deletions =
          deletions ??
          RecordDeletionDatasource(_datasource, ReportLocalDatasource()),
      super([]) {
    load();
  }

  void load() => state = _datasource.loadAll();

  Future<void> delete(String id) async {
    await _deletions.delete(id);
    if (mounted) load();
  }

  Future<void> deleteAll() async {
    await _deletions.deleteAll();
    if (mounted) load();
  }
}
