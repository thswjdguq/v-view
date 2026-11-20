import 'dart:async';
import 'package:camera/camera.dart';
import '../../services/speech_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../data/remote/gaze/camera_frame_converter.dart';
import '../../state/interview/interview_provider.dart';
import '../../state/interview/speech_provider.dart';
import '../../state/app_mode_provider.dart';
import '../../state/session_setup/session_setup_provider.dart';
import '../../state/gaze/gaze_provider.dart';
import '../../state/report/report_provider.dart';
import '../../domain/report/session_report.dart';
import '../report/report_screen.dart';
import '../common/error_display.dart';
import 'widgets/question_card.dart';
import 'widgets/timer_widget.dart';
import 'widgets/interview_camera_panel.dart';

class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({super.key});

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _answerController = TextEditingController();
  int get _defaultTimerSeconds =>
      ref.read(sessionInputProvider).timerMinutes * 60;

  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraError = false;
  bool _micDenied = false;
  bool _isSubmitting = false;
  bool _isFinishing = false;
  bool _allowLeave = false;
  bool _stoppingForTimeUp = false;
  bool get _cameraEnabled => ref.read(sessionInputProvider).cameraEnabled;

  SpeechService? _speechService;
  bool _sttActive = false;
  bool _speechStarting = false;
  String? _speechMessage;
  StreamSubscription<String>? _sttSub;
  StreamSubscription<SpeechState>? _speechStateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!ref.read(isDemoModeProvider)) _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(isDemoModeProvider) && _cameraEnabled) await _initCamera();
      if (!mounted) return;
      _startSession();
    });
  }

  Future<void> _initCamera() async {
    try {
      final micStatus = await Permission.microphone.status;
      if (mounted && micStatus.isPermanentlyDenied) {
        setState(() {
          _micDenied = true;
        });
      }
    } catch (_) {}

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraError = true;
          });
        }
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
      if (!kIsWeb) {
        await controller.startImageStream((image) {
          final inputImage = CameraFrameConverter.convert(
            image: image,
            camera: front,
          );
          if (inputImage != null) {
            ref.read(gazeProvider.notifier).processFrame(inputImage);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cameraError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    _cameraController?.dispose();
    _sttSub?.cancel();
    _speechStateSub?.cancel();
    _speechService?.stopListening();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initSpeech() {
    final service = ref.read(speechServiceProvider);
    _speechService = service;
    _sttSub = service.textStream.listen((text) {
      if (!mounted) return;
      _answerController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      ref.read(interviewProvider.notifier).submitAnswer(text);
    });
    _speechStateSub = service.stateStream.listen((speech) {
      if (!mounted) return;
      setState(() {
        _sttActive = speech.isListening;
        _speechMessage = speech.message;
      });
    });
  }

  Future<void> _toggleMic() async {
    final service = _speechService;
    final questionId = ref.read(interviewProvider).currentQuestion?.id;
    final current = ref.read(interviewProvider);
    if (service == null ||
        _speechStarting ||
        _isSubmitting ||
        _isFinishing ||
        _stoppingForTimeUp ||
        current.isPreparing ||
        current.isAnswerTimeUp) {
      return;
    }
    setState(() => _speechStarting = true);
    try {
      if (_sttActive) {
        await service.stopListening();
      } else {
        final available = await service.initialize();
        if (!mounted) return;
        if (!available) {
          if (!kIsWeb) {
            final permission = await Permission.microphone.status;
            if (!mounted) return;
            setState(() => _micDenied = !permission.isGranted);
          }
          return;
        }
        if (_isSubmitting ||
            _isFinishing ||
            ref.read(interviewProvider).currentQuestion?.id != questionId ||
            ref.read(interviewProvider).phase != InterviewPhase.inProgress) {
          return;
        }
        FocusScope.of(context).unfocus();
        setState(() => _micDenied = false);
        await service.startListening(initialText: _answerController.text);
      }
    } on Exception {
      if (mounted) {
        setState(
          () => _speechMessage = '마이크를 시작하지 못했어요. 권한과 기기의 음성 인식 서비스를 확인해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _speechStarting = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused) {
      _pauseSession();
      _cameraController?.stopImageStream();
    } else if (lifecycle == AppLifecycleState.resumed && !kIsWeb) {
      _cameraController?.startImageStream((image) {
        final camera = _cameraController?.description;
        if (camera == null) return;
        final inputImage = CameraFrameConverter.convert(
          image: image,
          camera: camera,
        );
        if (inputImage != null) {
          ref.read(gazeProvider.notifier).processFrame(inputImage);
        }
      });
    }
  }

  void _startSession() {
    final input = ref.read(sessionInputProvider);
    if (_cameraEnabled) ref.read(gazeProvider.notifier).start();
    final saved = ref.read(interviewProvider);
    _answerController.text = saved.userAnswers[saved.currentQuestion?.id] ?? '';
    if (saved.questions.isEmpty) {
      ref.read(interviewProvider.notifier).start(input);
    }
    if (saved.phase == InterviewPhase.paused) {
      ref.read(gazeProvider.notifier).pauseCapture();
    } else {
      _startTimer(reset: saved.elapsedSeconds == 0);
    }
    _syncGazeCapture();
  }

  void _syncGazeCapture() {
    final state = ref.read(interviewProvider);
    final gaze = ref.read(gazeProvider.notifier);
    if (_cameraEnabled &&
        _cameraReady &&
        !ref.read(isDemoModeProvider) &&
        state.phase == InterviewPhase.inProgress &&
        !state.isPreparing &&
        !state.isAnswerTimeUp &&
        !_isSubmitting &&
        !_stoppingForTimeUp) {
      gaze.resumeCapture();
    } else {
      gaze.pauseCapture();
    }
  }

  void _beginAnswerNow() {
    ref.read(interviewProvider.notifier).beginAnswer();
    _syncGazeCapture();
    _startTimer();
  }

  void _extendAnswerTime() {
    ref.read(interviewProvider.notifier).extendAnswerTime();
    _syncGazeCapture();
    _startTimer();
  }

  Future<void> _handleTimeUp() async {
    if (_stoppingForTimeUp || _isFinishing) return;
    final questionId = ref.read(interviewProvider).currentQuestion?.id;
    setState(() => _stoppingForTimeUp = true);
    _syncGazeCapture();
    ref.read(interviewProvider.notifier).submitAnswer(_answerController.text);
    await _speechService?.stopListening();
    if (!mounted) return;
    if (!_isFinishing &&
        ref.read(interviewProvider).currentQuestion?.id == questionId) {
      ref.read(interviewProvider.notifier).submitAnswer(_answerController.text);
      await ref.read(interviewProvider.notifier).flushDraft();
    }
    if (!mounted) return;
    setState(() {
      _sttActive = false;
      _stoppingForTimeUp = false;
    });
  }

  void _startTimer({bool reset = false}) {
    _timer?.cancel();
    if (reset) {
      ref.read(interviewProvider.notifier).resetTimer(_defaultTimerSeconds);
    }
    if (ref.read(interviewProvider).isAnswerTimeUp) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final state = ref.read(interviewProvider);
      if (state.phase != InterviewPhase.inProgress ||
          _isSubmitting ||
          _stoppingForTimeUp) {
        return;
      }
      ref.read(interviewProvider.notifier).tickTimer();
      if (ref.read(interviewProvider).isAnswerTimeUp) {
        _timer?.cancel();
        await _handleTimeUp();
      }
    });
  }

  void _pauseSession() {
    if (ref.read(interviewProvider).phase != InterviewPhase.inProgress) return;
    _timer?.cancel();
    ref.read(interviewProvider.notifier).pause();
    ref.read(gazeProvider.notifier).pauseCapture();
    ref.read(interviewProvider.notifier).submitAnswer(_answerController.text);
    unawaited(ref.read(interviewProvider.notifier).flushDraft());
    _speechService?.stopListening();
  }

  void _resumeSession() {
    ref.read(interviewProvider.notifier).resume();
    _syncGazeCapture();
    _startTimer();
  }

  Future<void> _submitAndNext({bool skipFollowUp = false}) async {
    if (_isSubmitting ||
        _isFinishing ||
        _stoppingForTimeUp ||
        ref.read(interviewProvider).isPreparing) {
      return;
    }
    setState(() => _isSubmitting = true);
    _timer?.cancel();
    _syncGazeCapture();
    ref
        .read(interviewProvider.notifier)
        .submitAnswer(_answerController.text.trim());
    await _speechService?.stopListening();
    if (!mounted || _isFinishing) return;
    setState(() => _sttActive = false);
    final answer = _answerController.text.trim();
    ref.read(interviewProvider.notifier).submitAnswer(answer);
    if (answer.isEmpty) {
      ref.read(interviewProvider.notifier).pause();
      final skip = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('아직 답변이 없어요'),
          content: const Text('답변 없이 다음 질문으로 넘어갈까요? 이 질문은 답변 없음으로 기록돼요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 답변하기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('질문 건너뛰기'),
            ),
          ],
        ),
      );
      if (!mounted || _isFinishing) return;
      ref.read(interviewProvider.notifier).resume();
      if (skip != true) {
        setState(() => _isSubmitting = false);
        _syncGazeCapture();
        _startTimer();
        return;
      }
    }
    _answerController.clear();
    if (skipFollowUp) {
      await ref.read(interviewProvider.notifier).nextBaseQuestion(answer);
    } else {
      await ref.read(interviewProvider.notifier).nextQuestion(answer);
    }
    if (!mounted || _isFinishing) return;
    setState(() => _isSubmitting = false);
    _syncGazeCapture();
    final phase = ref.read(interviewProvider).phase;
    if (phase == InterviewPhase.inProgress) {
      _startTimer(reset: true);
    } else if (phase == InterviewPhase.paused) {
      ref.read(interviewProvider.notifier).resetTimer(_defaultTimerSeconds);
    }
  }

  Future<void> _finishSession() async {
    if (_isFinishing) return;
    _isFinishing = true;
    _timer?.cancel();
    if (!_isSubmitting || _answerController.text.trim().isNotEmpty) {
      ref
          .read(interviewProvider.notifier)
          .submitAnswer(_answerController.text.trim());
    }
    await _speechService?.stopListening();
    if (!mounted) return;
    if (!_isSubmitting || _answerController.text.trim().isNotEmpty) {
      ref
          .read(interviewProvider.notifier)
          .submitAnswer(_answerController.text.trim());
    }
    _cameraController?.stopImageStream();
    ref.read(gazeProvider.notifier).stop();
    ref.read(interviewProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(interviewProvider);

    ref.listen(interviewProvider, (previous, next) {
      if (previous?.isPreparing != next.isPreparing ||
          previous?.currentIndex != next.currentIndex) {
        _syncGazeCapture();
      }
      if (next.phase == InterviewPhase.finished) {
        _timer?.cancel();
        ref.read(gazeProvider.notifier).stop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ReportScreen()),
        );
      }
    });

    return PopScope(
      canPop: _allowLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitDialog(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(child: _buildBody(context, state)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, InterviewState state) {
    return switch (state.phase) {
      InterviewPhase.loadingQuestions => const _QuestionLoadingSkeleton(),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final panels = _buildInterviewPanels(context, state);
        if (constraints.maxHeight >= 560) return panels;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: SizedBox(height: 560, child: panels),
        );
      },
    );
  }

  Widget _buildInterviewPanels(BuildContext context, InterviewState state) {
    final q = state.currentQuestion;
    if (q == null) return const SizedBox.shrink();
    final sampleAnswer = ref.watch(isDemoModeProvider)
        ? ref.watch(demoAnswerProvider(q))
        : null;

    return Column(
      children: [
        // ── Top bar: quit + progress + gaze ──
        if (state.draftSaveError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              state.draftSaveError!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              _GlassButton(
                onTap: () => _showExitDialog(context),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProgressBar(
                  current: state.currentIndex,
                  total: state.questions.length,
                ),
              ),
              const SizedBox(width: 12),
              _GazeIndicator(),
            ],
          ),
        ),
        // ── Status banners ──
        if (_cameraError || _micDenied)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                if (_cameraError)
                  _StatusBanner(
                    icon: Icons.videocam_off,
                    message: '카메라 없음 — 시선 분석 비활성',
                    color: Colors.orange,
                  ),
                if (_micDenied)
                  _StatusBanner(
                    icon: Icons.mic_off,
                    message: '마이크 권한 없음',
                    color: Colors.orange,
                  ),
              ],
            ),
          ),
        if (_cameraReady && _cameraController != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: InterviewCameraPanel(
              previewBuilder: (_) => CameraPreview(_cameraController!),
            ),
          ),
        // ── Question card ──
        Flexible(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _GlassPanel(
              borderRadius: 20,
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.secondaryContainer.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Text(
                            'Q${state.currentIndex + 1} / ${state.questions.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryContainer,
                            ),
                          ),
                        ),
                        if (state.isPreparing)
                          Text(
                            '준비 ${state.preparationSecondsRemaining}초',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          TimerWidget(seconds: state.timerSeconds),
                      ],
                    ),
                    const SizedBox(height: 12),
                    QuestionCard(
                      question: q,
                      index: state.currentIndex,
                      total: state.questions.length,
                    ),
                    if (!_cameraEnabled)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '카메라 없이 연습 중 · 시선 지표는 측정하지 않아요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (state.isPreparing)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          '질문을 읽고 생각을 정리해 보세요. 준비 시간은 답변 시간에 포함하지 않아요.',
                        ),
                      ),
                    if (state.isAnswerTimeUp)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3DE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '답변 시간이 끝났어요',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '자동 제출하지 않았어요. 답변을 확인해 제출하거나 시간을 늘릴 수 있어요.',
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _stoppingForTimeUp || _isSubmitting
                                  ? null
                                  : _extendAnswerTime,
                              child: const Text('30초 더 답변하기'),
                            ),
                          ],
                        ),
                      ),
                    if (state.followUpNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          state.followUpNotice!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (state.referenceReportId != null)
                      _PracticeReference(
                        report: ref
                            .read(reportProvider.notifier)
                            .loadById(state.referenceReportId!),
                        questionId: q.id,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // ── Answer area expands ──
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _GlassPanel(
              borderRadius: 16,
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _answerController,
                      onChanged: (text) => ref
                          .read(interviewProvider.notifier)
                          .submitAnswer(text),
                      enabled:
                          !_isSubmitting &&
                          !_sttActive &&
                          !_speechStarting &&
                          !state.isPreparing &&
                          !_stoppingForTimeUp,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.onSurface,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: state.isPreparing
                            ? '질문을 읽고 생각을 정리하는 시간이에요.'
                            : state.isAnswerTimeUp
                            ? '인식된 답변을 확인하거나 직접 수정해 주세요.'
                            : ref.watch(isDemoModeProvider)
                            ? '데모 답변을 직접 입력하세요...'
                            : '마이크로 답변하거나 직접 입력하세요...',
                        hintStyle: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        filled: false,
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.isPreparing
                                  ? '답변 준비 중'
                                  : state.isAnswerTimeUp
                                  ? '답변 확인·수정하기'
                                  : ref.watch(isDemoModeProvider)
                                  ? '텍스트 답변 데모'
                                  : (_sttActive ? '듣고 있어요' : '마이크로 답변하기'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              state.isPreparing
                                  ? '준비가 끝나면 입력하거나 마이크로 답변할 수 있어요.'
                                  : state.isAnswerTimeUp
                                  ? '마이크를 멈췄어요. 제출하거나 시간을 늘려 다시 답변할 수 있어요.'
                                  : ref.watch(isDemoModeProvider)
                                  ? '카메라·마이크 없이 샘플 피드백을 확인해요.'
                                  : _speechMessage ??
                                        (_sttActive
                                            ? '답변을 마치면 마이크를 눌러 인식을 종료하세요.'
                                            : '말한 내용이 자동으로 입력되고 AI 평가에 사용돼요.'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            if (sampleAnswer != null)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _answerController,
                                builder: (context, value, _) => TextButton(
                                  onPressed:
                                      value.text.trim().isNotEmpty ||
                                          _isSubmitting ||
                                          _isFinishing ||
                                          state.isPreparing ||
                                          _stoppingForTimeUp
                                      ? null
                                      : () {
                                          FocusScope.of(context).unfocus();
                                          _answerController
                                              .value = TextEditingValue(
                                            text: sampleAnswer,
                                            selection: TextSelection.collapsed(
                                              offset: sampleAnswer.length,
                                            ),
                                          );
                                          ref
                                              .read(interviewProvider.notifier)
                                              .submitAnswer(sampleAnswer);
                                        },
                                  child: const Text('샘플 답변 넣기'),
                                ),
                              ),
                            if (_micDenied)
                              IconButton(
                                tooltip: '앱 권한 설정',
                                onPressed: openAppSettings,
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            if (!ref.watch(isDemoModeProvider))
                              _MicButton(
                                active: _sttActive,
                                busy: _speechStarting,
                                onTap:
                                    _isSubmitting ||
                                        _speechStarting ||
                                        state.isPreparing ||
                                        state.isAnswerTimeUp ||
                                        _stoppingForTimeUp
                                    ? null
                                    : _toggleMic,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // ── Bottom control bar (glass) ──
        _GlassPanel(
          borderRadius: 24,
          bottomRounded: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (q.isFollowUp)
                  TextButton(
                    onPressed:
                        _isSubmitting ||
                            _speechStarting ||
                            state.isPreparing ||
                            _stoppingForTimeUp
                        ? null
                        : () => _submitAndNext(skipFollowUp: true),
                    child: const Text('기본 질문으로 넘어가기'),
                  ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _OutlineGlassButton(
                        label: '종료',
                        onTap: () => _showExitDialog(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _PrimaryGlassButton(
                        label: state.isPreparing
                            ? '바로 답변 시작'
                            : state.isLastQuestion
                            ? '답변 제출'
                            : '다음 질문',
                        loading:
                            _isSubmitting ||
                            _speechStarting ||
                            _stoppingForTimeUp,
                        onTap:
                            _isSubmitting ||
                                _speechStarting ||
                                _stoppingForTimeUp
                            ? null
                            : state.isPreparing
                            ? _beginAnswerNow
                            : _submitAndNext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPausedBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _GlassPanel(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  '면접이 일시정지되었습니다.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                _PrimaryGlassButton(label: '재개', onTap: _resumeSession),
                const SizedBox(height: 12),
                _OutlineGlassButton(label: '종료 및 리포트', onTap: _finishSession),
              ],
            ),
          ),
        ),
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
          if (ref.read(isLocalAiModeProvider))
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                _pauseSession();
                await _speechService?.stopListening();
                if (!mounted) return;
                ref
                    .read(interviewProvider.notifier)
                    .submitAnswer(_answerController.text);
                await ref.read(interviewProvider.notifier).flushDraft();
                if (!mounted) return;
                if (ref.read(interviewProvider).draftSaveError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('임시 저장을 완료하지 못해 연습 화면을 유지했어요.'),
                    ),
                  );
                  return;
                }
                setState(() => _allowLeave = true);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('저장하고 나가기'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
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

class _PracticeReference extends StatelessWidget {
  const _PracticeReference({required this.report, required this.questionId});
  final SessionReport? report;
  final String questionId;
  @override
  Widget build(BuildContext context) {
    if (report == null) return const SizedBox.shrink();
    final previous = report!.qaList
        .where((qa) => qa.question.id == questionId)
        .firstOrNull;
    if (previous == null) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('이전 답변·개선 목표'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                previous.userAnswer.trim().isEmpty
                    ? '이전 답변 없음'
                    : previous.userAnswer,
              ),
              for (final point in report!.improvementPoints)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${point.title}: ${point.description}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Glass panel helper ────────────────────────────────────────────────────
class _GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool bottomRounded;

  const _GlassPanel({
    required this.child,
    this.borderRadius = 16,
    this.bottomRounded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: bottomRounded
            ? BorderRadius.circular(borderRadius)
            : BorderRadius.vertical(top: Radius.circular(borderRadius)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

// ── Glass icon button ─────────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: child,
      ),
    );
  }
}

// ── Mic button ────────────────────────────────────────────────────────────
class _MicButton extends StatelessWidget {
  final bool active;
  final bool busy;
  final VoidCallback? onTap;
  const _MicButton({
    required this.active,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: active ? '음성 인식 중지' : '마이크로 답변하기',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? AppColors.secondaryContainer
            : AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        minimumSize: const Size(48, 48),
      ),
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(active ? Icons.mic_rounded : Icons.mic_none_rounded),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : current / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: AppColors.surfaceContainerHigh,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
        ),
      ),
    );
  }
}

// ── Gaze indicator ────────────────────────────────────────────────────────
class _GazeIndicator extends ConsumerWidget {
  const _GazeIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaze = ref.watch(gazeProvider);
    if (!gaze.isRunning) return const SizedBox.shrink();

    final isGazing = gaze.isCurrentlyGazing;
    final hasFace = gaze.faceDetected;
    final color = !hasFace
        ? Colors.grey
        : isGazing
        ? AppColors.primaryContainer
        : AppColors.secondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFace
                ? (isGazing
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded)
                : Icons.face_retouching_off_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            !hasFace
                ? '미감지'
                : isGazing
                ? '응시'
                : '분산',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary action button (glass context) ────────────────────────────────
class _PrimaryGlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _PrimaryGlassButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  State<_PrimaryGlassButton> createState() => _PrimaryGlassButtonState();
}

class _PrimaryGlassButtonState extends State<_PrimaryGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: EdgeInsets.only(top: _pressed ? 4 : 0),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: _pressed
              ? null
              : Border(
                  bottom: BorderSide(color: AppColors.primaryShadow, width: 3),
                ),
        ),
        child: widget.loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.label,
                style: TextStyle(
                  color: AppColors.onPrimaryContainer,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

// ── Outline button (glass context) ────────────────────────────────────────
class _OutlineGlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineGlassButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────
class _QuestionLoadingSkeleton extends StatefulWidget {
  const _QuestionLoadingSkeleton();

  @override
  State<_QuestionLoadingSkeleton> createState() =>
      _QuestionLoadingSkeletonState();
}

class _QuestionLoadingSkeletonState extends State<_QuestionLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _GlassPanel(
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryContainer),
                const SizedBox(height: 16),
                Text(
                  'AI가 맞춤 질문을 생성 중입니다...',
                  style: TextStyle(color: AppColors.onSurface, fontSize: 14),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _opacity,
                  builder: (context, _) => Opacity(
                    opacity: _opacity.value,
                    child: Column(
                      children: [
                        _SkeletonBar(width: double.infinity, height: 16),
                        const SizedBox(height: 8),
                        _SkeletonBar(width: 200, height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
