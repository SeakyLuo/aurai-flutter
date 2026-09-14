import 'package:sqflite/sqflite.dart';
import '../domain/message_sender.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';

const contactRelationshipSchema = [
  '''CREATE TABLE contact_friendships (
    owner_id TEXT NOT NULL REFERENCES message_senders(id),
    friend_id TEXT NOT NULL REFERENCES message_senders(id),
    created_at INTEGER NOT NULL,
    PRIMARY KEY(owner_id, friend_id), CHECK(owner_id != friend_id)
  )''',
  '''CREATE TABLE direct_conversation_pairs (
    conversation_id TEXT PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
    first_id TEXT NOT NULL REFERENCES message_senders(id),
    second_id TEXT NOT NULL REFERENCES message_senders(id),
    UNIQUE(first_id, second_id), CHECK(first_id < second_id)
  )''',
  '''INSERT INTO contact_friendships
    SELECT 'user:local', sender_id, created_at FROM ai_profiles WHERE is_temporary = 0
    UNION ALL SELECT sender_id, 'user:local', created_at FROM ai_profiles WHERE is_temporary = 0''',
];

class ContactRelationships {
  ContactRelationships(this.database);
  final Database database;

  static Future<void> befriend(
    DatabaseExecutor db,
    String owner,
    String friend,
  ) async {
    if (owner == friend) throw ArgumentError('不能添加自己为好友');
    final batch = db.batch();
    final now = DateTime.now().microsecondsSinceEpoch;
    for (final pair in [(owner, friend), (friend, owner)]) {
      batch.insert('contact_friendships', {
        'owner_id': pair.$1,
        'friend_id': pair.$2,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> add(String owner, String friend) =>
      database.transaction((txn) async {
        final rows = await txn.query(
          'message_senders',
          columns: ['id'],
          where: 'id IN (?, ?) AND archived = 0',
          whereArgs: [owner, friend],
          limit: 2,
        );
        if (rows.length != 2) throw ArgumentError('请选择两个不同且可用的联系人');
        await befriend(txn, owner, friend);
      });

  Future<List<Map<String, Object?>>> list(
    String owner,
    String query,
    int offset, {
    bool discover = false,
  }) {
    if (offset < 0) throw ArgumentError('分页位置不能为负数');
    return database.query(
      'message_senders',
      columns: ['id', 'name', 'kind'],
      where:
          'id != ? AND archived = 0 AND instr(lower(name), ?) > 0 '
          '${discover ? '' : 'AND id IN (SELECT friend_id FROM contact_friendships WHERE owner_id = ?)'}',
      whereArgs: [owner, query.toLowerCase(), if (!discover) owner],
      orderBy: 'name, id',
      limit: 51,
      offset: offset,
    );
  }

  Future<String> create(
    String owner,
    String friend,
    String title,
  ) => database.transaction((txn) async {
    final friendship = await txn.query(
      'contact_friendships',
      columns: ['friend_id'],
      where: 'owner_id = ? AND friend_id = ?',
      whereArgs: [owner, friend],
      limit: 1,
    );
    if (friendship.isEmpty) throw StateError('请先添加好友，再创建私聊');
    final pair = [owner, friend]..sort();
    final existing = await txn.query(
      'direct_conversation_pairs',
      where: 'first_id = ? AND second_id = ?',
      whereArgs: pair,
      limit: 1,
    );
    if (existing.isNotEmpty)
      return existing.single['conversation_id'] as String;
    // Keep existing human conversations, including their topic/history, intact.
    final old = await txn.query(
      'conversations',
      columns: ['id'],
      where:
          "kind = 'direct' AND id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL) AND id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL)",
      whereArgs: pair,
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    final String id;
    if (old.isNotEmpty) {
      id = old.single['id'] as String;
    } else {
      final conversation = Conversation.empty()
        ..defaultSenderId = friend == MessageSender.localUser.id
            ? owner
            : friend
        ..storedTitle = title;
      id = conversation.id;
      await txn.insert('conversations', conversationRow(conversation));
      // The legacy insertion trigger adds the human; replace it atomically with the actual pair.
      await txn.delete(
        'conversation_members',
        where: 'conversation_id = ?',
        whereArgs: [id],
      );
      final batch = txn.batch();
      for (final (position, sender) in pair.indexed) {
        batch.insert('conversation_members', {
          'conversation_id': id,
          'sender_id': sender,
          'position': position,
          'joined_at': conversation.createdAt.microsecondsSinceEpoch,
        });
      }
      await batch.commit(noResult: true);
    }
    await txn.insert('direct_conversation_pairs', {
      'conversation_id': id,
      'first_id': pair.first,
      'second_id': pair.last,
    });
    return id;
  });
}
