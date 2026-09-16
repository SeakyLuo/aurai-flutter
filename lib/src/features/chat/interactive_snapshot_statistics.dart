import 'package:flutter/material.dart';
import '../../domain/interactive_message.dart';
import 'interaction_content.dart';

class InteractiveSnapshotStatistics extends StatelessWidget {
  const InteractiveSnapshotStatistics({super.key, required this.card});
  final InteractiveMessage card;

  @override
  Widget build(BuildContext context) {
    final view = card.snapshotView;
    final visible =
        view?['summaryVisible'] == true && view?['revealed'] == true;
    final distribution = view?['distribution'] as List?;
    final submissions = view?['submissions'] as Map?;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          '当前历史版本${view?['round'] == null ? '' : ' · 第 ${view!['round']} 轮'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        if (visible && distribution != null)
          InteractionDistribution(
            data: {
              'items': distribution,
              'total': view!['submittedCount'],
              'selected': view['self'],
              'unit': '人',
            },
          )
        else
          Text(view?['revealed'] == false ? '此版本尚未揭晓统计' : '此版本未公开汇总统计'),
        if (submissions != null) ...[
          const SizedBox(height: 20),
          const Text('当时的参与者选择'),
          for (final choice in submissions.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(choice['name'] as String),
              subtitle: Text(choice['label'] as String),
            ),
        ],
      ],
    );
  }
}
