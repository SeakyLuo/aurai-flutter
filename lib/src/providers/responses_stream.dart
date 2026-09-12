import 'dart:convert';

import '../domain/model_provider.dart';

Future<Map<String, Object?>> readResponsesStream(
  Stream<List<int>> bytes, {
  void Function(String text)? onTextChanged,
}) async {
  final data = <String>[];
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
      case 'response.output_text.delta':
      case 'response.refusal.delta':
        final key = (
          event['output_index']! as int,
          event['content_index']! as int,
        );
        parts[key] = '${parts[key] ?? ''}${event['delta']! as String}';
        onTextChanged?.call(parts.values.join('\n'));
      case 'response.completed':
        return (event['response']! as Map).cast<String, Object?>();
      case 'response.failed':
      case 'response.incomplete':
      case 'error':
        throw ModelProviderException('模型回复未完成，请重试', detail: payload);
    }
  }
  throw const ModelProviderException('模型连接中断，回复未完成，请重试');
}
