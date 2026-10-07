import 'package:flutter/material.dart';

import '../../domain/interactive_message.dart';
import 'vote_message_heading.dart';

/// Kept outside the result scroll view so the vote context stays visible.
class VoteStatisticsHeader extends StatelessWidget {
  const VoteStatisticsHeader({super.key, required this.card});

  final InteractiveMessage card;

  @override
  Widget build(BuildContext context) {
    final multiple = card.buttons.any(
      (button) => (button['selection'] as Map?)?['mode'] == 'multiple',
    );
    final rules = [
      if (card.interaction.containsKey('actorWeights'))
        '按参与者票值计票'
      else if (multiple)
        '每个所选项各计一票',
      if (card.engine.allowChange) '改票会替换原票',
    ];
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoteMessageHeading(
            title: card.title,
            multiple: multiple,
            ongoing: !card.closed && !card.completed,
            anonymous: card.anonymous,
            status: card.closed
                ? '已结束'
                : card.completed
                ? '本轮已完成'
                : '进行中',
          ),
          if (card.body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(card.body, style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
          if (card.visible('summaryVisibility')) ...[
            const SizedBox(height: 10),
            Text(
              '${card.choices.length} 人参与',
              style: TextStyle(fontSize: 13, color: secondary),
            ),
          ],
          if (rules.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rules.join('；'),
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}
