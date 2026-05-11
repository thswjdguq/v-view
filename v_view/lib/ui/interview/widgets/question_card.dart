import 'package:flutter/material.dart';
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1} / $total',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (question.isFollowUp) ...[
                  const SizedBox(width: 8),
                  const Chip(label: Text('꼬리 질문'), padding: EdgeInsets.zero),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.text,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
