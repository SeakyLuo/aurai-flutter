import 'dart:convert';

import '../domain/model_provider.dart';
import 'response_citations.dart';

Future<Map<String, Object?>> readResponsesStream(
  Stream<List<int>> bytes, {
  void Function(String text)? onTextChanged,
  void Function(String text)? onReasoningChanged,
  void Function()? onProcessingStarted,
  void Function(int index)? onMessageStarted,
}) async {
  final reasoningParts = <(int, String, int), String>{};
  String lastReasoning = '';
  void reportReasoning() {
    final text = reasoningParts.values.join('\n');
    if (text.isEmpty || text == lastReasoning) return;
    lastReasoning = text;
    onReasoningChanged?.call(text);
  }

  void readReasoningItem(Map item, int index) {
    if (item['type'] != 'reasoning') return;
    final content = item['content'] as List? ?? const [];
    final summary = item['summary'] as List? ?? const [];
    final source = content.isNotEmpty ? content : summary;
    final kind = content.isNotEmpty ? 'text' : 'summary';
    reasoningParts.removeWhere((key, _) => key.$1 == index);
    for (var i = 0; i < source.length; i++) {
      final part = source[i] as Map;
      if (part['type'] == 'reasoning_text' || part['type'] == 'summary_text') {
        reasoningParts[(index, kind, i)] = part['text'] as String;
      }
    }
    reportReasoning();
  }

  var processingReported = false;
  void inspectItem(Map item) {
    final type = item['type'];
    if (!processingReported &&
        ((type == 'message' && item['phase'] == 'commentary') ||
            const {
              'function_call',
              'web_search_call',
              'computer_call',
              'code_interpreter_call',
              'file_search_call',
              'mcp_call',
              'image_generation_call',
              'local_shell_call',
              'shell_call',
              'apply_patch_call',
            }.contains(type))) {
      processingReported = true;
      onProcessingStarted?.call();
    }
  }

  final data = <String>[];
  int? activeMessage;
  final parts = <(int, int), String>{};
  await for (final line
      in bytes
          .timeout(const Duration(seconds: 60))
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
      continue;
    }
    if (line.isNotEmpty || data.isEmpty) continue;
    final payload = data.join('\n');
    data.clear();
    if (payload == '[DONE]') break;
    final event = (jsonDecode(payload) as Map).cast<String, Object?>();
    switch (event['type']) {
      case 'response.reasoning_text.delta':
      case 'response.reasoning_summary_text.delta':
        final summary =
            event['type'] == 'response.reasoning_summary_text.delta';
        final key = (
          event['output_index'] as int,
          summary ? 'summary' : 'text',
          event[summary ? 'summary_index' : 'content_index'] as int,
        );
        reasoningParts[key] =
            '${reasoningParts[key] ?? ''}${event['delta'] as String}';
        reportReasoning();
      case 'response.output_item.added':
      case 'response.output_item.done':
        final item = event['item'] as Map;
        inspectItem(item);
        if (event['type'] == 'response.output_item.done') {
          readReasoningItem(item, event['output_index'] as int);
        }
        if (event['type'] == 'response.output_item.done' &&
            item['type'] == 'message') {
          final text = (item['content'] as List)
              .cast<Map>()
              .map(
                (part) => switch (part['type']) {
                  'output_text' => responseTextWithCitations(
                    part.cast<String, Object?>(),
                  ),
                  'refusal' => part['refusal'] as String,
                  _ => '',
                },
              )
              .join('\n');
          if (text.isNotEmpty) {
            activeMessage = event['output_index'] as int;
            onMessageStarted?.call(activeMessage);
            onTextChanged?.call(text);
          }
        }
      case 'response.output_text.delta':
      case 'response.refusal.delta':
        final key = (
          event['output_index']! as int,
          event['content_index']! as int,
        );
        parts[key] = '${parts[key] ?? ''}${event['delta']! as String}';
        if (activeMessage != key.$1) {
          activeMessage = key.$1;
          onMessageStarted?.call(key.$1);
        }
        onTextChanged?.call(
          parts.entries
              .where((e) => e.key.$1 == key.$1)
              .map((e) => e.value)
              .join('\n'),
        );
      case 'response.incomplete':
      case 'response.failed':
      case 'response.completed':
        final response = (event['response']! as Map).cast<String, Object?>();
        final output = response['output'] as List;
        for (var i = 0; i < output.length; i++) {
          final item = output[i] as Map;
          inspectItem(item);
          readReasoningItem(item, i);
        }
        return response;
      case 'error':
        throw ModelProviderException('模型回复未完成，请重试', detail: payload);
    }
  }
  throw const ModelProviderException('模型连接中断，回复未完成，请重试');
}
