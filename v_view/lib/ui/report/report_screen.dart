import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../app.dart' show kPrimaryColor, kTextColor, kSuccessColor;
import '../../state/report/report_provider.dart';
import '../../state/interview/interview_provider.dart';
import '../../state/gaze/gaze_provider.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../../domain/interview/interview_question.dart';
import '../../domain/session_setup/session_input.dart';
import '../../state/history/history_provider.dart';
import 'widgets/gaze_metrics_card.dart';
import 'widgets/gaze_trend_chart.dart';
import 'widgets/improvement_list.dart';
import 'widgets/qa_summary_list.dart';
import 'widgets/session_summary_card.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateReport());
  }

  void _generateReport() {
    final interviewState = ref.read(interviewProvider);
    final gazeState = ref.read(gazeProvider);
    final sessionInput = ref.read(sessionInputProvider);
    final gazeMetrics = gazeState.latestMetrics ??
        ref.read(gazeProvider.notifier).computeFinalMetrics();

    final qaList = interviewState.questions.map((q) {
      final answer = interviewState.userAnswers[q.id] ?? '';
      return QuestionAnswer(
        question: q,
        userAnswer: answer,
        answerDurationSeconds: 0,
      );
    }).toList();

    ref.read(reportProvider.notifier).generate(
          interviewType: sessionInput.type,
          position: sessionInput.position,
          company: sessionInput.company,
          qaList: qaList,
          gazeMetrics: gazeMetrics,
          totalDurationSeconds: interviewState.elapsedSeconds,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('면접 리포트', style: const TextStyle(color: kTextColor, fontWeight: FontWeight.w800)),
        actions: [
          if (state.phase == ReportPhase.done && state.report != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: kTextColor),
              tooltip: '리포트 복사',
              onPressed: () => _copyToClipboard(context, state),
            ),
        ],
      ),
      body: switch (state.phase) {
        ReportPhase.generating => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: kSuccessColor),
                const SizedBox(height: 16),
                Text(
                  'AI가 피드백을 생성 중입니다...',
                  style: const TextStyle(color: kTextColor, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ReportPhase.done when state.report != null => _buildReport(
            context, state),
        ReportPhase.error => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('리포트 생성에 실패했습니다.', style: TextStyle(color: kTextColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _DuoButton(label: '다시 시도', onPressed: _generateReport),
              ],
            ),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Future<void> _copyToClipboard(BuildContext context, ReportState state) async {
    final report = state.report!;
    final typeName = switch (report.interviewType) {
      InterviewType.job => '직무면접',
      InterviewType.personality => '인성면접',
      InterviewType.university => '대학입시면접',
    };
    final buf = StringBuffer();
    buf.writeln('v-view 면접 리포트');
    buf.writeln('면접 유형: $typeName');
    buf.writeln('화면 응시율: ${report.gazeMetrics.gazeRate.toStringAsFixed(0)}%');
    buf.writeln('시선 분산: ${report.gazeMetrics.distractionCount}회');
    if (report.improvementPoints.isNotEmpty) {
      buf.writeln();
      buf.writeln('개선 포인트');
      for (int i = 0; i < report.improvementPoints.length; i++) {
        final p = report.improvementPoints[i];
        buf.writeln('${i + 1}. ${p.title}: ${p.description}');
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리포트가 클립보드에 복사됐습니다.')),
      );
    }
  }

  Widget _buildReport(BuildContext context, ReportState state) {
    final report = state.report!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SuccessHeader(gazeRate: report.gazeMetrics.gazeRate),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!report.isAiFeedbackAvailable)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9600).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'AI 피드백 생성에 실패하여 시선 지표만 제공됩니다.',
                            style: TextStyle(color: kTextColor, fontWeight: FontWeight.w700),
                          ),
                        ),
                      SessionSummaryCard(report: report),
                      const SizedBox(height: 16),
                      GazeMetricsCard(metrics: report.gazeMetrics),
                      const SizedBox(height: 16),
                      GazeTrendChart(
                        recentSessions: ref.read(historyProvider),
                      ),
                      const SizedBox(height: 16),
                      if (report.improvementPoints.isNotEmpty) ...[
                        ImprovementList(points: report.improvementPoints),
                        const SizedBox(height: 16),
                      ],
                      QaSummaryList(qaList: report.qaList),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: _DuoButton(
            label: '계속하기',
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ),
      ],
    );
  }
}

/// Duolingo 스타일 성공 헤더 — 초록 배경 + 등장 애니메이션 + 큰 숫자 강조
class _SuccessHeader extends StatelessWidget {
  final double gazeRate;
  const _SuccessHeader({required this.gazeRate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
      decoration: const BoxDecoration(
        color: kSuccessColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Bounce(
            from: 16,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_rounded, color: kSuccessColor, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '면접 연습을 완료했어요!',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            from: 12,
            child: Column(
              children: [
                Text(
                  '${gazeRate.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900),
                ),
                const Text(
                  '화면 응시율',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Duolingo 스타일 큰 CTA 버튼 — 두꺼운 하단 그림자, 누르면 아래로 이동
class _DuoButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const _DuoButton({required this.label, required this.onPressed});

  @override
  State<_DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<_DuoButton> {
  bool _pressed = false;

  static const _shadowColor = Color(0xFF3730A3);

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
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(16),
          border: Border(bottom: BorderSide(color: _shadowColor, width: _pressed ? 0 : 4)),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
