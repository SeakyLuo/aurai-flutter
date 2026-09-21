import '../../app/glass_notice.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/message_quick_reply.dart';
import '../../domain/quick_reply_option.dart';
import '../../domain/message_sender.dart';
import '../../domain/error_message.dart';
import 'member_avatar.dart';

class QuickReplyChips extends StatelessWidget {
  const QuickReplyChips({
    super.key,
    required this.replies,
    required this.database,
    this.onTap,
  });
  final List<MessageQuickReply> replies;
  final Database database;
  final Future<void> Function(String)? onTap;

  Future<void> _showPeople(BuildContext context) async {
    try {
      final ids = replies.map((r) => r.senderId).toSet();
      final rows = await database.query(
        'message_senders',
        where: 'id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids.toList(),
      );
      final senders = {
        for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
      };
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                for (final key in replies.map((r) => r.key).toSet()) ...[
                  Text(
                    '${quickReplyOptionsByKey[key]!.emoji} · ${replies.where((r) => r.key == key).length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  for (final reply in replies.where((r) => r.key == key))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: MemberAvatar(sender: senders[reply.senderId]!),
                      title: Text(senders[reply.senderId]!.name),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      );
    } on Object catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final key in replies.map((r) => r.key).toSet())
        Builder(
          builder: (context) {
            final group = replies.where((r) => r.key == key).toList();
            final own = group.any(
              (r) => r.senderId == MessageSender.localUser.id,
            );
            final colors = Theme.of(context).colorScheme;
            return Material(
              color: own
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap != null ? () => onTap!(key) : null,
                onLongPress: () => _showPeople(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 13,
                        color: own
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(quickReplyOptionsByKey[key]!.emoji),
                          Container(
                            width: .5,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            color:
                                (own
                                        ? colors.onPrimaryContainer
                                        : colors.onSurfaceVariant)
                                    .withValues(alpha: .2),
                          ),
                          Flexible(
                            child: Text(
                              group.first.senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (group.length > 1) Text('等 ${group.length} 人'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );
}
