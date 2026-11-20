import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/report/report_comparison.dart';
import '../../../theme/app_theme.dart';

class ReportComparisonCard extends StatelessWidget {
  const ReportComparisonCard({super.key, this.comparison});
  final ReportComparison? comparison;

  @override
  Widget build(BuildContext context) {
    final value = comparison;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '지난 연습과 비교',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (value == null)
            const Text(
              '같은 면접 유형·직무·회사의 기록이 쌓이면 변화를 비교할 수 있어요.',
              style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
            )
          else ...[
            Text(
              '${DateFormat('M월 d일 HH:mm').format(value.previous.createdAt)} 연습과 비교해요.',
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _ComparisonRow(
              label: '답변 완료율',
              value: _change(value.completionChange, '%p'),
            ),
            _ComparisonRow(
              label: '응시율',
              value: _change(value.gazeChange, '%p'),
            ),
            _ComparisonRow(
              label: '평균 답변 시간',
              value: _change(value.averageAnswerSecondsChange, '초'),
            ),
            const SizedBox(height: 8),
            const Text(
              '같은 면접 유형·직무·회사 기준이에요. 질문은 달라질 수 있으며 시간 변화는 연습을 돌아보는 참고값이에요.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _change(double? value, String unit) {
    if (value == null) return '비교할 측정 없음';
    if (value.abs() < 0.05) return '변화 없음';
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}$unit';
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );
}
