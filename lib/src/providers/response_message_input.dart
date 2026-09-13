import 'dart:convert';
import 'dart:io';

import '../domain/agent_models.dart';

Future<List<List<Map<String, Object?>>>> responseMessageInput(
  List<AgentMessage> messages,
) async {
  final input = <List<Map<String, Object?>>>[];
  for (final message in messages) {
    if (message.responseInput case final items?) {
      input.add(items);
      continue;
    }
    final content = <Map<String, Object?>>[
      if (message.text.isNotEmpty) {'type': 'input_text', 'text': message.text},
    ];
    for (final image in message.images) {
      final bytes = await File(image.path).readAsBytes();
      content.add({
        'type': 'input_image',
        'image_url': 'data:${image.mimeType};base64,${base64Encode(bytes)}',
        'detail': 'auto',
      });
    }
    input.add([
      {
        'role': message.role.name,
        'content': message.images.isEmpty ? message.text : content,
      },
    ]);
  }
  return input;
}
