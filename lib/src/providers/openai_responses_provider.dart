import 'model_image_input.dart';

import '../agent/system_prompt.dart';
import 'responses_context.dart';
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
    ModelConfig? summaryConfig,
    this.sharedContext,
  }) : _transport = ResponsesTransport(config),
       _summaryTransport = ResponsesTransport(summaryConfig ?? config),
       _context = ResponsesContext(
         ModelContextLimits.forModel(config.model),
         summaryLimits: ModelContextLimits.forModel(
           (summaryConfig ?? config).model,
         ),
         supportsImages: modelSupportsImageInput(config.model),
         systemPrompt: systemPrompt ?? agentSystemPrompt,
       );

  final ModelConfig config;
  final ResponsesTransport _transport;
  final ResponsesContext _context;
  final ResponsesTransport _summaryTransport;
  final SharedResponsesContext? sharedContext;

  @override
  Future<ModelTurn> respond(ModelRequest request) async {
    _transport.onReconnect = request.onReconnect;
    _transport.beginTurn();
    _summaryTransport.beginTurn();
    final compacted = await (sharedContext == null
        ? _context.prepare(request, _summaryTransport.summarize)
        : sharedContext!.prepare(
            _context,
            request,
            _summaryTransport.summarize,
          ));
    _transport.checkCancelled();
    final restart = request.continuationToken == null || compacted;
    final json = await _transport.send(
      {
        'model': config.model,
        'stream': true,
        'max_output_tokens': _context.limits.outputTokens,
        'instructions':
            '${_context.systemPrompt}\n${currentTimeContext()}\n${_capabilitySummary(request)}\n${request.personalContext}',
        'input': restart
            ? _context.input
            : [
                ...request.toolResults.map(functionCallOutput),
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
              'description': tool.description,
              'parameters': tool.modelInputSchema,
              'strict': true,
            },
          ),
        ],
        'tool_choice': 'auto',
        'parallel_tool_calls': false,
        'store': true,
        'include': ['reasoning.encrypted_content'],
        if (!restart) 'previous_response_id': request.continuationToken,
      },
      onTextChanged: request.onTextChanged,
      onMessageStarted: request.onMessageStarted,
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
    await Future.wait([_transport.cancel(), _summaryTransport.cancel()]);
  }
}
