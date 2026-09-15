import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import '../features/chat/conversation.dart';

class GroupUnreadMessages {
  GroupUnreadMessages(this.database);
  final Database database;
  static const baselineKey = 'group_unread_started_at';

  Future<void> initialize() => database.insert('app_state', {
    'key': baselineKey,
    'value': DateTime.now().microsecondsSinceEpoch.toString(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> load(List<Conversation> conversations) async {
    final groups = conversations
        .where((c) => c.kind == ConversationKind.group)
        .toList();
    if (groups.isEmpty) return;
    final states = await database.query(
      'app_state',
      where: 'key IN (${List.filled(groups.length + 1, '?').join(',')})',
      whereArgs: [baselineKey, for (final c in groups) 'group_read:${c.id}'],
    );
    final values = {
      for (final row in states) row['key']: row['value'] as String,
    };
    final baseline = int.parse(values[baselineKey]!);
    for (final group in groups) {
      final saved = values['group_read:${group.id}'];
      final cursor = saved == null ? null : jsonDecode(saved) as Map;
      group.groupReadAt = cursor == null ? baseline : cursor['at'] as int;
      group.groupReadId = cursor == null ? '' : cursor['id'] as String;
      group.unreadMessageCount = 0;
    }
    final rows = await database.rawQuery(
      '''
      SELECT conversation_id, COUNT(*) AS unread FROM messages
      WHERE sender_id != ? AND role = 'assistant'
        AND kind NOT IN ('commentary', 'system') AND (
          ${groups.map((_) => '(conversation_id = ? AND (created_at > ? OR (created_at = ? AND id > ?)))').join(' OR ')}
        ) GROUP BY conversation_id
    ''',
      [
        MessageSender.localUser.id,
        for (final c in groups) ...[
          c.id,
          c.groupReadAt,
          c.groupReadAt,
          c.groupReadId,
        ],
      ],
    );
    final byId = {for (final c in groups) c.id: c};
    for (final row in rows) {
      byId[row['conversation_id']]!.unreadMessageCount = row['unread'] as int;
    }
  }

  Future<void> markRead(Conversation conversation, AgentMessage through) async {
    final at = through.createdAt.microsecondsSinceEpoch;
    await database.rawInsert(
      '''
      INSERT INTO app_state(key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      WHERE json_extract(excluded.value, '\$.at') > json_extract(app_state.value, '\$.at')
        OR (json_extract(excluded.value, '\$.at') = json_extract(app_state.value, '\$.at')
          AND json_extract(excluded.value, '\$.id') > json_extract(app_state.value, '\$.id'))
    ''',
      [
        'group_read:${conversation.id}',
        jsonEncode({'at': at, 'id': through.id}),
      ],
    );
    if (at > conversation.groupReadAt ||
        (at == conversation.groupReadAt &&
            through.id.compareTo(conversation.groupReadId) > 0)) {
      conversation.groupReadAt = at;
      conversation.groupReadId = through.id;
      conversation.unreadMessageCount = 0;
    }
  }
}
