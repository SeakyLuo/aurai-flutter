import 'dart:convert';
import '../domain/tool_models.dart';

/// Delegated reads use the same approval and saved grants as other tools.
class UserDataReadTool
    implements
        AgentTool,
        RuntimeCapabilityAgentTool,
        PreflightAgentTool,
        ToolConfirmationPolicyAgentTool {
  UserDataReadTool({
    required this.original,
    required this.delegated,
    required this.resolve,
    required this.currentConversationId,
  });
  final AgentTool original;
  final String currentConversationId;
  final AgentTool delegated;
  final Future<({bool useUserScope, String title})> Function(ToolCall) resolve;
  bool _useUserScope = false;
  String _title = '';
  String? _scope;

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    _useUserScope = false;
    final scope = await resolve(call);
    _useUserScope = scope.useUserScope;
    _title = scope.title;
    final keys = call.arguments.keys.where((key) => key != 'offset').toList()
      ..sort();
    _scope = jsonEncode([
      currentConversationId,
      {for (final key in keys) key: call.arguments[key]},
    ]);
    if (original is PreflightAgentTool && !_useUserScope) {
      return await (original as PreflightAgentTool).preflight(call);
    }
    return null;
  }

  @override
  bool requiresConfirmation(ToolCall call) =>
      _useUserScope ||
      (original is ToolConfirmationPolicyAgentTool &&
          (original as ToolConfirmationPolicyAgentTool).requiresConfirmation(
            call,
          ));

  @override
  ToolDefinition get definition {
    final base = original.definition;
    return ToolDefinition(
      name: base.name,
      summary: base.summary,
      description:
          '${base.description} If the AI lacks access but the human user can read the target, this call requests approval to read using the user’s access. A refusal grants no access; do not repeatedly request it. This never permits sending, editing, joining groups or acting as the user.',
      inputSchema: base.inputSchema,
      capabilityId: base.capabilityId,
      safety: base.safety,
      executionTimeout: base.executionTimeout,
      confirmationMayBeRequired: true,
      singleUseConfirmation: _useUserScope ? false : base.singleUseConfirmation,
      authorizationScope: _scope,
      authorizationLabel:
          '读取“$_title”的${base.name == 'readHtmlMessage' && _useUserScope ? '小程序数据' : '会话数据'}',
      confirmationDescriptionBuilder: (args) => _useUserScope
          ? '是否允许读取“$_title”中本次请求的数据？\n仅限你有权查看的内容。${args['includePrivate'] == true ? '\n同时包含小程序源码和内部状态。' : ''}'
          : base.confirmationDescriptionFor(args) ?? '是否允许本次数据读取？',
    );
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final scope = await resolve(call);
    if (scope.useUserScope && !_useUserScope) {
      throw StateError('读取权限已变化，请重新申请授权');
    }
    final result = await (_useUserScope ? delegated : original).execute(call);
    if (!_useUserScope || result.status != ToolResultStatus.success)
      return result;
    return ToolResult(
      callId: result.callId,
      toolName: result.toolName,
      status: result.status,
      output: {
        ...result.output,
        'accessContext': {
          'viewer': 'user:local',
          'readOnly': true,
          'description':
              'User-authorized read from the human user’s perspective. Own participation and private views belong to that user, not the AI.',
        },
      },
      attachments: result.attachments,
    );
  }

  @override
  Future<void> cancel() async {
    await (_useUserScope ? delegated : original).cancel();
  }
}
