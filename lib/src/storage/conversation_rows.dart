import 'dart:io';

import '../domain/agent_models.dart';
import '../domain/message_image.dart';
import '../features/chat/conversation.dart';

Map<String, Object?> conversationRow(Conversation value) => {
  'id': value.id,
  'created_at': value.createdAt.microsecondsSinceEpoch,
  'updated_at': value.updatedAt.microsecondsSinceEpoch,
  'title': value.title,
  'preview': value.preview,
  'pinned': value.isPinned ? 1 : 0,
  'draft': value.draft,
  'pending_goal': value.pendingGoal,
  'run_state': value.runState.name,
  'error_detail': value.errorDetail,
  'active_run_id': value.activeRunId,
  'message_count': value.messageCount,
};

Conversation conversationFromRow(Map<String, Object?> row) =>
    Conversation(
        id: row['id']! as String,
        createdAt: DateTime.fromMicrosecondsSinceEpoch(
          row['created_at']! as int,
        ),
      )
      ..storedUpdatedAt = DateTime.fromMicrosecondsSinceEpoch(
        row['updated_at']! as int,
      )
      ..storedTitle = row['title']! as String
      ..storedPreview = row['preview'] as String?
      ..isPinned = row['pinned'] == 1
      ..draft = row['draft']! as String
      ..pendingGoal = row['pending_goal'] as String?
      ..runState = ChatRunState.values.byName(row['run_state']! as String)
      ..errorDetail = row['error_detail'] as String?
      ..activeRunId = row['active_run_id'] as String?
      ..messageCount = row['message_count']! as int;

Map<String, Object?> messageRow(String conversationId, AgentMessage value) => {
  'id': value.id,
  'conversation_id': conversationId,
  'run_id': value.runId,
  'model_turn_id': value.modelTurnId,
  'role': value.role.name,
  'kind': value.role == AgentMessageRole.user
      ? 'user'
      : value.taskSummary != null
      ? 'final'
      : 'assistant',
  'text': value.text,
  'created_at': value.createdAt.microsecondsSinceEpoch,
};

Map<String, Object?> attachmentRow(
  String conversationId,
  MessageImage image,
  int position, {
  String? messageId,
}) {
  final fileName = File(image.path).uri.pathSegments.last;
  return {
    'id': '$conversationId:$fileName',
    'conversation_id': conversationId,
    'message_id': messageId,
    'file_name': fileName,
    'mime_type': image.mimeType,
    'position': position,
  };
}

MessageImage imageFromRow(Map<String, Object?> row, String directory) =>
    MessageImage(
      path: '$directory/${row['file_name']}',
      mimeType: row['mime_type']! as String,
    );
