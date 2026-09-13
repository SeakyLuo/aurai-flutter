import 'package:sqflite/sqflite.dart';

const backfillGroupCreationMembers = '''
UPDATE conversations
SET creation_member_ids = (
  SELECT json_group_array(sender_id) FROM (
    SELECT sender_id FROM conversation_members
    WHERE conversation_id = conversations.id
      AND joined_at = conversations.created_at
      AND sender_id != 'user:local'
    ORDER BY position, sender_id
  )
)
WHERE kind = 'group'
  AND (creation_member_ids IS NULL OR creation_member_ids = '[]')
''';

Future<void> migrateGroupCreationData(Database db) async {
  await db.rawUpdate(backfillGroupCreationMembers);
  await db.update(
    'message_senders',
    {'avatar_icon': 'person'},
    where: 'avatar_icon = ?',
    whereArgs: ['orbit'],
  );
}
