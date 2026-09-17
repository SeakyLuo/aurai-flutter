import 'dart:convert';
import '../domain/agent_models.dart';
import '../domain/message_image.dart';
import '../domain/message_file.dart';
import '../domain/interactive_message.dart';
import '../html_games/html_game.dart';
import 'conversation_rows.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/message_sender.dart';

enum GroupSearchType {
  all('全部'),
  image('图片'),
  file('文件'),
  html('小程序'),
  interactive('交互');

  const GroupSearchType(this.label);
  final String label;
}

class GroupMessageSearchResult {
  const GroupMessageSearchResult(
    this.id,
    this.text,
    this.createdAt,
    this.sender, {
    required this.role,
    this.images = const [],
    this.files = const [],
    this.html,
    this.interactive,
  });
  final AgentMessageRole role;
  final List<MessageImage> images;
  final List<MessageFile> files;
  final HtmlGameCard? html;
  final InteractiveMessage? interactive;
  final String id, text;
  final DateTime createdAt;
  final MessageSender sender;
}

class GroupMessageSearch {
  const GroupMessageSearch(this.database, this.directory);
  final String directory;
  final Database database;
  static const pageSize = 40;

  Future<List<GroupMessageSearchResult>> search(
    String conversationId,
    String query,
    GroupSearchType type,
    int offset,
  ) async {
    final filter = switch (type) {
      GroupSearchType.all => '1 = 1',
      GroupSearchType.image =>
        "EXISTS (SELECT 1 FROM attachments a WHERE a.message_id = messages.id AND a.kind = 'image')",
      GroupSearchType.file =>
        "EXISTS (SELECT 1 FROM attachments a WHERE a.message_id = messages.id AND a.kind = 'file')",
      GroupSearchType.html => "kind = 'html_game'",
      GroupSearchType.interactive => 'interactive_json IS NOT NULL',
    };
    final rows = await database.query(
      'messages',
      where:
          '''conversation_id = ? AND (interactive_json IS NULL OR json_extract(interactive_json, '\$.participation.audience') IS NULL OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience') WHERE value = 'user:local')) AND role IN ('user', 'assistant')
        AND kind IN ('user', 'group_message', 'html_game')
        AND ($filter)
        ${query.isEmpty ? '' : '''AND (instr(lower(text), ?) > 0
          OR EXISTS (SELECT 1 FROM attachments a WHERE a.message_id = messages.id
            AND instr(lower(coalesce(a.display_name, '')), ?) > 0)
          OR (interactive_json IS NOT NULL AND (
            instr(lower(json_extract(interactive_json, '\$.title')), ?) > 0 OR
            instr(lower(json_extract(interactive_json, '\$.body')), ?) > 0)))'''}''',
      whereArgs: [
        conversationId,
        if (query.isNotEmpty) ...List.filled(4, query.toLowerCase()),
      ],
      orderBy: 'created_at DESC, id DESC',
      limit: pageSize,
      offset: offset,
    );
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id']).toList();
    final senderIds = rows.map((r) => r['sender_id']).toSet().toList();
    final related = await Future.wait([
      database.query(
        'message_senders',
        where: 'id IN (${List.filled(senderIds.length, '?').join(',')})',
        whereArgs: senderIds,
      ),
      database.query(
        'attachments',
        where: 'message_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
        orderBy: 'position',
      ),
      database.query(
        'html_games',
        columns: [
          'app_id',
          'message_id',
          'title',
          'preview',
          'display_mode',
          'background_mode',
          'display_width',
          'display_height',
          'measured_width',
          'measured_height',
          'measured_scale',
          'measured_version',
          'version',
          'status',
        ],
        where: 'message_id IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids,
      ),
    ]);
    final senders = {
      for (final row in related[0]) row['id']: MessageSender.fromRow(row),
    };
    final images = <String, List<MessageImage>>{};
    final files = <String, List<MessageFile>>{};
    for (final row in related[1]) {
      final id = row['message_id'] as String;
      if (row['kind'] == 'image') {
        images.putIfAbsent(id, () => []).add(imageFromRow(row, directory));
      } else {
        files.putIfAbsent(id, () => []).add(fileFromRow(row, directory));
      }
    }
    final cards = {
      for (final row in related[2])
        row['message_id']: HtmlGameCard.fromRow(row),
    };
    return rows.map((row) {
      final id = row['id'] as String;
      return GroupMessageSearchResult(
        id,
        row['text'] as String,
        DateTime.fromMicrosecondsSinceEpoch(row['created_at'] as int),
        senders[row['sender_id']]!,
        role: AgentMessageRole.values.byName(row['role'] as String),
        images: images[id] ?? const [],
        files: files[id] ?? const [],
        html: cards[id],
        interactive: row['interactive_json'] == null
            ? null
            : InteractiveMessage.fromJson(
                jsonDecode(row['interactive_json'] as String)
                    as Map<String, dynamic>,
              ),
      );
    }).toList();
  }
}
