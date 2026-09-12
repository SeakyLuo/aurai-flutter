import 'dart:convert';

import '../agent/system_prompt.dart';
import 'responses_context.dart';
import 'model_context_limits.dart';
import 'responses_transport.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';

class DeepSeekResponsesProvider implements ModelProvider {
  DeepSeekResponsesProvider(this.config)
    : _transport = ResponsesTransport(config),
      _context = ResponsesContext(ModelContextLimits.forModel(config.model));

  final ModelConfig config;
  final ResponsesTransport _transport;
  final ResponsesContext _context;

  @override
  Future<ModelTurn> respond(ModelRequest request) async {
    _transport.beginTurn();
    await _context.prepare(request, _transport.summarize);
    _transport.checkCancelled();
    final json = await _transport.send(
      _requestBody(request),
      onTextChanged: request.onTextChanged,
    );
    _appendResponseOutput(json);
    return _parseResponse(json);
  }

  Map<String, Object?> _requestBody(ModelRequest request) => <String, Object?>{
    'model': config.model,
    'stream': true,
    if (_context.limits case final limits?)
      'max_output_tokens': limits.outputTokens,
    'instructions':
        '$agentSystemPrompt\n${_capabilitySummary(request)}\n${request.personalContext}',
    'input': _context.input,
    'tools': request.tools
        .map(
          (tool) => <String, Object?>{
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.inputSchema,
          },
        )
        .toList(growable: false),
    'tool_choice': 'auto',
  };

  void _appendResponseOutput(Map<String, Object?> json) {
    final history = <Map<String, Object?>>[];
    final output = (json['output']! as List<Object?>)
        .cast<Map<Object?, Object?>>();
    for (final rawItem in output) {
      final item = rawItem.cast<String, Object?>();
      switch (item['type']) {
        case 'reasoning':
          history.add(<String, Object?>{
            'type': 'reasoning',
            'content': item['content']!,
          });
        case 'function_call':
          history.add(<String, Object?>{
            'type': 'function_call',
            'call_id': item['call_id']!,
            'name': item['name']!,
            'arguments': item['arguments']!,
          });
        case 'message':
          history.add(<String, Object?>{
            'role': 'assistant',
            'content': item['content']!,
          });
      }
    }
    _context.recordOutput(history);
  }

  String _capabilitySummary(ModelRequest request) {
    final lines = request.capabilities.map(
      (capability) =>
          '- ${capability.id}: ${capability.availability.name} (${capability.reason})',
    );
    return 'Current device capabilities:\n${lines.join('\n')}';
  }

  ModelTurn _parseResponse(Map<String, Object?> json) {
    final output = (json['output']! as List<Object?>)
        .cast<Map<Object?, Object?>>();
    final calls = <ToolCall>[];
    final textParts = <String>[];
    for (final rawItem in output) {
      final item = rawItem.cast<String, Object?>();
      if (item['type'] == 'function_call') {
        calls.add(
          ToolCall(
            id: item['call_id']! as String,
            name: item['name']! as String,
            arguments:
                (jsonDecode(item['arguments']! as String)
                        as Map<Object?, Object?>)
                    .cast<String, Object?>(),
          ),
        );
      }
      if (item['type'] == 'message') {
        final content = (item['content']! as List<Object?>)
            .cast<Map<Object?, Object?>>();
        for (final rawContent in content) {
          final contentItem = rawContent.cast<String, Object?>();
          if (contentItem['type'] == 'refusal') {
            textParts.add(contentItem['refusal']! as String);
          }
          if (contentItem['type'] == 'output_text') {
            textParts.add(contentItem['text']! as String);
          }
        }
      }
    }
    return ModelTurn(
      continuationToken: json['id']! as String,
      toolCalls: calls,
      text: textParts.isEmpty ? null : textParts.join('\n'),
    );
  }

  @override
  Future<void> cancel() => _transport.cancel();
}
