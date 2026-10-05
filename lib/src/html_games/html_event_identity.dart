import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Caller operation keys belong to one message instance.
String htmlEventIdentity(String messageId, String eventId) =>
    jsonEncode([messageId, eventId]);

Future<void> migrateHtmlEventIdentities(DatabaseExecutor db) async {
  // Keep callback references intact while both sides change in one transaction.
  await db.execute('PRAGMA defer_foreign_keys = ON');
  await db.execute('''UPDATE html_game_receipts SET event_id = (
    SELECT json_array(message_id, id) FROM html_game_events
    WHERE id = html_game_receipts.event_id
  )''');
  await db.execute(
    'UPDATE html_game_events SET id = json_array(message_id, id)',
  );
}
