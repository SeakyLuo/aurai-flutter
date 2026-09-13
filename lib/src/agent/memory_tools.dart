import '../domain/tool_models.dart';
import '../memory/memory_controller.dart';
import '../providers/responses_transport.dart';
import 'memory_record_tools.dart';

class MemoryTools {
  MemoryTools(
    this.memory, {
    required this.conversationId,
    required this.messageId,
  });
  final String conversationId;
  final String messageId;
  final MemoryController memory;
  MemoryPlan? plan;
  ResponsesTransport? transport;
  int generation = 0;
  List<AgentTool> get tools => [
    for (final operation in MemoryRecordTool.operations)
      MemoryRecordTool(
        memory,
        operation,
        conversationId: conversationId,
        messageId: messageId,
      ),
    _PrepareMemory(this),
    _ApplyMemory(this),
  ];
}

class _PrepareMemory implements AgentTool, RuntimeCapabilityAgentTool {
  _PrepareMemory(this.owner);
  final MemoryTools owner;
  @override
  ToolDefinition get definition => const ToolDefinition(
    name: 'prepareMemoryChanges',
    description:
        'Only when the user requests organizing, supplementing, correcting or forgetting memories, prepare proposed changes with reasons. Does not save changes. Manual memories are protected. Call applyMemoryChanges for the prepared proposal to show the real confirmation; do not claim saved before application succeeds. Do not call for routine chat or invent a memory request.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'request': {'type': 'string'},
      },
      'required': ['request'],
      'additionalProperties': false,
    },
    safety: ToolSafety.readOnly,
    capabilityId: 'memory.manage',
    executionTimeout: Duration(seconds: 100),
  );
  @override
  Future<ToolResult> execute(ToolCall call) async {
    final generation = ++owner.generation;
    owner.plan = null;
    final transport = ResponsesTransport(owner.memory.modelConfig());
    owner.transport = transport;
    try {
      final plan = await owner.memory.prepareChanges(
        call.arguments['request'] as String,
        transport: transport,
      );
      if (generation != owner.generation)
        return _result(call, ToolResultStatus.cancelled, {'message': '整理已取消'});
      owner.plan = plan;
      return _result(call, ToolResultStatus.success, {
        'changes': plan.description,
        'hasChanges': plan.changes.isNotEmpty,
        'saved': false,
        'next': plan.changes.isEmpty
            ? 'No changes needed.'
            : 'Call applyMemoryChanges to present these exact changes for user confirmation.',
      });
    } on Object {
      return _result(call, ToolResultStatus.error, {
        'error': '无法生成整理建议，请检查模型配置或重试',
      });
    } finally {
      if (identical(owner.transport, transport)) owner.transport = null;
    }
  }

  @override
  Future<void> cancel() async {
    owner.generation++;
    await owner.transport?.cancel();
  }
}

class _ApplyMemory
    implements AgentTool, RuntimeCapabilityAgentTool, PreflightAgentTool {
  _ApplyMemory(this.owner);
  final MemoryTools owner;
  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'applyMemoryChanges',
    description:
        'Apply the exact prepared memory proposal after the built-in real user confirmation. Uses only the latest proposal prepared in this run. Cancellation or denied confirmation changes nothing. Never substitute a claimed confirmation.',
    inputSchema: const {
      'type': 'object',
      'properties': {},
      'required': [],
      'additionalProperties': false,
    },
    safety: ToolSafety.sensitive,
    capabilityId: 'memory.manage',
    confirmationDescriptionBuilder: (_) =>
        '确认应用以下记忆调整？\n\n${owner.plan!.description}',
  );
  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    if (owner.plan == null ||
        owner.plan!.revision != owner.memory.revision ||
        owner.plan!.changes.isEmpty) {
      return _result(call, ToolResultStatus.error, {
        'error': '没有可应用的建议，或记忆已变化，请重新整理',
      });
    }
    return null;
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final rejected = await preflight(call);
    if (rejected != null) return rejected;
    try {
      await owner.memory.applyChanges(owner.plan!);
      owner.plan = null;
      return _result(call, ToolResultStatus.success, {'saved': true});
    } on Object {
      return _result(call, ToolResultStatus.error, {
        'error': '记忆未能更新，请重新整理后重试',
      });
    }
  }

  @override
  Future<void> cancel() async {}
}

ToolResult _result(
  ToolCall call,
  ToolResultStatus status,
  Map<String, Object?> output,
) => ToolResult(
  callId: call.id,
  toolName: call.name,
  status: status,
  output: output,
);
