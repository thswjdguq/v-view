import 'package:flutter/material.dart';
import '../../../app.dart' show kPrimaryColor, kSecondaryColor, kTextColor;
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
    return Column(
      children: InterviewType.values.map((type) {
        final (label, icon) = switch (type) {
          InterviewType.job => ('직무면접', Icons.work_rounded),
          InterviewType.personality => ('인성면접', Icons.emoji_people_rounded),
          InterviewType.university => ('대학입시', Icons.school_rounded),
        };
        final isSelected = selected == type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor.withValues(alpha: 0.1) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? kPrimaryColor : kSecondaryColor,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: isSelected ? kPrimaryColor : kTextColor, size: 28),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? kPrimaryColor : kTextColor,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, color: kPrimaryColor),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
