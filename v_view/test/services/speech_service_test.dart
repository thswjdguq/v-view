import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/services/speech_service.dart';

import '../support/fake_speech_recognizer.dart';

void main() {
  late FakeSpeechRecognizer recognizer;
  late SpeechService service;

  setUp(() {
    recognizer = FakeSpeechRecognizer();
    service = SpeechService(recognizer: recognizer);
  });

  tearDown(() => service.dispose());

  test('음성 답변은 기존 입력 뒤에 붙고 부분·최종 결과가 중복되지 않는다', () async {
    final transcripts = <String>[];
    final subscription = service.textStream.listen(transcripts.add);
    addTearDown(subscription.cancel);
    await service.initialize();
    await service.startListening(initialText: '기존 답변');
    recognizer.recognize('프로젝트');
    recognizer.recognize('프로젝트 경험', finalResult: true);
    await Future<void>.delayed(Duration.zero);

    expect(transcripts.last, '기존 답변 프로젝트 경험');
    expect(transcripts, isNot(contains('')));
  });

  test('음성 인식 종료 시 마이크 상태도 꺼지고 인식된 내용은 유지된다', () async {
    final transcripts = <String>[];
    final subscription = service.textStream.listen(transcripts.add);
    addTearDown(subscription.cancel);
    await service.initialize();
    await service.startListening();
    recognizer.recognize('말한 답변', finalResult: true);
    recognizer.completeRecognition();
    await Future<void>.delayed(Duration.zero);

    expect(service.isListening, isFalse);
    expect(transcripts.last, '말한 답변');
  });

  test('오류 뒤에 인식 종료 이벤트가 와도 실패 이유를 유지한다', () async {
    await service.initialize();
    await service.startListening();
    recognizer.fail('error_network');
    recognizer.completeRecognition();

    expect(service.state.message, contains('네트워크'));
    expect(service.isListening, isFalse);
  });

  test('마이크 시작을 기다리다가 중지해도 기기 인식기가 켜진 채 남지 않는다', () async {
    final startingGate = Completer<void>();
    recognizer.listenGate = startingGate;
    await service.initialize();
    final starting = service.startListening();
    await Future<void>.delayed(Duration.zero);
    final stopping = service.stopListening();
    startingGate.complete();
    await Future.wait([starting, stopping]);

    expect(recognizer.listening, isFalse);
    expect(service.isListening, isFalse);
  });

  test('인식 오류는 상태와 안내 메시지로 전달하고 다시 시작할 수 있다', () async {
    await service.initialize();
    await service.startListening();
    recognizer.fail('error_network');

    expect(service.isListening, isFalse);
    expect(service.state.message, contains('네트워크'));
    await service.startListening(initialText: '이전 답변');
    expect(service.isListening, isTrue);
    expect(service.state.message, isNull);
  });

  test('인식을 중지한 다음 도착한 결과는 다음 질문의 입력을 바꾸지 않는다', () async {
    final transcripts = <String>[];
    final subscription = service.textStream.listen(transcripts.add);
    addTearDown(subscription.cancel);
    await service.initialize();
    await service.startListening();
    recognizer.recognize('저장할 답변', finalResult: true);
    await service.stopListening();
    await Future<void>.delayed(Duration.zero);
    final count = transcripts.length;
    recognizer.recognize('늦게 도착한 이전 답변', finalResult: true);
    await Future<void>.delayed(Duration.zero);

    expect(transcripts.length, count);
    expect(transcripts.last, '저장할 답변');
  });

  test('음성 인식을 사용할 수 없을 때 원인을 표시한다', () async {
    recognizer.available = false;
    expect(await service.initialize(), isFalse);
    expect(service.state.message, isNotEmpty);
    expect(service.isListening, isFalse);
  });

  test('중지 요청 직후 도착한 최종 인식 결과까지 전달한 뒤 제출할 수 있다', () async {
    recognizer.finalizeOnStop = false;
    final transcripts = <String>[];
    final subscription = service.textStream.listen(transcripts.add);
    addTearDown(subscription.cancel);
    await service.initialize();
    await service.startListening();
    recognizer.recognize('부분 답변');
    final stopping = service.stopListening();
    await Future<void>.delayed(Duration.zero);
    recognizer.recognize('완성된 최종 답변', finalResult: true);
    await stopping;
    await Future<void>.delayed(Duration.zero);

    expect(transcripts.last, '완성된 최종 답변');
    expect(service.isListening, isFalse);
  });
}
