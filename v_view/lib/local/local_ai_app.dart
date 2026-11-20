import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/history/history_local_datasource.dart';
import '../data/local/report/report_local_datasource.dart';
import '../data/local/interview_draft_datasource.dart';
import '../data/remote/ai/claude_api_service.dart';
import '../state/app_mode_provider.dart';
import '../state/auth/auth_provider.dart';
import '../state/interview/interview_provider.dart';
import '../state/interview/interview_draft_provider.dart';
import '../state/local_connection_provider.dart';
import '../state/report/report_provider.dart';
import '../theme/app_theme.dart';
import '../ui/home/home_screen.dart';

/// Real API and device input, with no Firebase initialization or sample data.
class LocalAiApp extends StatelessWidget {
  const LocalAiApp({super.key, this.api, this.textScaler});
  final ClaudeApiService? api;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      isLocalAiModeProvider.overrideWithValue(true),
      isDemoModeProvider.overrideWithValue(false),
      authStateProvider.overrideWith((_) => Stream.value(null)),
      claudeApiServiceProvider.overrideWith(
        (_) => api ?? ClaudeApiService.local(),
      ),
      interviewDraftStoreProvider.overrideWith(
        (_) => InterviewDraftDatasource(),
      ),
      savedInterviewDraftProvider.overrideWith(
        (ref) => ref.read(interviewDraftStoreProvider)?.load(),
      ),
      localConnectionProvider.overrideWith(
        (ref) => ref.read(claudeApiServiceProvider).checkLocalConnection(),
      ),
      interviewProvider.overrideWith(
        (ref) => InterviewNotifier(
          ref.read(claudeApiServiceProvider),
          draftStore: ref.read(interviewDraftStoreProvider),
          onDraftChanged: (draft) =>
              ref.read(savedInterviewDraftProvider.notifier).state = draft,
        ),
      ),
      reportProvider.overrideWith(
        (ref) => ReportNotifier(
          ref.read(claudeApiServiceProvider),
          ReportLocalDatasource(),
          HistoryLocalDatasource(),
        ),
      ),
    ],
    child: MaterialApp(
      title: 'v-view 로컬 AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryContainer,
        ),
        scaffoldBackgroundColor: AppColors.surface,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: textScaler ?? MediaQuery.textScalerOf(context)),
        child: child!,
      ),
      home: const HomeScreen(),
    ),
  );
}
