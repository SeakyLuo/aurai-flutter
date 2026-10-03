import '../domain/tool_models.dart';

/// User approval applies only to the requested HTML instance and exact operation.
class HtmlDataAccessTool
    implements
        AgentTool,
        RuntimeCapabilityAgentTool,
        PreflightAgentTool,
        ToolConfirmationPolicyAgentTool {
  HtmlDataAccessTool({
    required this.original,
    required this.delegated,
    required this.resolve,
  });
  final AgentTool original, delegated;
  final Future<({bool allowed, String title})> Function(ToolCall) resolve;
  bool _delegated = false;
  String _title = '';
  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    final access = await resolve(call);
    _delegated = !access.allowed;
    _title = access.title;
    return null;
  }

  @override
  bool requiresConfirmation(ToolCall call) => _delegated;
  @override
  ToolDefinition get definition {
    final base = original.definition;
    final write = base.name == 'updateHtmlData';
    return ToolDefinition(
      name: base.name,
      description:
          '${base.description} If you lack instance access, this call requests user approval; do not hand the operation back to the user. Denial grants no access.',
      inputSchema: base.inputSchema,
      capabilityId: base.capabilityId,
      safety: base.safety,
      confirmationMayBeRequired: true,
      singleUseConfirmation: true,
      authorizationLabel: '${write ? '修改' : '读取'}小程序“$_title”的实例数据',
      confirmationDescriptionBuilder: (_) =>
          '是否允许此 AI ${write ? '修改' : '读取'}已发送的小程序“$_title”的数据？仅限此消息实例，可能包含私密数据；不会修改模板或其他实例。',
    );
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final access = await resolve(call);
    if (!access.allowed && !_delegated) throw StateError('实例权限已变化，请重新申请授权');
    return (_delegated ? delegated : original).execute(call);
  }

  @override
  Future<void> cancel() => (_delegated ? delegated : original).cancel();
}
