import '../domain/tool_models.dart';
import '../memory/memory_controller.dart';

class MemoryRecordTool
    implements AgentTool, RuntimeCapabilityAgentTool, PreflightAgentTool {
  MemoryRecordTool(
    this.memory,
    this.operation, {
    required this.conversationId,
    required this.messageId,
  });
  static const operations = ['list', 'read', 'create', 'update', 'delete'];
  final MemoryController memory;
  final String operation, conversationId;
  final String? messageId;
  bool get reading => operation == 'list' || operation == 'read';
  bool get hasId =>
      operation == 'read' || operation == 'update' || operation == 'delete';

  @override
  ToolDefinition get definition {
    final properties = <String, Object?>{
      if (operation == 'list') ...{
        'query': {
          'type': 'string',
          'description': 'Search memory text; empty lists all.',
        },
        'offset': {'type': 'integer', 'minimum': 0},
      },
      if (hasId)
        'id': {
          'type': 'string',
          'description':
              'Memory ID returned by listMemories/readMemory. Never ask the user to supply an ID.',
        },
      if (operation == 'create' || operation == 'update')
        'text': {'type': 'string', 'minLength': 1, 'maxLength': 300},
      if (!reading)
        'expectedRevision': {
          'type': 'integer',
          'description':
              'revision returned by listMemories or readMemory. Re-query if stale.',
        },
    };
    return ToolDefinition(
      name: operation == 'list' ? 'listMemories' : '${operation}Memory',
      description: switch (operation) {
        'list' =>
          'Search or list saved memories, newest updated first, 20 per page. Returns IDs, UTC creation/update timestamps, source references and revision. Use nextOffset for more. IDs are internal, do not display them to users.',
        'read' =>
          'Read one saved memory including creation/update times, source references and revision.',
        'create' =>
          'Save one lasting fact only when the user explicitly asks to remember it. Requires real confirmation. Query existing memories first to avoid duplicates. Do not store routine tasks, guesses or secrets.',
        'update' =>
          'Correct a specific saved memory only at the user’s explicit request and after real confirmation. Preserves ID, creation time and original source. Explicit corrections become protected manual memories.',
        _ =>
          'Forget one saved memory only at the user’s explicit request and after real confirmation. Deletes the memory without retaining a copy or creating a future exclusion rule. Can delete manual memories when explicitly requested.',
      },
      inputSchema: {
        'type': 'object',
        'properties': properties,
        'required': properties.keys.toList(),
        'additionalProperties': false,
      },
      safety: reading ? ToolSafety.readOnly : ToolSafety.sensitive,
      capabilityId: 'memory.manage',
      confirmationDescriptionBuilder: reading
          ? null
          : (args) => switch (operation) {
              'create' => '记住以下内容？\n\n${args['text']}',
              'update' =>
                '修改这条记忆？\n\n${memory.entryById(args['id'] as String)['text']}\n→ ${args['text']}',
              _ =>
                '忘记这条记忆？\n\n${memory.entryById(args['id'] as String)['text']}',
            },
    );
  }

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    try {
      if (hasId) memory.entryById(call.arguments['id'] as String);
      if (!reading && call.arguments['expectedRevision'] != memory.revision) {
        throw StateError('记忆已变化，请重新查询后操作');
      }
      return null;
    } on StateError catch (error) {
      return result(call, ToolResultStatus.error, {'error': error.message});
    }
  }

  @override
  Future<ToolResult> execute(ToolCall call) async {
    final rejected = await preflight(call);
    if (rejected != null) return rejected;
    try {
      final args = call.arguments;
      if (operation == 'list') {
        final query = (args['query'] as String).toLowerCase();
        final offset = args['offset'] as int;
        final matches =
            memory.entries
                .where(
                  (entry) =>
                      (entry['text'] as String).toLowerCase().contains(query),
                )
                .toList()
              ..sort((a, b) {
                final order = (b['updated_at'] as int).compareTo(
                  a['updated_at'] as int,
                );
                return order == 0
                    ? (a['id'] as String).compareTo(b['id'] as String)
                    : order;
              });
        return result(call, ToolResultStatus.success, {
          'memories': matches.skip(offset).take(20).map(memoryRecord).toList(),
          'total': matches.length,
          'revision': memory.revision,
          'nextOffset': offset + 20 < matches.length ? offset + 20 : null,
        });
      }
      if (operation == 'read')
        return result(call, ToolResultStatus.success, {
          'memory': memoryRecord(memory.entryById(args['id'] as String)),
          'revision': memory.revision,
        });
      final output = await memory.mutateRecord(
        operation,
        id: args['id'] as String?,
        text: args['text'] as String?,
        expectedRevision: args['expectedRevision'] as int,
        conversationId: conversationId,
        messageId: messageId,
      );
      return result(call, ToolResultStatus.success, {
        ...output,
        'revision': memory.revision,
      });
    } on StateError catch (error) {
      return result(call, ToolResultStatus.error, {'error': error.message});
    }
  }

  ToolResult result(
    ToolCall call,
    ToolResultStatus status,
    Map<String, Object?> output,
  ) => ToolResult(
    callId: call.id,
    toolName: call.name,
    status: status,
    output: output,
  );
  @override
  Future<void> cancel() async {}
}
