import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/interview/interview_provider.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../../state/gaze/gaze_provider.dart';
import '../report/report_screen.dart';
import '../common/error_display.dart';
import 'widgets/question_card.dart';
import 'widgets/timer_widget.dart';

class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({super.key});

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _answerController = TextEditingController();
  static const _defaultTimerSeconds = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused) {
      _pauseSession();
    }
  }

  void _startSession() {
    final input = ref.read(sessionInputProvider);
    ref.read(gazeProvider.notifier).start();
    ref.read(interviewProvider.notifier).start(input);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    ref.read(interviewProvider.notifier).resetTimer(_defaultTimerSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final phase = ref.read(interviewProvider).phase;
      if (phase == InterviewPhase.inProgress) {
        ref.read(interviewProvider.notifier).tickTimer();
      }
    });
  }

  void _pauseSession() {
    _timer?.cancel();
    ref.read(interviewProvider.notifier).pause();
  }

  void _resumeSession() {
    ref.read(interviewProvider.notifier).resume();
    _startTimer();
  }

  Future<void> _submitAndNext() async {
    final answer = _answerController.text.trim();
    _answerController.clear();
    _timer?.cancel();
    await ref.read(interviewProvider.notifier).nextQuestion(answer);
    _startTimer();
  }

  void _finishSession() {
    _timer?.cancel();
    ref.read(gazeProvider.notifier).stop();
    ref.read(interviewProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(interviewProvider);

    ref.listen(interviewProvider, (_, next) {
      if (next.phase == InterviewPhase.finished) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ReportScreen()),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => _showExitDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('모의 면접'),
          actions: [
            if (state.phase == InterviewPhase.inProgress)
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: _pauseSession,
              ),
          ],
        ),
        body: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, InterviewState state) {
    return switch (state.phase) {
      InterviewPhase.loadingQuestions => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AI가 맞춤 질문을 생성 중입니다...'),
            ],
          ),
        ),
      InterviewPhase.idle when state.errorMessage != null => ErrorDisplay(
          message: state.errorMessage!,
          onRetry: () {
            final input = ref.read(sessionInputProvider);
            ref.read(interviewProvider.notifier).start(input);
          },
        ),
      InterviewPhase.inProgress => _buildInterviewBody(context, state),
      InterviewPhase.paused => _buildPausedBody(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildInterviewBody(BuildContext context, InterviewState state) {
    final q = state.currentQuestion;
    if (q == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimerWidget(seconds: state.timerSeconds),
          const SizedBox(height: 16),
          QuestionCard(
            question: q,
            index: state.currentIndex,
            total: state.questions.length,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                hintText: '답변을 입력하세요...',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _showExitDialog,
                  child: const Text('면접 종료'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitAndNext,
                  child: Text(state.isLastQuestion ? '완료' : '다음 질문'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPausedBody(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('면접이 일시정지되었습니다.', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _resumeSession,
            child: const Text('재개'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _finishSession,
            child: const Text('종료 및 리포트 보기'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog([BuildContext? ctx]) {
    showDialog(
      context: ctx ?? context,
      builder: (_) => AlertDialog(
        title: const Text('면접 종료'),
        content: const Text('지금까지의 내용으로 리포트를 생성합니다. 종료할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _finishSession();
            },
            child: const Text('종료'),
          ),
        ],
      ),
    );
  }
}
