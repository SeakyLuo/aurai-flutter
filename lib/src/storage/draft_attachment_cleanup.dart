import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'new_conversation_draft.dart';

/// Removal intents survive a crash between saving the draft and deleting files.
class DraftAttachmentCleanup {
  DraftAttachmentCleanup(this.database, this.directory);
  final Database database;
  final String directory;
  static Future<void> _pending = Future.value();
  static const _prefix = 'draft_attachment_cleanup:';

  Future<void> remove(
    String path,
    String owner,
    Future<void> Function() saveRemoval,
  ) => _enqueue(() async {
    await database.insert('app_state', {
      'key': '$_prefix${File(path).uri.pathSegments.last}',
      'value': jsonEncode({'path': path, 'owner': owner}),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await saveRemoval();
    await _sweepSafely();
  });

  Future<void> recover() => _enqueue(_sweepSafely);

  Future<void> _sweepSafely() async {
    try {
      final rows = await database.query(
        'app_state',
        where: 'key GLOB ?',
        whereArgs: ['$_prefix*'],
        orderBy: 'key',
        limit: 32,
      );
      if (rows.isEmpty) return;
      final candidates = {
        for (final row in rows)
          row['key'] as String: jsonDecode(row['value'] as String) as Map,
      };
      final drafts = await Future.wait([
        for (final owner
            in candidates.values.map((v) => v['owner'] as String).toSet())
          NewConversationDraft().load(directory, senderId: owner),
      ]);
      final draftPaths = {
        for (final draft in drafts) ...[
          ...draft.draftImages.map((image) => image.path),
          ...draft.draftFiles.map((file) => file.path),
        ],
      };
      await database.transaction((txn) async {
        final referenced = await txn.query(
          'attachments',
          columns: ['file_name'],
          where: 'file_name IN (SELECT value FROM json_each(?))',
          whereArgs: [
            jsonEncode(
              candidates.values
                  .map((v) => File(v['path'] as String).uri.pathSegments.last)
                  .toList(),
            ),
          ],
        );
        final names = referenced.map((r) => r['file_name']).toSet();
        final batch = txn.batch();
        for (final entry in candidates.entries) {
          final file = File(entry.value['path'] as String);
          if (!names.contains(file.uri.pathSegments.last) &&
              !draftPaths.contains(file.path)) {
            try {
              if (await file.exists()) await file.delete();
            } on FileSystemException catch (error, stack) {
              developer.log(
                'Deferred attachment cleanup failed',
                error: error,
                stackTrace: stack,
              );
              continue;
            }
          }
          batch.delete('app_state', where: 'key = ?', whereArgs: [entry.key]);
        }
        await batch.commit(noResult: true);
      });
    } on Object catch (error, stack) {
      developer.log(
        'Attachment cleanup remains queued',
        error: error,
        stackTrace: stack,
      );
    }
  }

  static Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((Object _) {});
    return next;
  }
}
