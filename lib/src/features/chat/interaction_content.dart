import 'interactive_button_layout.dart';
import 'interactive_selection_view.dart';
import '../../domain/interactive_selection.dart';
import 'package:flutter/material.dart';
import 'interactive_message_button.dart';
import '../../agent/ask_user_tool.dart';
import 'user_question_option_tile.dart';

/// Renders projected data only. Rules and settlement live in the domain layer.
class InteractionContent extends StatelessWidget {
  const InteractionContent({
    super.key,
    required this.view,
    required this.shared,
    required this.buttons,
    required this.buttonColumns,
    required this.readOnly,
    required this.allowChange,
    required this.eligible,
    required this.busy,
    this.pendingButtonId,
    required this.onClick,
    this.question = false,
  });
  final Map<String, Object?> view;
  final int buttonColumns;
  final List<Map<String, Object?>> buttons;
  final bool readOnly, allowChange, eligible, shared;
  final String? busy;
  final String? pendingButtonId;
  final bool question;
  final void Function(Map<String, Object?> button, {Object? value}) onClick;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final submitted = view['submitted'] == true;
    final participantButtons = eligible
        ? buttons
        : const <Map<String, Object?>>[];
    final collecting = view['phase'] == 'collecting' && view['closed'] != true;
    final choosing = collecting && (!submitted || allowChange);
    final self = view['self'] as Map?;
    final answer = question
        ? self ?? (view['choices'] as List?)?.firstOrNull as Map?
        : null;
    final selectedButton = collecting && submitted && !allowChange
        ? participantButtons
              .where(
                (button) =>
                    button['selection'] == null &&
                    button['id'] == self!['buttonId'] &&
                    button['label'] == self['label'] &&
                    (button['action'] == 'submit' || !shared),
              )
              .firstOrNull
        : null;
    final showSubmitted = selectedButton != null;
    final status = view['closed'] == true || view['phase'] == 'closed'
        ? (question && answer != null ? '已回答' : '已结束')
        : view['completed'] == true
        ? '本轮已完成'
        : collecting
        ? (eligible ? '进行中' : '进行中 · 仅可查看')
        : null;
    final participationSummary = [
      if (status != null) status,
      if (!question && view['summaryVisible'] == true)
        '${view['submittedCount']} 人参与',
    ].join(' · ');
    final actions = participantButtons
        .where((button) => button['selection'] == null)
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
        if (participationSummary.isNotEmpty)
          Text(
            participationSummary,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        if (view['revealed'] == true && view['summaryVisible'] != true)
          Text(
            '统计尚未公开',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        if (question && !choosing && answer != null) ...[
          const SizedBox(height: 12),
          UserQuestionOptionTile(
            option: UserQuestionOption(
              title: '${answer['name']}的回答',
              content: answer['label'] as String,
            ),
            number: 1,
            selected: true,
            onTap: null,
          ),
        ],
        if ((actions.isNotEmpty || showSubmitted) &&
            (status != null ||
                (view['revealed'] == true && view['summaryVisible'] != true)))
          const SizedBox(height: 12),
        for (final button in buttons.where(
          (button) =>
              collecting &&
              (!question || choosing) &&
              button['selection'] != null,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InteractiveSelectionView(
              key: ValueKey((button['id'], view['round'])),
              button: button,
              question: question,
              self: self,
              locked:
                  readOnly ||
                  !eligible ||
                  !collecting ||
                  busy != null ||
                  pendingButtonId == button['id'],
              submitted: submitted,
              allowChange: allowChange,
              busy: busy == button['id'],
              showSubmit: eligible && !readOnly,
              onSubmit: (value) => onClick(button, value: value),
            ),
          ),
        if (selectedButton != null) ...[
          InteractiveMessageButton(
            button: {
              ...selectedButton,
              'label':
                  selectedButton['completedLabel'] ?? selectedButton['label'],
              'disabled': true,
            },
            busy: false,
            locked: true,
            onPressed: () {},
          ),
          if (actions.isNotEmpty) const SizedBox(height: 8),
        ],
        InteractiveButtonLayout(
          columns: buttonColumns,
          children: [
            for (final button in actions)
              InteractiveMessageButton(
                button: button,
                busy: busy == button['id'],
                locked:
                    readOnly || busy != null || pendingButtonId == button['id'],
                onPressed: () => onClick(button),
              ),
          ],
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
    final total = data['total'] as num;
    final selected = data['selected'] as Map?;
    final items = data['items'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, option) in items.indexed)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : 16,
            ),
            child: Builder(
              builder: (context) {
                final count = option['count'] as num;
                final ratio = total == 0 ? 0.0 : count / total;
                final mine =
                    selected != null &&
                    selectionEntries(Map<String, Object?>.from(selected)).any(
                      (choice) =>
                          choice['buttonId'] == option['buttonId'] &&
                          choice['label'] == option['label'],
                    );
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
      ],
    );
  }
}
