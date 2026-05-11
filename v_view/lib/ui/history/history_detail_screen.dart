import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/report/report_provider.dart';
import '../report/widgets/gaze_metrics_card.dart';
import '../report/widgets/improvement_list.dart';
import '../report/widgets/qa_summary_list.dart';

class HistoryDetailScreen extends ConsumerWidget {
  final String reportId;

  const HistoryDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.read(reportProvider.notifier).loadById(reportId);

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('리포트')),
        body: const Center(child: Text('리포트를 불러올 수 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('면접 리포트')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GazeMetricsCard(metrics: report.gazeMetrics),
            const SizedBox(height: 16),
            if (report.improvementPoints.isNotEmpty) ...[
              ImprovementList(points: report.improvementPoints),
              const SizedBox(height: 16),
            ],
            QaSummaryList(qaList: report.qaList),
          ],
        ),
      ),
    );
  }
}
