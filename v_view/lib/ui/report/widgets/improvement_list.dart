import 'package:flutter/material.dart';
import '../../../domain/report/session_report.dart';

class ImprovementList extends StatelessWidget {
  final List<ImprovementPoint> points;

  const ImprovementList({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '개선 포인트 TOP3',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...points.asMap().entries.map(
              (e) => _ImprovementItem(
                rank: e.key + 1,
                point: e.value,
              ),
            ),
      ],
    );
  }
}

class _ImprovementItem extends StatelessWidget {
  final int rank;
  final ImprovementPoint point;

  const _ImprovementItem({required this.rank, required this.point});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 14,
          child: Text('$rank', style: const TextStyle(fontSize: 12)),
        ),
        title: Text(point.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(point.description),
            const SizedBox(height: 4),
            Text(
              '근거: ${point.evidenceMetric}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
