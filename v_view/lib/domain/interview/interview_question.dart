class InterviewQuestion {
  final String id;
  final String text;
  final String intent;
  final bool isFollowUp;
  final String? parentQuestionId;

  const InterviewQuestion({
    required this.id,
    required this.text,
    required this.intent,
    this.isFollowUp = false,
    this.parentQuestionId,
  });
}

class QuestionAnswer {
  final InterviewQuestion question;
  final String userAnswer;
  final String? aiSummary;
  final int answerDurationSeconds;

  const QuestionAnswer({
    required this.question,
    required this.userAnswer,
    this.aiSummary,
    required this.answerDurationSeconds,
  });
}
