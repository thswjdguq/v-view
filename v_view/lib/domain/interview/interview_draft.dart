import '../session_setup/session_input.dart';
import 'interview_question.dart';

class InterviewDraft {
  const InterviewDraft({
    required this.sessionId,
    required this.input,
    required this.questions,
    required this.currentIndex,
    required this.answers,
    required this.durations,
    required this.timerSeconds,
    required this.elapsedSeconds,
    required this.savedAt,
    this.finished = false,
    this.referenceReportId,
    this.preparationSecondsRemaining = 0,
  });
  final String sessionId;
  final SessionInput input;
  final List<InterviewQuestion> questions;
  final int currentIndex;
  final Map<String, String> answers;
  final Map<String, int> durations;
  final int timerSeconds;
  final int elapsedSeconds;
  final DateTime savedAt;
  final bool finished;
  final String? referenceReportId;
  final int preparationSecondsRemaining;
  Map<String, dynamic> toMap() => {
    'version': 1,
    'sessionId': sessionId,
    'input': input.toMap(),
    'questions': questions.map((q) => q.toMap()).toList(),
    'currentIndex': currentIndex,
    'answers': answers,
    'durations': durations,
    'timerSeconds': timerSeconds,
    'elapsedSeconds': elapsedSeconds,
    'savedAt': savedAt.toIso8601String(),
    'finished': finished,
    'referenceReportId': referenceReportId,
    'preparationSecondsRemaining': preparationSecondsRemaining,
  };
  factory InterviewDraft.fromMap(Map raw) {
    if (raw['version'] != 1) {
      throw const FormatException('Unknown draft version');
    }
    final input = SessionInput.fromMap(raw['input'] as Map);
    final questions = (raw['questions'] as List)
        .map((q) => InterviewQuestion.fromMap(q as Map))
        .toList();
    final index = raw['currentIndex'] as int;
    final timer = raw['timerSeconds'] as int;
    final elapsed = raw['elapsedSeconds'] as int;
    final preparation = raw['preparationSecondsRemaining'] as int? ?? 0;
    if (questions.isEmpty ||
        index < 0 ||
        index >= questions.length ||
        timer < 0 ||
        elapsed < 0 ||
        preparation < 0 ||
        preparation > input.preparationSeconds) {
      throw const FormatException('Invalid draft progress');
    }
    return InterviewDraft(
      sessionId: raw['sessionId'] as String,
      input: input,
      questions: questions,
      currentIndex: index,
      answers: Map<String, String>.from(raw['answers'] as Map),
      durations: Map<String, int>.from(raw['durations'] as Map),
      timerSeconds: timer,
      elapsedSeconds: elapsed,
      savedAt: DateTime.parse(raw['savedAt'] as String),
      finished: raw['finished'] == true,
      referenceReportId: raw['referenceReportId'] as String?,
      preparationSecondsRemaining: preparation,
    );
  }
}
