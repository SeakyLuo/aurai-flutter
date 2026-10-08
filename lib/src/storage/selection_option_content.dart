import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import '../domain/message_sender.dart';
import 'conversation_visibility.dart';
import 'group_message_search.dart';

typedef SelectionOptionContent = ({
  String conversationId,
  GroupMessageSearchResult message,
});

/// One bounded batch for an option set; never query separately per option.
Future<Map<String, SelectionOptionContent>> loadSelectionOptionContent(
  Database database,
  String directory,
  Set<String> ids,
) async {
  if (ids.isEmpty) return {};
  if (ids.length > 25) throw ArgumentError('每题最多 25 个选项');
  final rows = await database.query(
    'messages',
    where:
        "id IN (${List.filled(ids.length, '?').join(',')}) "
        "AND role IN ('user', 'assistant') "
        "AND kind IN ('user', 'final', 'group_message', 'html_game') "
        'AND conversation_id IN (SELECT id FROM conversations WHERE $localUserConversation)',
    whereArgs: ids.toList(),
    limit: 25,
  );
  final visible = rows.where((row) {
    if (row['interactive_json'] == null) return true;
    return InteractiveMessage.fromJson(
      jsonDecode(row['interactive_json'] as String) as Map<String, dynamic>,
    ).canView(MessageSender.localUser.id);
  }).toList();
  final messages = await GroupMessageSearch(
    database,
    directory,
  ).hydrate(visible);
  final conversations = {
    for (final row in visible) row['id']: row['conversation_id'] as String,
  };
  return {
    for (final message in messages)
      message.id: (
        conversationId: conversations[message.id]!,
        message: message,
      ),
  };
}
