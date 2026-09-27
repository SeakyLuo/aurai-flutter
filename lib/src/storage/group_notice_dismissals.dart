import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

const groupNoticeDismissalsSchema = '''CREATE TABLE group_notice_dismissals (
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES message_senders(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK(kind IN ('announcement', 'pin')),
  version TEXT NOT NULL,
  PRIMARY KEY (conversation_id, sender_id, kind)
)''';

class GroupNoticeDismissals {
  const GroupNoticeDismissals(this.database);
  final Database database;

  Future<Map<String, String>> read(String groupId, String senderId) async {
    final rows = await database.query(
      'group_notice_dismissals',
      where: 'conversation_id = ? AND sender_id = ?',
      whereArgs: [groupId, senderId],
    );
    return {
      for (final row in rows) row['kind'] as String: row['version'] as String,
    };
  }

  Future<void> dismiss(
    String groupId,
    String senderId,
    String kind,
    String version,
  ) async {
    await database.transaction((txn) async {
      final members = await txn.query(
        'conversation_members',
        columns: ['sender_id'],
        where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
        whereArgs: [groupId, senderId],
        limit: 1,
      );
      if (members.isEmpty) throw StateError('群聊不存在或你已不在群中');
      await txn.insert('group_notice_dismissals', {
        'conversation_id': groupId,
        'sender_id': senderId,
        'kind': kind,
        'version': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

/// One-time import of the human viewer's existing banner preferences.
Future<void> migrateGroupNoticeDismissals(Database db) async {
  await db.execute(groupNoticeDismissalsSchema);
  final preferences = SharedPreferencesAsync();
  final keys = (await preferences.getKeys())
      .where(
        (key) =>
            key.startsWith('groupAnnouncementDismissed:') ||
            key.startsWith('groupPinDismissed:'),
      )
      .toList();
  final values = await Future.wait(keys.map(preferences.getInt));
  final groups = (await db.query(
    'conversations',
    columns: ['id'],
    where: "kind = 'group'",
  )).map((row) => row['id']).toSet();
  final batch = db.batch();
  for (var i = 0; i < keys.length; i++) {
    final key = keys[i];
    final groupId = key.substring(key.indexOf(':') + 1);
    if (!groups.contains(groupId)) continue;
    batch.insert('group_notice_dismissals', {
      'conversation_id': groupId,
      'sender_id': 'user:local',
      'kind': key.startsWith('groupAnnouncement') ? 'announcement' : 'pin',
      'version': values[i]!.toString(),
    });
  }
  await batch.commit(noResult: true);
}
