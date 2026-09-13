import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'task_failure_icon.dart';

class TaskFailureCard extends StatelessWidget {
  const TaskFailureCard({
    super.key,
    required this.onRetry,
    required this.error,
  });
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xff292529)
            : const Color(0xfffffcfd),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff503940)
              : const Color(0xfffae9ee),
        ),
      ),
      child: Row(
        children: [
          const TaskFailureIcon(size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.85,
            alignment: Alignment.centerRight,
            transformHitTests: false,
            child: RoundAction(
              label: '重试',
              icon: Icons.refresh_rounded,
              primary: true,
              compact: true,
              inkResponse: false,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    ),
  );
}
