import 'package:flutter/material.dart';
import '../../../domain/interview/interview_question.dart';

class QaSummaryList extends StatelessWidget {
  final List<QuestionAnswer> qaList;

  const QaSummaryList({super.key, required this.qaList});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Q&A 요약',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          'Q${widget.index + 1}. ${widget.qa.question.text}',
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 답변',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(widget.qa.userAnswer.isEmpty
                    ? '(답변 없음)'
                    : widget.qa.userAnswer),
                if (widget.qa.aiSummary != null) ...[
                  const Divider(height: 16),
                  const Text('AI 요약',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(widget.qa.aiSummary!,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
