import '../session_setup/session_input.dart';

class SessionHistoryItem {
  final String id;
  final DateTime createdAt;
  final InterviewType interviewType;
  final String position;
  final String company;
  final double gazeRate;
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
    required this.distractionCount,
    required this.totalQuestions,
    required this.totalDurationSeconds,
  });
}
