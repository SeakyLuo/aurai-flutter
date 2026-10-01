part of 'chat_controller.dart';

extension GroupToolAccess on ChatController {
  AgentTool _withGroupMemberAccess(
    AgentTool tool,
    String actorId,
    String? groupId,
  ) {
    if (tool is! GroupAutoReplyTool &&
        tool is! GroupWakeTool &&
        tool is! GroupMuteTool) {
      return tool;
    }
    final currentGroupId = switch (tool) {
      GroupAutoReplyTool() => tool.currentGroupId,
      GroupWakeTool() => tool.currentGroupId,
      GroupMuteTool() => tool.currentGroupId,
      _ => groupId,
    };
    return PeerAccessTool(tool, (call) async {
      final id = call.arguments['groupId'] as String? ?? currentGroupId;
      if (id == null) throw ArgumentError('请先指定目标群聊');
      final targetId = call.arguments['senderId'] as String?;
      final (groups, members) = await (
        _store.database.query(
          'conversations',
          columns: ['title'],
          where: "id = ? AND kind = 'group'",
          whereArgs: [id],
          limit: 1,
        ),
        groupStore.members(id),
      ).wait;
      final actor = members.where((m) => m.sender.id == actorId).firstOrNull;
      if (tool is GroupAutoReplyTool) {
        final args = call.arguments;
        if ([
              args['senderId'] != null,
              args['senderIds'] != null,
              args['all'] == true,
            ].where((v) => v).length !=
            1)
          throw ArgumentError('senderId、senderIds、all 必须三选一');
        if (groups.isEmpty || actor == null) throw StateError('只能操作自己已加入的群');
        if ((args['all'] == true || args['senderIds'] != null) &&
            !actor.role.canManage)
          throw StateError('只有群主和群管理员可以批量暂停或恢复接话，不能申请越权');
        final ids = args['all'] == true
            ? members
                  .where((m) => m.sender.kind == MessageSenderKind.agent)
                  .map((m) => m.sender.id)
                  .toSet()
            : {
                if (targetId != null) targetId,
                ...?(args['senderIds'] as List?)?.cast<String>(),
              };
        final targets = members
            .where((m) => ids.contains(m.sender.id))
            .toList();
        if (targets.isEmpty || targets.length != ids.length)
          throw ArgumentError('请选择群内现有 AI 成员');
        var approval = false;
        for (final target in targets) {
          if (target.sender.kind != MessageSenderKind.agent || target.isMuted)
            throw StateError('只能调整未被禁言的 AI 成员');
          if (target.sender.id == actorId) continue;
          if (target.role == GroupMemberRole.owner ||
              actor.role == GroupMemberRole.member &&
                  target.role == GroupMemberRole.admin)
            throw StateError('不能调整更高角色成员的自动接话，不能申请越权');
          approval = approval || actor.role == target.role;
        }
        return (
          approval: approval,
          scope: jsonEncode([id, ...(ids.toList()..sort())]),
          description:
              '在“' +
              groups.single['title'].toString() +
              '”中' +
              (tool.pause ? '暂停' : '恢复') +
              targets.map((m) => m.sender.name).join('、') +
              '的自动接话' +
              (args['triggerReply'] == true ? '并触发思考' : ''),
        );
      }
      final target = members.where((m) => m.sender.id == targetId).firstOrNull;
      if (groups.isEmpty || actor == null || target == null) {
        throw StateError('只能操作自己已加入的群中的现有成员');
      }
      if (tool is GroupMuteTool) {
        if (!actor.role.canManage)
          throw StateError('只有群主和群管理员可以禁言或解除禁言，不能申请越权');
        if (targetId == actorId ||
            target.role == GroupMemberRole.owner ||
            actor.role == GroupMemberRole.admin &&
                target.role == GroupMemberRole.admin) {
          throw StateError('不能禁言自己、群主或同级管理员，不能申请越权');
        }
      } else {
        if (target.sender.kind != MessageSenderKind.agent) {
          throw StateError('只能调整 AI 成员的接话和唤醒状态');
        }
        if (target.isMuted) throw StateError('该成员已被禁言，不能调整接话或唤醒');
      }
      var approval = false;
      if (tool is GroupAutoReplyTool && targetId != actorId) {
        if (target.role == GroupMemberRole.owner ||
            actor.role == GroupMemberRole.member &&
                target.role == GroupMemberRole.admin) {
          throw StateError('不能调整更高角色成员的自动接话，不能申请越权');
        }
        approval = actor.role == target.role;
      }
      final action = switch (call.name) {
        'pauseGroupAutoReply' => '暂停自动接话',
        'resumeGroupAutoReply' =>
          call.arguments['triggerReply'] == true ? '恢复自动接话并触发思考' : '恢复自动接话',
        'wakeGroupMember' => '唤醒',
        _ => switch (call.arguments['durationMinutes']) {
          0 => '解除禁言',
          null => '永久禁言',
          final minutes => '禁言 $minutes 分钟',
        },
      };
      return (
        approval: approval,
        scope: jsonEncode([
          id,
          targetId,
          if (tool is GroupMuteTool) call.arguments['durationMinutes'],
        ]),
        description:
            '在“${groups.single['title']}”中对“${target.sender.name}”$action',
      );
    });
  }
}
