import 'package:flutter/material.dart';
import '../../domain/interactive_selection.dart';
import '../../domain/interactive_message.dart';
import '../../domain/message_sender.dart';
import 'member_profile_avatar.dart';
import 'chat_controller.dart';
import 'settings_icon.dart';

typedef InteractiveOptionKey = (String, String);

class InteractiveStatisticsOverview extends StatelessWidget {
  const InteractiveStatisticsOverview({
    super.key,
    required this.card,
    required this.controller,
    required this.groupId,
    required this.senders,
    required this.onParticipant,
    required this.onOption,
  });
  final InteractiveMessage card;
  final ChatController controller;
  final String groupId;
  final Map<String, MessageSender> senders;
  final ValueChanged<String> onParticipant;
  final ValueChanged<InteractiveOptionKey> onOption;

  @override
  Widget build(BuildContext context) {
    final summaryVisible = card.visible('summaryVisibility');
    final peopleVisible = card.visible('visibility');
    final multiple = card.buttons.any(
      (button) => (button['selection'] as Map?)?['mode'] == 'multiple',
    );
    final groups = <InteractiveOptionKey, List<String>>{};
    if (peopleVisible) {
      for (final entry in card.choices.entries) {
        for (final choice in selectionEntries(entry.value)) {
          final key = (choice['buttonId'] as String, choice['label'] as String);
          groups.putIfAbsent(key, () => []).add(entry.key);
        }
      }
    }
    final people = peopleVisible
        ? card.choices.keys.toList()
        : card.choices.keys
              .where((id) => id == MessageSender.localUser.id)
              .toList();
    return ListView(
      key: const PageStorageKey('statistics-overview'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          card.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          [
            card.closed
                ? '已结束'
                : card.completed
                ? '本轮已完成'
                : '进行中',
            if (summaryVisible) '${card.choices.length} 人参与',
          ].join(' · '),
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (card.hasInteraction) ...[
          const SizedBox(height: 8),
          Text(
            '投票规则：${[card.interaction.containsKey('actorWeights')
                ? '按参与者票值计票'
                : multiple
                ? '多选，每个所选项各计一票'
                : '单选，每人一票', if (card.engine.allowChange) '改票会替换原票', if (multiple) '每个所选项分别计票'].join('；')}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (summaryVisible) ...[
          Text(
            card.hasInteraction
                ? card.completed
                      ? '投票结果'
                      : '实时票数'
                : '最近操作',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (!card.hasInteraction) ...[
            const SizedBox(height: 6),
            Text(
              '按每人最近一次操作汇总',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          for (final option in card.summary)
            _option(
              context,
              option,
              groups[(
                    option['buttonId'] as String,
                    option['label'] as String,
                  )] ??
                  const [],
            ),
          if (card.choices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('还没有人参与'),
            ),
        ] else ...[
          Text(
            card.shared && !card.engine.revealed
                ? '本轮尚未揭晓统计'
                : card.participation['summaryVisibility'] == 'afterClose'
                ? '结束后公开汇总'
                : '汇总不公开',
          ),
          const SizedBox(height: 20),
        ],
        if (!summaryVisible || !peopleVisible) ...[
          Text(
            peopleVisible ? '参与情况' : '我的记录',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (!peopleVisible) ...[
            const SizedBox(height: 8),
            Text(
              card.shared && !card.engine.revealed
                  ? '本轮尚未公开参与者选择'
                  : card.participation['visibility'] == 'afterClose'
                  ? '结束后公开参与者记录'
                  : '其他人的记录不公开',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(peopleVisible ? '还没有人参与' : '你还没有参与'),
            ),
          for (final id in people)
            InteractiveParticipantTile(
              controller: controller,
              groupId: groupId,
              card: card,
              sender: statisticsSender(card, senders, id),
              actor: id,
              onTap: () => onParticipant(id),
            ),
        ],
      ],
    );
  }

  Widget _option(
    BuildContext context,
    Map<String, Object?> option,
    List<String> people,
  ) {
    final colors = Theme.of(context).colorScheme;
    final count = option['count'] as num;
    final ratio = card.choices.isEmpty ? 0.0 : count / card.totalWeight;
    final key = (option['buttonId'] as String, option['label'] as String);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: card.visible('visibility') ? () => onOption(key) : null,
        child: Semantics(
          button: card.visible('visibility'),
          label:
              '选项：${option['label']}，$count ${card.hasInteraction ? '票' : '人'}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      option['label'] as String,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$count ${card.hasInteraction ? '票' : '人'}${card.hasInteraction ? ' · ${(ratio * 100).round()}%' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (card.hasInteraction) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.primary,
                ),
              ],
              if (people.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    for (
                      var index = 0;
                      index < people.length && index < 5;
                      index++
                    )
                      Tooltip(
                        message: statisticsName(card, people[index]),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Stack(
                            children: [
                              MemberProfileAvatar(
                                controller: controller,
                                groupId: groupId,
                                sender: statisticsSender(
                                  card,
                                  senders,
                                  people[index],
                                ),
                                size: 32,
                              ),
                              if (index == 4 && people.length > 5)
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: .48,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '+${people.length - 5}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String statisticsName(InteractiveMessage card, String id) =>
    id == MessageSender.localUser.id
    ? '我'
    : card.participants[id]!['name'] as String;

MessageSender statisticsSender(
  InteractiveMessage card,
  Map<String, MessageSender> senders,
  String id,
) =>
    senders[id] ??
    MessageSender(
      id: id,
      name: card.participants[id]!['name'] as String,
      kind: MessageSenderKind.agent,
    );

class InteractiveParticipantTile extends StatelessWidget {
  const InteractiveParticipantTile({
    super.key,
    required this.card,
    required this.controller,
    required this.groupId,
    required this.sender,
    required this.actor,
    required this.onTap,
  });
  final InteractiveMessage card;
  final ChatController controller;
  final String groupId;
  final MessageSender sender;
  final String actor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: MemberProfileAvatar(
      controller: controller,
      sender: sender,
      groupId: groupId,
    ),
    title: Text(statisticsName(card, actor)),
    subtitle: Text(
      card.shared
          ? (card.choices[actor]?['label'] as String? ?? '本轮尚未提交')
          : card.participants[actor]!['label'] as String,
    ),
    trailing: const SettingsIcon(type: SettingsIconType.chevron),
    onTap: onTap,
  );
}
