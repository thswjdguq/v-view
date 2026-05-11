import 'package:flutter/material.dart';

class TimerWidget extends StatelessWidget {
  final int seconds;

  const TimerWidget({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final isWarning = seconds <= 30;
    return Row(
      children: [
        Icon(
          Icons.timer,
          color: isWarning ? Colors.red : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          _format(seconds),
          style: TextStyle(
            color: isWarning ? Colors.red : null,
            fontWeight: isWarning ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  String _format(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
