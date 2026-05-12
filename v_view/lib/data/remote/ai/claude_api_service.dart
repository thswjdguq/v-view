import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../domain/session_setup/session_input.dart';
import '../../../domain/interview/interview_question.dart';
import '../../../domain/report/session_report.dart';
import '../../../domain/gaze/gaze_metrics.dart';

class ClaudeApiService {
  static const _baseUrl = 'https://api.anthropic.com/v1';
  static const _model = 'claude-opus-4-7';
  static const _timeoutSeconds = 30;

  late final Dio _dio;

  ClaudeApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: _timeoutSeconds),
      receiveTimeout: const Duration(seconds: _timeoutSeconds),
      headers: {
        'x-api-key': dotenv.env['ANTHROPIC_API_KEY'] ?? '',
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
    ));
    _dio.interceptors.add(_NetworkErrorInterceptor());
  }

  Future<List<InterviewQuestion>> generateQuestions(SessionInput input) async {
    final prompt = _buildQuestionPrompt(input);
    final response = await _dio.post('/messages', data: {
      'model': _model,
      'max_tokens': 1024,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
    });
    return _parseQuestions(response.data);
  }

  Future<InterviewQuestion> generateFollowUp({
    required InterviewQuestion question,
    required String userAnswer,
  }) async {
    final prompt = _buildFollowUpPrompt(question, userAnswer);
    final response = await _dio.post('/messages', data: {
      'model': _model,
      'max_tokens': 512,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
    });
    return _parseFollowUp(response.data, question.id);
  }

  Future<List<ImprovementPoint>> generateFeedback({
    required List<QuestionAnswer> qaList,
    required GazeMetrics gazeMetrics,
  }) async {
    final prompt = _buildFeedbackPrompt(qaList, gazeMetrics);
    final response = await _dio.post('/messages', data: {
      'model': _model,
      'max_tokens': 1024,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
    });
    return _parseFeedback(response.data);
  }

  String _buildQuestionPrompt(SessionInput input) {
    final typeName = switch (input.type) {
      InterviewType.job => '직무면접',
      InterviewType.personality => '인성면접',
      InterviewType.university => '대학입시면접',
    };
    return '''당신은 면접관입니다. 아래 정보를 바탕으로 $typeName 예상 질문 3개를 JSON 배열로 생성하세요.
직종/전공: ${input.position}
회사/학교: ${input.company}
자기소개서: ${input.selfIntroduction}

응답 형식 (JSON만 반환):
[{"id":"q1","text":"질문 내용","intent":"평가 포인트"},...]''';
  }

  String _buildFollowUpPrompt(InterviewQuestion q, String answer) {
    return '''면접 질문: ${q.text}
지원자 답변: $answer

위 답변을 바탕으로 꼬리 질문 1개를 JSON으로 반환하세요.
형식: {"text":"꼬리 질문","intent":"평가 포인트"}''';
  }

  String _buildFeedbackPrompt(List<QuestionAnswer> qaList, GazeMetrics gaze) {
    final qaText = qaList
        .map((qa) => '질문: ${qa.question.text}\n답변: ${qa.userAnswer}')
        .join('\n\n');
    return '''면접 세션 분석 결과입니다.

[Q&A]
$qaText

[시선 지표]
화면 응시율: ${gaze.gazeRate.toStringAsFixed(1)}%
시선 분산 횟수: ${gaze.distractionCount}회
시선 분산 총 시간: ${gaze.totalDistractionSeconds.toStringAsFixed(1)}초
최장 분산 시간: ${gaze.maxDistractionSeconds.toStringAsFixed(1)}초
측정 품질: ${gaze.quality.name}

개선 포인트 TOP3를 JSON 배열로 반환하세요.
형식: [{"title":"개선항목","description":"상세설명","evidenceMetric":"근거지표"},...]''';
  }

  List<InterviewQuestion> _parseQuestions(Map<String, dynamic> data) {
    final text = data['content'][0]['text'] as String;
    final list = (_extractJson(text) as List).cast<Map<String, dynamic>>();
    return list
        .map((q) => InterviewQuestion(
              id: q['id'] as String,
              text: q['text'] as String,
              intent: q['intent'] as String,
            ))
        .toList();
  }

  InterviewQuestion _parseFollowUp(Map<String, dynamic> data, String parentId) {
    final text = data['content'][0]['text'] as String;
    final q = _extractJson(text) as Map<String, dynamic>;
    return InterviewQuestion(
      id: 'fu_${DateTime.now().millisecondsSinceEpoch}',
      text: q['text'] as String,
      intent: q['intent'] as String,
      isFollowUp: true,
      parentQuestionId: parentId,
    );
  }

  List<ImprovementPoint> _parseFeedback(Map<String, dynamic> data) {
    final text = data['content'][0]['text'] as String;
    final list = (_extractJson(text) as List).cast<Map<String, dynamic>>();
    return list
        .map((p) => ImprovementPoint(
              title: p['title'] as String,
              description: p['description'] as String,
              evidenceMetric: p['evidenceMetric'] as String,
            ))
        .toList();
  }

  dynamic _extractJson(String text) {
    final startBracket = text.indexOf('[');
    final startBrace = text.indexOf('{');
    final int start;
    final int end;
    if (startBracket != -1 && (startBrace == -1 || startBracket < startBrace)) {
      start = startBracket;
      end = text.lastIndexOf(']') + 1;
    } else {
      start = startBrace;
      end = text.lastIndexOf('}') + 1;
    }
    if (start == -1 || end <= start) throw const FormatException('No JSON found');
    return json.decode(text.substring(start, end));
  }
}

class _NetworkErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final enriched = switch (err.type) {
      DioExceptionType.connectionError => err.copyWith(
          message: '인터넷 연결을 확인해주세요. (연결 오류)',
        ),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout =>
        err.copyWith(
          message: 'AI 서버 응답이 지연되고 있습니다. ($_timeoutSeconds초 초과)',
        ),
      DioExceptionType.badResponse => err.copyWith(
          message: 'API 오류: ${err.response?.statusCode}',
        ),
      _ => err,
    };
    handler.next(enriched);
  }
}

const _timeoutSeconds = ClaudeApiService._timeoutSeconds;
