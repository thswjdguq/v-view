import 'package:flutter/material.dart';
import '../../../app.dart' show kPrimaryColor, kTextColor;
import '../../../domain/interview/interview_question.dart';

class QuestionCard extends StatelessWidget {
  final InterviewQuestion question;
  final int index;
  final int total;

  const QuestionCard({
    super.key,
    required this.question,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '질문 ${index + 1} / $total',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            if (question.isFollowUp) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '꼬리 질문',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimaryColor),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          question.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: kTextColor,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
