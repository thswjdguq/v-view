import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/interview/interview_provider.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../../theme/app_theme.dart';
import '../interview/interview_screen.dart';

/// Prepares the session without exposing future questions.
class QuestionListScreen extends ConsumerStatefulWidget {
  const QuestionListScreen({super.key});
  @override
  ConsumerState<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends ConsumerState<QuestionListScreen> {
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    ref.read(interviewProvider.notifier).reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    await ref
        .read(interviewProvider.notifier)
        .start(ref.read(sessionInputProvider));
    if (!mounted || _opening) return;
    final state = ref.read(interviewProvider);
    if (state.phase != InterviewPhase.inProgress || state.questions.isEmpty) {
      return;
    }
    _opening = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const InterviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(interviewProvider).errorMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('면접 준비')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                error == null ? Icons.forum_rounded : Icons.cloud_off_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                error == null ? '지원 자료를 읽고 있어요' : '질문을 준비하지 못했어요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                error ?? '준비되면 첫 질문부터 시작해요.\n앞으로 나올 질문은 미리 보여드리지 않아요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (error == null)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _prepare,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
