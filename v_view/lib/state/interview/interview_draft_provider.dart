import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/interview_draft_datasource.dart';
import '../../domain/interview/interview_draft.dart';

final interviewDraftStoreProvider = Provider<InterviewDraftDatasource?>(
  (_) => null,
);
final savedInterviewDraftProvider = StateProvider<InterviewDraft?>(
  (ref) => ref.read(interviewDraftStoreProvider)?.load(),
);
