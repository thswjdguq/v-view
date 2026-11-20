import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/speech_service.dart';

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
