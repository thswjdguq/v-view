import '../../local/hive_service.dart';
import '../../../domain/session_setup/session_input.dart';

class SessionInputLocalDatasource {
  static const _key = 'last_input';

  Future<void> save(SessionInput input) =>
      HiveService.sessionInputBox.put(_key, input.toMap());

  void clear() {
    HiveService.sessionInputBox.delete(_key);
  }

  SessionInput? load() {
    final raw = HiveService.sessionInputBox.get(_key);
    if (raw == null) return null;
    try {
      return SessionInput.fromMap(raw);
    } catch (_) {
      return null;
    }
  }
}
