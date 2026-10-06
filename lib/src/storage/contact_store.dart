import 'package:sqflite/sqflite.dart';

import '../domain/contact_display_names.dart';

const contactSchema = '''CREATE TABLE contacts (
  owner_id TEXT NOT NULL REFERENCES message_senders(id) ON DELETE CASCADE,
  friend_id TEXT NOT NULL REFERENCES message_senders(id) ON DELETE CASCADE,
  remark_name TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  memo TEXT NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(owner_id, friend_id), CHECK(owner_id != friend_id)
)''';

class ContactStore {
  const ContactStore(this.database);
  final Database database;

  Future<void> loadLocalNames() async {
    final rows = await database.query(
      'contacts',
      columns: ['friend_id', 'remark_name'],
      where: "owner_id = 'user:local' AND remark_name != ''",
    );
    ContactDisplayNames.replace({
      for (final row in rows)
        row['friend_id'] as String: row['remark_name'] as String,
    });
  }

  Future<void> setRemark(String friendId, String value) async {
    final name = value.trim();
    if (name.length > 40) throw ArgumentError('备注名最多 40 个字');
    await database.transaction((txn) async {
      final friends = await txn.query(
        'contact_friendships',
        columns: ['friend_id'],
        where: "owner_id = 'user:local' AND friend_id = ?",
        whereArgs: [friendId],
        limit: 1,
      );
      if (friends.isEmpty) throw StateError('请先添加好友，再设置备注名');
      await txn.insert('contacts', {
        'owner_id': 'user:local',
        'friend_id': friendId,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'contacts',
        {
          'remark_name': name,
          'updated_at': DateTime.now().microsecondsSinceEpoch,
        },
        where: "owner_id = 'user:local' AND friend_id = ?",
        whereArgs: [friendId],
      );
    });
    ContactDisplayNames.set(friendId, name);
  }
}
