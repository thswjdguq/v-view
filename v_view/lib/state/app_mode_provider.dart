import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/interview/interview_question.dart';

/// 별도 데모 진입점에서만 true로 대체한다. 실제 기능 실패를 데모로 숨기지 않는다.
final isDemoModeProvider = Provider<bool>((_) => false);

/// PC loopback API entry point; microphone/camera and real evaluation stay enabled.
final isLocalAiModeProvider = Provider<bool>((_) => false);

/// 실제 면접에는 샘플을 제공하지 않는다. 데모 Scope에서만 질문별 예시를 주입한다.
final demoAnswerProvider = Provider.autoDispose
    .family<String?, InterviewQuestion>((_, _) => null);
