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
  bool _cancelRequested = false;

  Future<ToolResult> execute(
    ToolCall call, {
    void Function(ToolResult)? onWaitingForUser,
  }) async {
    _cancelRequested = false;
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
    _registry.load([call.name]);
    final capability = _registry.capabilityFor(tool);
    final questions = _registry.find('askUser') as AskUserTool?;
    if (call.userAction != null &&
        (tool.definition.waitsForUser ||
            questions == null ||
            questions.hasPending)) {
      return ToolResult(
        callId: call.id,
        toolName: call.name,
        status: ToolResultStatus.error,
        output: const {
          'error':
              '当前工具已有用户等待流程，或已有问题未处理，不能再添加人工交接。此次动作尚未执行，请移除 userAction 或先处理已有问题。',
        },
      );
    }
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
      }
    }
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
      final result = await tool
          .execute(call)
          .timeout(tool.definition.executionTimeout);
      if (_cancelRequested ||
          call.userAction == null ||
          result.status != ToolResultStatus.success ||
          result.output.containsKey('error') ||
          result.output['cancelled'] == true ||
          result.output['pending'] == true ||
          result.output['performed'] == false ||
          result.output['opened'] == false ||
          result.output['started'] == false ||
          result.output['granted'] == false)
        return result;
      _activeTool = questions;
      onWaitingForUser?.call(result);
      final answer = await questions!.waitForUserAction(call.userAction!);
      return ToolResult(
        callId: result.callId,
        toolName: result.toolName,
        status: result.status,
        attachments: result.attachments,
        output: {
          ...result.output,
          'userAction': {
            'instruction': call.userAction,
            ...answer,
            'next': answer['reportedCompleted'] == true
                ? '用户报告手动步骤完成。重新观察或检查实际状态后再继续，不将此确认当作系统授权或任务成功。'
                : '用户取消或反馈了问题，未确认完成。不要继续依赖该步骤的操作；取消不撤销之前已执行的动作，不自动重新交接。',
          },
        },
      );
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
    _cancelRequested = true;
    final tool = _activeTool;
    if (tool != null) {
      await tool.cancel();
    }
  }
}
