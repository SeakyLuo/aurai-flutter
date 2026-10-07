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
          'description':
              'Search text, names, evidenced aliases and specific keywords. Empty lists recent memories. Older memories remain searchable.',
        },
        'offset': {'type': 'integer', 'minimum': 0},
        'preferCurrentProject': {
          'type': 'boolean',
          'description':
              'Use true for normal current-project work. Use false when the user asks about another project or compares projects. This changes ranking only; all this AI memories remain searchable.',
        },
      },
      if (operation == 'read')
        'sourceOffset': {'type': 'integer', 'minimum': 0},
      if (hasId && !reading)
        'expectedVersion': {'type': 'integer', 'minimum': 1},
      if (hasId)
        'id': {
          'type': 'string',
          'description':
              'Memory ID returned by listMemories/readMemory. Never ask the user to supply an ID.',
        },
      if (operation == 'create' || operation == 'update')
        'text': {
          'type': 'string',
          'minLength': 1,
          'maxLength': memoryTextLimit,
        },
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
          '${memory.projectShared ? "Search or list shared memories belonging to the current project, available to every AI in this project" : "Search or list this AI own memories across private chat and all groups"}, ranked by keyword relevance and recency, 20 per page. Returns IDs, device-local creation/update timestamps with explicit UTC offset, source references and revision. Use nextOffset for more. IDs are internal, do not display them to users.',
        'read' =>
          'Read one memory available to the current memory owner (this AI or the current project), including creation/update times, source references and revision.',
        'create' =>
          'Save one lasting fact only when the user explicitly asks to remember it. Query existing memories first to avoid duplicates. Do not store routine tasks, guesses or secrets.',
        'update' =>
          'Correct a specific saved memory only at the user’s explicit request. Preserves ID, creation time and original source. Explicit corrections become protected manual memories. Only editableHere memories can be changed here.',
        _ =>
          'Forget one saved memory only at the user’s explicit request. Deletes the memory without retaining a copy or creating a future exclusion rule. Can delete manual memories when explicitly requested.',
      },
      inputSchema: {
        'type': 'object',
        'properties': properties,
        'required': properties.keys.toList(),
        'additionalProperties': false,
      },
      safety: reading ? ToolSafety.readOnly : ToolSafety.lowRisk,
      capabilityId: 'memory.manage',
    );
  }

  @override
  Future<ToolResult?> preflight(ToolCall call) async {
    try {
      if (!reading && call.arguments['expectedRevision'] != memory.revision) {
        throw StateError('记忆已变化，请重新查询后操作');
      }
      return null;
    } on StateError catch (error) {
      return result(call, ToolResultStatus.error, {'error': error.toString()});
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
        final matches = await memory.readableMemories(
          query: query,
          offset: offset,
          preferCurrentProject: args['preferCurrentProject'] as bool,
        );
        return result(call, ToolResultStatus.success, {
          'memories': matches.take(20).map(memory.contextualRecord).toList(),
          'revision': memory.revision,
          'nextOffset': matches.length > 20 ? offset + 20 : null,
        });
      }
      if (operation == 'read') {
        final row = await memory.readableMemory(args['id'] as String);
        if (row == null) throw StateError('这条记忆已删除，请重新查询');
        final offset = args['sourceOffset'] as int;
        final sources = await memory.sources(
          args['id'] as String,
          offset: offset,
        );
        return result(call, ToolResultStatus.success, {
          'memory': memory.contextualRecord(row),
          'sources': sources.take(20).toList(),
          'nextSourceOffset': sources.length > 20 ? offset + 20 : null,
          'revision': memory.revision,
        });
      }
      final output = await memory.mutateRecord(
        operation,
        id: args['id'] as String?,
        text: args['text'] as String?,
        expectedVersion: args['expectedVersion'] as int?,
        expectedRevision: args['expectedRevision'] as int,
        conversationId: conversationId,
        messageId: messageId,
      );
      return result(call, ToolResultStatus.success, {
        ...output,
        'revision': memory.revision,
      });
    } on StateError catch (error) {
      return result(call, ToolResultStatus.error, {'error': error.toString()});
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
