enum FollowUpKind { clarification, challenge }

class InterviewQuestion {
  final String id;
  final String text;
  final String intent;
  final bool isFollowUp;
  final String? parentQuestionId;
  final FollowUpKind? followUpKind;
  final String? followUpReason;
  final String? followUpEvidence;

  const InterviewQuestion({
    required this.id,
    required this.text,
    required this.intent,
    this.isFollowUp = false,
    this.parentQuestionId,
    this.followUpKind,
    this.followUpReason,
    this.followUpEvidence,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'intent': intent,
    'isFollowUp': isFollowUp,
    'parentQuestionId': parentQuestionId,
    'followUpKind': followUpKind?.name,
    'followUpReason': followUpReason,
    'followUpEvidence': followUpEvidence,
  };

  factory InterviewQuestion.fromMap(Map raw) => InterviewQuestion(
    id: raw['id'] as String,
    text: raw['text'] as String,
    intent: raw['intent'] as String,
    isFollowUp: raw['isFollowUp'] == true,
    parentQuestionId: raw['parentQuestionId'] as String?,
    followUpKind: FollowUpKind.values
        .where((kind) => kind.name == raw['followUpKind'])
        .firstOrNull,
    followUpReason: raw['followUpReason'] as String?,
    followUpEvidence: raw['followUpEvidence'] as String?,
  );
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
