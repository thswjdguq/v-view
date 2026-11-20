import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/session_setup/session_input.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'content': '[{"id":"q1","text":"질문","intent":"경험"}]'},
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

const input = SessionInput(
  type: InterviewType.job,
  position: '개발',
  company: '회사',
  selfIntroduction: '소개',
);

void main() {
  test('중계 요청에는 Firebase ID 토큰을 사용하고 매 요청 갱신한다', () async {
    final adapter = _Adapter();
    final client = Dio(BaseOptions(baseUrl: 'https://proxy.example/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(client.close);
    var count = 0;
    final api = ClaudeApiService(
      client: client,
      idTokenProvider: () async => 'firebase-${++count}',
    );
    await api.generateQuestions(input);
    await api.generateQuestions(input);
    expect(adapter.requests.map((r) => r.headers['Authorization']), [
      'Bearer firebase-1',
      'Bearer firebase-2',
    ]);
    expect(adapter.requests.first.uri.host, 'proxy.example');
  });
  test('로그인 토큰이 없으면 네트워크 요청 전에 안내한다', () async {
    final adapter = _Adapter();
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(client.close);
    final api = ClaudeApiService(
      client: client,
      idTokenProvider: () async => null,
    );
    await expectLater(
      api.generateQuestions(input),
      throwsA(
        isA<AiServiceException>().having(
          (e) => e.message,
          '안내',
          contains('로그인'),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
  test('중계 주소가 없으면 복구 가능한 설정 오류로 반환한다', () async {
    final api = ClaudeApiService(
      endpoint: '',
      idTokenProvider: () async => 'token',
    );
    await expectLater(
      api.generateQuestions(input),
      throwsA(isA<AiServiceException>()),
    );
  });
  test('외부 HTTP 주소는 로그인 토큰을 전송하지 않는다', () async {
    var tokenRead = false;
    final api = ClaudeApiService(
      endpoint: 'http://proxy.example/v1',
      idTokenProvider: () async {
        tokenRead = true;
        return 'token';
      },
    );
    await expectLater(
      api.generateQuestions(input),
      throwsA(isA<AiServiceException>()),
    );
    expect(tokenRead, isFalse);
  });
}
