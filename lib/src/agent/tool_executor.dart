import '../domain/ui_tool_actions.dart';
import 'dart:async';

import '../domain/capability.dart';
import '../domain/tool_models.dart';
import 'tool_registry.dart';

typedef ToolConfirmation =
    Future<bool> Function(ToolCall call, ToolDefinition definition);

class ToolExecutor {
  ToolExecutor({
    required ToolRegistry registry,
    required ToolConfirmation confirm,
  }) : _registry = registry,
       _confirm = confirm;

  final ToolRegistry _registry;
  final ToolConfirmation _confirm;
  AgentTool? _activeTool;
  final Map<String, Object> _authorizationGrants = <String, Object>{};

  Future<ToolResult> execute(ToolCall call) async {
    final tool = _registry.find(call.name);
    if (tool == null || !_registry.isExposed(call.name)) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: const <String, Object?>{
          'error': 'Tool is not loaded for this turn. Use searchTools first.',
        },
      );
    }
    final capability = _registry.capabilityFor(tool);
    if (tool is PreflightAgentTool) {
      final rejected = await (tool as PreflightAgentTool).preflight(call);
      if (rejected != null) return rejected;
    }
    if (tool is! RuntimeCapabilityAgentTool &&
        (capability == null ||
            capability.availability == CapabilityAvailability.unavailable ||
            capability.availability == CapabilityAvailability.unsupported)) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: <String, Object?>{
          'error': 'Capability is not available',
          'capability': tool.definition.capabilityId,
          'availability': capability?.availability.name ?? 'unavailable',
          'reason': capability?.reason ?? 'Capability was not reported',
        },
      );
    }
    if (tool.definition.safetyFor(call.arguments)
        case ToolSafety.sensitive || ToolSafety.destructive) {
      final scopedTool = tool is ScopedAuthorizationAgentTool
          ? tool as ScopedAuthorizationAgentTool
          : null;
      final requestedScope = scopedTool?.authorizationScope(call);
      final grantedScope = _authorizationGrants[call.name];
      final alreadyGranted =
          scopedTool != null &&
          grantedScope != null &&
          scopedTool.authorizationCovers(grantedScope, requestedScope!);
      if (!alreadyGranted) {
        final approved = await _confirm(call, tool.definition);
        if (!approved) {
          return ToolResult(
            callId: call.id,
            toolName: call.name,
            status: ToolResultStatus.denied,
            output: <String, Object?>{
              'error': 'Operation was not approved',
              if (tool.definition.taskScopedConfirmation &&
                  isScreenTool(call.name))
                'next':
                    'This screen operation was not approved. Do not repeat the same request. If the observation is stale, observe again before acting. If the user declined screen access, stop screen operations; authorization can only be requested in a new user task.',
            },
          );
        }
        if (requestedScope != null) {
          _authorizationGrants[call.name] = requestedScope;
        }
      }
    }
    _activeTool = tool;
    try {
      return await tool.execute(call).timeout(tool.definition.executionTimeout);
    } on TimeoutException {
      await tool.cancel();
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: <String, Object?>{
          'error':
              'Tool timed out after ${tool.definition.executionTimeout.inSeconds} seconds',
        },
      );
    } finally {
      _activeTool = null;
    }
  }

  Future<void> cancel() async {
    final tool = _activeTool;
    if (tool != null) {
      await tool.cancel();
    }
  }
}
