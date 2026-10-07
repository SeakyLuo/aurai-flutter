import 'package:sqflite/sqflite.dart';

import '../features/chat/conversation.dart';
import 'conversation_rows.dart';

class PersonalChats {
  static Future<String> open(
    DatabaseExecutor transaction,
    String senderId,
    String title, {
    Conversation? draft,
  }) async {
    final rows = await transaction.query(
      'conversations',
      columns: ['id'],
      where: 'personal_chat = 1 AND default_sender_id = ?',
      whereArgs: [senderId],
    );
    if (rows.isNotEmpty) {
      final id = rows.single['id'] as String;
      await transaction.update(
        'conversations',
        {'archived': 0, 'title': title},
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    final conversation = (draft ?? Conversation.empty())
      ..isPersonalChat = true
      ..defaultSenderId = senderId
      ..storedTitle = title;
    await transaction.insert('conversations', conversationRow(conversation));
    return conversation.id;
  }
}
