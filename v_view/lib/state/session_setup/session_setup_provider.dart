import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/session_setup/session_input.dart';
import '../../domain/session_setup/profile_catalog.dart'
    show normalizeProfileName;
import '../../data/local/session/session_input_local_datasource.dart';

final _datasource = SessionInputLocalDatasource();

final sessionInputProvider =
    StateNotifierProvider<SessionInputNotifier, SessionInput>((ref) {
      return SessionInputNotifier(_datasource.load(), _datasource);
    });

class SessionInputNotifier extends StateNotifier<SessionInput> {
  final SessionInputLocalDatasource? _ds;

  SessionInputNotifier(SessionInput? saved, [this._ds])
    : super(
        saved ??
            const SessionInput(
              type: InterviewType.job,
              position: '',
              company: '',
              selfIntroduction: '',
            ),
      );

  void update(SessionInput input) {
    state = input;
    _ds?.save(input);
  }

  void setType(InterviewType type) => update(state.copyWith(type: type));
  void setPosition(String v) => update(state.copyWith(position: v));
  void setCompany(String v) => update(state.copyWith(company: v));
  void setSelfIntroduction(String v) =>
      update(state.copyWith(selfIntroduction: v));
  void setAge(String v) => update(state.copyWith(age: v));
  void setEducation(String v) => update(state.copyWith(education: v));
  void setSchool(String v) => update(state.copyWith(school: v.trim()));
  void setCertificationNames(List<String> values) {
    final seen = <String>{};
    final entries = values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty && seen.add(normalizeProfileName(v)))
        .toList();
    update(
      state.copyWith(certifications: entries.join('\n'), certificates: entries),
    );
  }

  void setCertifications(String v) => update(state.copyWith(certifications: v));
  void setResumeSummary(String v) => update(state.copyWith(resumeSummary: v));
  void setEssayQuestion(int index, String v) =>
      _setEssay(index, state.essayAt(index).copyWith(question: v));
  void setEssayAnswer(int index, String v) =>
      _setEssay(index, state.essayAt(index).copyWith(answer: v));
  void _setEssay(int index, ApplicationEssay essay) {
    final entries = List.generate(3, state.essayAt);
    entries[index] = essay;
    update(state.copyWith(essays: entries));
  }

  void setQuestionCount(int v) => update(state.copyWith(questionCount: v));
  void setTimerMinutes(int v) => update(state.copyWith(timerMinutes: v));
  void setPreparationSeconds(int v) {
    if ([0, 15, 30].contains(v)) update(state.copyWith(preparationSeconds: v));
  }

  void setCameraEnabled(bool v) => update(state.copyWith(cameraEnabled: v));

  void reset() {
    state = const SessionInput(
      type: InterviewType.job,
      position: '',
      company: '',
      selfIntroduction: '',
    );
    _ds?.clear();
  }

  bool get isValid =>
      state.position.trim().isNotEmpty &&
      state.company.trim().isNotEmpty &&
      state.hasApplicationMaterial;
}
