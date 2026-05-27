import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: const Text('면접 리포트'),
        actions: [
          if (state.phase == ReportPhase.done && state.report != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '리포트 복사',
              onPressed: () => _copyToClipboard(context, state),
            ),
        ],
      ),
      body: switch (state.phase) {
        ReportPhase.generating => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('AI가 피드백을 생성 중입니다...'),
              ],
            ),
          ),
        ReportPhase.done when state.report != null => _buildReport(
            context, state),
        ReportPhase.error => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('리포트 생성에 실패했습니다.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _generateReport,
                  child: const Text('다시 시도'),
                ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!report.isAiFeedbackAvailable)
            const Card(
              color: Colors.amber,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('AI 피드백 생성에 실패하여 시선 지표만 제공됩니다.'),
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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  Navigator.popUntil(context, (r) => r.isFirst),
              child: const Text('홈으로'),
            ),
          ),
        ],
      ),
    );
  }
}
