import 'model_image_input.dart';

import '../agent/system_prompt.dart';
import 'responses_context.dart';
import 'response_window.dart';
import 'shared_responses_context.dart';
import 'current_time_context.dart';
import 'response_citations.dart';
import 'model_context_limits.dart';
import 'responses_transport.dart';
import '../domain/model_provider.dart';
import '../domain/tool_models.dart';

class OpenAiResponsesProvider implements ModelProvider {
  OpenAiResponsesProvider(
    this.config, {
    required String? systemPrompt,
    SharedResponsesContext? sharedContext,
  }) : _transport = ResponsesTransport(config),
       _context = ResponseWindow(
         ModelContextLimits.forConfig(config),
         supportsImages: configSupportsImageInput(config),
         sharedContext: sharedContext,
         systemPrompt: systemPrompt ?? agentSystemPrompt,
       );

  final ModelConfig config;
  final ResponsesTransport _transport;
  final ResponseWindow _context;

  @override
  Future<ModelTurn> respond(ModelRequest request) async {
    _transport.onReconnect = request.onReconnect;
    _transport.beginTurn();
    final shifted = await _context.prepare(request);
    _transport.checkCancelled();
    final restart = request.continuationToken == null || shifted;
    final json = await _transport.send(
      {
        'model': config.apiModel,
        'stream': true,
        'max_output_tokens': _context.limits.outputTokens,
        'instructions':
            '${_context.systemPrompt}\n${currentTimeContext()}\n${_capabilitySummary(request)}\n${_context.refreshedContext ?? request.personalContext}',
        'input': restart
            ? _context.input
            : [
                ...request.toolResults.map(functionCallOutput),
                ..._context.supportsImages
                    ? request.userMessageInput
                    : textOnlyModelInput(request.userMessageInput),
                for (final update in request.userUpdates)
                  {'role': 'user', 'content': update},
              ],
        'tools': [
          if (request.tools.any((tool) => tool.name == 'searchWeb'))
            {'type': 'web_search'},
          ...request.tools.map(
            (tool) => <String, Object?>{
              'type': 'function',
              'name': tool.name,
              'description': tool.modelDescription,
              'parameters': tool.modelInputSchema,
              'strict': true,
            },
          ),
        ],
        'tool_choice': 'auto',
        if (request.responseSchema != null)
          'text': {
            'format': {
              'type': 'json_schema',
              'name': 'interactive_choice',
              'strict': true,
              'schema': request.responseSchema,
            },
          },
        'parallel_tool_calls': false,
        'store': true,
        'include': ['reasoning.encrypted_content'],
        if (!restart) 'previous_response_id': request.continuationToken,
      },
      onTextChanged: request.onTextChanged,
      onMessageStarted: request.onMessageStarted,
      onMessageCompleted: request.onMessageCompleted,
      onProcessingStarted: request.onProcessingStarted,
    );
    _context.recordOutput(
      (json['output']! as List)
          .map((item) => (item as Map).cast<String, Object?>())
          .toList(),
    );
    return _parseResponse(json, request);
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
          ToolCall.fromJsonArguments(
            id: item['call_id']! as String,
            name: item['name']! as String,
            arguments: item['arguments']! as String,
            acceptsEmptyArguments: request.tools.any(
              (tool) => tool.name == item['name'] && tool.acceptsEmptyArguments,
            ),
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
            messageParts.add(responseTextWithCitations(contentItem));
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
  Future<void> cancel() async {
    await _transport.cancel();
  }
}
