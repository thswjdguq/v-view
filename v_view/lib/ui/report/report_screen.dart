import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../domain/interview/interview_question.dart';
import '../../domain/gaze/gaze_metrics.dart';
import '../../state/gaze/gaze_provider.dart';
import '../../state/app_mode_provider.dart';
import '../../state/history/history_provider.dart';
import '../../state/interview/interview_provider.dart';
import '../../state/report/report_provider.dart';
import '../../state/report/report_comparison_provider.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../history/history_list_screen.dart';
import '../session_setup/session_setup_screen.dart';
import 'widgets/report_content.dart';
import 'widgets/report_copy_button.dart';
import 'widgets/feedback_retry_panel.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _generationStarted = false;
  String? _sessionId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateReport());
  }

  Future<void> _generateReport() async {
    if (!mounted) return;
    final interviewState = ref.read(interviewProvider);
    _sessionId = interviewState.sessionId;
    await ref.read(interviewProvider.notifier).flushDraft();
    if (!mounted) return;
    _generationStarted = true;
    final gazeState = ref.read(gazeProvider);
    final sessionInput = ref.read(sessionInputProvider);
    var gazeMetrics =
        gazeState.latestMetrics ??
        ref.read(gazeProvider.notifier).computeFinalMetrics();
    if (!sessionInput.cameraEnabled) gazeMetrics = GazeMetrics.cameraDisabled;
    if (interviewState.recoveredFromDraft &&
        gazeMetrics.quality != GazeQuality.unavailable) {
      gazeMetrics = GazeMetrics(
        gazeRate: gazeMetrics.gazeRate,
        distractionCount: gazeMetrics.distractionCount,
        totalDistractionSeconds: gazeMetrics.totalDistractionSeconds,
        maxDistractionSeconds: gazeMetrics.maxDistractionSeconds,
        quality: GazeQuality.reference,
        qualityNote: '앱을 다시 연 뒤 측정한 구간만 포함하는 참고 지표입니다.',
      );
    }

    final qaList = interviewState.questions.map((q) {
      final answer = interviewState.userAnswers[q.id] ?? '';
      return QuestionAnswer(
        question: q,
        userAnswer: answer,
        answerDurationSeconds: interviewState.answerDurations[q.id] ?? 0,
      );
    }).toList();

    await ref
        .read(reportProvider.notifier)
        .generate(
          interviewType: sessionInput.type,
          position: sessionInput.position,
          company: sessionInput.company,
          qaList: qaList,
          gazeMetrics: gazeMetrics,
          totalDurationSeconds: interviewState.elapsedSeconds,
        );

    // generate()가 기록을 Hive에 저장하므로 히스토리 목록을 새로고침
    if (mounted) ref.read(historyProvider.notifier).load();
    if (mounted &&
        ref.read(reportProvider).phase == ReportPhase.done &&
        _sessionId != null) {
      await ref.read(interviewProvider.notifier).completeDraft(_sessionId!);
    }
  }

  Future<void> _retrySave() async {
    await ref.read(reportProvider.notifier).retrySave();
    if (mounted) ref.read(historyProvider.notifier).load();
    if (mounted &&
        ref.read(reportProvider).phase == ReportPhase.done &&
        _sessionId != null) {
      await ref.read(interviewProvider.notifier).completeDraft(_sessionId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        title: const Text('면접 리포트'),
        actions: [
          if (_generationStarted &&
              state.phase != ReportPhase.generating &&
              state.report != null)
            ReportCopyButton(
              report: state.report!,
              isDemo: ref.watch(isDemoModeProvider),
            ),
        ],
      ),
      body: !_generationStarted
          ? const _GeneratingView()
          : switch (state.phase) {
              ReportPhase.generating => const _GeneratingView(),
              _ when state.report != null => _buildReport(context, state),
              ReportPhase.error => _ErrorView(
                message: state.errorMessage,
                onRetry: _generateReport,
              ),
              _ => const SizedBox.shrink(),
            },
    );
  }

  Widget _buildReport(BuildContext context, ReportState state) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ReportContent(
              report: state.report!,
              isDemo: ref.watch(isDemoModeProvider),
              comparison: ref.watch(reportComparisonProvider(state.report!)),
              feedbackAction:
                  state.phase == ReportPhase.done &&
                      !ref.watch(isDemoModeProvider)
                  ? FeedbackRetryPanel(reportId: state.report!.id)
                  : null,
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: state.phase != ReportPhase.done
              ? _SaveStatus(state: state, onRetry: _retrySave)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '기록에 자동 저장됐어요',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _DuoButton(
                      label: '다시 연습하기',
                      icon: Icons.replay_rounded,
                      onPressed: () {
                        ref.read(interviewProvider.notifier).reset();
                        ref.read(gazeProvider.notifier).reset();
                        final navigator = Navigator.of(context);
                        navigator.popUntil((route) => route.isFirst);
                        navigator.push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SessionSetupScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _OutlineButton(
                      label: '기록 보기',
                      icon: Icons.history_rounded,
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (_) => const HistoryListScreen(),
                        ),
                        (route) => route.isFirst,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.state, required this.onRetry});
  final ReportState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.phase == ReportPhase.saving) {
      return const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('기록을 저장하고 있어요')),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.errorMessage ?? '기록을 저장하지 못했어요.',
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '앱을 닫기 전에 상단 복사 버튼으로 답변과 피드백을 보관할 수 있어요.',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.save_outlined),
          label: const Text('저장 다시 시도'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ── Generating view ────────────────────────────────────────────────────────

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 40,
              color: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: AppColors.primaryContainer,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'AI가 피드백을 생성 중입니다...',
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  const _ErrorView({required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            message ?? '리포트 생성에 실패했습니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _DuoButton(label: '다시 시도', onPressed: onRetry),
        ],
      ),
    );
  }
}

// ── Duo CTA button ─────────────────────────────────────────────────────────

class _DuoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const _DuoButton({required this.label, required this.onPressed, this.icon});

  @override
  State<_DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<_DuoButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: double.infinity,
        margin: EdgeInsets.only(top: _pressed ? 4 : 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: _pressed
              ? null
              : Border(
                  bottom: BorderSide(color: AppColors.primaryShadow, width: 4),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: AppColors.onPrimaryContainer, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.onPrimaryContainer,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Outline button ─────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const _OutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: 20, color: AppColors.primary)
            : const SizedBox.shrink(),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: const BorderSide(color: AppColors.primaryContainer, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
