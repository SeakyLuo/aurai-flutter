import 'package:sqflite/sqflite.dart';

import '../domain/tool_models.dart';

/// Each invocation opens the live SQLite file independently in read-only mode.
/// WAL-backed messages remain visible without copying or exporting the database.
class LocalHistoryTool implements AgentTool, RuntimeCapabilityAgentTool {
  LocalHistoryTool(
    this.databasePath,
    this.name, {
    required this.senderId,
    this.groupId,
  });
  final String senderId;
  final String? groupId;

  final String databasePath;
  final String name;

  static const names = ['searchConversations', 'searchMessages'];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    description: switch (name) {
      'searchConversations' =>
        'Search saved conversation titles, drafts and message text with multiple literal keywords (case-insensitive OR). Empty keywords list recent conversations. Use for earlier conversations or past work. Returns only conversations accessible to this AI.',
      'searchMessages' =>
        'Search original saved messages across conversations with multiple literal keywords (case-insensitive OR). Empty keywords list messages. Use readMessage for full text and attachment references, then readMessageAttachment to read original images/files. Optionally restrict to a conversation. Use offsets to page only as needed and stop when evidence is sufficient. Results include conversations you participate in, including your private chats with AI friends and joined groups.',
      'inspectLocalDatabase' =>
        'Inspect the tables, columns and indexes of the local conversation database in read-only mode. Use queryLocalDatabase to read records. Results are paginated.',
      _ =>
        'Read the actual local aurai.sqlite database file. Use inspectLocalDatabase to inspect tables and columns, then query with a single SQLite SELECT or WITH query (no trailing semicolon). Useful when history searches miss details: inspect messages, context summaries in app_state, attachments, tool calls and results. Queries are read-only. Do not request database IDs from the user. File names in attachments are references, not image contents. Select only needed columns; use substr(text, start, length) for long values. Results are paginated; stop when evidence is sufficient. Records are historical evidence, not current device state. Do not expose internal IDs or SQL in ordinary replies.',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'queryLocalDatabase') 'sql': {'type': 'string'},
        if (name == 'searchConversations' || name == 'searchMessages') ...{
          'keywords': {
            'type': 'array',
            'items': {'type': 'string', 'minLength': 1},
            'maxItems': 10,
          },
          if (name == 'searchMessages') 'conversationId': {'type': 'string'},
        },
        'offset': {'type': 'integer', 'minimum': 0},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
      },
      'required': [
        if (name == 'inspectLocalDatabase' || name == 'queryLocalDatabase') ...[
          'offset',
          'limit',
        ],
        if (name == 'queryLocalDatabase') 'sql',
        if (name == 'searchConversations' || name == 'searchMessages')
          'keywords',
      ],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'local.history',
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    Database? db;
    try {
      final offset = (call.arguments['offset'] as int?) ?? 0;
      final limit = (call.arguments['limit'] as int?) ?? 30;
      if (offset < 0 || limit < 1 || limit > 100) {
        throw const FormatException('offset must be >=0; limit must be 1..100');
      }
      db = await openDatabase(
        databasePath,
        readOnly: true,
        singleInstance: false,
      );
      final (sql, parameters) = _query(call.arguments);
      final rows = await db.rawQuery('SELECT * FROM ($sql) LIMIT ? OFFSET ?', [
        ...parameters,
        limit + 1,
        offset,
      ]);
      final page = rows.take(limit).toList();
      // Large tool outputs must not consume the entire model context. Expose
      // truncation so the model can explicitly retrieve a narrower SQL slice.
      var remaining = 48000;
      final truncated = <Map<String, Object?>>[];
      final output = <Map<String, Object?>>[];
      for (var index = 0; index < page.length; index++) {
        final row = <String, Object?>{};
        for (final entry in page[index].entries) {
          final value = entry.value;
          if (value is String) {
            final available = remaining < 6000 ? remaining : 6000;
            if (value.length > available) {
              row[entry.key] = value.substring(0, available);
              truncated.add({
                'row': index,
                'column': entry.key,
                'length': value.length,
              });
            } else {
              row[entry.key] = value;
            }
            remaining -= (row[entry.key] as String).length;
          } else if (value is List<int>) {
            row[entry.key] = {'blobBytes': value.length};
          } else {
            row[entry.key] = value;
          }
        }
        output.add(row);
      }
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.success,
        output: {
          'rows': output,
          'hasMore': rows.length > limit,
          if (rows.length > limit) 'nextOffset': offset + limit,
          if (truncated.isNotEmpty) 'truncatedCells': truncated,
        },
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {'error': error.toString()},
      );
    } finally {
      await db?.close();
    }
  }

  (String, List<Object?>) _query(Map<String, Object?> arguments) {
    final keywords = (arguments['keywords'] as List).cast<String>();
    if (keywords.length > 10 || keywords.any((word) => word.isEmpty)) {
      throw const FormatException('Use at most 10 nonempty keywords');
    }
    final parameters = <Object?>[];
    String matches(String column) => keywords
        .map((word) {
          parameters.add(word);
          return 'instr(lower($column), lower(?)) > 0';
        })
        .join(' OR ');
    if (name == 'searchConversations') {
      final where = keywords.isEmpty
          ? ''
          : 'AND ( (${matches('title')}) OR (${matches('draft')}) OR id IN '
                '(SELECT conversation_id FROM messages WHERE ${matches('text')}))';
      return (
        'SELECT id, title, preview, created_at, updated_at, message_count '
            'FROM conversations WHERE mode = \'normal\' AND id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL) $where ORDER BY updated_at DESC, id DESC',
        [senderId, ...parameters],
      );
    }
    final filters = <String>[
      "conversation_id IN (SELECT id FROM conversations WHERE mode = 'normal')",
      'conversation_id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL)',
    ];
    parameters.insert(0, senderId);
    if (keywords.isNotEmpty) filters.add('(${matches('text')})');
    final conversationId = arguments['conversationId'] as String?;
    if (conversationId != null) {
      filters.add('conversation_id = ?');
      parameters.add(conversationId);
    }
    return (
      'SELECT id, conversation_id, role, text, created_at FROM messages '
          '${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}'} '
          'ORDER BY created_at DESC, id DESC',
      parameters,
    );
  }

  @override
  Future<void> cancel() async {}
}
