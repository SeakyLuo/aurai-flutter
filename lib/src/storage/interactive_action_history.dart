import 'package:sqflite/sqflite.dart';

const interactiveActionSchema = [
  '''CREATE TABLE interactive_actions (
    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    actor_id TEXT NOT NULL,
    actor_name TEXT NOT NULL,
    button_id TEXT NOT NULL,
    label TEXT NOT NULL,
    definition_revision INTEGER NOT NULL,
    participant_revision INTEGER NOT NULL,
    before_json TEXT,
    created_at INTEGER NOT NULL
  )''',
  'CREATE INDEX interactive_action_history ON interactive_actions(message_id, actor_id, sequence DESC)',
];

Future<List<Map<String, Object?>>> readInteractiveHistory(
  DatabaseExecutor db,
  String messageId,
  String actorId, {
  int? before,
}) => db.query(
  'interactive_actions',
  columns: [
    'sequence',
    'button_id',
    'label',
    'created_at',
    'participant_revision',
    'before_json IS NOT NULL AS has_snapshot',
  ],
  where:
      'message_id = ? AND actor_id = ?${before == null ? '' : ' AND sequence < ?'}',
  whereArgs: [messageId, actorId, if (before != null) before],
  orderBy: 'sequence DESC',
  limit: 50,
);

Future<bool> hasInteractiveHistory(
  DatabaseExecutor db,
  String messageId,
  String actorId,
) async {
  final rows = await db.query(
    'interactive_actions',
    columns: ['sequence'],
    where: 'message_id = ? AND actor_id = ?',
    whereArgs: [messageId, actorId],
    limit: 1,
  );
  return rows.isNotEmpty;
}
