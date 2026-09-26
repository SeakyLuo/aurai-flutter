import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'group_chat_store.dart';
import 'group_system_notice.dart';

const groupMessageMarksSchema = [
  '''CREATE TABLE group_pinned_messages (
    conversation_id TEXT PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    updated_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE group_favorite_messages (
    conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    saved_at INTEGER NOT NULL,
    marked_by TEXT,
    PRIMARY KEY (conversation_id, message_id)
  )''',
  'CREATE INDEX group_pin_message ON group_pinned_messages(message_id)',
  'CREATE INDEX group_favorite_message ON group_favorite_messages(message_id)',
  'CREATE INDEX group_favorite_time ON group_favorite_messages(conversation_id, saved_at DESC, message_id DESC)',
];

typedef GroupMessageMarkStatus = ({String groupId, bool pinned, bool favorite});

class GroupMessageMarks {
  const GroupMessageMarks(
    this.groups, {
    this.actorId = 'user:local',
    this.accessActorId,
  });
  final GroupChatStore groups;
  final String actorId;
  final String? accessActorId;
  String get viewerId => accessActorId ?? actorId;
  Database get database => groups.database;
  static final changes = StreamController<String>.broadcast();

  Future<void> _member(String groupId, {DatabaseExecutor? executor}) async {
    final rows = await (executor ?? database).query(
      'conversation_members',
      columns: ['sender_id'],
      where:
          "conversation_id = ? AND sender_id = ? AND left_at IS NULL AND conversation_id IN (SELECT id FROM conversations WHERE kind = 'group')",
      whereArgs: [groupId, viewerId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('群聊不存在或你已不在群中');
  }

  Future<GroupMessageMarkStatus?> status(String messageId) async {
    final rows = await database.query(
      'messages',
      columns: ['conversation_id'],
      where: '''id = ? AND kind IN ('user', 'group_message', 'html_game')
        AND conversation_id IN (SELECT id FROM conversations WHERE kind = 'group')
        AND (interactive_json IS NULL OR json_extract(interactive_json, '\$.participation.audience') IS NULL)''',
      whereArgs: [messageId],
    );
    if (rows.isEmpty) return null;
    final groupId = rows.single['conversation_id'] as String;
    await _member(groupId);
    final marks = await Future.wait([
      database.query(
        'group_pinned_messages',
        columns: ['message_id'],
        where: 'conversation_id = ? AND message_id = ?',
        whereArgs: [groupId, messageId],
      ),
      database.query(
        'group_favorite_messages',
        columns: ['message_id'],
        where: 'conversation_id = ? AND message_id = ?',
        whereArgs: [groupId, messageId],
      ),
    ]);
    return (
      groupId: groupId,
      pinned: marks[0].isNotEmpty,
      favorite: marks[1].isNotEmpty,
    );
  }

  Future<void> pin(String groupId, String messageId, bool value) =>
      _set('group_pinned_messages', 'updated_at', groupId, messageId, value);

  Future<void> favorite(String groupId, String messageId, bool value) =>
      _set('group_favorite_messages', 'saved_at', groupId, messageId, value);

  Future<void> _set(
    String table,
    String timeColumn,
    String groupId,
    String messageId,
    bool value,
  ) async {
    final notice = await database.transaction((txn) async {
      await _member(groupId, executor: txn);
      if (value) {
        final rows = await txn.query(
          'messages',
          columns: ['id'],
          where:
              r"id = ? AND conversation_id = ? AND kind IN ('user', 'group_message', 'html_game') AND (interactive_json IS NULL OR json_extract(interactive_json, '$.participation.audience') IS NULL)",
          whereArgs: [messageId, groupId],
        );
        if (rows.isEmpty) throw StateError('只能操作本群对所有成员可见的消息');
        await txn.insert(
          table,
          {
            'conversation_id': groupId,
            'message_id': messageId,
            timeColumn: DateTime.now().microsecondsSinceEpoch,
            if (table == 'group_favorite_messages') 'marked_by': actorId,
          },
          conflictAlgorithm: table == 'group_pinned_messages'
              ? ConflictAlgorithm.replace
              : ConflictAlgorithm.ignore,
        );
        if (table == 'group_pinned_messages') {
          final senders = await txn.query(
            'message_senders',
            columns: ['name'],
            where: 'id = ?',
            whereArgs: [actorId],
          );
          return writeGroupNotice(
            txn,
            groupId,
            '${senders.single['name']} 置顶了一条消息',
          );
        }
      } else {
        await txn.delete(
          table,
          where: 'conversation_id = ? AND message_id = ?',
          whereArgs: [groupId, messageId],
        );
      }
      return null;
    });
    changes.add(groupId);
    if (notice != null) await groups.onSystemNotice?.call(groupId, notice);
  }

  Future<Map<String, Object?>?> pinned(String groupId) async {
    await _member(groupId);
    final marks = await database.query(
      'group_pinned_messages',
      where: 'conversation_id = ?',
      whereArgs: [groupId],
    );
    if (marks.isEmpty) return null;
    final rows = await database.query(
      'messages',
      where: 'id = ?',
      whereArgs: [marks.single['message_id']],
    );
    if (rows.isEmpty) return null;
    return {...rows.single, 'updated_at': marks.single['updated_at']};
  }

  Future<List<Map<String, Object?>>> page(String groupId, int offset) async {
    await _member(groupId);
    final marks = await database.query(
      'group_favorite_messages',
      where: 'conversation_id = ?',
      whereArgs: [groupId],
      orderBy: 'saved_at DESC, message_id DESC',
      limit: 40,
      offset: offset,
    );
    if (marks.isEmpty) return [];
    final actorIds = marks
        .map((row) => row['marked_by'])
        .whereType<String>()
        .toSet();
    final results = await Future.wait([
      database.query(
        'messages',
        where: 'id IN (${List.filled(marks.length, '?').join(',')})',
        whereArgs: marks.map((row) => row['message_id']).toList(),
      ),
      if (actorIds.isNotEmpty)
        database.query(
          'message_senders',
          columns: ['id', 'name'],
          where: 'id IN (${List.filled(actorIds.length, '?').join(',')})',
          whereArgs: actorIds.toList(),
        ),
    ]);
    final rows = results.first;
    final names = {
      if (actorIds.isNotEmpty)
        for (final actor in results[1]) actor['id']: actor['name'],
    };
    final byId = {for (final row in rows) row['id']: row};
    return [
      for (final mark in marks)
        if (byId.containsKey(mark['message_id']))
          {
            ...byId[mark['message_id']]!,
            'saved_at': mark['saved_at'],
            'marked_by': mark['marked_by'],
            'marked_by_name': names[mark['marked_by']],
          },
    ];
  }
}
