import 'package:sqflite/sqflite.dart';

final assetLibrarySchema = [
  '''CREATE TABLE assets (
    file_name TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    kind TEXT NOT NULL,
    byte_size INTEGER,
    source TEXT NOT NULL CHECK(source IN ('generated', 'uploaded')),
    created_at INTEGER NOT NULL,
    conversation_id TEXT REFERENCES conversations(id) ON DELETE SET NULL,
    message_id TEXT REFERENCES messages(id) ON DELETE SET NULL,
    deleted_at INTEGER,
    purged INTEGER NOT NULL DEFAULT 0 CHECK(purged IN (0, 1))
  )''',
  'CREATE INDEX asset_order ON assets(purged, deleted_at, created_at DESC, file_name)',
  'CREATE INDEX asset_source_order ON assets(purged, source, created_at DESC, file_name)',
  for (final event in ['INSERT', 'UPDATE OF message_id'])
    '''CREATE TRIGGER asset_capture_${event == 'INSERT' ? 'insert' : 'update'}
    AFTER $event ON attachments
    WHEN NEW.message_id IS NOT NULL
      AND (SELECT mode FROM conversations WHERE id = NEW.conversation_id) = 'normal'
    BEGIN
      INSERT OR IGNORE INTO assets
        (file_name, name, mime_type, kind, byte_size, source, created_at, conversation_id, message_id)
      SELECT NEW.file_name,
        COALESCE(NULLIF(NEW.display_name, ''), CASE WHEN m.sender_id = 'user:local' THEN '上传的图片' ELSE 'AI 生成的图片' END),
        NEW.mime_type, NEW.kind, NEW.byte_size,
        CASE WHEN m.sender_id = 'user:local' THEN 'uploaded' ELSE 'generated' END,
        m.created_at, NEW.conversation_id, m.id
      FROM messages m WHERE m.id = NEW.message_id;
    END''',
];

Future<void> migrateAssetLibrary(DatabaseExecutor db) async {
  await db.execute(
    "UPDATE attachments SET id = conversation_id || ':' || COALESCE(message_id, 'draft') || ':' || file_name",
  );
  for (final statement in assetLibrarySchema) {
    await db.execute(statement);
  }
  await db.execute('''INSERT OR IGNORE INTO assets
    (file_name, name, mime_type, kind, byte_size, source, created_at, conversation_id, message_id)
    SELECT a.file_name,
      COALESCE(NULLIF(a.display_name, ''), CASE WHEN m.sender_id = 'user:local' THEN '上传的图片' ELSE 'AI 生成的图片' END),
      a.mime_type, a.kind, a.byte_size,
      CASE WHEN m.sender_id = 'user:local' THEN 'uploaded' ELSE 'generated' END,
      m.created_at, a.conversation_id, m.id
    FROM attachments a INNER JOIN messages m ON m.id = a.message_id
    WHERE a.conversation_id IN (SELECT id FROM conversations WHERE mode = 'normal')
    ORDER BY m.created_at, m.id''');
}
