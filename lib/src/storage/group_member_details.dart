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

  Future<({String nickname, String remark})> read(String groupId) async {
    final rows = await database.query(
      'group_member_details',
      where: 'conversation_id = ? AND sender_id = ?',
      whereArgs: [groupId, MessageSender.localUser.id],
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
    required String nickname,
    required String remark,
  }) async {
    await database.insert('group_member_details', {
      'conversation_id': groupId,
      'sender_id': MessageSender.localUser.id,
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
