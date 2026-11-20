import 'dart:async';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechState {
  final bool isListening;
  final String? message;

  const SpeechState({this.isListening = false, this.message});
}

class SpeechService {
  SpeechService({SpeechToText? recognizer})
    : _stt = recognizer ?? SpeechToText();

  final SpeechToText _stt;
  final _textCtrl = StreamController<String>.broadcast();
  final _stateCtrl = StreamController<SpeechState>.broadcast();

  bool _available = false;
  bool _acceptResults = false;
  bool _disposed = false;
  int _session = 0;
  SpeechState _state = const SpeechState();
  Completer<void>? _finalResult;
  Future<void>? _stopping;
  Future<dynamic>? _starting;

  Stream<String> get textStream => _textCtrl.stream;
  Stream<SpeechState> get stateStream => _stateCtrl.stream;
  SpeechState get state => _state;
  bool get isListening => _state.isListening;

  Future<bool> initialize() async {
    if (_disposed) return false;
    if (_available) return true;
    try {
      _available = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      if (!_available) {
        _emit(false, '음성 인식을 사용할 수 없어요. 마이크·음성 인식 권한과 기기의 음성 인식 서비스를 확인해 주세요.');
      }
      return _available;
    } on Exception {
      _emit(false, '음성 인식을 시작하지 못했어요. 기기의 음성 인식 서비스와 마이크 권한을 확인해 주세요.');
      return false;
    }
  }

  Future<void> startListening({String initialText = ''}) async {
    if (_stopping != null) await _stopping;
    if (_disposed || isListening) return;
    if (!_available && !await initialize()) return;
    final session = ++_session;
    final prefix = initialText.trim();
    _acceptResults = true;
    _finalResult = Completer<void>();
    _emit(true);
    try {
      final starting = _stt.listen(
        onResult: (result) {
          if (_disposed || !_acceptResults || session != _session) return;
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _textCtrl.add(prefix.isEmpty ? words : '$prefix $words');
          }
          if (result.finalResult) _completeFinalResult();
        },
        listenOptions: SpeechListenOptions(
          localeId: 'ko_KR',
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      _starting = starting;
      await starting;
      if (!_disposed &&
          session == _session &&
          !_stt.isListening &&
          isListening) {
        _acceptResults = false;
        _emit(false, '음성 인식을 시작하지 못했어요. 마이크와 기기의 음성 인식 서비스를 확인해 주세요.');
      }
    } on Exception {
      _acceptResults = false;
      _emit(false, '음성 인식을 시작하지 못했어요. 잠시 후 마이크를 다시 눌러 주세요.');
    } finally {
      _starting = null;
    }
  }

  void _onStatus(String status) {
    if (_disposed) return;
    if (!_acceptResults && !isListening && _state.message != null) return;
    if (status == SpeechToText.listeningStatus && _acceptResults) {
      _emit(true);
    } else if (status == SpeechToText.doneStatus) {
      _acceptResults = false;
      _completeFinalResult();
      _emit(false, '음성 인식이 끝났어요. 마이크를 눌러 이어서 답변할 수 있어요.');
    } else if (status == SpeechToText.notListeningStatus) {
      _emit(false);
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (_disposed) return;
    _acceptResults = false;
    _completeFinalResult();
    final message = switch (error.errorMsg) {
      'error_network' ||
      'error_network_timeout' => '음성 인식 네트워크 연결을 확인하고 다시 시도해 주세요.',
      'error_permission' || 'error_insufficient_permissions' =>
        '마이크·음성 인식 권한이 필요해요. 앱 설정에서 권한을 허용해 주세요.',
      'error_no_match' ||
      'error_speech_timeout' => '음성이 감지되지 않았어요. 마이크를 다시 누르고 말씀해 주세요.',
      _ => '음성 인식이 중단됐어요. 입력된 답변은 유지되며 마이크를 다시 누를 수 있어요.',
    };
    _emit(false, message);
  }

  Future<void> stopListening() {
    if (_stopping != null) return _stopping!;
    if (_disposed || (!isListening && !_acceptResults)) return Future.value();
    return _stopping = _stopCurrentSession();
  }

  Future<void> _stopCurrentSession() async {
    try {
      await _starting;
      await _stt.stop();
      await _finalResult?.future.timeout(
        const Duration(milliseconds: 800),
        onTimeout: () {},
      );
    } on Exception {
      _emit(false, '음성 인식을 종료했어요. 입력된 답변을 확인해 주세요.');
    } finally {
      _acceptResults = false;
      _session++;
      _stopping = null;
      _emit(false, _state.message);
    }
  }

  void _completeFinalResult() {
    if (_finalResult != null && !_finalResult!.isCompleted) {
      _finalResult!.complete();
    }
  }

  void _emit(bool listening, [String? message]) {
    if (_disposed) return;
    _state = SpeechState(isListening: listening, message: message);
    _stateCtrl.add(_state);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _acceptResults = false;
    _session++;
    _completeFinalResult();
    try {
      await _starting;
      await _stt.cancel();
    } on Exception {
      // Some platforms do not provide a recognizer to cancel.
    }
    await _textCtrl.close();
    await _stateCtrl.close();
  }
}
