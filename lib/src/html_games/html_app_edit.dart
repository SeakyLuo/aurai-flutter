import '../agent/html_message_source.dart';
import 'html_app_store.dart';
import 'html_code_changes.dart';
import 'miniapp_team_store.dart';

extension HtmlAppEdit on HtmlAppStore {
  Future<Map<String, Object?>> edit(
    String operation,
    String actor,
    Map<String, Object?> args,
  ) => database.transaction((txn) async {
    final app = await MiniappTeamStore.app(txn, args['appId'] as String);
    final id = app['id'] as String;
    if (!await MiniappTeamStore.canEdit(txn, app, actor)) {
      throw StateError('尚未加入开发团队，请先使用 requestHtmlAppEdit 申请修改，获批后再编辑');
    }
    final reference = MiniappTeamStore.canManage(app, actor)
        ? await HtmlAppStore.reference(app)
        : <String, Object?>{'appId': id, 'sourcePath': app['source_path']};
    final version = app['version'] as int;
    final source =
        app['legacy_html'] as String? ?? await HtmlAppStore.code(app);
    if (operation == 'readHtmlApp') {
      return {
        ...reference,
        'title': app['title'],
        'version': version,
        'html': source,
      };
    }
    if (args['expectedVersion'] != version) {
      throw StateError('小程序已更新，请重新读取后再修改');
    }
    final resolved = await HtmlMessageSource.resolve(args, creating: false);
    final html = resolved['html'] as String?;
    if (html == null) throw ArgumentError('请提供 html 或 sourcePath');
    if (html == source) {
      return {
        ...reference,
        'updated': false,
        'title': app['title'],
        'version': version,
      };
    }
    final path = await HtmlAppStore.publish(id, html);
    final now = DateTime.now().microsecondsSinceEpoch;
    await txn.update(
      'html_apps',
      {
        'source_path': path,
        'legacy_html': null,
        'version': version + 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    // Snapshot launchers keep their own HTML; shared-code launchers reload.
    // Message versions are independent and must never move backwards.
    await txn.rawUpdate(
      "UPDATE html_games SET version = version + 1, preview = NULL, "
      "updated_at = ? WHERE app_id = ? AND html = ''",
      [now, id],
    );
    return {
      ...reference,
      'sourcePath': path,
      'updated': true,
      'title': app['title'],
      'version': version + 1,
      ...htmlCodeChanges(id, app['title'] as String, source, html),
    };
  });
}
