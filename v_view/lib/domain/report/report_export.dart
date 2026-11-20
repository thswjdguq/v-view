import '../gaze/gaze_metrics.dart';
import '../session_setup/session_input.dart';
import 'session_report.dart';

/// Notion·문서에 붙여 넣을 수 있는 Markdown. 자유 입력은 코드 블록으로 보존한다.
String formatReportForExport(SessionReport report, {bool isDemo = false}) {
  final answered = report.qaList
      .where((qa) => qa.userAnswer.trim().isNotEmpty)
      .length;
  final total = report.qaList.length;
  final completion = total == 0 ? 0.0 : answered / total * 100;
  final type = switch (report.interviewType) {
    InterviewType.job => '직무면접',
    InterviewType.personality => '인성면접',
    InterviewType.university => '대학입시면접',
  };
  final out = StringBuffer()..writeln('# v-view 면접 연습 리포트');
  if (isDemo) out.writeln('\n> DEMO · 가상 데이터 · 실제 AI 평가가 아닙니다');
  out
    ..writeln('\n## 연습 요약')
    ..writeln('- 면접 유형: $type')
    ..writeln('- 기록 시각: ${report.createdAt.toIso8601String()}')
    ..writeln(
      '- 답변 완료: $answered / $total개 (${completion.toStringAsFixed(1)}%)',
    )
    ..writeln('- 전체 진행 시간: ${report.totalDurationSeconds}초')
    ..writeln('\n완료율은 작성 여부이며 답변 역량 점수가 아닙니다.')
    ..writeln('\n## 시선 지표');
  final gaze = report.gazeMetrics;
  if (gaze.quality == GazeQuality.unavailable) {
    out.writeln('- 화면 응시율: 측정 불가');
  } else {
    out
      ..writeln(
        '- 화면 응시율: ${gaze.gazeRate.toStringAsFixed(1)}%${gaze.quality == GazeQuality.reference ? ' (참고용)' : ''}',
      )
      ..writeln('- 시선 분산: ${gaze.distractionCount}회')
      ..writeln('- 최장 분산: ${gaze.maxDistractionSeconds.toStringAsFixed(1)}초');
  }
  if (gaze.qualityNote?.isNotEmpty == true) {
    out.writeln(_block(gaze.qualityNote!));
  }
  out
    ..writeln('얼굴 방향을 바탕으로 추정한 참고 지표입니다.')
    ..writeln(
      '\n## ${isDemo
          ? '샘플 안내'
          : report.isAiFeedbackAvailable
          ? 'AI 피드백'
          : '지표 기반 안내'}',
    );
  for (var i = 0; i < report.improvementPoints.length; i++) {
    final point = report.improvementPoints[i];
    out
      ..writeln('\n### 제안 ${i + 1}')
      ..writeln(
        _block(
          '${point.title}\n${point.description}\n근거: ${point.evidenceMetric}',
        ),
      );
  }
  if (report.improvementPoints.isEmpty) out.writeln('생성된 안내가 없습니다.');
  out.writeln('\n## 질문과 내 답변');
  for (var i = 0; i < report.qaList.length; i++) {
    final qa = report.qaList[i];
    out
      ..writeln('\n### 질문 ${i + 1}${qa.question.isFollowUp ? ' · 꼬리질문' : ''}')
      ..writeln('질문:')
      ..writeln(_block(qa.question.text))
      ..writeln('질문 의도:')
      ..writeln(_block(qa.question.intent))
      ..writeln(
        qa.answerDurationSeconds > 0
            ? '답변 시간: ${qa.answerDurationSeconds}초'
            : '시간 기록 없음',
      )
      ..writeln('내 답변:')
      ..writeln(_block(qa.userAnswer.trim().isEmpty ? '미작성' : qa.userAnswer));
    if (qa.question.followUpReason != null) out.writeln(_block('추가 질문 이유: ${qa.question.followUpReason}\n답변 근거: ${qa.question.followUpEvidence ?? ''}'));
  }
  return out.toString();
}

String _block(String value) {
  var width = 3;
  for (final match in RegExp(r'`+').allMatches(value)) {
    if (match.group(0)!.length >= width) width = match.group(0)!.length + 1;
  }
  final fence = List.filled(width, '`').join();
  return '$fence\n$value\n$fence';
}
