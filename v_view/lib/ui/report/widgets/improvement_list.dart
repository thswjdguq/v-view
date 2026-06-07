import 'package:flutter/material.dart';
import '../../../app.dart' show kPrimaryColor, kSecondaryColor, kTextColor;
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
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kTextColor),
        ),
        const SizedBox(height: 12),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSecondaryColor, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
            child: Text(
              '$rank',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kTextColor)),
                const SizedBox(height: 4),
                Text(point.description, style: const TextStyle(fontSize: 14, color: kTextColor, height: 1.4)),
                const SizedBox(height: 6),
                Text(
                  '근거: ${point.evidenceMetric}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
