import 'package:flutter/material.dart';
import '../../../domain/session_setup/session_input.dart';

class InterviewTypeSelector extends StatelessWidget {
  final InterviewType selected;
  final ValueChanged<InterviewType> onChanged;

  const InterviewTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: InterviewType.values.map((type) {
        final label = switch (type) {
          InterviewType.job => '직무면접',
          InterviewType.personality => '인성면접',
          InterviewType.university => '대학입시',
        };
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected == type,
              onSelected: (_) => onChanged(type),
            ),
          ),
        );
      }).toList(),
    );
  }
}
