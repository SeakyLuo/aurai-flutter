import 'package:flutter/material.dart';

import '../../domain/interactive_message.dart';
import '../../domain/message_sender.dart';
import 'vote_message_heading.dart';
import 'participation_summary.dart';

/// Kept outside the result scroll view so the vote context stays visible.
class VoteStatisticsHeader extends StatelessWidget {
  const VoteStatisticsHeader({super.key, required this.card});

  final InteractiveMessage card;

  @override
  Widget build(BuildContext context) {
    final actors = (card.interaction['actors'] as List?)?.cast<String>();
    final eligible =
        actors == null || actors.contains(MessageSender.localUser.id);
    final multiple = card.buttons.any(
      (button) => (button['selection'] as Map?)?['mode'] == 'multiple',
    );
    final rules = [
      if (!card.isQuestionnaire) ...[
        if (card.interaction.containsKey('actorWeights'))
          '按参与者票值计票'
        else if (multiple)
          '每个所选项各计一票',
        if (card.engine.allowChange) '改票会替换原票',
      ] else if (card.engine.allowChange)
        '提交后可修改回答',
    ];
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VoteMessageHeading(
            questionnaire: card.isQuestionnaire,
            title: card.title,
            multiple: multiple,
            ongoing: !card.closed && !card.completed,
            anonymous: card.anonymous,
            status: card.closed
                ? '已结束'
                : card.completed
                ? '已完成'
                : '进行中',
          ),
          if (card.body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(card.body, style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
          if (card.visible('summaryVisibility') || !eligible) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (card.visible('summaryVisibility'))
                  participationSummaryText(
                    card.choices.length,
                    actors?.length,
                    questionnaire: card.isQuestionnaire,
                  ),
                if (!eligible) '不需要你参与',
              ].join(' · '),
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
