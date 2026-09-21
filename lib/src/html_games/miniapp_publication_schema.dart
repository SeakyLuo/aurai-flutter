import 'package:sqflite/sqflite.dart';

const miniappPublicationSchema = [
  '''CREATE TABLE miniapp_publications (
    app_id TEXT PRIMARY KEY REFERENCES html_apps(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    publisher_id TEXT NOT NULL,
    source_path TEXT NOT NULL,
    stateful INTEGER NOT NULL,
    revision INTEGER NOT NULL,
    listed INTEGER NOT NULL DEFAULT 1,
    updated_at INTEGER NOT NULL
  )''',
  'CREATE INDEX miniapp_publication_listing ON miniapp_publications(listed, updated_at DESC, app_id)',
  '''CREATE TABLE miniapp_installations (
    source_id TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    app_id TEXT NOT NULL UNIQUE REFERENCES html_apps(id),
    revision TEXT NOT NULL,
    PRIMARY KEY(source_id, owner_id)
  )''',
];

/// Preserve any publication and installation rows from earlier development builds.
Future<void> migrateMiniappPublications(DatabaseExecutor database) async {
  for (final statement in miniappPublicationSchema) {
    await database.execute(
      statement
          .replaceFirst('CREATE TABLE ', 'CREATE TABLE IF NOT EXISTS ')
          .replaceFirst('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS '),
    );
  }
  await database.execute(
    "INSERT OR IGNORE INTO miniapp_installations(source_id, owner_id, app_id, revision) SELECT id, 'user:local', id, 'legacy' FROM html_apps WHERE id = 'builtin.tipoff'",
  );
}
