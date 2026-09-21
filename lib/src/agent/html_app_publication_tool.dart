import '../domain/tool_models.dart';
import '../html_games/miniapp_library_store.dart';

class HtmlAppPublicationTool implements AgentTool, RuntimeCapabilityAgentTool {
  HtmlAppPublicationTool(this.name, this.store, this.actor);
  final String name, actor;
  final MiniappLibraryStore store;
  static const names = [
    'listHtmlAppPublications',
    'readHtmlAppPublication',
    'publishHtmlApp',
    'updateHtmlAppPublication',
    'withdrawHtmlApp',
  ];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.messages',
    safety:
        name == 'readHtmlAppPublication' || name == 'listHtmlAppPublications'
        ? ToolSafety.readOnly
        : ToolSafety.lowRisk,
    description: switch (name) {
      'listHtmlAppPublications' =>
        'Find up to 50 miniapps created by you or owned by the local user, by title. Returns current publication revisions. Use this to resolve appId for publication tools; never ask the user for IDs.',
      'readHtmlAppPublication' =>
        'Read publication state and revision of a miniapp you created or the local user owns. Resolve appId with listHtmlAppPublications, never ask the user for IDs. Installed copies and bundled apps cannot be published with these tools.',
      'publishHtmlApp' =>
        'Publish the first version of a miniapp to the local application library on behalf of the user. Use only when the user requests publication, never automatically after creating a message. Snapshots current code without chat history or saved data. This does not publish to the internet. Read publication state first; expectedRevision must be 0.',
      'updateHtmlAppPublication' =>
        'Publish a new code snapshot of an already published or withdrawn miniapp, only when the user asks. Draft edits do not change the released version. Preserves installed copies and their data; users explicitly update. Read the current revision first.',
      _ =>
        'Withdraw a miniapp from the local library when requested by the user. Keeps draft code, installed copies and saved data. Read the current revision first.',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name == 'listHtmlAppPublications')
          'query': {'type': 'string'}
        else
          'appId': {'type': 'string'},
        if (name != 'readHtmlAppPublication' &&
            name != 'listHtmlAppPublications')
          'expectedRevision': {'type': 'integer', 'minimum': 0},
        if (name == 'publishHtmlApp' || name == 'updateHtmlAppPublication') ...{
          'title': {'type': 'string', 'minLength': 1, 'maxLength': 100},
          'description': {'type': 'string', 'minLength': 1, 'maxLength': 500},
        },
      },
      'required': [
        if (name == 'listHtmlAppPublications') 'query' else 'appId',
        if (name != 'readHtmlAppPublication' &&
            name != 'listHtmlAppPublications')
          'expectedRevision',
        if (name == 'publishHtmlApp' || name == 'updateHtmlAppPublication') ...[
          'title',
          'description',
        ],
      ],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    try {
      if (name == 'listHtmlAppPublications') {
        final apps = await store.database.query(
          'html_apps',
          columns: [
            'id',
            'creator_id',
            '(COALESCE((SELECT title FROM miniapp_metadata WHERE app_id = html_apps.id), title)) AS title',
          ],
          where:
              "creator_id IN (?, 'user:local') AND instr(lower(COALESCE((SELECT title FROM miniapp_metadata WHERE app_id = html_apps.id), title)), lower(?)) > 0 AND id NOT LIKE 'builtin.%' AND id NOT IN (SELECT app_id FROM miniapp_installations)",
          whereArgs: [actor, call.arguments['query'] as String],
          orderBy: 'updated_at DESC, id',
          limit: 50,
        );
        final ids = apps.map((r) => r['id'] as String).toList();
        final releases = ids.isEmpty
            ? <Map<String, Object?>>[]
            : await store.database.query(
                'miniapp_publications',
                columns: ['app_id', 'revision', 'listed'],
                where: 'app_id IN (${List.filled(ids.length, '?').join(',')})',
                whereArgs: ids,
              );
        final byId = {for (final r in releases) r['app_id']: r};
        return ToolResult(
          callId: call.id,
          toolName: name,
          status: ToolResultStatus.success,
          output: {
            'apps': [
              for (final app in apps)
                {
                  'appId': app['id'],
                  'title': app['title'],
                  'revision': byId[app['id']]?['revision'] ?? 0,
                  'published': byId[app['id']]?['listed'] == 1,
                },
            ],
          },
        );
      }
      final id = call.arguments['appId'] as String;
      final rows = await store.database.query(
        'html_apps',
        columns: ['creator_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw StateError('小程序不存在');
      if (rows.single['creator_id'] != actor &&
          rows.single['creator_id'] != 'user:local') {
        throw StateError('只能管理自己创建或用户拥有的小程序');
      }
      if (id.startsWith('builtin.'))
        throw StateError('内置小程序随 App 更新，不通过发布工具修改');
      var entry = await store.refresh(
        MiniappEntry(id: id, title: '', publisher: '', kind: MiniappKind.draft),
      );
      if (!entry.draft) throw StateError('添加的副本不能作为自己的作品发布');
      if (name != 'readHtmlAppPublication' &&
          name != 'listHtmlAppPublications') {
        if (call.arguments['expectedRevision'] != entry.revision) {
          throw StateError('发布版本已变化，请重新读取发布状态');
        }
        if (name == 'withdrawHtmlApp') {
          await store.withdraw(entry);
        } else {
          if (name == 'publishHtmlApp' && entry.revision != 0) {
            throw StateError('已有发布记录，请使用发布更新工具');
          }
          if (name == 'updateHtmlAppPublication' && entry.revision == 0) {
            throw StateError('尚未发布，请使用首次发布工具');
          }
          await store.publish(
            entry,
            call.arguments['title'] as String,
            call.arguments['description'] as String,
          );
        }
        entry = await store.refresh(entry);
      }
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.success,
        output: {
          'appId': id,
          'title': entry.publishedTitle ?? entry.title,
          'description': entry.description,
          'revision': entry.revision,
          'published': entry.listed,
          'scope': 'local',
          'publisherId': 'user:local',
        },
      );
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: name,
        status: ToolResultStatus.error,
        output: {
          'message': error is StateError ? error.message : error.toString(),
        },
      );
    }
  }

  @override
  Future<void> cancel() async {}
}
