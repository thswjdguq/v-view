import 'package:flutter/material.dart';
import '../../../domain/interview/interview_question.dart';
import '../../../theme/app_theme.dart';

class QaSummaryList extends StatelessWidget {
  final List<QuestionAnswer> qaList;

  const QaSummaryList({super.key, required this.qaList});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '질문별 답변 돌아보기',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (qaList.isEmpty)
          const Text(
            '기록된 질문이 없어요.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ...qaList.asMap().entries.map(
          (e) => _QaItem(index: e.key, qa: e.value),
        ),
      ],
    );
  }
}

class _QaItem extends StatefulWidget {
  final int index;
  final QuestionAnswer qa;

  const _QaItem({required this.index, required this.qa});

  @override
  State<_QaItem> createState() => _QaItemState();
}

class _QaItemState extends State<_QaItem> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          'Q${widget.index + 1}. ${widget.qa.question.text}',
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          widget.qa.answerDurationSeconds > 0
              ? '답변 시간 ${widget.qa.answerDurationSeconds}초'
              : '답변 시간 기록 없음',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 답변',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (widget.qa.question.followUpReason != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '추가 질문 이유: ${widget.qa.question.followUpReason}\n답변 근거: ${widget.qa.question.followUpEvidence ?? ''}',
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  widget.qa.userAnswer.trim().isEmpty
                      ? '(답변 없음)'
                      : widget.qa.userAnswer,
                ),
                if (widget.qa.aiSummary != null) ...[
                  const Divider(height: 16),
                  const Text(
                    'AI 요약',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.qa.aiSummary!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
