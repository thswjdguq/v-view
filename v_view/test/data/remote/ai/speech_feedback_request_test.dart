import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';

class _FeedbackAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content': jsonEncode([
                {
                  'title': '해결 결과 구체화',
                  'description': '버그 수정 후 어떤 검증을 수행했는지 덧붙여 주세요.',
                  'evidenceMetric': '"상태 초기화 시점을 수정했습니다"라는 답변',
                },
              ]),
            },
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('음성에서 변환한 답변과 질문 의도를 AI 평가 요청에 포함한다', () async {
    final adapter = _FeedbackAdapter();
    final client = Dio(BaseOptions(baseUrl: 'https://api.openai.com/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(client.close);
    final api = ClaudeApiService(client: client);
    const answer = '이전 질문이 남는 문제를 재현하고 상태 초기화 시점을 수정했습니다.';

    final feedback = await api.generateFeedback(
      qaList: const [
        QuestionAnswer(
          question: InterviewQuestion(
            id: 'q1',
            text: '해결한 문제를 소개해주세요.',
            intent: '원인 분석과 검증 과정',
          ),
          userAnswer: answer,
          answerDurationSeconds: 42,
        ),
      ],
      gazeMetrics: GazeMetrics.empty,
    );
    final messages = (adapter.request!.data as Map)['messages'] as List;
    final prompt = messages.last['content'] as String;
    expect(prompt, contains(answer));
    expect(prompt, contains('원인 분석과 검증 과정'));
    expect(prompt, contains('42초'));
    expect(feedback.single.evidenceMetric, contains('상태 초기화 시점을 수정했습니다'));
  });
}
