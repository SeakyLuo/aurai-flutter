import 'dart:convert';

import '../agent/system_prompt.dart';
import 'responses_context.dart';
import 'current_time_context.dart';
import 'model_context_limits.dart';
import 'responses_transport.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';

class DeepSeekResponsesProvider implements ModelProvider {
  DeepSeekResponsesProvider(this.config, {required String? systemPrompt})
    : _transport = ResponsesTransport(config),
      _context = ResponsesContext(
        ModelContextLimits.forModel(config.model),
        systemPrompt: systemPrompt ?? agentSystemPrompt,
      );

  final ModelConfig config;
  final ResponsesTransport _transport;
  final ResponsesContext _context;

  @override
  Future<ModelTurn> respond(ModelRequest request) async {
    _transport.onReconnect = request.onReconnect;
    _transport.beginTurn();
    await _context.prepare(request, _transport.summarize);
    _transport.checkCancelled();
    final json = await _transport.send(
      _requestBody(request),
      onTextChanged: request.onTextChanged,
      onMessageStarted: request.onMessageStarted,
      onProcessingStarted: request.onProcessingStarted,
    );
    _appendResponseOutput(json);
    return _parseResponse(json, request);
  }

  Map<String, Object?> _requestBody(ModelRequest request) => <String, Object?>{
    'model': config.model,
    'stream': true,
    if (_context.limits case final limits?)
      'max_output_tokens': limits.outputTokens,
    'instructions':
        '${_context.systemPrompt}\n${currentTimeContext()}\n${_capabilitySummary(request)}\n${request.personalContext}',
    'input': _context.input,
    'tools': request.tools
        .map(
          (tool) => <String, Object?>{
            'type': 'function',
            'name': tool.name,
            'description': tool.description,
            'parameters': tool.modelInputSchema,
          },
        )
        .toList(growable: false),
    'tool_choice': 'auto',
  };

  void _appendResponseOutput(Map<String, Object?> json) {
    _context.recordOutput(
      (json['output']! as List)
          .map((item) => (item as Map).cast<String, Object?>())
          .toList(),
    );
  }

  String _capabilitySummary(ModelRequest request) {
    final lines = request.capabilities.map(
      (capability) =>
          '- ${capability.id}: ${capability.availability.name} (${capability.reason})',
    );
    return 'Current device capabilities:\n${lines.join('\n')}';
  }

  ModelTurn _parseResponse(Map<String, Object?> json, ModelRequest request) {
    final output = (json['output']! as List<Object?>)
        .cast<Map<Object?, Object?>>();
    final calls = <ToolCall>[];
    final textParts = <String>[];
    for (final rawItem in output) {
      final item = rawItem.cast<String, Object?>();
      if (item['type'] == 'function_call' && json['status'] == 'completed') {
        calls.add(
          ToolCall.fromModel(
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
        final messageParts = <String>[];
        final content = (item['content']! as List<Object?>)
            .cast<Map<Object?, Object?>>();
        for (final rawContent in content) {
          final contentItem = rawContent.cast<String, Object?>();
          if (contentItem['type'] == 'refusal') {
            messageParts.add(contentItem['refusal']! as String);
          }
          if (contentItem['type'] == 'output_text') {
            messageParts.add(contentItem['text']! as String);
          }
        }
        textParts.add(messageParts.join('\n'));
      }
    }
    return ModelTurn(
      response: json,
      requestInput: retainedRequestInput(request),
      continuationToken: json['id']! as String,
      toolCalls: calls,
      text: textParts.isEmpty ? null : textParts.last,
    );
  }

  @override
  Future<void> cancel() => _transport.cancel();
}
