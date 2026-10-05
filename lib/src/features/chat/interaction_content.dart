import 'interactive_button_layout.dart';
import 'interactive_selection_view.dart';
import '../../domain/interactive_selection.dart';
import 'package:flutter/material.dart';
import 'interactive_message_button.dart';
import '../../domain/message_sender.dart';
import 'vote_participant_avatars.dart';

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
    this.members = const {},
    this.onOpenMember,
    this.onStatistics,
  });
  final Map<String, Object?> view;
  final int buttonColumns;
  final List<Map<String, Object?>> buttons;
  final bool readOnly, allowChange, eligible, shared;
  final String? busy;
  final String? pendingButtonId;
  final bool question;
  final Map<String, MessageSender> members;
  final ValueChanged<String>? onOpenMember;
  final VoidCallback? onStatistics;
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
    final editingSelection = choosing && eligible && !readOnly;
    final components = (view['components'] as List);
    final hasDistribution = components.any(
      (component) => component['type'] == 'distribution',
    );
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
        for (final component in components.where(
          (component) =>
              question ||
              !editingSelection ||
              component['type'] != 'distribution',
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: switch (component['type']) {
              'distribution' => InteractionDistribution(
                data: Map<String, Object?>.from(component as Map),
                hideZeroVotes: true,
                submissions: view['submissions'] as Map?,
                members: members,
                onOpenMember: onOpenMember,
                onShowAll: onStatistics,
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
        if (!question && participationSummary.isNotEmpty)
          Text(
            participationSummary,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        if (view['revealed'] == true && view['summaryVisible'] != true)
          Text(
            '统计尚未公开',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        if ((actions.isNotEmpty || showSubmitted) &&
            (status != null ||
                (view['revealed'] == true && view['summaryVisible'] != true)))
          const SizedBox(height: 12),
        for (final button in buttons.where(
          (button) =>
              (question ||
                  editingSelection ||
                  (collecting && !hasDistribution)) &&
              button['selection'] != null,
        ))
          Padding(
            padding: EdgeInsets.only(bottom: question ? 0 : 8),
            child: InteractiveSelectionView(
              key: ValueKey((button['id'], view['round'])),
              button: button,
              question: question,
              self: question ? answer : self,
              locked:
                  readOnly ||
                  !eligible ||
                  !collecting ||
                  busy != null ||
                  pendingButtonId == button['id'],
              submitted: question ? answer != null : submitted,
              allowChange: allowChange,
              busy: busy == button['id'],
              showSubmit:
                  eligible &&
                  !readOnly &&
                  collecting &&
                  (!question || choosing),
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
  const InteractionDistribution({
    super.key,
    required this.data,
    this.hideZeroVotes = false,
    this.submissions,
    this.members = const {},
    this.onOpenMember,
    this.onShowAll,
  });
  final Map<String, Object?> data;
  final bool hideZeroVotes;
  final Map? submissions;
  final Map<String, MessageSender> members;
  final ValueChanged<String>? onOpenMember;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = data['total'] as num;
    final selected = data['selected'] as Map?;
    final options = data['items'] as List;
    final items = hideZeroVotes && options.length >= 3
        ? options.where((option) => option['count'] != 0).toList()
        : options;
    final voters = <(String, String), List<MessageSender>>{};
    if (items.length <= 2 && submissions != null) {
      for (final entry in submissions!.entries) {
        final id = entry.key as String;
        final choice = Map<String, Object?>.from(entry.value as Map);
        final sender =
            members[id] ??
            MessageSender(
              id: id,
              name: choice['name'] as String,
              kind: MessageSenderKind.agent,
            );
        for (final selection in selectionEntries(choice)) {
          voters
              .putIfAbsent((
                selection['buttonId'] as String,
                selection['label'] as String,
              ), () => [])
              .add(sender);
        }
      }
    }
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
                            backgroundColor: colors.onSurface.withValues(
                              alpha: 0.08,
                            ),
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
                    if (voters[(option['buttonId'], option['label'])]
                        case final people? when people.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      VoteParticipantAvatars(
                        people: people,
                        onOpenMember: onOpenMember,
                        onShowAll: onShowAll,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
