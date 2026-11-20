import 'profile_catalog.dart' show normalizeProfileName;

enum InterviewType { job, personality, university }

class ApplicationEssay {
  const ApplicationEssay({required this.question, this.answer = ''});
  final String question;
  final String answer;
  ApplicationEssay copyWith({String? question, String? answer}) =>
      ApplicationEssay(
        question: question ?? this.question,
        answer: answer ?? this.answer,
      );
  Map<String, dynamic> toMap() => {'question': question, 'answer': answer};
  factory ApplicationEssay.fromMap(Map raw) => ApplicationEssay(
    question: raw['question'] as String? ?? '',
    answer: raw['answer'] as String? ?? '',
  );
}

class SessionInput {
  static const essayPrompts = [
    '지원 동기와 목표를 알려주세요.',
    '문제를 해결하거나 성과를 만든 경험을 알려주세요.',
    '협업 경험과 배운 점을 알려주세요.',
  ];
  final InterviewType type;
  final String position;
  final String company;
  final String selfIntroduction;
  final String age;
  final String education;
  final String school;
  final String certifications;
  final List<String> certificates;
  final String resumeSummary;
  final List<ApplicationEssay> essays;
  final int questionCount;
  final int timerMinutes;
  final int preparationSeconds;
  final bool cameraEnabled;

  const SessionInput({
    required this.type,
    required this.position,
    required this.company,
    this.selfIntroduction = '',
    this.age = '',
    this.education = '',
    this.school = '',
    this.certifications = '',
    this.certificates = const [],
    this.resumeSummary = '',
    this.essays = const [],
    this.questionCount = 3,
    this.timerMinutes = 2,
    this.preparationSeconds = 0,
    this.cameraEnabled = true,
  });

  SessionInput copyWith({
    InterviewType? type,
    String? position,
    String? company,
    String? selfIntroduction,
    String? age,
    String? education,
    String? school,
    String? certifications,
    List<String>? certificates,
    String? resumeSummary,
    List<ApplicationEssay>? essays,
    int? questionCount,
    int? timerMinutes,
    int? preparationSeconds,
    bool? cameraEnabled,
  }) {
    return SessionInput(
      type: type ?? this.type,
      position: position ?? this.position,
      company: company ?? this.company,
      selfIntroduction: selfIntroduction ?? this.selfIntroduction,
      age: age ?? this.age,
      education: education ?? this.education,
      school: school ?? this.school,
      certifications: certifications ?? this.certifications,
      certificates: List.unmodifiable(
        certificates ??
            (certifications != null ? const <String>[] : this.certificates),
      ),
      resumeSummary: resumeSummary ?? this.resumeSummary,
      essays: List.unmodifiable(essays ?? this.essays),
      questionCount: questionCount ?? this.questionCount,
      timerMinutes: timerMinutes ?? this.timerMinutes,
      preparationSeconds: preparationSeconds ?? this.preparationSeconds,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
    );
  }

  ApplicationEssay essayAt(int index) => index < essays.length
      ? essays[index]
      : ApplicationEssay(question: essayPrompts[index]);
  bool get hasApplicationMaterial =>
      resumeSummary.trim().isNotEmpty ||
      selfIntroduction.trim().isNotEmpty ||
      essays.any((e) => e.answer.trim().isNotEmpty);
  List<String> get certificationNames {
    final seen = <String>{};
    final values = certificates.isNotEmpty
        ? certificates
        : certifications.split(RegExp(r'[,;\n·]'));
    return List.unmodifiable(
      values
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty && seen.add(normalizeProfileName(v))),
    );
  }

  Map<String, dynamic> get applicationContext => {
    'profile': {
      if (age.trim().isNotEmpty) 'age': age.trim(),
      if (education.trim().isNotEmpty) 'education': education.trim(),
      if (school.trim().isNotEmpty) 'school': school.trim(),
      if (certificationNames.isNotEmpty) 'certifications': certificationNames,
    },
    if (resumeSummary.trim().isNotEmpty) 'resumeSummary': resumeSummary.trim(),
    'essays': essays
        .where((e) => e.answer.trim().isNotEmpty)
        .map((e) => e.toMap())
        .toList(),
    if (selfIntroduction.trim().isNotEmpty)
      'previousIntroduction': selfIntroduction.trim(),
  };
  Map<String, dynamic> toMap() => {
    'type': type.index,
    'position': position,
    'company': company,
    'selfIntroduction': selfIntroduction,
    'age': age,
    'education': education,
    'school': school,
    'certifications': certifications,
    'certificates': certificationNames,
    'resumeSummary': resumeSummary,
    'essays': essays.map((e) => e.toMap()).toList(),
    'questionCount': questionCount,
    'timerMinutes': timerMinutes,
    'preparationSeconds': preparationSeconds,
    'cameraEnabled': cameraEnabled,
  };
  factory SessionInput.fromMap(Map raw) => SessionInput(
    type: InterviewType.values[raw['type'] as int],
    position: raw['position'] as String,
    company: raw['company'] as String,
    selfIntroduction: raw['selfIntroduction'] as String? ?? '',
    age: raw['age'] as String? ?? '',
    education: raw['education'] as String? ?? '',
    school: raw['school'] as String? ?? '',
    certifications: raw['certifications'] as String? ?? '',
    certificates: List.unmodifiable(
      List<String>.from(raw['certificates'] as List? ?? []),
    ),
    resumeSummary: raw['resumeSummary'] as String? ?? '',
    essays: List.unmodifiable(
      (raw['essays'] as List? ?? []).map(
        (e) => ApplicationEssay.fromMap(e as Map),
      ),
    ),
    questionCount: raw['questionCount'] as int? ?? 3,
    timerMinutes: raw['timerMinutes'] as int? ?? 2,
    preparationSeconds: [0, 15, 30].contains(raw['preparationSeconds'])
        ? raw['preparationSeconds'] as int
        : 0,
    cameraEnabled: raw['cameraEnabled'] as bool? ?? true,
  );
}
