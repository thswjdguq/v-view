import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/report/session_report.dart';
import '../../domain/gaze/gaze_metrics.dart';
import '../../domain/interview/interview_question.dart';
import '../../domain/session_setup/session_input.dart';
import '../../domain/history/session_history.dart';
import '../../data/remote/ai/claude_api_service.dart';
import '../../data/local/report/report_local_datasource.dart';
import '../../data/local/history/history_local_datasource.dart';
import '../interview/interview_provider.dart';

enum ReportPhase { idle, generating, saving, done, error }

class FeedbackRetryStatus {
  const FeedbackRetryStatus({
    this.busy = false,
    this.hasPendingSave = false,
    this.errorMessage,
  });
  final bool busy;
  final bool hasPendingSave;
  final String? errorMessage;
}

class ReportState {
  final ReportPhase phase;
  final SessionReport? report;
  final String? errorMessage;
  final Map<String, FeedbackRetryStatus> feedbackRetries;

  const ReportState({
    this.phase = ReportPhase.idle,
    this.report,
    this.errorMessage,
    this.feedbackRetries = const {},
  });

  ReportState copyWith({
    ReportPhase? phase,
    SessionReport? report,
    String? errorMessage,
    Map<String, FeedbackRetryStatus>? feedbackRetries,
  }) {
    return ReportState(
      phase: phase ?? this.phase,
      report: report,
      errorMessage: errorMessage,
      feedbackRetries: feedbackRetries ?? this.feedbackRetries,
    );
  }
}

final reportLocalDatasource = Provider((_) => ReportLocalDatasource());
final historyLocalDatasource = Provider((_) => HistoryLocalDatasource());

final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>((
  ref,
) {
  return ReportNotifier(
    ref.read(claudeApiServiceProvider),
    ref.read(reportLocalDatasource),
    ref.read(historyLocalDatasource),
  );
});

class ReportNotifier extends StateNotifier<ReportState> {
  final ClaudeApiService _api;
  final ReportLocalDatasource _reportRepo;
  final HistoryLocalDatasource _historyRepo;
  static const _uuid = Uuid();
  int _generation = 0;
  final bool _feedbackIsAi;
  _PendingReport? _pending;
  final _pendingFeedback = <String, SessionReport>{};

  ReportNotifier(
    this._api,
    this._reportRepo,
    this._historyRepo, {
    bool feedbackIsAi = true,
  }) : _feedbackIsAi = feedbackIsAi,
       super(const ReportState());

  Future<void> generate({
    required InterviewType interviewType,
    required String position,
    required String company,
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
    required int totalDurationSeconds,
  }) async {
    if (!mounted) return;
    final generation = ++_generation;
    _pending = null;
    state = state.copyWith(phase: ReportPhase.generating);
    final id = _uuid.v4();
    final answers = List<QuestionAnswer>.unmodifiable(qaList);

    List<ImprovementPoint> improvements;
    bool aiFeedbackAvailable = _feedbackIsAi;

    try {
      improvements = await _api.generateFeedback(
        qaList: answers,
        gazeMetrics: gazeMetrics,
      );
    } on Exception {
      aiFeedbackAvailable = false;
      improvements = _fallbackImprovements(gazeMetrics);
    }
    if (!mounted || generation != _generation) return;

    final report = SessionReport(
      id: id,
      createdAt: DateTime.now(),
      interviewType: interviewType,
      gazeMetrics: gazeMetrics,
      qaList: answers,
      totalQuestions: answers.length,
      totalDurationSeconds: totalDurationSeconds,
      improvementPoints: improvements,
      isAiFeedbackAvailable: aiFeedbackAvailable,
    );

    final pending = _PendingReport(
      report,
      SessionHistoryItem(
        id: id,
        createdAt: report.createdAt,
        interviewType: interviewType,
        position: position,
        company: company,
        gazeRate: gazeMetrics.gazeRate,
        gazeQuality: gazeMetrics.quality,
        distractionCount: gazeMetrics.distractionCount,
        totalQuestions: answers.length,
        totalDurationSeconds: totalDurationSeconds,
      ),
    );
    _pending = pending;
    await _persist(pending, generation);
  }

  /// Retry disk writes with the same ID and feedback; never repeat a paid AI request.
  Future<void> retrySave() async {
    if (!mounted || state.phase != ReportPhase.error) return;
    final pending = _pending;
    if (pending == null) return;
    await _persist(pending, _generation);
  }

  Future<void> _persist(_PendingReport pending, int generation) async {
    state = state.copyWith(phase: ReportPhase.saving, report: pending.report);
    try {
      // Both writes are idempotent by ID. A partial failure can be retried.
      await _reportRepo.save(pending.report);
      await _historyRepo.save(pending.history);
      if (!mounted || generation != _generation) return;
      _pending = null;
      state = state.copyWith(phase: ReportPhase.done, report: pending.report);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        phase: ReportPhase.error,
        report: pending.report,
        errorMessage: '기록을 저장하지 못했어요. 저장 공간을 확인한 뒤 저장을 다시 시도해 주세요.',
      );
    }
  }

  SessionReport? loadById(String id) => _reportRepo.load(id);

  void _feedbackStatus(
    String id,
    FeedbackRetryStatus status, {
    SessionReport? updated,
  }) {
    if (!mounted) return;
    state = state.copyWith(
      phase: state.phase,
      errorMessage: state.errorMessage,
      report: updated != null && state.report?.id == id
          ? updated
          : state.report,
      feedbackRetries: {...state.feedbackRetries, id: status},
    );
  }

  Future<void> retryFeedback(String id) async {
    if (!mounted || state.feedbackRetries[id]?.busy == true) return;
    final saved = _reportRepo.load(id);
    if (saved == null) {
      _pendingFeedback.remove(id);
      return;
    }
    if (saved.isAiFeedbackAvailable && !_pendingFeedback.containsKey(id)) {
      return;
    }
    if (!saved.qaList.any((qa) => qa.userAnswer.trim().isNotEmpty)) {
      _feedbackStatus(
        id,
        const FeedbackRetryStatus(errorMessage: '평가할 답변이 저장되지 않았어요.'),
      );
      return;
    }
    _feedbackStatus(
      id,
      FeedbackRetryStatus(
        busy: true,
        hasPendingSave: _pendingFeedback.containsKey(id),
      ),
    );
    try {
      var updated = _pendingFeedback[id];
      if (updated == null) {
        final points = await _api.generateFeedback(
          qaList: saved.qaList,
          gazeMetrics: saved.gazeMetrics,
        );
        if (!mounted) return;
        updated = saved.withFeedback(points);
        _pendingFeedback[id] = updated;
      }
      if (_reportRepo.load(id) == null) {
        _pendingFeedback.remove(id);
        _feedbackStatus(
          id,
          const FeedbackRetryStatus(errorMessage: '삭제된 기록에는 평가를 저장하지 않았어요.'),
        );
        return;
      }
      await _reportRepo.save(updated);
      if (!mounted) return;
      _pendingFeedback.remove(id);
      _feedbackStatus(id, const FeedbackRetryStatus(), updated: updated);
    } catch (error) {
      if (!mounted) return;
      final pending = _pendingFeedback.containsKey(id);
      _feedbackStatus(
        id,
        FeedbackRetryStatus(
          hasPendingSave: pending,
          errorMessage: pending
              ? '평가를 받았지만 저장하지 못했어요. 저장만 다시 시도할 수 있어요.'
              : error is AiServiceException
              ? error.message
              : 'AI 평가를 받지 못했어요. PC 연결을 확인해 주세요.',
        ),
      );
    }
  }

  // AI 실패 시 시선 지표만으로 최소 피드백 제공
  List<ImprovementPoint> _fallbackImprovements(GazeMetrics gaze) {
    if (gaze.quality == GazeQuality.unavailable) {
      return const [
        ImprovementPoint(
          title: '시선 측정 환경 확인',
          description:
              '시선을 측정하지 못했습니다. 카메라 권한과 조명을 확인하고 얼굴이 화면 안에 보이도록 조정해주세요.',
          evidenceMetric: '시선 측정 불가',
        ),
      ];
    }
    final points = <ImprovementPoint>[];

    if (gaze.gazeRate < 70) {
      points.add(
        ImprovementPoint(
          title: '화면 응시 유지',
          description:
              '면접 중 카메라를 더 자주 바라보는 연습이 필요합니다. 현재 응시율 ${gaze.gazeRate.toStringAsFixed(0)}%.',
          evidenceMetric: '화면 응시율 ${gaze.gazeRate.toStringAsFixed(0)}%',
        ),
      );
    }

    if (gaze.distractionCount >= 3) {
      points.add(
        ImprovementPoint(
          title: '시선 분산 줄이기',
          description:
              '면접 중 ${gaze.distractionCount}회 시선이 분산되었습니다. 시선을 안정적으로 유지하는 연습을 권장합니다.',
          evidenceMetric: '시선 분산 ${gaze.distractionCount}회',
        ),
      );
    }

    if (gaze.maxDistractionSeconds >= 3.0) {
      points.add(
        ImprovementPoint(
          title: '장시간 시선 분산 개선',
          description:
              '최대 ${gaze.maxDistractionSeconds.toStringAsFixed(1)}초간 시선이 분산된 구간이 있습니다. 집중력 훈련을 권장합니다.',
          evidenceMetric:
              '최장 분산 ${gaze.maxDistractionSeconds.toStringAsFixed(1)}초',
        ),
      );
    }

    if (points.isEmpty) {
      points.add(
        const ImprovementPoint(
          title: '답변 구체성 향상',
          description: '시선 지표는 양호합니다. STAR 기법으로 답변을 더 구체적으로 전달하는 연습을 권장합니다.',
          evidenceMetric: '화면 응시율',
        ),
      );
    }

    return points.take(3).toList();
  }
}

class _PendingReport {
  final SessionReport report;
  final SessionHistoryItem history;
  const _PendingReport(this.report, this.history);
}
