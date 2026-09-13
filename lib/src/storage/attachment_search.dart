import 'package:sqflite/sqflite.dart';

import '../domain/message_file.dart';
import '../domain/message_image.dart';
import 'conversation_rows.dart';

class AttachmentSearchResult {
  const AttachmentSearchResult({
    required this.conversationId,
    required this.messageId,
    required this.title,
    required this.image,
    required this.file,
    this.matchText,
    this.fileName = '图片',
    this.messageExcerpt = '',
  });
  final String conversationId, messageId, title;
  final String? matchText;
  final String fileName, messageExcerpt;
  final MessageImage? image;
  final MessageFile? file;
}

class AttachmentSearch {
  const AttachmentSearch(this.database, this.directory);
  final Database database;
  final String directory;
  static const pageSize = 30;

  Future<List<AttachmentSearchResult>> search(
    String query,
    int offset, {
    int limit = pageSize,
  }) async {
    final rows = await database.rawQuery(
      '''
      SELECT a.*, c.title AS conversation_title,
        substr(m.text, max(1, instr(lower(m.text), ?) - 24), 100) AS message_excerpt
      FROM attachments a
      INNER JOIN messages m ON m.id = a.message_id
      INNER JOIN conversations c ON c.id = a.conversation_id
      ${query.isEmpty ? '' : '''WHERE instr(lower(coalesce(a.display_name, '')), ?) > 0
        OR instr(lower(m.text), ?) > 0'''}
      ORDER BY m.created_at DESC, a.position, a.id
      LIMIT ? OFFSET ?
    ''',
      [
        query,
        if (query.isNotEmpty) query,
        if (query.isNotEmpty) query,
        limit,
        offset,
      ],
    );
    return rows
        .map(
          (row) => AttachmentSearchResult(
            conversationId: row['conversation_id'] as String,
            messageId: row['message_id'] as String,
            title: row['conversation_title'] as String,
            fileName: row['display_name'] as String? ?? '图片',
            messageExcerpt: row['message_excerpt'] as String,
            matchText: query.isEmpty
                ? null
                : (row['display_name'] as String? ?? '').toLowerCase().contains(
                    query,
                  )
                ? '文件名：${row['display_name']}'
                : '消息内容：${row['message_excerpt']}',
            image: row['kind'] == 'image' ? imageFromRow(row, directory) : null,
            file: row['kind'] == 'file' ? fileFromRow(row, directory) : null,
          ),
        )
        .toList();
  }
}
