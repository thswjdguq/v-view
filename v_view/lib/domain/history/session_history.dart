import '../session_setup/session_input.dart';
import '../gaze/gaze_metrics.dart';

class SessionHistoryItem {
  final String id;
  final DateTime createdAt;
  final InterviewType interviewType;
  final String position;
  final String company;
  final double gazeRate;
  final GazeQuality gazeQuality;
  final int distractionCount;
  final int totalQuestions;
  final int totalDurationSeconds;

  const SessionHistoryItem({
    required this.id,
    required this.createdAt,
    required this.interviewType,
    required this.position,
    required this.company,
    required this.gazeRate,
    this.gazeQuality = GazeQuality.reference,
    required this.distractionCount,
    required this.totalQuestions,
    required this.totalDurationSeconds,
  });
}
