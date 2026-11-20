import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interview/interview_provider.dart';

final localConnectionProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(claudeApiServiceProvider).checkLocalConnection(),
);
