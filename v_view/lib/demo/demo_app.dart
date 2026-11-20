import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/history/history_local_datasource.dart';
import '../data/local/report/report_local_datasource.dart';
import '../state/app_mode_provider.dart';
import '../state/auth/auth_provider.dart';
import '../state/history/history_provider.dart';
import '../state/interview/interview_provider.dart';
import '../state/report/report_provider.dart';
import '../state/session_setup/session_setup_provider.dart';
import '../theme/app_theme.dart';
import '../ui/history/history_detail_screen.dart';
import '../ui/history/history_list_screen.dart';
import '../ui/questions/question_list_screen.dart';
import 'demo_api_service.dart';
import 'demo_fixtures.dart';

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      isDemoModeProvider.overrideWithValue(true),
      authStateProvider.overrideWith((_) => Stream.value(null)),
      claudeApiServiceProvider.overrideWithValue(DemoApiService()),
      sessionInputProvider.overrideWith((_) => SessionInputNotifier(demoInput)),
      demoAnswerProvider.overrideWith(
        (ref, question) =>
            buildDemoAnswer(question, ref.watch(sessionInputProvider).type),
      ),
      interviewProvider.overrideWith(
        (ref) => InterviewNotifier(ref.read(claudeApiServiceProvider)),
      ),
      reportProvider.overrideWith(
        (ref) => ReportNotifier(
          ref.read(claudeApiServiceProvider),
          ReportLocalDatasource(),
          HistoryLocalDatasource(),
          feedbackIsAi: false,
        ),
      ),
    ],
    child: MaterialApp(
      title: 'v-view 포트폴리오 데모',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryContainer,
        ),
        scaffoldBackgroundColor: AppColors.surface,
      ),
      builder: (context, child) => Material(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: const Text(
                  'DEMO · 가상 데이터 · 실제 AI 평가가 아닙니다',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: child!),
            ],
          ),
        ),
      ),
      home: const _DemoHome(),
    ),
  );
}

class _DemoHome extends ConsumerWidget {
  const _DemoHome();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('v-view 체험하기')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          Icons.record_voice_over_rounded,
          size: 64,
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        const Text(
          '면접 연습을 기록하고\n다음 답변을 준비하세요',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            await seedDemoData(restoreSamples: true);
            ref.read(historyProvider.notifier).load();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('샘플 기록 2개를 다시 넣었어요.')),
              );
            }
          },
          child: const Text('샘플 기록 다시 넣기'),
        ),
        const Text(
          '로그인과 API 키 없이 질문 → 텍스트 답변 → 리포트 → 기록 흐름을 체험할 수 있어요.\n\n샘플 기록의 수치는 가상 데이터입니다. 이 데모는 외부 AI·카메라·마이크를 사용하지 않으며, 작성한 답변은 이 기기의 데모 전용 저장소에 남습니다.',
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('샘플 질문으로 연습하기'),
          onPressed: () {
            ref.read(sessionInputProvider.notifier).update(demoInput);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const QuestionListScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.assessment_outlined),
          label: const Text('샘플 리포트 보기'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const HistoryDetailScreen(reportId: 'demo-current'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.history),
          label: const Text('연습 기록 보기'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HistoryListScreen()),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '샘플 리포트에서는 답변 완료율, 질문별 답변·시간, 지난 연습과의 변화량을 확인해보세요.',
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
      ],
    ),
  );
}
