import 'dart:convert';
import 'provider_error.dart';

import '../domain/model_provider.dart';

/// Adapt the shared conversation representation to Chat Completions.
Map<String, Object?> chatCompletionsBody(
  Map<String, Object?> body, {
  bool supportsTools = true,
  bool openRouter = false,
}) {
  final messages = <Map<String, Object?>>[
    if (body['instructions'] case final String instructions)
      {'role': 'system', 'content': instructions},
  ];
  final toolImages = <Map<String, Object?>>[];
  void flushImages() {
    if (toolImages.isEmpty) return;
    messages.add({'role': 'user', 'content': List.of(toolImages)});
    toolImages.clear();
  }

  final input = body['input'];
  final items = input is String
      ? [
          {'role': 'user', 'content': input},
        ]
      : input as List;
  for (final raw in items) {
    final item = raw as Map;
    switch (item['type']) {
      case 'reasoning':
        // Responses-only reasoning items are not Chat Completions messages.
        continue;
      case 'function_call':
        if (!supportsTools) continue;
        flushImages();
        if (messages.isEmpty || messages.last['role'] != 'assistant') {
          messages.add({'role': 'assistant', 'content': ''});
        }
        final calls =
            messages.last.putIfAbsent(
                  'tool_calls',
                  () => <Map<String, Object?>>[],
                )
                as List;
        calls.add({
          'id': item['call_id'],
          'type': 'function',
          'function': {'name': item['name'], 'arguments': item['arguments']},
        });
      case 'function_call_output':
        final output = item['output'];
        var text = '';
        if (output is String) {
          text = output;
        } else {
          final parts = (output as List).cast<Map>();
          text = parts
              .where((p) => p['type'] == 'input_text')
              .map((p) => p['text'])
              .join('\n');
          toolImages.addAll(
            parts.where((p) => p['type'] == 'input_image').map(_imagePart),
          );
        }
        messages.add({
          'role': supportsTools ? 'tool' : 'user',
          if (supportsTools) 'tool_call_id': item['call_id'],
          'content': text,
        });
      default:
        flushImages();
        final content = item['content'];
        messages.add({
          'role': item['role'] == 'developer' ? 'system' : item['role'],
          'content': item['role'] == 'assistant' && content is List
              // Tool-only replies have empty string content, not an empty text part.
              ? content
                    .cast<Map>()
                    .map(
                      (part) => part['type'] == 'refusal'
                          ? part['refusal']
                          : part['text'],
                    )
                    .join('')
              : content is String
              ? content
              : [
                  for (final part in (content as List).cast<Map>())
                    if (part['type'] == 'input_image')
                      _imagePart(part)
                    else
                      {
                        'type': 'text',
                        'text': part['type'] == 'refusal'
                            ? part['refusal']
                            : part['text'],
                      },
                ],
          if (openRouter && item['reasoning_details'] != null)
            'reasoning_details': item['reasoning_details'],
          if (!openRouter && item['reasoning_content'] != null)
            'reasoning_content': item['reasoning_content'],
        });
    }
  }
  flushImages();
  final tools = (body['tools'] as List? ?? const []).cast<Map>();
  return {
    'model': body['model'],
    'stream': true,
    'messages': messages,
    for (final key in ['reasoning', 'thinking', 'enable_thinking'])
      if (body.containsKey(key)) key: body[key],
    if (body['max_output_tokens'] != null)
      'max_tokens': body['max_output_tokens'],
    if (supportsTools && tools.isNotEmpty) ...{
      'tools': [
        for (final tool in tools)
          {
            'type': 'function',
            'function': {
              'name': tool['name'],
              'description': tool['description'],
              'parameters': tool['parameters'],
            },
          },
      ],
      'tool_choice': 'auto',
    },
  };
}

Map<String, Object?> _imagePart(Map part) => {
  'type': 'image_url',
  'image_url': {'url': part['image_url']},
};

Future<Map<String, Object?>> readChatCompletionsStream(
  Stream<List<int>> bytes, {
  void Function(String)? onTextChanged,
  void Function(String)? onReasoningChanged,
  void Function()? onProcessingStarted,
  void Function(int)? onMessageStarted,
}) async {
  final text = StringBuffer(), reasoning = StringBuffer();
  final calls = <int, Map<String, Object?>>{};
  final reasoningDetails = <Map<String, Object?>>[];
  String? id, finish;
  Map? usage;
  var started = false, processing = false;
  final data = <String>[];
  void consume() {
    if (data.isEmpty) return;
    final payload = data.join('\n');
    data.clear();
    if (payload == '[DONE]') return;
    final event = jsonDecode(payload);
    if (event is! Map) {
      throw ModelProviderException(
        '模型响应格式与 Chat Completions 协议不匹配，请检查请求转换的协议设置',
        detail: payload,
      );
    }
    if (event['error'] != null) {
      throw providerResponseError(jsonEncode(event['error']));
    }
    final choices = event['choices'];
    if (choices is! List) {
      throw ModelProviderException(
        '模型响应格式与 Chat Completions 协议不匹配，请检查请求转换的协议设置',
        detail: payload,
      );
    }
    final eventId = event['id'] as String?;
    // Filter annotations carry an empty ID and are not new responses.
    if (eventId != null && eventId.isNotEmpty) id = eventId;
    usage = event['usage'] as Map? ?? usage;
    for (final choice in choices.cast<Map>()) {
      if (choice['index'] != 0) continue;
      finish = choice['finish_reason'] as String? ?? finish;
      final delta = choice['delta'] as Map?;
      // Some compatible providers send a finish-only chunk with a null delta.
      if (delta == null) {
        if (choice['finish_reason'] != null) continue;
        // DMX also emits content-filter annotations separately from text.
        if (choice.containsKey('content_filter_results') ||
            choice.containsKey('content_filter_offsets')) {
          continue;
        }
        throw ModelProviderException('模型服务返回了无效的消息片段', detail: payload);
      }
      if (!processing && delta['tool_calls'] != null) {
        processing = true;
        onProcessingStarted?.call();
      }
      final reasoningChunk =
          delta['reasoning_content'] as String? ??
          delta['reasoning'] as String? ??
          '';
      for (final detail in (delta['reasoning_details'] as List? ?? const [])) {
        reasoningDetails.add(Map<String, Object?>.from(detail as Map));
      }
      if (reasoningChunk.isNotEmpty) {
        reasoning.write(reasoningChunk);
        onReasoningChanged?.call(reasoning.toString());
      }
      final chunk = delta['content'] as String? ?? '';
      if (chunk.isNotEmpty) {
        if (!started) {
          started = true;
          onMessageStarted?.call(0);
        }
        text.write(chunk);
        onTextChanged?.call(text.toString());
      }
      for (final call
          in (delta['tool_calls'] as List? ?? const []).cast<Map>()) {
        final target = calls.putIfAbsent(
          call['index'] as int,
          () => {'id': '', 'name': '', 'arguments': ''},
        );
        final callId = call['id'] as String?;
        // Continuation chunks can carry an empty ID; retain the initial ID.
        if (callId != null && callId.isNotEmpty) target['id'] = callId;
        final function = call['function'] as Map?;
        if (function != null) {
          for (final key in ['name', 'arguments']) {
            if (function[key] != null)
              target[key] = '${target[key]}${function[key]}';
          }
        }
      }
    }
  }

  await for (final line
      in bytes
          .timeout(const Duration(seconds: 60))
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.startsWith('data:'))
      data.add(line.substring(5).trimLeft());
    else if (line.isEmpty)
      consume();
  }
  consume();
  if (finish == null || id == null) {
    throw const ModelConnectionInterrupted('模型连接已中断，回复未完成');
  }
  final completed = finish == 'stop' || finish == 'tool_calls';
  if (completed) {
    final seenIds = <String>{};
    for (final entry in calls.entries) {
      final callId = entry.value['id'] as String;
      if (callId.isEmpty || !seenIds.add(callId)) {
        throw ModelProviderException(
          '模型服务返回了无效的工具调用编号，本次工具尚未执行，请重试或更换模型',
          detail:
              'responseId=$id, toolIndex=${entry.key}, '
              'tool=${entry.value['name']}, '
              'reason=${callId.isEmpty ? 'missing_tool_call_id' : 'duplicate_tool_call_id'}',
        );
      }
    }
  }
  return {
    'id': id,
    'status': completed ? 'completed' : 'incomplete',
    if (!completed) 'incomplete_details': {'reason': finish},
    if (usage != null)
      'usage': {
        'input_tokens': usage!['prompt_tokens'],
        'output_tokens': usage!['completion_tokens'],
        'total_tokens': usage!['total_tokens'],
      },
    'output': [
      if (text.isNotEmpty ||
          reasoning.isNotEmpty ||
          reasoningDetails.isNotEmpty)
        {
          'type': 'message',
          'role': 'assistant',
          if (reasoning.isNotEmpty) 'reasoning_content': reasoning.toString(),
          if (reasoningDetails.isNotEmpty)
            'reasoning_details': reasoningDetails,
          'content': [
            if (text.isNotEmpty)
              {'type': 'output_text', 'text': text.toString()},
          ],
        },
      for (final index in calls.keys.toList()..sort())
        {
          'type': 'function_call',
          'call_id': calls[index]!['id'],
          'name': calls[index]!['name'],
          'arguments': calls[index]!['arguments'],
        },
    ],
  };
}
