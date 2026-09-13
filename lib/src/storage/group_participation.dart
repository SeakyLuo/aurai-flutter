import 'package:sqflite/sqflite.dart';

const groupParticipationSchema = '''
CREATE TABLE group_participation (
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES message_senders(id) ON DELETE CASCADE,
  paused INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (conversation_id, sender_id)
)
''';

class GroupParticipation {
  GroupParticipation(this.database);
  final Database database;

  Future<Set<String>> paused(String groupId) async {
    final rows = await database.query(
      'group_participation',
      columns: ['sender_id'],
      where: 'conversation_id = ? AND paused = 1',
      whereArgs: [groupId],
    );
    return rows.map((row) => row['sender_id'] as String).toSet();
  }

  Future<void> set(String groupId, String senderId, bool paused) async {
    await database.insert('group_participation', {
      'conversation_id': groupId,
      'sender_id': senderId,
      'paused': paused ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
