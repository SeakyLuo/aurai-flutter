import 'message_file.dart';
import 'message_image.dart';

enum AssetSource {
  generated('AI 生成'),
  uploaded('我上传的');

  const AssetSource(this.label);
  final String label;
}

enum AssetType {
  image('图片'),
  document('文档'),
  media('音视频'),
  other('其他');

  const AssetType(this.label);
  final String label;

  static const documentExtensions = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'md',
    'csv',
    'rtf',
    'odt',
    'ods',
    'odp',
  ];
}

enum AssetSort {
  newest('最近添加', 'created_at DESC, file_name DESC'),
  oldest('最早添加', 'created_at, file_name'),
  name('名称', 'name COLLATE NOCASE, file_name');

  const AssetSort(this.label, this.orderBy);
  final String label, orderBy;
}

class LibraryAsset {
  const LibraryAsset({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.kind,
    required this.size,
    required this.source,
    required this.createdAt,
    required this.path,
    required this.conversationId,
    required this.messageId,
  });
  final String id, name, mimeType, kind, path;
  final int? size;
  final AssetSource source;
  final DateTime createdAt;
  final String? conversationId, messageId;
  bool get isImage => kind == 'image' || mimeType.startsWith('image/');
  MessageImage get image =>
      MessageImage(path: path, mimeType: mimeType, name: name);
  MessageFile get file =>
      MessageFile(path: path, name: name, mimeType: mimeType, size: size!);
  String get sizeLabel => size == null
      ? '图片'
      : size! < 1024
      ? '$size B'
      : size! < 1024 * 1024
      ? '${(size! / 1024).toStringAsFixed(1)} KB'
      : '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';

  factory LibraryAsset.fromRow(Map<String, Object?> row, String directory) =>
      LibraryAsset(
        id: row['file_name'] as String,
        name: row['name'] as String,
        mimeType: row['mime_type'] as String,
        kind: row['kind'] as String,
        size: row['byte_size'] as int?,
        source: AssetSource.values.byName(row['source'] as String),
        createdAt: DateTime.fromMicrosecondsSinceEpoch(
          row['created_at'] as int,
        ),
        path: '$directory/${row['file_name']}',
        conversationId: row['conversation_id'] as String?,
        messageId: row['message_id'] as String?,
      );
}
