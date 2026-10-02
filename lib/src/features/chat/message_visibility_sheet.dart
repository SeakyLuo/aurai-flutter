import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import 'member_avatar.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';

Future<void> showMessageVisibilitySheet(
  BuildContext context, {
  required AgentMessage message,
  required Database database,
}) async {
  final audience = message.excludedAudience ?? message.audience;
  final rows = await database.query(
    'message_senders',
    where: audience == null
        ? 'id IN (SELECT sender_id FROM conversation_members '
              'WHERE conversation_id = (SELECT conversation_id FROM messages '
              'WHERE id = ?) AND left_at IS NULL)'
        : 'id IN (${List.filled(audience.length, '?').join(',')})',
    whereArgs: audience == null ? [message.id] : audience,
  );
  final members = rows.map(MessageSender.fromRow).toList();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  SettingsGlassAction(
                    label: '关闭',
                    icon: Icons.close_rounded,
                    iconWidget: const QuestionIcon(
                      type: QuestionIconType.close,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      message.excludedAudience != null
                          ? '以下成员不可见'
                          : audience == null
                          ? '所有群成员可见'
                          : '仅以下成员可见',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  for (final member in members)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          MemberAvatar(sender: member, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              member.name,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
