import 'package:sqflite/sqflite.dart';

const miniappReleaseNotesSchema =
    '''CREATE TABLE IF NOT EXISTS miniapp_release_notes (
  app_id TEXT NOT NULL REFERENCES html_apps(id) ON DELETE CASCADE,
  revision INTEGER NOT NULL,
  notes TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (app_id, revision)
)''';

class MiniappReleaseNote {
  const MiniappReleaseNote(this.revision, this.notes, this.createdAt);
  final int revision;
  final String notes;
  final DateTime createdAt;
}

Future<List<MiniappReleaseNote>> readMiniappReleaseNotes(
  DatabaseExecutor database,
  String appId, {
  int? beforeRevision,
  int limit = 20,
}) async {
  final rows = await database.query(
    'miniapp_release_notes',
    where: 'app_id = ?${beforeRevision == null ? '' : ' AND revision < ?'}',
    whereArgs: [appId, if (beforeRevision != null) beforeRevision],
    orderBy: 'revision DESC',
    limit: limit,
  );
  return rows
      .map(
        (row) => MiniappReleaseNote(
          row['revision'] as int,
          row['notes'] as String,
          DateTime.fromMicrosecondsSinceEpoch(row['created_at'] as int),
        ),
      )
      .toList();
}
