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

enum ReportPhase { idle, generating, done, error }

class ReportState {
  final ReportPhase phase;
  final SessionReport? report;
  final String? errorMessage;

  const ReportState({
    this.phase = ReportPhase.idle,
    this.report,
    this.errorMessage,
  });

  ReportState copyWith({
    ReportPhase? phase,
    SessionReport? report,
    String? errorMessage,
  }) {
    return ReportState(
      phase: phase ?? this.phase,
      report: report,
      errorMessage: errorMessage,
    );
  }
}

final reportLocalDatasource = Provider((_) => ReportLocalDatasource());
final historyLocalDatasource = Provider((_) => HistoryLocalDatasource());

final reportProvider =
    StateNotifierProvider<ReportNotifier, ReportState>((ref) {
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

  ReportNotifier(this._api, this._reportRepo, this._historyRepo)
      : super(const ReportState());

  Future<void> generate({
    required InterviewType interviewType,
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
    required int totalDurationSeconds,
  }) async {
    state = state.copyWith(phase: ReportPhase.generating);
    final id = _uuid.v4();

    List<ImprovementPoint> improvements;
    bool aiFeedbackAvailable = true;

    try {
      improvements = await _api.generateFeedback(
        qaList: qaList,
        gazeMetrics: gazeMetrics,
      );
    } on Exception {
      aiFeedbackAvailable = false;
      improvements = _fallbackImprovements(gazeMetrics);
    }

    final report = SessionReport(
      id: id,
      createdAt: DateTime.now(),
      interviewType: interviewType,
      gazeMetrics: gazeMetrics,
      qaList: qaList,
      totalQuestions: qaList.length,
      totalDurationSeconds: totalDurationSeconds,
      improvementPoints: improvements,
      isAiFeedbackAvailable: aiFeedbackAvailable,
    );

    _reportRepo.save(report);
    _historyRepo.save(SessionHistoryItem(
      id: id,
      createdAt: report.createdAt,
      interviewType: interviewType,
      position: '',
      company: '',
      gazeRate: gazeMetrics.gazeRate,
      distractionCount: gazeMetrics.distractionCount,
      totalQuestions: qaList.length,
      totalDurationSeconds: totalDurationSeconds,
    ));

    state = state.copyWith(phase: ReportPhase.done, report: report);
  }

  SessionReport? loadById(String id) => _reportRepo.load(id);

  // AI 실패 시 시선 지표만으로 최소 피드백 제공
  List<ImprovementPoint> _fallbackImprovements(GazeMetrics gaze) {
    if (gaze.gazeRate < 60) {
      return [
        const ImprovementPoint(
          title: '화면 응시 유지',
          description: '면접 중 카메라를 더 자주 바라보는 연습이 필요합니다.',
          evidenceMetric: '화면 응시율',
        ),
      ];
    }
    return [];
  }
}
