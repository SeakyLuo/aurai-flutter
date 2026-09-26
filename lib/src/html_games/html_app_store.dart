import 'dart:convert';
import 'html_data_commit.dart';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';

const htmlAppSchema = '''CREATE TABLE html_apps (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  title TEXT NOT NULL,
  source_path TEXT,
  legacy_html TEXT,
  state_json TEXT NOT NULL,
  stateful INTEGER NOT NULL DEFAULT 0,
  version INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  last_opened_at INTEGER
)''';

const htmlAppIndex =
    'CREATE INDEX html_apps_owner ON html_apps(creator_id, updated_at DESC, id)';

/// Applications outlive message launchers. Code and JSON documents live on disk.
class HtmlAppStore {
  HtmlAppStore(this.database);
  final Database database;
  static const maxHtmlBytes = 4 * 1024 * 1024;
  static const maxDataBytes = 4 * 1024 * 1024;

  static Future<Directory> directory(String id) async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/agent-shell/miniapps/$id');
  }

  static Future<String> publish(String id, String html) async {
    final root = await directory(id);
    await Directory('${root.path}/data').create(recursive: true);
    final code = await Directory('${root.path}/code').create(recursive: true);
    final file = File('${code.path}/${newMessageId()}.html');
    await file.writeAsString(html, flush: true);
    return file.path;
  }

  static Future<Map<String, Object?>> load(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query('html_apps', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('小程序不存在');
    var app = Map<String, Object?>.from(rows.single);
    // Legacy code moves only when this application is opened. A failed file
    // write leaves the database copy intact and does not block other apps.
    if (app['legacy_html'] != null) {
      final path = await publish(id, app['legacy_html'] as String);
      await db.update(
        'html_apps',
        {'source_path': path, 'legacy_html': null},
        where: 'id = ?',
        whereArgs: [id],
      );
      app = {...app, 'source_path': path, 'legacy_html': null};
    }
    return app;
  }

  static Future<String> code(Map<String, Object?> app) =>
      File(app['source_path'] as String).readAsString();

  Future<List<Map<String, Object?>>> list(
    String creator,
    String query,
  ) => database.query(
    'html_apps',
    columns: [
      'id AS appId',
      '(COALESCE((SELECT title FROM miniapp_metadata WHERE app_id = html_apps.id), title)) AS title',
      'source_path AS sourcePath',
      'updated_at',
    ],
    where:
        'creator_id = ? AND instr(lower(COALESCE((SELECT title FROM miniapp_metadata WHERE app_id = html_apps.id), title)), lower(?)) > 0',
    whereArgs: [creator, query],
    orderBy: 'updated_at DESC, id',
    limit: 50,
  );

  static Future<Map<String, Object?>> reference(
    Map<String, Object?> app,
  ) async => {
    'appId': app['id'],
    'sourcePath': app['source_path'],
    'dataDirectory': '${(await directory(app['id'] as String)).path}/data',
  };

  static Future<File> _dataFile(String id, String name) async {
    // Data names are flat JSON documents, never arbitrary host paths.
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}\.json$').hasMatch(name)) {
      throw ArgumentError('数据文件名需为字母、数字、横线或下划线组成的 .json 文件');
    }
    final folder = Directory('${(await directory(id)).path}/data');
    await folder.create(recursive: true);
    final root = await folder.resolveSymbolicLinks();
    final support = await getApplicationSupportDirectory();
    final workspace = await Directory(
      '${support.path}/agent-shell',
    ).resolveSymbolicLinks();
    final expected =
        '$workspace${Platform.pathSeparator}miniapps${Platform.pathSeparator}$id';
    if (!root.startsWith('$expected${Platform.pathSeparator}')) {
      throw StateError('小程序数据目录不可指向外部');
    }
    final file = File('$root/$name');
    if (await FileSystemEntity.type(file.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('小程序数据文件不可使用符号链接');
    }
    return file;
  }

  static Future<Map<String, Object?>> _read(File file) async {
    if (!await file.exists()) return {'revision': 0, 'value': null};
    final handle = await file.open();
    try {
      if (await handle.length() > maxDataBytes) throw StateError('数据文件超过 4 MB');
      final bytes = await handle.read(maxDataBytes + 1);
      if (bytes.length > maxDataBytes) throw StateError('数据文件超过 4 MB');
      final json = utf8.decode(bytes);
      return (jsonDecode(json) as Map).cast<String, Object?>();
    } finally {
      await handle.close();
    }
  }

  /// Both the page and AI use this transaction to serialize versioned writes.
  Future<Map<String, Object?>> data(
    String id,
    String name, {
    required String actor,
    String? messageId,
    bool write = false,
    int? expectedRevision,
    Object? value,
  }) async {
    HtmlDataCommit? commit;
    try {
      return await database.transaction((txn) async {
        final apps = await txn.query(
          'html_apps',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (apps.isEmpty) throw StateError('小程序不存在');
        Map<String, Object?>? session;
        if (messageId == null) {
          if (apps.single['creator_id'] != actor)
            throw StateError('只能访问自己创建的小程序数据');
        } else {
          final refs = await txn.query(
            'html_games',
            columns: ['app_id', 'session_data_json', 'version'],
            where:
                "message_id = ? AND app_id = ? AND message_id IN (SELECT id FROM messages WHERE kind = 'html_game')",
            whereArgs: [messageId, id],
          );
          if (refs.isEmpty) throw StateError('小程序入口已删除或撤回');
          if (refs.single['session_data_json'] != null) session = refs.single;
        }
        if (session != null) {
          final documents =
              (jsonDecode(session['session_data_json'] as String) as Map)
                  .cast<String, Object?>();
          final previous =
              documents[name] as Map? ?? {'revision': 0, 'value': null};
          if (!write) return previous.cast<String, Object?>();
          if (expectedRevision != previous['revision'])
            throw StateError('数据已更新，请重新读取后再保存');
          final next = {
            'revision': (previous['revision'] as int) + 1,
            'value': value,
          };
          documents[name] = next;
          final encoded = jsonEncode(documents);
          if (utf8.encode(encoded).length > maxDataBytes)
            throw ArgumentError('本条消息的数据最多 4 MB');
          await txn.update(
            'html_games',
            {
              'session_data_json': encoded,
              'version': (session['version'] as int) + 1,
              'preview': null,
              'updated_at': DateTime.now().microsecondsSinceEpoch,
            },
            where: 'message_id = ?',
            whereArgs: [messageId],
          );
          return next;
        }
        final file = await _dataFile(id, name);
        commit = HtmlDataCommit(file, 'html_data_commit:$id:$name');
        await commit!.recover(txn);
        final previous = await _read(file);
        if (!write) return previous;
        if (expectedRevision != previous['revision']) {
          throw StateError('数据已更新，请重新读取后再保存');
        }
        final next = {
          'revision': (previous['revision'] as int) + 1,
          'value': value,
        };
        final bytes = utf8.encode(jsonEncode(next));
        if (bytes.length > maxDataBytes) throw ArgumentError('单个数据文件最多 4 MB');
        await commit!.replace(txn, bytes);
        final version = (apps.single['version'] as int) + 1;
        await txn.update(
          'html_apps',
          {
            'version': version,
            'updated_at': DateTime.now().microsecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'html_games',
          {'version': version, 'preview': null},
          where: 'app_id = ? AND session_data_json IS NULL',
          whereArgs: [id],
        );
        return next;
      });
    } on Object {
      if (commit != null) await database.transaction(commit!.recover);
      rethrow;
    }
  }
}
