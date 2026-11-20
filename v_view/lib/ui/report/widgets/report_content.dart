import 'package:flutter/material.dart';
import '../../../domain/report/session_report.dart';
import '../../../domain/report/report_comparison.dart';
import '../../../theme/app_theme.dart';
import 'gaze_metrics_card.dart';
import 'improvement_list.dart';
import 'qa_summary_list.dart';
import 'session_summary_card.dart';
import 'report_comparison_card.dart';

/// 새로 생성한 결과와 저장된 기록에서 같은 리포트를 표시한다.
class ReportContent extends StatelessWidget {
  const ReportContent({
    super.key,
    required this.report,
    this.comparison,
    this.isDemo = false,
    this.feedbackAction,
  });

  final SessionReport report;
  final ReportComparison? comparison;
  final bool isDemo;
  final Widget? feedbackAction;

  @override
  Widget build(BuildContext context) {
    final answered = report.qaList
        .where((qa) => qa.userAnswer.trim().isNotEmpty)
        .length;
    final total = report.qaList.length;
    final completion = total == 0 ? 0.0 : answered / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '연습을 돌아볼 시간이에요',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '측정 결과와 내 답변을 확인하고 다음 연습 목표를 정해 보세요.',
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 20),
        SessionSummaryCard(report: report),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '답변 완료율',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(completion * 100).round()}%',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '$answered / $total개 답변',
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 8,
                  color: AppColors.primaryContainer,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  semanticsLabel: '답변 완료율',
                  semanticsValue: '${(completion * 100).round()}%',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '내용을 입력한 질문의 비율이며, 답변의 질을 평가한 점수는 아니에요.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GazeMetricsCard(metrics: report.gazeMetrics),
        const SizedBox(height: 16),
        ReportComparisonCard(comparison: comparison),
        const SizedBox(height: 24),
        Text(
          isDemo
              ? '샘플 피드백'
              : (report.isAiFeedbackAvailable ? 'AI 피드백' : '지표 기반 피드백'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isDemo
              ? '샘플 규칙으로 제공하는 안내이며, 실제 AI가 답변을 평가한 결과가 아니에요.'
              : report.isAiFeedbackAvailable
              ? '답변과 응시 지표를 바탕으로 생성한 연습 제안이에요.'
              : 'AI 연결이 원활하지 않아 측정 지표를 바탕으로 안내해요.',
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        ?feedbackAction,
        const SizedBox(height: 16),
        if (report.improvementPoints.isNotEmpty)
          ImprovementList(points: report.improvementPoints)
        else
          const Text(
            '이번 연습에는 생성된 개선 의견이 없어요. 아래에서 내 답변을 돌아보세요.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        const SizedBox(height: 24),
        QaSummaryList(qaList: report.qaList),
      ],
    );
  }
}
