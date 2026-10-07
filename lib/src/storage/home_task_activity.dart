import 'package:sqflite/sqflite.dart';
import '../features/chat/conversation.dart';
import 'conversation_visibility.dart';

Future<void> loadHomeTaskActivity(
  Database database,
  List<Conversation> items,
) async {
  if (items.isEmpty) return;
  final senders = items
      .where((c) => c.isPersonalChat)
      .map((c) => c.defaultSenderId)
      .toSet()
      .toList();
  final groups = items
      .where((c) => c.kind == ConversationKind.group)
      .map((c) => c.id)
      .toList();
  final results = await Future.wait([
    if (senders.isNotEmpty)
      database.query(
        'conversations',
        columns: ['default_sender_id'],
        distinct: true,
        where:
            "kind = 'direct' AND personal_chat = 0 AND archived = 0 AND run_state IN ('running', 'stopping') AND $localUserConversation AND default_sender_id IN (${List.filled(senders.length, '?').join(',')})",
        whereArgs: senders,
      ),
    if (groups.isNotEmpty)
      database.rawQuery(
        '''SELECT DISTINCT conversation_id FROM agent_runs
      WHERE status = 'running' AND conversation_id IN (${List.filled(groups.length, '?').join(',')})
      UNION SELECT DISTINCT conversation_id FROM organized_tasks
      WHERE conversation_id IN (${List.filled(groups.length, '?').join(',')})
        AND task_id IN (SELECT id FROM conversations WHERE run_state IN ('running', 'stopping'))''',
        [...groups, ...groups],
      ),
  ]);
  final activeSenders = senders.isEmpty
      ? <Object?>{}
      : results.first.map((r) => r['default_sender_id']).toSet();
  final activeGroups = groups.isEmpty
      ? <Object?>{}
      : results.last.map((r) => r['conversation_id']).toSet();
  for (final item in items) {
    item.hasRunningTasks = item.isPersonalChat
        ? activeSenders.contains(item.defaultSenderId)
        : activeGroups.contains(item.id);
  }
}
