import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../domain/gaze/gaze_metrics.dart';

class GazeMetricsCard extends StatelessWidget {
  final GazeMetrics metrics;

  const GazeMetricsCard({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '시선 분석',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (metrics.quality != GazeQuality.normal) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      metrics.quality == GazeQuality.unavailable
                          ? '측정 불가'
                          : '참고용',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.orange.shade100,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            if (metrics.qualityNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  metrics.qualityNote!,
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: metrics.gazeRate,
                      title: '${metrics.gazeRate.toStringAsFixed(0)}%',
                      color: Colors.blue,
                    ),
                    PieChartSectionData(
                      value: 100 - metrics.gazeRate,
                      title: '',
                      color: Colors.grey.shade200,
                    ),
                  ],
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MetricRow(label: '화면 응시율', value: '${metrics.gazeRate.toStringAsFixed(1)}%'),
            _MetricRow(label: '시선 분산 횟수', value: '${metrics.distractionCount}회'),
            _MetricRow(
              label: '시선 분산 총 시간',
              value: '${metrics.totalDistractionSeconds.toStringAsFixed(1)}초',
            ),
            _MetricRow(
              label: '최장 분산 시간',
              value: '${metrics.maxDistractionSeconds.toStringAsFixed(1)}초',
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
