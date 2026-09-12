import 'dart:convert';

import '../agent/system_prompt.dart';
import 'responses_context.dart';
import 'response_citations.dart';
import 'model_context_limits.dart';
import 'responses_transport.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';

class OpenAiResponsesProvider implements ModelProvider {
  OpenAiResponsesProvider(this.config)
    : _transport = ResponsesTransport(config),
      _context = ResponsesContext(ModelContextLimits.forModel(config.model));

  final ModelConfig config;
  final ResponsesTransport _transport;
  final ResponsesContext _context;

  @override
  Future<ModelTurn> respond(ModelRequest request) async {
    _transport.beginTurn();
    final compacted = await _context.prepare(request, _transport.summarize);
    _transport.checkCancelled();
    final restart = request.continuationToken == null || compacted;
    final json = await _transport.send({
      'model': config.model,
      'stream': true,
      if (_context.limits case final limits?)
        'max_output_tokens': limits.outputTokens,
      'instructions':
          '$agentSystemPrompt\n${_capabilitySummary(request)}\n${request.personalContext}',
      'input': restart
          ? _context.input
          : request.toolResults.map(functionCallOutput).toList(),
      'tools': [
        {'type': 'web_search'},
        ...request.tools.map(
          (tool) => <String, Object?>{
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.inputSchema,
            'strict': true,
          },
        ),
      ],
      'tool_choice': 'auto',
      'parallel_tool_calls': false,
      'store': true,
      'include': ['reasoning.encrypted_content'],
      if (!restart) 'previous_response_id': request.continuationToken,
    }, onTextChanged: request.onTextChanged);
    _context.recordOutput(
      (json['output']! as List)
          .map((item) => (item as Map).cast<String, Object?>())
          .toList(),
    );
    return _parseResponse(json);
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
            textParts.add(responseTextWithCitations(contentItem));
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
