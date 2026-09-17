import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';

/// SQLite records which file replacement committed. Recovery runs under the
/// same database lock before a page or AI reads or writes this document again.
class HtmlDataCommit {
  HtmlDataCommit(this.file, this.key);
  final File file;
  final String key;
  File get _journal => File('${file.path}.journal');
  File get _backup => File('${file.path}.backup');
  File get _pending => File('${file.path}.pending');

  Future<void> recover(DatabaseExecutor db) async {
    if (!await _journal.exists()) return;
    final journal = jsonDecode(await _journal.readAsString()) as Map;
    final rows = await db.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    final committed = rows.isNotEmpty && rows.single['value'] == journal['id'];
    if (!committed) {
      if (journal['hadFile'] == true) {
        await _pending.writeAsBytes(await _backup.readAsBytes(), flush: true);
        await _pending.rename(file.path);
      } else if (await file.exists()) {
        await file.delete();
      }
    }
    await _journal.delete();
    if (await _backup.exists()) await _backup.delete();
  }

  Future<void> replace(DatabaseExecutor db, List<int> bytes) async {
    final id = newMessageId();
    final hadFile = await file.exists();
    if (hadFile)
      await _backup.writeAsBytes(await file.readAsBytes(), flush: true);
    final pendingJournal = File('${_journal.path}.pending');
    await pendingJournal.writeAsString(
      jsonEncode({'id': id, 'hadFile': hadFile}),
      flush: true,
    );
    await pendingJournal.rename(_journal.path);
    await _pending.writeAsBytes(bytes, flush: true);
    await _pending.rename(file.path);
    await db.insert('app_state', {
      'key': key,
      'value': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
