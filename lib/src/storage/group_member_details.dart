import 'package:sqflite/sqflite.dart';
import '../domain/message_sender.dart';

const groupMemberDetailsSchema = '''CREATE TABLE group_member_details (
  conversation_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  nickname TEXT NOT NULL DEFAULT '',
  remark TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (conversation_id, sender_id),
  FOREIGN KEY (conversation_id, sender_id)
    REFERENCES conversation_members(conversation_id, sender_id) ON DELETE CASCADE
)''';

class GroupMemberDetailsStore {
  const GroupMemberDetailsStore(this.database);
  final Database database;

  Future<void> setNickname(
    String groupId, {
    required String actorId,
    required String senderId,
    required String nickname,
  }) async {
    await database.transaction(
      (txn) => setNicknames(
        txn,
        groupId,
        actorId: actorId,
        nicknames: {senderId: nickname},
      ),
    );
  }

  static Future<void> setNicknames(
    DatabaseExecutor db,
    String groupId, {
    required String actorId,
    required Map<String, String> nicknames,
  }) async {
    if (nicknames.isEmpty) return;
    if (nicknames.length > 33 ||
        nicknames.values.any((name) => name.trim().length > 32)) {
      throw ArgumentError(
        '\u7fa4\u6635\u79f0\u6700\u591a32\u5b57\uff0c\u5355\u6b21\u6700\u591a33\u4f4d\u6210\u5458',
      );
    }
    final members = await db.query(
      'conversation_members',
      columns: ['sender_id', 'role'],
      where: 'conversation_id = ? AND left_at IS NULL',
      whereArgs: [groupId],
      limit: 33,
    );
    final ids = members.map((m) => m['sender_id']).toSet();
    if (!ids.contains(actorId) ||
        nicknames.keys.any((id) => !ids.contains(id))) {
      throw StateError(
        '\u53ea\u80fd\u4fee\u6539\u5f53\u524d\u7fa4\u6210\u5458\u7684\u6635\u79f0',
      );
    }
    final actor = members.firstWhere((m) => m['sender_id'] == actorId);
    if (nicknames.keys.any((id) => id != actorId) &&
        !{'owner', 'admin'}.contains(actor['role'])) {
      throw StateError(
        '\u53ea\u6709\u7fa4\u4e3b\u548c\u7fa4\u7ba1\u7406\u5458\u53ef\u4ee5\u4fee\u6539\u5176\u4ed6\u6210\u5458\u7684\u7fa4\u6635\u79f0',
      );
    }
    final stored = await db.query(
      'group_member_details',
      columns: ['sender_id'],
      where: 'conversation_id = ?',
      whereArgs: [groupId],
    );
    final existing = stored.map((row) => row['sender_id']).toSet();
    final batch = db.batch();
    for (final entry in nicknames.entries) {
      if (existing.contains(entry.key)) {
        batch.update(
          'group_member_details',
          {'nickname': entry.value.trim()},
          where: 'conversation_id = ? AND sender_id = ?',
          whereArgs: [groupId, entry.key],
        );
      } else {
        batch.insert('group_member_details', {
          'conversation_id': groupId,
          'sender_id': entry.key,
          'nickname': entry.value.trim(),
          'remark': '',
        });
      }
    }
    await batch.commit(noResult: true);
  }

  Future<({String nickname, String remark})> read(
    String groupId, {
    String senderId = 'user:local',
  }) async {
    final rows = await database.query(
      'group_member_details',
      where: 'conversation_id = ? AND sender_id = ?',
      whereArgs: [groupId, senderId],
    );
    return rows.isEmpty
        ? (nickname: '', remark: '')
        : (
            nickname: rows.single['nickname'] as String,
            remark: rows.single['remark'] as String,
          );
  }

  Future<void> save(
    String groupId, {
    String senderId = 'user:local',
    required String nickname,
    required String remark,
  }) async {
    await database.insert('group_member_details', {
      'conversation_id': groupId,
      'sender_id': senderId,
      'nickname': nickname.trim(),
      'remark': remark.trim(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, MessageSender>> applyNames(
    String groupId,
    Map<String, MessageSender> senders,
  ) async {
    final rows = await database.query(
      'group_member_details',
      columns: ['sender_id', 'nickname'],
      where:
          "conversation_id = ? AND nickname != '' AND sender_id IN (${List.filled(senders.length, '?').join(',')})",
      whereArgs: [groupId, ...senders.keys],
    );
    final result = {...senders};
    for (final row in rows) {
      final sender = senders[row['sender_id']]!;
      result[sender.id] = MessageSender(
        id: sender.id,
        name: row['nickname'] as String,
        kind: sender.kind,
        avatarIcon: sender.avatarIcon,
        avatarColor: sender.avatarColor,
        avatarPath: sender.avatarPath,
        archived: sender.archived,
      );
    }
    return result;
  }
}
