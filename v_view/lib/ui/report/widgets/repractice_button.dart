import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/report/session_report.dart';
import '../../../state/app_mode_provider.dart';
import '../../../state/history/history_provider.dart';
import '../../../state/interview/interview_provider.dart';
import '../../../state/session_setup/session_setup_provider.dart';
import '../../../state/gaze/gaze_provider.dart';
import '../../../state/local_connection_provider.dart';
import '../../home/widgets/local_practice_tools.dart';
import '../../interview/interview_screen.dart';

class RepracticeButton extends ConsumerStatefulWidget {
  const RepracticeButton({super.key, required this.report});
  final SessionReport report;
  @override
  ConsumerState<RepracticeButton> createState() => _RepracticeButtonState();
}

class _RepracticeButtonState extends ConsumerState<RepracticeButton> {
  bool _busy = false;
  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (ref.read(isLocalAiModeProvider)) {
        ref.invalidate(localConnectionProvider);
        if (!await ref.read(localConnectionProvider.future)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PC의 로컬 AI 연결을 먼저 확인해 주세요.')),
            );
          }
          return;
        }
        if (!mounted ||
            !await confirmReplacingDraft(context, ref) ||
            !mounted) {
          return;
        }
      }
      final report = widget.report;
      final base = report.qaList
          .where((qa) => !qa.question.isFollowUp)
          .map((qa) => qa.question)
          .toList();
      if (base.isEmpty) return;
      final summary = ref
          .read(historyProvider)
          .where((item) => item.id == report.id)
          .firstOrNull;
      final current = ref.read(sessionInputProvider);
      final input = current.copyWith(
        type: report.interviewType,
        position: summary?.position ?? current.position,
        company: summary?.company ?? current.company,
        timerMinutes: current.timerMinutes,
        questionCount: base.length,
      );
      ref.read(sessionInputProvider.notifier).update(input);
      ref.read(gazeProvider.notifier).reset();
      ref
          .read(interviewProvider.notifier)
          .startPrepared(input, base, referenceReportId: report.id);
      await ref.read(interviewProvider.notifier).flushDraft();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const InterviewScreen()),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: FilledButton.icon(
      onPressed: _busy ? null : _start,
      icon: const Icon(Icons.replay),
      label: const Text('피드백 보며 같은 질문으로 연습'),
    ),
  );
}
