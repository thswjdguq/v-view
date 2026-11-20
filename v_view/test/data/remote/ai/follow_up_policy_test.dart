import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/data/remote/ai/claude_api_service.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/session_setup/session_input.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.value);
  final Object value;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'content': jsonEncode(value)},
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

const question = InterviewQuestion(
  id: 'q1',
  text: '성과를 어떻게 확인했나요?',
  intent: '검증 확인',
);
void main() {
  test('질문 생성에 이름 없이 프로필과 각 자소서의 질문·답변을 전달한다', () async {
    final adapter = _Adapter([
      {'id': 'q1', 'text': '본인의 역할을 설명해 주세요.', 'intent': '역할 확인'},
    ]);
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(client.close);
    await ClaudeApiService(client: client).generateQuestions(
      const SessionInput(
        type: InterviewType.job,
        position: '개발',
        company: '가상 회사',
        age: '26',
        education: '컴퓨터공학',
        school: '충남대학교',
        certifications: '정보처리기사',
        certificates: ['정보처리기사', '정보처리산업기사'],
        essays: [
          ApplicationEssay(question: '어떤 문제를 해결했나요?', answer: '중복 저장을 수정했습니다.'),
          ApplicationEssay(question: '협업 경험은?', answer: '팀원과 역할을 나눴습니다.'),
        ],
      ),
    );
    final prompt =
        (adapter.request!.data['messages'] as List).last['content'] as String;
    expect(prompt, contains('정보처리기사'));
    expect(prompt, contains('정보처리산업기사'));
    expect(prompt, contains('충남대학교'));
    expect(prompt, contains('어떤 문제를 해결했나요?'));
    expect(prompt, contains('중복 저장을 수정했습니다.'));
    expect(prompt, contains('팀원과 역할을 나눴습니다.'));
    expect(prompt, isNot(contains('"name"')));
  });
  test('추가 질문은 실제 답변 인용·필요성·종류를 포함한다', () async {
    final adapter = _Adapter({
      'needsFollowUp': true,
      'kind': 'clarification',
      'reason': '결과 확인 방법이 설명되지 않았습니다.',
      'evidence': '잘 됐습니다',
      'text': '어떤 방법으로 결과를 확인했나요?',
      'intent': '검증 방법 확인',
    });
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(client.close);
    final result = await ClaudeApiService(
      client: client,
    ).generateFollowUp(question: question, userAnswer: '수정한 뒤 잘 됐습니다.');
    expect(result!.followUpKind, FollowUpKind.clarification);
    expect(result.followUpReason, isNotEmpty);
    expect(result.followUpEvidence, '잘 됐습니다');
  });
  test('이전 문답을 전달하며 이미 해결한 내용을 다시 캐묻지 않게 한다', () async {
    final adapter = _Adapter({'needsFollowUp': false});
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(client.close);
    final result = await ClaudeApiService(client: client).generateFollowUp(
      question: question,
      userAnswer: '테스트로 결과를 확인했습니다.',
      conversation: const [
        QuestionAnswer(
          question: InterviewQuestion(
            id: 'q0',
            text: '어떤 문제를 해결했나요?',
            intent: '문제 확인',
          ),
          userAnswer: '중복 저장 오류를 수정했습니다.',
          answerDurationSeconds: 10,
        ),
      ],
    );
    expect(result, isNull);
    expect(jsonEncode(adapter.request!.data), contains('중복 저장 오류를 수정했습니다.'));
  });
  test('답변에 없는 인용이나 설명 없는 압박 질문은 거부한다', () async {
    for (final value in [
      {
        'needsFollowUp': true,
        'kind': 'challenge',
        'reason': '근거 확인',
        'evidence': '99% 개선',
        'text': '근거는 무엇인가요?',
        'intent': '검증',
      },
      {
        'needsFollowUp': true,
        'kind': 'challenge',
        'text': '왜 그렇게 했나요?',
        'intent': '검증',
      },
    ]) {
      final client = Dio()..httpClientAdapter = _Adapter(value);
      addTearDown(client.close);
      await expectLater(
        ClaudeApiService(
          client: client,
        ).generateFollowUp(question: question, userAnswer: '테스트로 확인했습니다.'),
        throwsA(isA<AiServiceException>()),
      );
    }
  });
}
