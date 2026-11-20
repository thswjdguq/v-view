import '../gaze/gaze_metrics.dart';
import 'session_report.dart';

class ReportComparison {
  const ReportComparison({required this.current, required this.previous});
  final SessionReport current;
  final SessionReport previous;

  double get completionChange => _completion(current) - _completion(previous);

  double? get gazeChange =>
      current.gazeMetrics.quality == GazeQuality.normal &&
          previous.gazeMetrics.quality == GazeQuality.normal
      ? current.gazeMetrics.gazeRate - previous.gazeMetrics.gazeRate
      : null;

  double? get averageAnswerSecondsChange {
    final now = _averageAnswerSeconds(current);
    final before = _averageAnswerSeconds(previous);
    return now == null || before == null ? null : now - before;
  }

  double _completion(SessionReport report) => report.qaList.isEmpty
      ? 0
      : report.qaList.where((qa) => qa.userAnswer.trim().isNotEmpty).length /
            report.qaList.length *
            100;

  double? _averageAnswerSeconds(SessionReport report) {
    final answers = report.qaList
        .where(
          (qa) =>
              qa.userAnswer.trim().isNotEmpty && qa.answerDurationSeconds > 0,
        )
        .toList();
    if (answers.isEmpty) return null;
    return answers.fold<int>(
          0,
          (total, qa) => total + qa.answerDurationSeconds,
        ) /
        answers.length;
  }
}
