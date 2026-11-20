import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/report/report_provider.dart';

class FeedbackRetryPanel extends ConsumerWidget {
  const FeedbackRetryPanel({super.key, required this.reportId});
  final String reportId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      reportProvider.select((state) => state.feedbackRetries[reportId]),
    );
    final report = ref.read(reportProvider.notifier).loadById(reportId);
    if (report == null ||
        (report.isAiFeedbackAvailable && status?.hasPendingSave != true)) {
      return const SizedBox.shrink();
    }
    final hasAnswer = report.qaList.any(
      (qa) => qa.userAnswer.trim().isNotEmpty,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status?.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                status!.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          OutlinedButton.icon(
            onPressed: status?.busy == true || !hasAnswer
                ? null
                : () =>
                      ref.read(reportProvider.notifier).retryFeedback(reportId),
            icon: status?.busy == true
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              status?.busy == true
                  ? '처리 중…'
                  : status?.hasPendingSave == true
                  ? '평가 저장 다시 시도'
                  : '저장한 답변으로 AI 평가 받기',
            ),
          ),
          Text(
            hasAnswer
                ? '버튼을 누르면 저장한 답변으로 GPT API를 요청해요.'
                : '평가할 답변이 저장되지 않았어요.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
