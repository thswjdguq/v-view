import '../gaze/gaze_metrics.dart';
import '../interview/interview_question.dart';
import '../session_setup/session_input.dart';

class ImprovementPoint {
  final String title;
  final String description;
  final String evidenceMetric;

  const ImprovementPoint({
    required this.title,
    required this.description,
    required this.evidenceMetric,
  });
}

class SessionReport {
  final String id;
  final DateTime createdAt;
  final InterviewType interviewType;
  final GazeMetrics gazeMetrics;
  final List<QuestionAnswer> qaList;
  final int totalQuestions;
  final int totalDurationSeconds;
  final List<ImprovementPoint> improvementPoints;
  final bool isAiFeedbackAvailable;

  const SessionReport({
    required this.id,
    required this.createdAt,
    required this.interviewType,
    required this.gazeMetrics,
    required this.qaList,
    required this.totalQuestions,
    required this.totalDurationSeconds,
    required this.improvementPoints,
    this.isAiFeedbackAvailable = true,
  });
}
