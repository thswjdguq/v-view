import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Replaces the device recognizer while exercising the real SpeechService.
class FakeSpeechRecognizer extends Fake implements SpeechToText {
  bool available = true;
  bool listening = false;
  bool finalizeOnStop = true;
  Completer<void>? stopGate;
  Completer<void>? listenGate;
  SpeechResultListener? _onResult;
  SpeechStatusListener? _onStatus;
  SpeechErrorListener? _onError;
  String lastWords = '';

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<SpeechConfigOption>? options,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    return available;
  }

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    _onResult = onResult;
    if (listenGate != null) await listenGate!.future;
    lastWords = '';
    listening = true;
    _onStatus?.call(SpeechToText.listeningStatus);
  }

  void recognize(String words, {bool finalResult = false}) {
    lastWords = words;
    _onResult?.call(
      SpeechRecognitionResult([
        SpeechRecognitionWords(words, null, 1),
      ], finalResult ? ResultType.finalResult.value : ResultType.partial.value),
    );
  }

  void completeRecognition() {
    listening = false;
    _onStatus?.call(SpeechToText.doneStatus);
  }

  void fail(String code) {
    listening = false;
    _onError?.call(SpeechRecognitionError(code, true));
  }

  @override
  Future<void> stop() async {
    if (stopGate != null) await stopGate!.future;
    if (!finalizeOnStop) return;
    if (lastWords.isNotEmpty) recognize(lastWords, finalResult: true);
    completeRecognition();
  }

  @override
  Future<void> cancel() async {
    listening = false;
  }
}
