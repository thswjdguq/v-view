import '../../local/hive_service.dart';
import '../../../domain/history/session_history.dart';
import '../../../domain/session_setup/session_input.dart';
import '../../../domain/gaze/gaze_metrics.dart';

class HistoryLocalDatasource {
  List<SessionHistoryItem> loadAll() {
    return HiveService.historyBox.values.cast<Map>().map(_fromMap).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(SessionHistoryItem item) =>
      HiveService.historyBox.put(item.id, _toMap(item));

  List<String> get storedIds =>
      HiveService.historyBox.keys.cast<String>().toList();

  Future<void> deleteMany(Iterable<String> ids) =>
      HiveService.historyBox.deleteAll(ids);

  Map _toMap(SessionHistoryItem item) => {
    'id': item.id,
    'createdAt': item.createdAt.toIso8601String(),
    'interviewType': item.interviewType.index,
    'position': item.position,
    'company': item.company,
    'gazeRate': item.gazeRate,
    'gazeQuality': item.gazeQuality.index,
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
    gazeQuality: _quality(raw['gazeQuality']),
    distractionCount: raw['distractionCount'] as int,
    totalQuestions: raw['totalQuestions'] as int,
    totalDurationSeconds: raw['totalDurationSeconds'] as int,
  );

  GazeQuality _quality(Object? index) =>
      index is int && index >= 0 && index < GazeQuality.values.length
      ? GazeQuality.values[index]
      : GazeQuality.reference;
}
