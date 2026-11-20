import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_view/domain/gaze/gaze_metrics.dart';
import 'package:v_view/domain/interview/interview_question.dart';
import 'package:v_view/domain/report/report_comparison.dart';
import 'package:v_view/domain/report/session_report.dart';
import 'package:v_view/domain/session_setup/session_input.dart';
import 'package:v_view/ui/report/widgets/report_comparison_card.dart';

SessionReport _report(
  String id, {
  bool answered = true,
  GazeQuality quality = GazeQuality.normal,
}) => SessionReport(
  id: id,
  createdAt: DateTime(2026, 11, 3),
  interviewType: InterviewType.job,
  gazeMetrics: GazeMetrics(
    gazeRate: 80,
    distractionCount: 0,
    totalDistractionSeconds: 0,
    maxDistractionSeconds: 0,
    quality: quality,
  ),
  qaList: [
    QuestionAnswer(
      question: const InterviewQuestion(id: 'q1', text: '질문', intent: '경험'),
      userAnswer: answered ? '답변' : '',
      answerDurationSeconds: 30,
    ),
  ],
  totalQuestions: 1,
  totalDurationSeconds: 30,
  improvementPoints: const [],
);

void main() {
  testWidgets('완료율 변화는 %p로 표시하고 측정 불가 응시율은 비교하지 않는다', (tester) async {
    final comparison = ReportComparison(
      current: _report('current', quality: GazeQuality.unavailable),
      previous: _report('previous', answered: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReportComparisonCard(comparison: comparison)),
      ),
    );
    expect(find.text('+100.0%p'), findsOneWidget);
    expect(find.text('비교할 측정 없음'), findsWidgets);
    expect(find.textContaining('점 향상'), findsNothing);
  });

  testWidgets('첫 연습은 가짜 변화 대신 비교 조건을 안내하고 큰 글자도 지원한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const Scaffold(body: ReportComparisonCard()),
      ),
    );
    expect(find.textContaining('같은 면접 유형·직무·회사'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
