part of 'conversation_reader.dart';

extension ConversationSearchReader on ConversationReader {
  Future<List<ConversationSearchResult>> search(
    String query,
    int offset, {
    bool includeReasoning = false,
    String? projectId,
  }) async {
    final projectFilter = projectId == null ? '' : ' AND project_id = ?';
    final projectArgs = projectId == null ? const <Object?>[] : [projectId];
    if (query.isEmpty) {
      final rows = await database.query(
        'conversations',
        where:
            "$visibleConversation AND $localUserConversation AND mode = 'normal'$projectFilter",
        whereArgs: projectArgs,
        orderBy: 'pinned DESC, updated_at DESC, id DESC',
        limit: ConversationReader.pageSize,
        offset: offset,
      );
      return [
        for (final row in rows)
          (
            conversation: conversationFromRow(row),
            messageId: null,
            sender: null,
            snippet: '',
          ),
      ];
    }
    final messageFilter = includeReasoning
        ? "kind NOT IN ('system', 'quick_reply')"
        : "kind NOT IN ('system', 'quick_reply', 'reasoning')";
    final hits = await database.rawQuery(
      '''SELECT id AS message_id, conversation_id, text, sender_id, created_at, id AS sort_id
         FROM messages WHERE $messageFilter AND conversation_id IN (SELECT id FROM conversations WHERE $localUserConversation AND mode = 'normal'$projectFilter) AND instr(lower(text), ?) > 0
         UNION ALL
         SELECT NULL AS message_id, id AS conversation_id,
           CASE WHEN instr(lower(draft), ?) > 0 THEN draft ELSE '' END AS text,
           NULL AS sender_id, created_at, id AS sort_id
         FROM conversations
         WHERE $visibleConversation AND $localUserConversation AND mode = 'normal'$projectFilter AND (instr(lower(title), ?) > 0 OR instr(lower(draft), ?) > 0)
           AND id NOT IN (
             SELECT conversation_id FROM messages WHERE $messageFilter AND instr(lower(text), ?) > 0
           )
         ORDER BY created_at DESC, sort_id DESC
         LIMIT ? OFFSET ?''',
      [
        ...projectArgs,
        query,
        query,
        ...projectArgs,
        query,
        query,
        query,
        ConversationReader.pageSize,
        offset,
      ],
    );
    if (hits.isEmpty) return [];
    final ids = hits.map((hit) => hit['conversation_id'] as String).toSet();
    final senderIds = hits
        .map((hit) => hit['sender_id'])
        .whereType<String>()
        .toSet();
    final related = await Future.wait([
      database.query(
        'conversations',
        where: 'id IN (${_slots(ids.length)})',
        whereArgs: ids.toList(),
      ),
      if (senderIds.isNotEmpty)
        database.query(
          'message_senders',
          where: 'id IN (${_slots(senderIds.length)})',
          whereArgs: senderIds.toList(),
        ),
    ]);
    final conversations = {
      for (final row in related.first)
        row['id'] as String: conversationFromRow(row),
    };
    final senders = {
      if (senderIds.isNotEmpty)
        for (final row in related[1])
          row['id'] as String: MessageSender.fromRow(row),
    };
    return hits.map((hit) {
      final text = hit['text'] as String;
      final index = text.toLowerCase().indexOf(query);
      final start = index > 4 ? index - 4 : 0;
      return (
        conversation: conversations[hit['conversation_id']]!,
        messageId: hit['message_id'] as String?,
        sender: hit['sender_id'] == null ? null : senders[hit['sender_id']]!,
        snippet:
            '${start > 0 ? '…' : ''}${text.substring(start).replaceAll('\n', ' ')}',
      );
    }).toList();
  }
}
