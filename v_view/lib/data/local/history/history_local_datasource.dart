import '../../local/hive_service.dart';
import '../../../domain/history/session_history.dart';
import '../../../domain/session_setup/session_input.dart';

class HistoryLocalDatasource {
  List<SessionHistoryItem> loadAll() {
    return HiveService.historyBox.values
        .cast<Map>()
        .map(_fromMap)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void save(SessionHistoryItem item) {
    HiveService.historyBox.put(item.id, _toMap(item));
  }

  void delete(String id) => HiveService.historyBox.delete(id);

  void deleteAll() => HiveService.historyBox.clear();

  Map _toMap(SessionHistoryItem item) => {
        'id': item.id,
        'createdAt': item.createdAt.toIso8601String(),
        'interviewType': item.interviewType.index,
        'position': item.position,
        'company': item.company,
        'gazeRate': item.gazeRate,
        'distractionCount': item.distractionCount,
        'totalQuestions': item.totalQuestions,
        'totalDurationSeconds': item.totalDurationSeconds,
      };

  SessionHistoryItem _fromMap(Map raw) => SessionHistoryItem(
        id: raw['id'] as String,
        createdAt: DateTime.parse(raw['createdAt'] as String),
        interviewType: InterviewType.values[raw['interviewType'] as int],
        position: raw['position'] as String,
        company: raw['company'] as String,
        gazeRate: (raw['gazeRate'] as num).toDouble(),
        distractionCount: raw['distractionCount'] as int,
        totalQuestions: raw['totalQuestions'] as int,
        totalDurationSeconds: raw['totalDurationSeconds'] as int,
      );
}
