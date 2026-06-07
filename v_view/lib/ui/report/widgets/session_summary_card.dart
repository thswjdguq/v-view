import 'package:flutter/material.dart';
import '../../../app.dart' show kSecondaryColor, kTextColor;
import '../../../domain/report/session_report.dart';
import '../../../domain/session_setup/session_input.dart';

class SessionSummaryCard extends StatelessWidget {
  final SessionReport report;

  const SessionSummaryCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final typeName = switch (report.interviewType) {
      InterviewType.job => '직무면접',
      InterviewType.personality => '인성면접',
      InterviewType.university => '대학입시면접',
    };
    final minutes = report.totalDurationSeconds ~/ 60;
    final seconds = report.totalDurationSeconds % 60;
    final durationText = minutes > 0
        ? '$minutes분 $seconds초'
        : '$seconds초';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondaryColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '세션 요약',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kTextColor),
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: '면접 유형', value: typeName),
          _SummaryRow(label: '총 질문 수', value: '${report.totalQuestions}개'),
          _SummaryRow(label: '총 답변 시간', value: durationText),
          _SummaryRow(
            label: '날짜',
            value:
                '${report.createdAt.year}.${report.createdAt.month.toString().padLeft(2, '0')}.${report.createdAt.day.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 15)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kTextColor)),
        ],
      ),
    );
  }
}
