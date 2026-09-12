import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';

Future<void> migrateConversations(
  Database database,
  String? saved,
  String imageDirectory,
) async {
  final List<Conversation> conversations;
  final String? activeId;
  if (saved == null) {
    conversations = [];
    activeId = null;
  } else {
    final json = (jsonDecode(saved) as Map).cast<String, Object?>();
    if (json['version'] == 2) {
      conversations = (json['conversations']! as List)
          .map(
            (item) => Conversation.fromJson(
              (item as Map).cast<String, Object?>(),
              imageDirectory: imageDirectory,
            ),
          )
          .toList();
      activeId = json['activeConversation']! as String;
    } else {
      conversations = [
        Conversation.fromJson(
          json,
          legacy: true,
          imageDirectory: imageDirectory,
        ),
      ];
      activeId = conversations.single.id;
    }
  }
  await database.transaction((txn) async {
    final batch = txn.batch();
    for (final conversation in conversations) {
      _importConversation(batch, conversation);
    }
    if (activeId != null) {
      batch.insert('app_state', {
        'key': 'active_conversation',
        'value': activeId,
      });
    }
    batch.insert('app_state', {'key': 'initialized', 'value': '1'});
    await batch.commit(noResult: true);
  });
}

void _importConversation(Batch batch, Conversation conversation) {
  final runByMessage = <String, String>{};
  final finals = <String>{};
  final runs = <Map<String, Object?>>[];
  final events = <Map<String, Object?>>[];
  String? userId;
  for (final message in conversation.messages) {
    if (message.role == AgentMessageRole.user) userId = message.id;
    final summary = message.taskSummary;
    if (summary == null) continue;
    final runId = 'legacy:${message.id}';
    conversation.activeRunId = runId;
    finals.add(message.id);
    for (final id in [...summary.intermediateMessageIds, message.id]) {
      runByMessage[id] = runId;
    }
    runs.add({
      'id': runId,
      'conversation_id': conversation.id,
      'user_message_id': userId,
      'status': 'completed',
      'is_task': 1,
      'elapsed_ms': summary.elapsedMilliseconds,
      'final_message_id': message.id,
    });
    var messageIndex = 0;
    for (final activity in summary.activities) {
      events.add({
        'conversation_id': conversation.id,
        'run_id': runId,
        if (activity.status == null) ...{
          'kind': 'message',
          'message_id': summary.intermediateMessageIds[messageIndex++],
        } else ...{
          'kind': 'legacy',
          'legacy_text': activity.text,
          'legacy_status': activity.status!.name,
        },
      });
    }
  }
  if (conversation.pendingGoal != null ||
      (runs.isEmpty && conversation.steps.isNotEmpty)) {
    final runId = 'legacy:${conversation.id}:active';
    conversation.activeRunId = runId;
    runs.add({
      'id': runId,
      'conversation_id': conversation.id,
      'user_message_id': userId,
      'status': conversation.runState.name,
      'error_detail': conversation.errorDetail,
    });
    for (final step in conversation.steps) {
      events.add({
        'conversation_id': conversation.id,
        'run_id': runId,
        'kind': 'legacy',
        'legacy_text': step.title,
        'legacy_status': step.status.name,
      });
    }
  }
  batch.insert('conversations', conversationRow(conversation));
  for (final run in runs) {
    batch.insert('agent_runs', run);
  }
  for (final message in conversation.messages) {
    batch.insert('messages', {
      ...messageRow(conversation.id, message),
      'run_id': runByMessage[message.id],
      'kind': finals.contains(message.id)
          ? 'final'
          : runByMessage.containsKey(message.id)
          ? 'commentary'
          : message.role.name,
    });
    for (var i = 0; i < message.images.length; i++) {
      batch.insert(
        'attachments',
        attachmentRow(
          conversation.id,
          message.images[i],
          i,
          messageId: message.id,
        ),
      );
    }
  }
  for (var i = 0; i < conversation.draftImages.length; i++) {
    batch.insert(
      'attachments',
      attachmentRow(conversation.id, conversation.draftImages[i], i),
    );
  }
  for (final event in events) {
    batch.insert('run_events', event);
  }
  if (conversation.contextSummary != null) {
    batch.insert('app_state', {
      'key': 'context_summary:${conversation.id}',
      'value': jsonEncode(conversation.contextSummary!.toJson()),
    });
  }
}
