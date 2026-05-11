import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/history/session_history.dart';
import '../../data/local/history/history_local_datasource.dart';

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<SessionHistoryItem>>((ref) {
  return HistoryNotifier(HistoryLocalDatasource());
});

class HistoryNotifier extends StateNotifier<List<SessionHistoryItem>> {
  final HistoryLocalDatasource _datasource;

  HistoryNotifier(this._datasource) : super([]) {
    load();
  }

  void load() => state = _datasource.loadAll();

  void delete(String id) {
    _datasource.delete(id);
    state = state.where((item) => item.id != id).toList();
  }

  void deleteAll() {
    _datasource.deleteAll();
    state = [];
  }
}
