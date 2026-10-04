import '../domain/ui_tool_actions.dart';
import 'dart:async';

import '../domain/capability.dart';
import '../domain/tool_models.dart';
import 'tool_registry.dart';
import 'ask_user_tool.dart';

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
  String? get activeToolName => _activeTool?.definition.name;
  bool _cancelRequested = false;

  Future<ToolResult> execute(ToolCall call) async {
    _cancelRequested = false;
    try {
      return await _execute(call);
    } on Object catch (error) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: _cancelRequested
            ? ToolResultStatus.cancelled
            : ToolResultStatus.error,
        output: {
          'error': error.toString(),
          'next': '先根据原始报错检查原因或调整操作；原因未消除前不要重复相同调用。',
        },
      );
    }
  }

  Future<ToolResult> _execute(ToolCall call) async {
    final tool = _registry.find(call.name);
    if (tool == null) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: const <String, Object?>{
          'code': 'unknown_tool',
          'error':
              'Tool does not exist. Use searchTools to find an available tool.',
        },
      );
    }
    final capability = _registry.capabilityFor(tool);
    if (tool is! RuntimeCapabilityAgentTool &&
        (capability == null ||
            capability.availability == CapabilityAvailability.unavailable ||
            capability.availability == CapabilityAvailability.unsupported)) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: <String, Object?>{
          'code': 'capability_unavailable',
          'error': 'Capability is not available',
          'capability': tool.definition.capabilityId,
          'availability': capability?.availability.name ?? 'unavailable',
          'reason': capability?.reason ?? 'Capability was not reported',
        },
      );
    }
    if (!_registry.isExposed(call.name)) {
      final definition = _registry.catalog.firstWhere(
        (item) => item.name == call.name,
      );
      _registry.retain(call.name);
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: {
          'code': 'tool_loaded_for_next_turn',
          'executed': false,
          'message':
              'Tool loaded automatically. On the next model turn, call it using the provided schema. No searchTools call is needed. Loading grants no permission.',
          'tool': {
            'name': definition.name,
            'description': definition.description,
            'parameters': definition.modelInputSchema,
          },
        },
      );
    }
    _registry.retain(call.name);
    if (tool is PreflightAgentTool) {
      try {
        final rejected = await (tool as PreflightAgentTool).preflight(call);
        if (rejected != null) return rejected;
      } on StateError catch (error) {
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: ToolResultStatus.denied,
          output: {'error': error.toString()},
        );
      } on ArgumentError catch (error) {
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: ToolResultStatus.error,
          output: {'error': error.toString()},
        );
      }
    }
    final safety = tool.definition.safetyFor(call.arguments);
    final needsConfirmation = tool is ToolConfirmationPolicyAgentTool
        ? (tool as ToolConfirmationPolicyAgentTool).requiresConfirmation(call)
        : safety == ToolSafety.sensitive || safety == ToolSafety.destructive;
    if (needsConfirmation) {
      {
        final seconds = call.confirmationTimeoutSeconds;
        if (seconds != null && seconds <= 0) {
          return ToolResult(
            callId: call.id,
            toolName: call.name,
            status: ToolResultStatus.error,
            output: const {
              'error':
                  'Specify null or a positive integer confirmationTimeoutSeconds to choose the user approval waiting time.',
            },
          );
        }
        final approved = await confirmTool(call, tool.definition);
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
      }
    }
    return runAuthorizedTool(
      call,
      tool.definition,
      () => _executeAuthorized(tool, call),
    );
  }

  Future<bool> confirmTool(ToolCall call, ToolDefinition definition) =>
      _confirm(call, definition);

  Future<ToolResult> runAuthorizedTool(
    ToolCall call,
    ToolDefinition definition,
    Future<ToolResult> Function() action,
  ) => action();

  Future<ToolResult> _executeAuthorized(AgentTool tool, ToolCall call) async {
    if (_cancelRequested) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.cancelled,
        output: const {'cancelled': true, 'performed': false},
      );
    }
    _activeTool = tool;
    try {
      final ToolResult result;
      try {
        final execution = tool.execute(call);
        // Questions own their deadline, including deferred user responses.
        result = tool is AskUserTool
            ? await execution
            : await execution.timeout(tool.definition.executionTimeout);
      } on StateError catch (error) {
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: _cancelRequested
              ? ToolResultStatus.cancelled
              : ToolResultStatus.error,
          output: {
            'code': 'tool_operation_rejected',
            'error': error.toString(),
            'next': '先根据失败原因检查当前状态或调整操作；原因未消除前不要重复相同调用。',
          },
        );
      } on ArgumentError catch (error) {
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: _cancelRequested
              ? ToolResultStatus.cancelled
              : ToolResultStatus.error,
          output: {
            'code': 'invalid_tool_arguments',
            'error': error.toString(),
            'next': '先根据错误修正参数；不要原样重试。',
          },
        );
      }
      return result;
    } on TimeoutException catch (error) {
      String? cancellationError;
      try {
        await tool.cancel();
      } on Object catch (error) {
        cancellationError = error.toString();
      }
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: <String, Object?>{
          'error': error.toString(),
          'timeoutSeconds': tool.definition.executionTimeout.inSeconds,
          if (cancellationError != null) 'cancellationError': cancellationError,
          'next': '先检查执行状态；超时不代表操作未生效，不要自动重试。',
        },
      );
    } finally {
      _activeTool = null;
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    final tool = _activeTool;
    if (tool != null) {
      await tool.cancel();
    }
  }
}
