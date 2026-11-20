import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/interview/interview_question.dart';
import '../../domain/session_setup/session_input.dart';
import '../../data/remote/ai/claude_api_service.dart';
import '../../data/local/interview_draft_datasource.dart';
import '../../domain/interview/interview_draft.dart';

enum InterviewPhase { idle, loadingQuestions, inProgress, paused, finished }

class InterviewState {
  final InterviewPhase phase;
  final List<InterviewQuestion> questions;
  final int currentIndex;
  final Map<String, String> userAnswers;
  final Map<String, int> answerDurations;
  final int timerSeconds;
  final int elapsedSeconds;
  final String? errorMessage;
  final String? sessionId;
  final String? referenceReportId;
  final String? draftSaveError;
  final bool recoveredFromDraft;
  final String? followUpNotice;
  final int preparationSecondsRemaining;

  const InterviewState({
    this.phase = InterviewPhase.idle,
    this.questions = const [],
    this.currentIndex = 0,
    this.userAnswers = const {},
    this.answerDurations = const {},
    this.timerSeconds = 120,
    this.elapsedSeconds = 0,
    this.errorMessage,
    this.sessionId,
    this.referenceReportId,
    this.draftSaveError,
    this.recoveredFromDraft = false,
    this.followUpNotice,
    this.preparationSecondsRemaining = 0,
  });

  InterviewState copyWith({
    InterviewPhase? phase,
    List<InterviewQuestion>? questions,
    int? currentIndex,
    Map<String, String>? userAnswers,
    Map<String, int>? answerDurations,
    int? timerSeconds,
    int? elapsedSeconds,
    String? errorMessage,
    String? sessionId,
    String? referenceReportId,
    String? draftSaveError,
    bool clearDraftSaveError = false,
    String? followUpNotice,
    bool clearFollowUpNotice = false,
    int? preparationSecondsRemaining,
  }) {
    return InterviewState(
      phase: phase ?? this.phase,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      userAnswers: userAnswers ?? this.userAnswers,
      answerDurations: answerDurations ?? this.answerDurations,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      errorMessage: errorMessage,
      sessionId: sessionId ?? this.sessionId,
      referenceReportId: referenceReportId ?? this.referenceReportId,
      draftSaveError: clearDraftSaveError
          ? null
          : draftSaveError ?? this.draftSaveError,
      recoveredFromDraft: recoveredFromDraft,
      followUpNotice: clearFollowUpNotice
          ? null
          : followUpNotice ?? this.followUpNotice,
      preparationSecondsRemaining:
          preparationSecondsRemaining ?? this.preparationSecondsRemaining,
    );
  }

  InterviewQuestion? get currentQuestion =>
      questions.isEmpty ? null : questions[currentIndex];

  bool get isLastQuestion => currentIndex >= questions.length - 1;
  bool get isPreparing => preparationSecondsRemaining > 0;
  bool get isAnswerTimeUp =>
      questions.isNotEmpty && !isPreparing && timerSeconds <= 0;
}

final claudeApiServiceProvider = Provider(
  (_) => ClaudeApiService(
    idTokenProvider: () async {
      final user = FirebaseAuth.instance.currentUser;
      return user == null ? null : await user.getIdToken();
    },
  ),
);

final interviewProvider =
    StateNotifierProvider<InterviewNotifier, InterviewState>((ref) {
      return InterviewNotifier(ref.read(claudeApiServiceProvider));
    });

class InterviewNotifier extends StateNotifier<InterviewState> {
  final ClaudeApiService _api;
  int _revision = 0;
  bool _advancing = false;
  final InterviewDraftDatasource? _draftStore;
  final void Function(InterviewDraft?)? _onDraftChanged;
  SessionInput? _input;
  Timer? _draftTimer;
  Future<void> _writeTail = Future.value();
  final _closedSessions = <String>{};

  InterviewNotifier(
    this._api, {
    InterviewDraftDatasource? draftStore,
    void Function(InterviewDraft?)? onDraftChanged,
  }) : _draftStore = draftStore,
       _onDraftChanged = onDraftChanged,
       super(const InterviewState());

  Future<void> start(SessionInput input) async {
    final revision = ++_revision;
    _advancing = false;
    _input = input;
    state = InterviewState(
      phase: InterviewPhase.loadingQuestions,
      sessionId: const Uuid().v4(),
      timerSeconds: input.timerMinutes * 60,
      preparationSecondsRemaining: input.preparationSeconds,
    );
    try {
      final questions = await _api.generateQuestions(input);
      if (!mounted || revision != _revision) return;
      state = state.copyWith(
        phase: InterviewPhase.inProgress,
        questions: questions,
        currentIndex: 0,
      );
      _scheduleDraft();
    } on Exception catch (error) {
      if (!mounted || revision != _revision) return;
      state = state.copyWith(
        phase: InterviewPhase.idle,
        errorMessage: error is AiServiceException
            ? error.message
            : '질문 생성에 실패했습니다. 네트워크를 확인하고 다시 시도해주세요.',
      );
    }
  }

  void submitAnswer(String answer) {
    final q = state.currentQuestion;
    if (q == null) return;
    final updated = Map<String, String>.from(state.userAnswers);
    updated[q.id] = answer;
    state = state.copyWith(userAnswers: updated);
    _scheduleDraft();
  }

  Future<void> nextQuestion(String answer) async {
    await _advance(answer, allowFollowUp: true);
  }

  Future<void> nextBaseQuestion(String answer) async {
    await _advance(answer, allowFollowUp: false);
  }

  Future<void> _advance(String answer, {required bool allowFollowUp}) async {
    if (_advancing ||
        state.phase != InterviewPhase.inProgress ||
        state.isPreparing) {
      return;
    }
    final q = state.currentQuestion;
    if (q == null) return;
    final revision = _revision;
    _advancing = true;
    try {
      state = state.copyWith(clearFollowUpNotice: true);
      submitAnswer(answer);
      if (_draftStore != null) await flushDraft();
      if (!mounted || revision != _revision) return;
      if (allowFollowUp && answer.trim().isNotEmpty) {
        try {
          final followUp = await _api.generateFollowUp(
            question: q,
            userAnswer: answer,
            conversation: [
              for (final previous in state.questions.take(
                state.currentIndex + 1,
              ))
                QuestionAnswer(
                  question: previous,
                  userAnswer: state.userAnswers[previous.id] ?? '',
                  answerDurationSeconds:
                      state.answerDurations[previous.id] ?? 0,
                ),
            ],
          );
          if (!mounted || revision != _revision) return;
          if (followUp != null &&
              !state.questions.any(
                (existing) =>
                    existing.id == followUp.id ||
                    _sameQuestion(existing.text, followUp.text),
              )) {
            final updated = List<InterviewQuestion>.from(state.questions);
            updated.insert(state.currentIndex + 1, followUp);
            state = state.copyWith(
              questions: updated,
              currentIndex: state.currentIndex + 1,
              timerSeconds: (_input?.timerMinutes ?? 2) * 60,
              preparationSecondsRemaining: _input?.preparationSeconds ?? 0,
            );
            return;
          }
        } on Exception {
          if (!mounted || revision != _revision) return;
          state = state.copyWith(
            followUpNotice: '추가 질문을 판단하지 못해 기본 질문으로 이동했어요.',
          );
        }
      }

      if (!mounted || revision != _revision) return;
      final nextIndex = allowFollowUp
          ? state.currentIndex + 1
          : state.questions.indexWhere(
              (question) => !question.isFollowUp,
              state.currentIndex + 1,
            );
      if (nextIndex < 0 || nextIndex >= state.questions.length) {
        state = state.copyWith(phase: InterviewPhase.finished);
      } else {
        state = state.copyWith(
          currentIndex: nextIndex,
          timerSeconds: (_input?.timerMinutes ?? 2) * 60,
          preparationSecondsRemaining: _input?.preparationSeconds ?? 0,
        );
      }
    } finally {
      if (revision == _revision) {
        _advancing = false;
        _scheduleDraft();
      }
    }
  }

  bool _sameQuestion(String a, String b) =>
      a.replaceAll(RegExp(r'[\s.,!?]'), '').toLowerCase() ==
      b.replaceAll(RegExp(r'[\s.,!?]'), '').toLowerCase();

  void reset() {
    final id = state.sessionId;
    _draftTimer?.cancel();
    if (id != null) unawaited(completeDraft(id));
    _revision++;
    _advancing = false;
    state = const InterviewState();
  }

  void pause() {
    state = state.copyWith(phase: InterviewPhase.paused);
    _scheduleDraft();
  }

  void resume() {
    state = state.copyWith(phase: InterviewPhase.inProgress);
    _scheduleDraft();
  }

  void finish() {
    _revision++;
    _advancing = false;
    state = state.copyWith(phase: InterviewPhase.finished);
    _scheduleDraft();
  }

  void tickTimer() {
    if (state.phase != InterviewPhase.inProgress) return;
    if (state.isPreparing) {
      state = state.copyWith(
        preparationSecondsRemaining: state.preparationSecondsRemaining - 1,
      );
      if (state.preparationSecondsRemaining % 5 == 0) _scheduleDraft();
      return;
    }
    if (state.timerSeconds <= 0) return;
    final durations = Map<String, int>.from(state.answerDurations);
    final question = state.currentQuestion;
    if (question != null) {
      durations[question.id] = (durations[question.id] ?? 0) + 1;
    }
    state = state.copyWith(
      timerSeconds: state.timerSeconds - 1,
      elapsedSeconds: state.elapsedSeconds + 1,
      answerDurations: durations,
    );
    if (state.elapsedSeconds % 5 == 0 || state.timerSeconds == 0) {
      _scheduleDraft();
    }
  }

  void beginAnswer() {
    if (state.phase != InterviewPhase.inProgress || !state.isPreparing) return;
    state = state.copyWith(preparationSecondsRemaining: 0);
    _scheduleDraft();
  }

  void extendAnswerTime() {
    if (state.phase != InterviewPhase.inProgress || !state.isAnswerTimeUp) {
      return;
    }
    state = state.copyWith(timerSeconds: 30);
    _scheduleDraft();
  }

  void resetTimer(int seconds) {
    state = state.copyWith(timerSeconds: seconds);
    _scheduleDraft();
  }

  void startPrepared(
    SessionInput input,
    List<InterviewQuestion> questions, {
    String? referenceReportId,
  }) {
    if (questions.isEmpty) return;
    reset();
    _input = input;
    state = InterviewState(
      phase: InterviewPhase.inProgress,
      sessionId: const Uuid().v4(),
      questions: List.unmodifiable(questions),
      timerSeconds: input.timerMinutes * 60,
      referenceReportId: referenceReportId,
      preparationSecondsRemaining: input.preparationSeconds,
    );
    _scheduleDraft();
  }

  void restoreDraft(InterviewDraft draft) {
    _revision++;
    _advancing = false;
    _input = draft.input;
    state = InterviewState(
      phase: draft.finished ? InterviewPhase.finished : InterviewPhase.paused,
      sessionId: draft.sessionId,
      referenceReportId: draft.referenceReportId,
      questions: List.unmodifiable(draft.questions),
      currentIndex: draft.currentIndex,
      userAnswers: Map.of(draft.answers),
      answerDurations: Map.of(draft.durations),
      timerSeconds: draft.timerSeconds,
      elapsedSeconds: draft.elapsedSeconds,
      recoveredFromDraft: true,
      preparationSecondsRemaining: draft.preparationSecondsRemaining,
    );
  }

  void _scheduleDraft() {
    if (_draftStore == null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(flushDraft()),
    );
  }

  Future<void> flushDraft() async {
    _draftTimer?.cancel();
    if (!mounted ||
        _draftStore == null ||
        _input == null ||
        state.questions.isEmpty ||
        state.sessionId == null) {
      return;
    }
    final id = state.sessionId!;
    if (_closedSessions.contains(id)) return;
    final draft = InterviewDraft(
      sessionId: id,
      input: _input!,
      questions: List.of(state.questions),
      currentIndex: state.currentIndex,
      answers: Map.of(state.userAnswers),
      durations: Map.of(state.answerDurations),
      timerSeconds: state.timerSeconds,
      elapsedSeconds: state.elapsedSeconds,
      savedAt: DateTime.now(),
      finished: state.phase == InterviewPhase.finished,
      referenceReportId: state.referenceReportId,
      preparationSecondsRemaining: state.preparationSecondsRemaining,
    );
    _writeTail = _writeTail.then((_) async {
      if (_closedSessions.contains(id)) return;
      try {
        await _draftStore.save(draft);
        if (mounted && state.sessionId == id) {
          state = state.copyWith(clearDraftSaveError: true);
          _onDraftChanged?.call(draft);
        }
      } catch (_) {
        if (mounted && state.sessionId == id) {
          state = state.copyWith(
            draftSaveError:
                '자동 저장하지 못했어요. 저장 공간을 확인하고 연습을 종료하기 전에 답변을 보관해 주세요.',
          );
        }
      }
    });
    await _writeTail;
  }

  Future<void> completeDraft(String id) async {
    _closedSessions.add(id);
    if (state.sessionId == id) _draftTimer?.cancel();
    _writeTail = _writeTail.then((_) async {
      try {
        await _draftStore?.clearIfSession(id);
        if (mounted) _onDraftChanged?.call(_draftStore?.load());
      } catch (_) {
        /* A later retry can clear the remaining draft. */
      }
    });
    await _writeTail;
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    super.dispose();
  }
}
