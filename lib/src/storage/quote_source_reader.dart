import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/interactive_message.dart';
import '../domain/message_quote.dart';
import '../domain/message_summary.dart';

/// One page resolves all original messages and attachments in two batch reads.
Future<void> loadQuoteSources(
  DatabaseExecutor database,
  Iterable<MessageQuote> quotes,
) async {
  final ids = quotes.map((quote) => quote.messageId).toSet();
  if (ids.isEmpty) return;
  final where = 'id IN (${List.filled(ids.length, '?').join(',')})';
  final results = await Future.wait([
    database.query('messages', where: where, whereArgs: ids.toList()),
    database.query(
      'attachments',
      where: 'message_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids.toList(),
      orderBy: 'position',
    ),
  ]);
  final attachments = <String, List<String>>{};
  for (final row in results[1]) {
    if (row['kind'] == 'miniapp_media') continue;
    attachments
        .putIfAbsent(row['message_id'] as String, () => [])
        .add(
          MessageSummary.attachment(
            kind: row['kind'] as String,
            mimeType: row['mime_type'] as String,
            name: row['display_name'] as String?,
          ),
        );
  }
  final sources = {
    for (final row in results[0])
      row['id'] as String: AgentMessage(
        id: row['id'] as String,
        role: AgentMessageRole.values.byName(row['role'] as String),
        senderId: row['sender_id'] as String,
        text: MessageSummary.content(
          text: row['text'] as String,
          htmlTitle: row['kind'] == 'html_game' ? row['text'] as String : null,
          attachments: attachments[row['id']] ?? const [],
        ),
        markdown: row['markdown'] == 1,
        isSystem: row['kind'] == 'system',
        isGroupMessage: row['kind'] == 'group_message',
        createdAt: DateTime.fromMicrosecondsSinceEpoch(
          row['created_at'] as int,
        ),
        interactive: row['interactive_json'] == null
            ? null
            : InteractiveMessage.fromJson(
                jsonDecode(row['interactive_json'] as String)
                    as Map<String, dynamic>,
              ),
      ),
  };
  for (final quote in quotes) {
    final source = sources[quote.messageId];
    // Only a missing original uses the stored snapshot.
    if (source != null) quote.resolveSource(source);
  }
}
