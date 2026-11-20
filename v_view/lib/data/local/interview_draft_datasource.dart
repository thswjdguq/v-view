import '../../domain/interview/interview_draft.dart';
import 'hive_service.dart';

class InterviewDraftDatasource {
  static const key = 'active_interview';
  InterviewDraft? load() {
    try {
      final raw = HiveService.sessionBox.get(key);
      return raw == null ? null : InterviewDraft.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(InterviewDraft draft) =>
      HiveService.sessionBox.put(key, draft.toMap());
  Future<void> clearIfSession(String id) async {
    if (HiveService.sessionBox.get(key)?['sessionId'] == id) {
      await HiveService.sessionBox.delete(key);
    }
  }
}
