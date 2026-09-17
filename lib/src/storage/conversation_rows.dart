import '../domain/message_quote.dart';
import 'dart:convert';
import '../domain/message_file.dart';
import 'dart:io';

import '../domain/agent_models.dart';
import '../domain/message_image.dart';
import '../features/chat/conversation.dart';

Map<String, Object?> conversationRow(Conversation value) => {
  'id': value.id,
  'created_at': value.createdAt.microsecondsSinceEpoch,
  'updated_at': value.updatedAt.microsecondsSinceEpoch,
  'title': value.title,
  'kind': value.kind.name,
  'mode': value.mode.name,
  'creation_member_ids': jsonEncode(value.creationMemberIds),
  'default_sender_id': value.defaultSenderId,
  'preview': value.preview,
  'pinned': value.isPinned ? 1 : 0,
  'archived': value.isArchived ? 1 : 0,
  'scheduled_task': value.isScheduledTask ? 1 : 0,
  'draft': value.draft,
  'draft_quote_json': value.draftQuote == null
      ? null
      : jsonEncode(value.draftQuote!.toJson()),
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
      ..isStored = true
      ..kind = ConversationKind.values.byName(row['kind'] as String)
      ..mode = ConversationMode.values.byName(row['mode'] as String)
      ..creationMemberIds = row['creation_member_ids'] == null
          ? []
          : (jsonDecode(row['creation_member_ids'] as String) as List)
                .cast<String>()
      ..defaultSenderId = row['default_sender_id'] as String
      ..storedUpdatedAt = DateTime.fromMicrosecondsSinceEpoch(
        row['updated_at']! as int,
      )
      ..storedTitle = row['title']! as String
      ..storedPreview = row['preview'] as String?
      ..isPinned = row['pinned'] == 1
      ..isArchived = row['archived'] == 1
      ..isScheduledTask = row['scheduled_task'] == 1
      ..draftQuote = row['draft_quote_json'] == null
          ? null
          : MessageQuote.fromJson(
              (jsonDecode(row['draft_quote_json'] as String) as Map)
                  .cast<String, Object?>(),
            )
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
  'interactive_json': value.interactive == null
      ? null
      : jsonEncode(value.interactive!.toJson(includeParticipants: true)),
  'quote_json': value.quote == null ? null : jsonEncode(value.quote!.toJson()),
  'role': value.role.name,
  'sender_id': value.senderId,
  'kind': value.isFailure
      ? 'message_failure'
      : value.quickReplyToId != null
      ? 'quick_reply'
      : value.isSystem
      ? 'system'
      : value.htmlGame != null
      ? 'html_game'
      : value.role == AgentMessageRole.user
      ? 'user'
      : value.isGroupMessage
      ? 'group_message'
      : value.isReasoning
      ? 'reasoning'
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
    'display_name': image.name,
    'position': position,
  };
}

MessageImage imageFromRow(Map<String, Object?> row, String directory) =>
    MessageImage(
      path: '$directory/${row['file_name']}',
      mimeType: row['mime_type']! as String,
      name: row['display_name'] as String?,
    );

Map<String, Object?> fileAttachmentRow(
  String conversationId,
  MessageFile file,
  int position, {
  String? messageId,
}) => {
  'id': '$conversationId:${file.id}',
  'conversation_id': conversationId,
  'message_id': messageId,
  'file_name': file.id,
  'mime_type': file.mimeType,
  'kind': 'file',
  'display_name': file.name,
  'byte_size': file.size,
  'position': position,
};
MessageFile fileFromRow(Map<String, Object?> row, String directory) =>
    MessageFile(
      path: '$directory/${row['file_name']}',
      name: row['display_name'] as String,
      mimeType: row['mime_type'] as String,
      size: row['byte_size'] as int,
    );
