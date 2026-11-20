import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/session_setup/session_input.dart';

const _input = SessionInput(
  type: InterviewType.job,
  position: '개발자',
  company: '가상 회사',
  selfIntroduction: '연습용 소개',
);

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {
              'content':
                  '[{"id":"q1","text":"해결한 문제는 무엇인가요?","intent":"경험 확인"}]',
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
  test('PC 연결 확인은 상태 경로만 읽고 AI 요청을 보내지 않는다', () async {
    final adapter = _HealthAdapter();
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(client.close);
    expect(
      await ClaudeApiService.local(client: client).checkLocalConnection(),
      isTrue,
    );
    expect(adapter.requests.single.uri.path, '/health');
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.data, isNull);
  });
  test('로컬 질문 요청은 Firebase 인증이나 앱 API 키 없이 PC 주소로 전송한다', () async {
    final adapter = _Adapter();
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(client.close);
    final api = ClaudeApiService.local(client: client);
    final questions = await api.generateQuestions(_input);
    expect(questions.single.id, 'q1');
    final request = adapter.requests.single;
    expect(request.uri.toString(), 'http://127.0.0.1:8080/v1/chat/completions');
    expect(
      request.headers.keys.where((key) => key.toLowerCase() == 'authorization'),
      isEmpty,
    );
  });
  test('로컬 모드는 외부·LAN 주소를 요청 전에 거부한다', () async {
    for (final endpoint in [
      'https://api.openai.com/v1',
      'http://192.168.1.5:8080/v1',
      'http://127.0.0.1.untrusted.example/v1',
      'http://user:pass@127.0.0.1/v1',
      'http://127.0.0.1/v1?key=x',
    ]) {
      final adapter = _Adapter();
      final client = Dio()..httpClientAdapter = adapter;
      addTearDown(client.close);
      final api = ClaudeApiService.local(client: client, endpoint: endpoint);
      await expectLater(
        api.generateQuestions(_input),
        throwsA(isA<AiServiceException>()),
      );
      expect(adapter.requests, isEmpty);
    }
  });
  test('Android 에뮬레이터의 PC 전용 주소를 허용한다', () async {
    final adapter = _Adapter();
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(client.close);
    await ClaudeApiService.local(
      client: client,
      endpoint: 'http://10.0.2.2:8080/v1',
    ).generateQuestions(_input);
    expect(adapter.requests.single.uri.host, '10.0.2.2');
  });
}

class _HealthAdapter extends _Adapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"status":"ok","service":"v-view-local-ai"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
