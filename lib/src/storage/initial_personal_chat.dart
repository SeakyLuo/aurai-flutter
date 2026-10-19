import 'package:sqflite/sqflite.dart';

import '../domain/message_sender.dart';
import '../domain/system_notice_text.dart';
import 'contact_relationships.dart';
import 'personal_chats.dart';
import 'system_notice.dart';

/// Seed a real friend conversation once; deleting it must not recreate it.
Future<void> initializePersonalChat(Database database) => database.transaction((
  txn,
) async {
  final initialized = await txn.query(
    'app_state',
    columns: ['key'],
    where: 'key = ?',
    whereArgs: ['initial_personal_chat'],
    limit: 1,
  );
  if (initialized.isNotEmpty) return;
  final conversations = await txn.query(
    'conversations',
    columns: ['id'],
    limit: 1,
  );
  if (conversations.isEmpty) {
    final rows = await txn.query(
      'message_senders',
      where: 'id = ?',
      whereArgs: [MessageSender.aurai.id],
      limit: 1,
    );
    final sender = MessageSender.fromRow(rows.single);
    await ContactRelationships.befriend(
      txn,
      MessageSender.localUser.id,
      sender.id,
    );
    final id = await PersonalChats.open(txn, sender.id, sender.displayName);
    await writeSystemNotice(
      txn,
      id,
      '你已添加了${systemNoticeMember(sender.id, sender.displayName)}，现在可以开始聊天了。',
    );
    await txn.insert('app_state', {
      'key': 'active_conversation',
      'value': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await txn.insert('app_state', {'key': 'initial_personal_chat', 'value': '1'});
});
