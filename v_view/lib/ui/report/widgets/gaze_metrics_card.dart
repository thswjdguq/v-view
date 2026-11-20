import 'package:flutter/material.dart';
import '../../../domain/gaze/gaze_metrics.dart';
import '../../../theme/app_theme.dart';

class GazeMetricsCard extends StatelessWidget {
  final GazeMetrics metrics;

  const GazeMetricsCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final available = metrics.quality != GazeQuality.unavailable;
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '시선 분석',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.onSurface,
                ),
              ),
              if (metrics.quality != GazeQuality.normal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    available ? '참고용' : '측정 불가',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '얼굴 방향으로 카메라 응시 상태를 추정한 참고 지표예요.',
            style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
          ),
          if (metrics.qualityNote != null) ...[
            const SizedBox(height: 8),
            Text(
              metrics.qualityNote!,
              style: const TextStyle(color: AppColors.secondary, height: 1.5),
            ),
          ],
          const SizedBox(height: 16),
          if (available) ...[
            Text(
              '${metrics.gazeRate.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (metrics.gazeRate / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: AppColors.primaryContainer,
                backgroundColor: AppColors.surfaceContainerHigh,
                semanticsLabel: '화면 응시율',
                semanticsValue: '${metrics.gazeRate.toStringAsFixed(1)}%',
              ),
            ),
            const SizedBox(height: 16),
            _MetricRow(
              label: '시선 분산 횟수',
              value: '${metrics.distractionCount}회',
            ),
            _MetricRow(
              label: '시선 분산 총 시간',
              value: '${metrics.totalDistractionSeconds.toStringAsFixed(1)}초',
            ),
            _MetricRow(
              label: '최장 분산 시간',
              value: '${metrics.maxDistractionSeconds.toStringAsFixed(1)}초',
            ),
          ] else
            const Text(
              '얼굴 감지 정보가 충분하지 않아 응시율을 표시하지 않았어요. 다음 연습에서 카메라와 조명을 확인해 주세요.',
              style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
