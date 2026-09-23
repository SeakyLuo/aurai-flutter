import 'dart:convert';

import '../../domain/agent_models.dart';

/// Unsent messages stay outside history and model context until dispatched.
class PendingMessageQueue {
  final messages = <AgentMessage>[];
  bool paused = false;
  bool busy = false;
  Object? error;

  String encode() => jsonEncode({
    'paused': paused,
    'messages': messages.map((message) => message.toJson()).toList(),
  });

  PendingMessageQueue();

  PendingMessageQueue.restore(String value, String directory) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    // Restoring the app never sends a user's waiting messages without a new action.
    paused = true;
    messages.addAll([
      for (final entry in json['messages'] as List)
        AgentMessage.fromJson(
          (entry as Map).cast<String, Object?>(),
          imageDirectory: directory,
        ),
    ]);
  }
}
