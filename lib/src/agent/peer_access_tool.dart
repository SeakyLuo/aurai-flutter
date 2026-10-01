import '../domain/tool_models.dart';

typedef PeerAccess = ({bool approval, String scope, String description});

/// Approval delegates an equal-level operation, never a group role.
class PeerAccessTool
    implements
        AgentTool,
        RuntimeCapabilityAgentTool,
        PreflightAgentTool,
        ToolConfirmationPolicyAgentTool {
  PeerAccessTool(this.original, this.resolve);
  final AgentTool original;
  final Future<PeerAccess> Function(ToolCall) resolve;
  PeerAccess? _access;

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    _access = await resolve(call);
    if (original is PreflightAgentTool) {
      return (original as PreflightAgentTool).preflight(call);
    }
    return null;
  }

  @override
  bool requiresConfirmation(ToolCall call) =>
      _access!.approval ||
      (original is ToolConfirmationPolicyAgentTool
          ? (original as ToolConfirmationPolicyAgentTool).requiresConfirmation(
              call,
            )
          : {
              ToolSafety.sensitive,
              ToolSafety.destructive,
            }.contains(original.definition.safetyFor(call.arguments)));

  @override
  ToolDefinition get definition {
    final base = original.definition;
    return ToolDefinition(
      name: base.name,
      description: '${base.description} 授权不能借用用户的群管理角色。',
      inputSchema: base.inputSchema,
      capabilityId: base.capabilityId,
      safety: base.safety,
      actionArgument: base.actionArgument,
      actionSafety: base.actionSafety,
      executionTimeout: base.executionTimeout,
      confirmationMayBeRequired: true,
      singleUseConfirmation: base.singleUseConfirmation,
      taskScopedConfirmation: base.taskScopedConfirmation,
      waitsForUser: base.waitsForUser,
      authorizationScope: _access?.scope,
      authorizationLabel: _access?.description,
      confirmationDescriptionBuilder: (args) => _access!.approval
          ? '${_access!.description}\n是否允许？授权仅限此 AI、目标和操作。'
          : base.confirmationDescriptionFor(args) ?? base.description,
    );
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final current = await resolve(call);
    if (current.scope != _access!.scope ||
        current.approval && !_access!.approval) {
      throw StateError('操作权限已变化，请重新申请授权');
    }
    return original.execute(call);
  }

  @override
  Future<void> cancel() => original.cancel();
}
