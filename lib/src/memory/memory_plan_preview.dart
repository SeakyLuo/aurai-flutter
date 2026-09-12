import 'package:flutter/material.dart';
import 'memory_plan.dart';

class MemoryPlanPreview extends StatelessWidget {
  const MemoryPlanPreview({super.key, required this.plan});
  final MemoryPlan plan;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '建议调整',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('确认后才会应用，手动保存的记忆保持不变。'),
        const SizedBox(height: 20),
        for (final change in plan.changes) ...[
          Text(
            change.label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (change.before.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              change.before.join('\n'),
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (change.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              change.text,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '原因：${change.reason}',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
        ],
      ],
    ),
  );
}
