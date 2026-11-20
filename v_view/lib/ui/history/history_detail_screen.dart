import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/report/report_provider.dart';
import '../../state/app_mode_provider.dart';
import '../../state/report/report_comparison_provider.dart';
import '../../theme/app_theme.dart';
import '../report/widgets/report_content.dart';
import '../report/widgets/report_copy_button.dart';
import '../report/widgets/feedback_retry_panel.dart';
import '../report/widgets/repractice_button.dart';

class HistoryDetailScreen extends ConsumerWidget {
  final String reportId;

  const HistoryDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      reportProvider.select((state) => state.feedbackRetries[reportId]),
    );
    final report = ref.read(reportProvider.notifier).loadById(reportId);

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('리포트')),
        body: const Center(child: Text('리포트를 불러올 수 없습니다.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('면접 리포트'),
        actions: [
          ReportCopyButton(
            report: report,
            isDemo: ref.watch(isDemoModeProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReportContent(
              report: report,
              isDemo: ref.watch(isDemoModeProvider),
              comparison: ref.watch(reportComparisonProvider(report)),
              feedbackAction: ref.watch(isDemoModeProvider)
                  ? null
                  : FeedbackRetryPanel(reportId: reportId),
            ),
            if (report.qaList.any((qa) => !qa.question.isFollowUp))
              RepracticeButton(report: report),
          ],
        ),
      ),
    );
  }
}
