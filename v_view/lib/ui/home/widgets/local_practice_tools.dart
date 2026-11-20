import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../state/interview/interview_draft_provider.dart';
import '../../../state/interview/interview_provider.dart';
import '../../../state/gaze/gaze_provider.dart';
import '../../../state/session_setup/session_setup_provider.dart';
import '../../../state/local_connection_provider.dart';
import '../../interview/interview_screen.dart';
import '../../report/report_screen.dart';

Future<bool> confirmReplacingDraft(BuildContext context, WidgetRef ref) async {
  await ref.read(interviewProvider.notifier).flushDraft();
  if (!context.mounted) return false;
  if (ref.read(savedInterviewDraftProvider) == null) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('새 연습을 시작할까요?'),
          content: const Text('진행 중인 임시 기록은 새 연습으로 바뀝니다. 저장한 리포트는 유지돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('돌아가기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새 연습 시작'),
            ),
          ],
        ),
      ) ??
      false;
}

class LocalPracticeTools extends ConsumerWidget {
  const LocalPracticeTools({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(localConnectionProvider);
    final draft = ref.watch(savedInterviewDraftProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2EAE5), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.computer_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connection.when(
                          data: (ready) => ready ? 'PC 연결됨' : 'PC 연결 확인 필요',
                          loading: () => 'PC 연결 확인 중…',
                          error: (_, _) => 'PC 연결 확인 필요',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'PC 연결 다시 확인',
                      onPressed: () => ref.invalidate(localConnectionProvider),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (draft != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '저장된 연습이 있어요',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${draft.input.position} · 답변 ${draft.answers.values.where((answer) => answer.trim().isNotEmpty).length}개',
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(sessionInputProvider.notifier)
                          .update(draft.input);
                      ref.read(interviewProvider.notifier).restoreDraft(draft);
                      ref.read(gazeProvider.notifier).reset();
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => draft.finished
                              ? const ReportScreen()
                              : const InterviewScreen(),
                        ),
                      );
                    },
                    child: Text(draft.finished ? '리포트 만들기' : '연습 이어하기'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final discard = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('임시 기록을 지울까요?'),
                          content: const Text(
                            '이 연습의 작성 중 답변을 지웁니다. 저장된 리포트는 유지돼요.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('임시 기록 지우기'),
                            ),
                          ],
                        ),
                      );
                      if (discard == true) {
                        await ref
                            .read(interviewProvider.notifier)
                            .completeDraft(draft.sessionId);
                      }
                    },
                    child: const Text('임시 기록 지우기'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
