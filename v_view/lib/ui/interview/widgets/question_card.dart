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
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.followUpKind == FollowUpKind.challenge
                      ? '근거 확인 질문'
                      : question.followUpKind == FollowUpKind.clarification
                      ? '추가 확인 질문'
                      : '꼬리 질문',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kPrimaryColor,
                  ),
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
        if (question.followUpReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '추가 질문 이유: ${question.followUpReason}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }
}
