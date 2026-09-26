import '../domain/tool_models.dart';

/// Cross-group access is delegated only after the normal tool approval flow.
class GroupAccessTool
    implements
        AgentTool,
        RuntimeCapabilityAgentTool,
        PreflightAgentTool,
        ToolConfirmationPolicyAgentTool {
  GroupAccessTool({
    required this.original,
    required this.delegated,
    required this.resolve,
  });
  final AgentTool original, delegated;
  final Future<({bool useUserScope, String title, String preview})> Function(
    ToolCall,
  )
  resolve;
  bool _delegated = false;
  String _title = '';
  String _preview = '';

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    _delegated = false;
    final scope = await resolve(call);
    _delegated = scope.useUserScope;
    _title = scope.title;
    _preview = scope.preview;
    return null;
  }

  @override
  bool requiresConfirmation(ToolCall call) => _delegated;

  @override
  ToolDefinition get definition {
    final base = original.definition;
    final action = switch (base.name) {
      'readGroupAnnouncement' => '读取群公告',
      'updateGroupAnnouncement' => '更新群公告',
      'readGroupPinnedMessage' => '读取置顶消息',
      'pinGroupMessage' => '置顶消息（替换已有消息置顶）',
      'unpinGroupMessage' => '为全群取消消息置顶',
      'listGroupFavorites' => '读取群标记',
      'addGroupFavorite' => '添加群标记',
      _ => '取消群标记',
    };
    return ToolDefinition(
      name: base.name,
      description:
          '${base.description} In groups you have not joined, request approval through this tool using the human user\'s access. Denial grants no access; do not repeatedly request it.',
      inputSchema: base.inputSchema,
      capabilityId: base.capabilityId,
      safety: base.safety,
      executionTimeout: base.executionTimeout,
      confirmationMayBeRequired: true,
      singleUseConfirmation: true,
      confirmationDescriptionBuilder: (args) =>
          '允许 AI 在未加入的群“$_title”中$action？'
          '\n$_preview'
          '${base.name == 'updateGroupAnnouncement' ? '\n\n${(args['content'] as String).trim().isEmpty ? '清空群公告' : args['content']}' : ''}',
    );
  }

  @override
  Future<ToolResult> execute(ToolCall call) =>
      (_delegated ? delegated : original).execute(call);
  @override
  Future<void> cancel() => (_delegated ? delegated : original).cancel();
}
