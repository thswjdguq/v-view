import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/state/interview/interview_provider.dart';

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.payload, this.status);
  final Object payload;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(payload),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

const _input = SessionInput(
  type: InterviewType.job,
  position: '개발자',
  company: '회사',
  selfIntroduction: '소개',
);
const _question = InterviewQuestion(
  id: 'q1',
  text: '경험을 소개해주세요.',
  intent: '경험',
);

void main() {
  ClaudeApiService apiFor(
    Object payload, {
    int status = 200,
    bool envelope = true,
  }) {
    final client = Dio(BaseOptions(baseUrl: 'https://api.openai.com/v1'))
      ..httpClientAdapter = _ResponseAdapter(
        envelope
            ? {
                'choices': [
                  {
                    'message': {
                      'content': payload is String
                          ? payload
                          : jsonEncode(payload),
                    },
                  },
                ],
              }
            : payload,
        status,
      );
    addTearDown(client.close);
    return ClaudeApiService(client: client);
  }

  test('빈 질문 목록은 진행 가능한 면접으로 처리하지 않는다', () async {
    await expectLater(
      apiFor([]).generateQuestions(_input),
      throwsA(isA<Exception>()),
    );
  });

  test('중복 질문 ID는 서로 다른 답변을 덮어쓸 수 있으므로 거부한다', () async {
    final api = apiFor([
      {'id': 'q1', 'text': '첫 질문', 'intent': '경험'},
      {'id': 'q1', 'text': '두 번째 질문', 'intent': '동기'},
    ]);
    await expectLater(api.generateQuestions(_input), throwsA(isA<Exception>()));
  });

  test('질문 필드 누락은 TypeError 대신 복구 가능한 오류로 반환한다', () async {
    await expectLater(
      apiFor([
        {'id': 'q1', 'text': '질문'},
      ]).generateQuestions(_input),
      throwsA(isA<Exception>()),
    );
  });

  test('API 응답 구조가 누락돼도 로딩이 해제되고 형식 오류를 안내한다', () async {
    final notifier = InterviewNotifier(
      apiFor({'choices': []}, envelope: false),
    );
    addTearDown(notifier.dispose);
    await notifier.start(_input);
    expect(notifier.state.phase, InterviewPhase.idle);
    expect(notifier.state.errorMessage, contains('형식'));
  });

  test('문자열 false를 꼬리질문 허용으로 해석하지 않는다', () async {
    await expectLater(
      apiFor({
        'needsFollowUp': 'false',
        'text': '추가 질문',
        'intent': '확인',
      }).generateFollowUp(question: _question, userAnswer: '답변'),
      throwsA(isA<Exception>()),
    );
  });

  test('빈 피드백은 성공 대신 지표 기반 대체 결과로 처리할 수 있는 오류를 반환한다', () async {
    await expectLater(
      apiFor(
        [],
      ).generateFeedback(qaList: const [], gazeMetrics: GazeMetrics.empty),
      throwsA(isA<Exception>()),
    );
  });

  test('피드백 근거 누락은 복구 가능한 오류로 반환한다', () async {
    await expectLater(
      apiFor([
        {'title': '개선', 'description': '설명'},
      ]).generateFeedback(qaList: const [], gazeMetrics: GazeMetrics.empty),
      throwsA(isA<Exception>()),
    );
  });

  test('유효한 코드블록 JSON 질문은 읽을 수 있다', () async {
    final questions = await apiFor(
      '```json\n[{"id":"q1","text":"경험?","intent":"경험"}]\n```',
    ).generateQuestions(_input);
    expect(questions.single.text, '경험?');
  });

  test('요청 제한은 연결 오류 대신 잠시 후 재시도를 안내한다', () async {
    final notifier = InterviewNotifier(
      apiFor(
        {
          'error': {'message': 'rate limit'},
        },
        status: 429,
        envelope: false,
      ),
    );
    addTearDown(notifier.dispose);
    await notifier.start(_input);
    expect(notifier.state.errorMessage, contains('잠시 후'));
  });
}
