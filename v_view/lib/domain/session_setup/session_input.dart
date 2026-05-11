enum InterviewType { job, personality, university }

class SessionInput {
  final InterviewType type;
  final String position;
  final String company;
  final String selfIntroduction;

  const SessionInput({
    required this.type,
    required this.position,
    required this.company,
    required this.selfIntroduction,
  });

  SessionInput copyWith({
    InterviewType? type,
    String? position,
    String? company,
    String? selfIntroduction,
  }) {
    return SessionInput(
      type: type ?? this.type,
      position: position ?? this.position,
      company: company ?? this.company,
      selfIntroduction: selfIntroduction ?? this.selfIntroduction,
    );
  }
}
