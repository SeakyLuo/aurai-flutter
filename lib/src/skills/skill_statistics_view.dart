import 'package:flutter/material.dart';

import '../features/chat/settings_appearance.dart';
import 'skill_store.dart';

class SkillStatisticsView extends StatelessWidget {
  const SkillStatisticsView({
    super.key,
    required this.store,
    required this.skillId,
  });
  final SkillStore store;
  final String skillId;

  String _time(DateTime? time) {
    if (time == null) return '暂无记录';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          for (final entry in [
            ('创建时间', _time(store.createdAt(skillId))),
            ('更新时间', _time(store.updatedAt(skillId))),
            ('使用次数', '${store.useCount(skillId)} 次'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.$1, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      entry.$2,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
