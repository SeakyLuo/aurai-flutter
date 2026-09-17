import 'package:flutter/material.dart';
import '../features/chat/settings_appearance.dart';
import 'memory_plan.dart';

class MemoryPlanPreview extends StatelessWidget {
  const MemoryPlanPreview({super.key, required this.plan});
  final MemoryPlan plan;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '建议调整 · ${plan.changes.length} 项',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '确认后才会应用，手动保存的记忆保持不变。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final change in plan.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChangeCard(change: change),
          ),
      ],
    ),
  );
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.change});
  final MemoryChange change;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final deleting = change.ids.isNotEmpty && change.text.isEmpty;
    final adding = change.ids.isEmpty;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = deleting
        ? colors.error
        : adding
        ? (dark ? const Color(0xff82d9bb) : const Color(0xff168365))
        : colors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(18),
        border: deleting
            ? Border.all(color: accent.withValues(alpha: .3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '待${change.label}',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!adding) ...[
            if (!deleting) ...[
              Text(
                '修改前',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
            ],
            for (final text in change.before)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: deleting ? 16 : 14,
                    height: 1.5,
                    color: deleting
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                    fontWeight: deleting ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
          ],
          if (!deleting) ...[
            if (!adding) ...[
              const SizedBox(height: 4),
              Text(
                '修改后',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              change.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Divider(
            height: 16,
            color: colors.outlineVariant.withValues(alpha: .5),
          ),
          Text(
            deleting ? '删除原因' : '调整原因',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            change.reason,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
