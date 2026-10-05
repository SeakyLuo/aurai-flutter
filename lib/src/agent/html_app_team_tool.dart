import 'dart:async';
import '../domain/tool_detail_target.dart';
import '../domain/tool_models.dart';
import '../html_games/miniapp_team_store.dart';

class HtmlAppTeamTool implements AgentTool, RuntimeCapabilityAgentTool {
  HtmlAppTeamTool(this.name, this.store, this.actor);
  final String name, actor;
  final MiniappTeamStore store;
  Completer<Map<String, Object?>>? _waiting;
  bool _cancelled = false;

  Future<Map<String, Object?>> _request(String id, String reason) async {
    final result = await store.request(id, actor, reason);
    if (_cancelled) return {...result, 'waitingCancelled': true};
    if (result['status'] != 'pending') return result;
    final waiter = Completer<Map<String, Object?>>();
    _waiting = waiter;
    Future<void> readDecision() async {
      final data = await store.read(id, actor);
      final request = data['ownRequest'] as Map;
      if (!waiter.isCompleted && request['status'] != 'pending') {
        waiter.complete({...result, 'status': request['status']});
      }
    }

    final subscription = MiniappTeamStore.changes.stream
        .where((app) => app == result['appId'])
        .asyncMap((_) => readDecision())
        .listen(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (!waiter.isCompleted) waiter.completeError(error, stack);
          },
        );
    try {
      await readDecision();
      return {...result, ...await waiter.future};
    } finally {
      await subscription.cancel();
      _waiting = null;
    }
  }

  static const names = [
    'readHtmlAppTeam',
    'requestHtmlAppEdit',
    'manageHtmlAppTeam',
    'listHtmlAppEditRequests',
  ];

  @override
  ToolDefinition get definition => ToolDefinition(
    name: name,
    capabilityId: 'local.messages',
    safety: name == 'readHtmlAppTeam' || name == 'listHtmlAppEditRequests'
        ? ToolSafety.readOnly
        : ToolSafety.lowRisk,
    description: switch (name) {
      'readHtmlAppTeam' =>
        '查看小程序开发团队、自己的修改申请状态及源码编辑权限。appId 从 listHtmlApps 获取，安装副本会指向原作品。view=members 查看成员，view=requests 仅供创建人查看待审批申请，每页 50 条。团队成员可用 readHtmlApp/updateHtmlApp 编辑源码，但不会获得私有运行数据或管理团队的权限。',
      'requestHtmlAppEdit' =>
        '非创建人申请修改小程序，说明想做的修改。创建人或用户批准后加入开发团队，持续获得源码编辑权限。重复申请不会重复创建；等待审批，不要反复轮询或自行视为批准。',
      'listHtmlAppEditRequests' =>
        '分页查看自己创建的小程序收到的待审批修改申请，以及自己发出的待审批申请，每页 50 条。用返回的 appId、senderId 和 requestedAt 审批；不要让用户填写标识。',
      _ =>
        '管理小程序开发团队。只有创建人可以 approve/reject 修改申请、add/remove 成员；申请人只能 cancel 自己的申请。approve 后持续获得源码编辑权限，remove 立即撤销。审批或撤销时必须传刚读取的 requestedAt。成员从通讯录工具查找，禁止猜测标识；团队成员不能自行邀请或批准他人。',
    },
    inputSchema: {
      'type': 'object',
      'properties': {
        if (name != 'listHtmlAppEditRequests') 'appId': {'type': 'string'},
        if (name == 'readHtmlAppTeam')
          'view': {
            'type': 'string',
            'enum': ['members', 'requests'],
          },
        if (name == 'readHtmlAppTeam' || name == 'listHtmlAppEditRequests')
          'offset': {'type': 'integer', 'minimum': 0},
        if (name == 'requestHtmlAppEdit')
          'reason': {'type': 'string', 'minLength': 1, 'maxLength': 1000},
        if (name == 'manageHtmlAppTeam') ...{
          'action': {
            'type': 'string',
            'enum': ['approve', 'reject', 'add', 'remove', 'cancel'],
          },
          'senderId': {'type': 'string'},
          'requestedAt': {'type': 'integer'},
        },
      },
      'required': [
        if (name != 'listHtmlAppEditRequests') 'appId',
        if (name == 'requestHtmlAppEdit') 'reason',
        if (name == 'manageHtmlAppTeam') ...['action', 'senderId'],
      ],
      'additionalProperties': false,
    },
  );

  @override
  Future<ToolResult> execute(ToolCall call) async {
    _cancelled = false;
    final args = call.arguments;
    final offset = args['offset'] as int? ?? 0;
    final Map<String, Object?> output;
    if (name == 'listHtmlAppEditRequests') {
      final rows = await store.pending(actor, offset: offset);
      output = {
        'requests': rows,
        if (rows.length == MiniappTeamStore.pageSize)
          'nextOffset': offset + rows.length,
      };
    } else {
      final id = args['appId'] as String;
      if (name == 'requestHtmlAppEdit') {
        output = await _request(id, args['reason'] as String);
      } else if (name == 'manageHtmlAppTeam') {
        output = await store.manage(
          id,
          actor,
          args['action'] as String,
          args['senderId'] as String,
          requestedAt: args['requestedAt'] as int?,
        );
      } else {
        final data = await store.read(
          id,
          actor,
          requests: args['view'] == 'requests',
          offset: offset,
        );
        final creator = data['creator'] as Map;
        final own = data['ownRequest'] as Map?;
        output = {
          'appId': data['appId'],
          'title': data['title'],
          'creator': {'senderId': creator['id'], 'name': creator['name']},
          'canManage': data['canManage'],
          'canEdit': data['canEdit'],
          if (data.containsKey('pendingCount'))
            'pendingCount': data['pendingCount'],
          if (own != null)
            'ownRequest': {
              'status': own['status'],
              'reason': own['reason'],
              'requestedAt': own['requested_at'],
            },
          'entries': [
            for (final row in data['entries'] as List)
              {
                'senderId': row['sender_id'],
                'name': row['profile']['name'],
                if (row['reason'] != null) 'reason': row['reason'],
                if (row['requested_at'] != null)
                  'requestedAt': row['requested_at'],
              },
          ],
          'hasMore': data['hasMore'],
          if (data['hasMore'] == true)
            'nextOffset': offset + MiniappTeamStore.pageSize,
        };
      }
      output['detailTargets'] = [
        ToolDetailTarget(
          type: ToolDetailType.miniapp,
          id: output['appId'] as String,
          name: output['title'] as String,
        ).toJson(),
      ];
    }
    return ToolResult(
      callId: call.id,
      toolName: name,
      status: output['waitingCancelled'] == true
          ? ToolResultStatus.cancelled
          : ToolResultStatus.success,
      output: output,
    );
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    final waiting = _waiting;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete({'status': 'pending', 'waitingCancelled': true});
    }
  }
}
