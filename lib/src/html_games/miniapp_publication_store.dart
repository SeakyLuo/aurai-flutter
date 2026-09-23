part of 'miniapp_library_store.dart';

extension MiniappPublicationOperations on MiniappLibraryStore {
  Future<void> publish(
    MiniappEntry entry,
    String title,
    String description, {
    required String changeLog,
  }) async {
    title = title.trim();
    description = description.trim();
    changeLog = changeLog.trim();
    if (changeLog.isEmpty || changeLog.length > 2000) {
      throw ArgumentError('请填写更新日志，最多 2000 字');
    }
    if (!entry.draft || entry.bundled) throw StateError('只有自己创建的小程序可以发布');
    if (title.isEmpty ||
        title.length > 100 ||
        description.isEmpty ||
        description.length > 500) {
      throw ArgumentError('请填写名称和简介，名称最多 100 字、简介最多 500 字');
    }
    final app = await HtmlAppStore.load(database, entry.id);
    final html = await HtmlAppStore.code(app);
    if (utf8.encode(html).length > HtmlAppStore.maxHtmlBytes)
      throw StateError('小程序文件超过大小限制');
    final snapshot = await HtmlAppStore.publish(entry.id, html);
    await database.transaction((txn) async {
      final installed = await txn.query(
        'miniapp_installations',
        columns: ['app_id'],
        where: 'app_id = ?',
        whereArgs: [entry.id],
      );
      if (installed.isNotEmpty) throw StateError('添加的小程序不能作为自己的作品发布');
      final current = await txn.query(
        'html_apps',
        columns: ['source_path'],
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      if (current.single['source_path'] != app['source_path']) {
        throw StateError('小程序代码已更新，请重新打开详情后发布');
      }
      final old = await txn.query(
        'miniapp_publications',
        where: 'app_id = ?',
        whereArgs: [entry.id],
      );
      final revision = old.isEmpty ? 0 : old.single['revision'] as int;
      if (revision != entry.revision) throw StateError('发布版本已变化，请重新打开详情');
      final values = <String, Object?>{
        'app_id': entry.id,
        'title': title,
        'description': description,
        'publisher_id': app['creator_id'],
        'source_path': snapshot,
        'stateful': app['stateful'],
        'revision': revision + 1,
        'listed': 1,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      };
      await MiniappMetadataStore.write(txn, entry, title, description);
      await txn.insert('miniapp_release_notes', {
        'app_id': entry.id,
        'revision': revision + 1,
        'notes': changeLog,
        'created_at': values['updated_at'],
      });
      if (old.isEmpty) {
        await txn.insert('miniapp_publications', values);
      } else {
        await txn.update(
          'miniapp_publications',
          values,
          where: 'app_id = ?',
          whereArgs: [entry.id],
        );
      }
    });
  }

  Future<void> withdraw(MiniappEntry entry) async {
    if (!entry.draft || entry.bundled) throw StateError('只有自己的作品可以撤下');
    final changed = await database.update(
      'miniapp_publications',
      {'listed': 0},
      where: 'app_id = ? AND revision = ? AND listed = 1',
      whereArgs: [entry.id, entry.revision],
    );
    if (changed != 1) throw StateError('小程序版本正在变化，请重试打开');
  }

  Future<String> install(MiniappEntry entry) async {
    if (entry.bundled) {
      await installBundled(entry);
      return entry.id;
    }
    final sourceId = entry.publicationId;
    final releases = await database.query(
      'miniapp_publications',
      where: 'app_id = ? AND listed = 1',
      whereArgs: [sourceId],
    );
    if (releases.isEmpty) throw StateError('此小程序已撤下，已添加的版本仍可使用');
    final release = releases.single;
    final installations = await database.query(
      'miniapp_installations',
      where: 'source_id = ? AND owner_id = ?',
      whereArgs: [sourceId, MiniappLibraryStore.owner],
    );
    final installed = installations.firstOrNull;
    final revision = '${release['revision']}';
    if (installed != null && installed['revision'] == revision)
      return installed['app_id'] as String;
    final id = installed?['app_id'] as String? ?? newMessageId();
    final code = await File(release['source_path'] as String).readAsString();
    final path = await HtmlAppStore.publish(id, code);
    await database.transaction((txn) async {
      final latest = await txn.query(
        'miniapp_publications',
        columns: ['revision', 'listed'],
        where: 'app_id = ?',
        whereArgs: [sourceId],
      );
      if (latest.single['revision'] != release['revision'] ||
          latest.single['listed'] != 1) {
        throw StateError('小程序版本正在变化，请重试打开');
      }
      final values = <String, Object?>{
        'title': release['title'],
        'source_path': path,
        'stateful': release['stateful'],
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      };
      if (installed == null) {
        await txn.insert('html_apps', {
          ...values,
          'id': id,
          'creator_id': MiniappLibraryStore.owner,
          'state_json': '{}',
        });
        await txn.insert('miniapp_installations', {
          'source_id': sourceId,
          'owner_id': MiniappLibraryStore.owner,
          'app_id': id,
          'revision': revision,
        });
      } else {
        final app = await txn.query(
          'html_apps',
          columns: ['version'],
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'html_apps',
          {...values, 'version': (app.single['version'] as int) + 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'miniapp_installations',
          {'revision': revision},
          where: 'source_id = ? AND owner_id = ? AND revision = ?',
          whereArgs: [
            sourceId,
            MiniappLibraryStore.owner,
            installed['revision'],
          ],
        );
      }
    });
    return id;
  }

  /// Bundled code has a content-addressed filename. Only code changes on update;
  /// the existing application's state and data directory remain in place.
  Future<void> installBundled(MiniappEntry entry) async {
    final directory = await HtmlAppStore.directory(entry.id);
    final path = '${directory.path}/code/bundled-${entry.bundleVersion}.html';
    final rows = await database.query(
      'html_apps',
      columns: ['source_path', 'version'],
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    final changed = rows.isEmpty || rows.single['source_path'] != path;
    if (changed) {
      final source = await rootBundle.loadString(entry.asset!);
      if (utf8.encode(source).length > HtmlAppStore.maxHtmlBytes)
        throw StateError('小程序文件超过大小限制');
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(source, flush: true);
    }
    await database.transaction((txn) async {
      final values = <String, Object?>{
        'title': entry.title,
        'source_path': path,
        'updated_at': DateTime.now().microsecondsSinceEpoch,
      };
      if (rows.isEmpty) {
        await txn.insert('html_apps', {
          ...values,
          'id': entry.id,
          'creator_id': MiniappLibraryStore.owner,
          'state_json': '{}',
          'stateful': 1,
        });
      } else if (changed) {
        await txn.update(
          'html_apps',
          {...values, 'version': (rows.single['version'] as int) + 1},
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
      await txn.insert('miniapp_installations', {
        'source_id': entry.id,
        'owner_id': MiniappLibraryStore.owner,
        'app_id': entry.id,
        'revision': entry.releaseKey,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
