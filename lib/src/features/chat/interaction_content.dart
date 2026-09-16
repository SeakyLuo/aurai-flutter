import 'package:flutter/material.dart';
import 'interactive_message_button.dart';

/// Renders projected data only. Rules and settlement live in the domain layer.
class InteractionContent extends StatelessWidget {
  const InteractionContent({
    super.key,
    required this.view,
    required this.shared,
    required this.buttons,
    required this.readOnly,
    required this.allowChange,
    required this.eligible,
    required this.editing,
    required this.busy,
    required this.onEditing,
    required this.onClick,
  });
  final Map<String, Object?> view;
  final List<Map<String, Object?>> buttons;
  final bool readOnly, allowChange, eligible, editing, shared;
  final String? busy;
  final ValueChanged<bool> onEditing;
  final ValueChanged<Map<String, Object?>> onClick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final submitted = view['submitted'] == true;
    final collecting = view['phase'] == 'collecting' && view['closed'] != true;
    final choosing = collecting && (!submitted || editing);
    final self = view['self'] as Map?;
    final actions = buttons
        .where(
          (button) => button['action'] == 'nextRound'
              ? view['completed'] == true && view['closed'] != true
              : (button['action'] == 'submit' || !shared)
              ? choosing
              : collecting,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!editing)
          for (final component in view['components'] as List)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: switch (component['type']) {
                'distribution' => InteractionDistribution(
                  data: Map<String, Object?>.from(component as Map),
                ),
                'metric' => Text(
                  '${component['label'] ?? ''} ${component['value'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _ => Text(
                  '${component['value'] ?? ''}',
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              },
            ),
        Text(
          view['closed'] == true || view['phase'] == 'closed'
              ? '已结束'
              : view['completed'] == true
              ? '本轮已完成'
              : submitted
              ? (view['revealed'] == true
                    ? '已提交：${self!['label']}'
                    : '已提交：${self!['label']}，等待其他参与者')
              : eligible
              ? '请选择'
              : '等待本轮参与者提交',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        if (view['revealed'] == true && view['summaryVisible'] != true)
          Text(
            '统计尚未公开',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        if (actions.isNotEmpty) const SizedBox(height: 12),
        for (final (index, button) in actions.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          InteractiveMessageButton(
            button: button,
            busy: busy == button['id'],
            locked:
                readOnly ||
                busy != null ||
                (!eligible &&
                    ['submit', 'nextRound'].contains(button['action'])),
            onPressed: () => onClick(button),
          ),
        ],
        if (collecting && submitted && allowChange && eligible && !readOnly)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy != null ? null : () => onEditing(!editing),
              child: Text(editing ? '取消修改' : '修改选择'),
            ),
          ),
      ],
    );
  }
}

class InteractionDistribution extends StatelessWidget {
  const InteractionDistribution({super.key, required this.data});
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = data['total'] as int;
    final selected = data['selected'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in data['items'] as List)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Builder(
              builder: (context) {
                final count = option['count'] as int;
                final ratio = total == 0 ? 0.0 : count / total;
                final mine =
                    selected?['buttonId'] == option['buttonId'] &&
                    selected?['label'] == option['label'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${option['label']}${mine ? ' · 我的选择' : ''}',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: mine ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                            backgroundColor: colors.surfaceContainerHighest,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$count ${data['unit']} · ${(ratio * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        Text(
          '$total 人参与',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
