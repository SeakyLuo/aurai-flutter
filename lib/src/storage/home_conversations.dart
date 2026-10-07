import 'group_unread_messages.dart';
import 'home_task_activity.dart';
import 'conversation_visibility.dart';
import 'group_list_preview.dart';
import '../domain/message_sender.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'group_chat_store.dart';
import 'development_projects.dart';

class HomeConversations {
  HomeConversations(this.store);
  final GroupChatStore store;
  static const pageSize = 50;
  // List headers resolve their previews separately. Full error details are
  // loaded with the conversation, not transferred for every list refresh.
  static const _headerColumns = [
    'id',
    'created_at',
    'updated_at',
    'draft_updated_at',
    'title',
    'kind',
    'personal_chat',
    'mode',
    'creation_member_ids',
    'default_sender_id',
    'pinned',
    'archived',
    'scheduled_task',
    'project_id',
    'draft',
    'draft_quote_json',
    'pending_goal',
    'run_state',
    'active_run_id',
    'message_count',
  ];
  static const _groupsWhere =
      "kind = 'group' AND archived = 0 AND $visibleConversation AND $localUserConversation";

  Future<List<Conversation>> chats({
    int offset = 0,
    int limit = pageSize,
  }) async {
    final rows = await store.database.query(
      'conversations',
      columns: _headerColumns,
      where:
          "(kind = 'group' OR (kind = 'direct' AND personal_chat = 1)) AND archived = 0 AND $localUserConversation",
      orderBy:
          'pinned DESC, MAX(draft_updated_at, COALESCE((SELECT created_at FROM messages WHERE conversation_id = conversations.id AND $conversationListMessageVisibility ORDER BY created_at DESC, id DESC LIMIT 1), created_at)) DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    final items = await _headers(rows);
    await loadHomeTaskActivity(store.database, items);
    return items;
  }

  Future<List<Conversation>> recent({
    int offset = 0,
    int limit = pageSize,
  }) async {
    final rows = await store.database.query(
      'conversations',
      columns: _headerColumns,
      where:
          "kind = 'direct' AND personal_chat = 0 AND archived = 0 AND $visibleConversation AND $localUserConversation",
      orderBy: 'pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return _headers(rows);
  }

  Future<List<Conversation>> forwardTargets(String query, int offset) async {
    final rows = await store.database.query(
      'conversations',
      columns: _headerColumns,
      where: "archived = 0 AND instr(lower(title), ?) > 0",
      whereArgs: [query.toLowerCase()],
      orderBy: 'MAX(updated_at, draft_updated_at) DESC, id DESC',
      limit: 30,
      offset: offset,
    );
    return _headers(rows);
  }

  Future<int> groupCount() async {
    final rows = await store.database.query(
      'conversations',
      columns: ['COUNT(*) AS count'],
      where: _groupsWhere,
    );
    return rows.single['count'] as int;
  }

  Future<List<Conversation>> forProject(
    String projectId, {
    int offset = 0,
    int limit = pageSize,
  }) async {
    final rows = await store.database.query(
      'conversations',
      columns: _headerColumns,
      where:
          'project_id = ? AND archived = 0 AND $visibleConversation AND $localUserConversation',
      whereArgs: [projectId],
      orderBy: 'pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return _headers(rows);
  }

  Future<List<Conversation>> groups({
    Conversation? after,
    int limit = pageSize,
  }) async {
    final rows = await store.database.query(
      'conversations',
      columns: _headerColumns,
      where:
          '$_groupsWhere'
          "${after == null ? '' : ' AND (pinned < ? OR (pinned = ? AND (MAX(updated_at, draft_updated_at) < ? OR (MAX(updated_at, draft_updated_at) = ? AND id < ?))))'}",
      whereArgs: after == null
          ? null
          : [
              after.isPinned ? 1 : 0,
              after.isPinned ? 1 : 0,
              after.listUpdatedAt.microsecondsSinceEpoch,
              after.listUpdatedAt.microsecondsSinceEpoch,
              after.id,
            ],
      orderBy: 'pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC',
      limit: limit,
    );
    return _headers(rows);
  }

  Future<List<Conversation>> forAi(
    String senderId, {
    int offset = 0,
    int limit = pageSize,
  }) async {
    final rows = await store.database.query(
      'conversations',
      columns: _headerColumns,
      where:
          "kind = 'direct' AND personal_chat = 0 AND default_sender_id = ? AND archived = 0 AND $visibleConversation AND $localUserConversation",
      whereArgs: [senderId],
      orderBy: 'pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return _headers(rows);
  }

  Future<int> unreadCompletionsForAi(String senderId) async {
    final rows = await store.database.query(
      'conversations',
      columns: ['COUNT(*) AS count'],
      where:
          "kind = 'direct' AND personal_chat = 0 AND default_sender_id = ? AND archived = 0 AND $visibleConversation AND $localUserConversation AND run_state = 'idle' AND active_run_id IS NOT NULL AND pending_goal IS NULL AND NOT EXISTS (SELECT 1 FROM app_state WHERE key = 'seen_run:' || conversations.id AND value = conversations.active_run_id)",
      whereArgs: [senderId],
    );
    return rows.single['count'] as int;
  }

  Future<List<Conversation>> _headers(List<Map<String, Object?>> rows) async {
    final items = rows.map(conversationFromRow).toList();
    if (items.isEmpty) return items;
    final results = await Future.wait<Object?>([
      store.database.query(
        'app_state',
        where: 'key IN (${List.filled(items.length, '?').join(',')})',
        whereArgs: items.map((c) => 'seen_run:${c.id}').toList(),
        limit: items.length,
      ),
      loadConversationListPreviews(store.database, items),
      loadPendingQuestionPreviews(store.database, items),
      store.database.query(
        'attachments',
        columns: ['conversation_id', 'kind', 'display_name'],
        where:
            'message_id IS NULL AND conversation_id IN (${List.filled(items.length, '?').join(',')})',
        whereArgs: items.map((c) => c.id).toList(),
        orderBy: 'position',
      ),
      GroupUnreadMessages(store.database).load(items),
    ]);
    final attachments = <String, Set<String>>{};
    for (final row in results[3] as List<Map<String, Object?>>) {
      attachments
          .putIfAbsent(row['conversation_id'] as String, () => {})
          .add(row['kind'] == 'image' ? '[图片]' : '[文件] ${row['display_name']}');
    }
    for (final item in items) {
      item.storedDraftAttachmentPreview = attachments[item.id]?.join(' ');
    }
    final seen = results[0] as List<Map<String, Object?>>;
    final values = {for (final row in seen) row['key']: row['value'] as String};
    for (final item in items) {
      item.seenRunId = values['seen_run:${item.id}'];
    }
    return items;
  }

  Future<Map<String, MessageSender>> senders(List<Conversation> items) async {
    final ids = items
        .where((c) => c.kind == ConversationKind.direct)
        .map((c) => c.defaultSenderId)
        .toSet()
        .toList();
    if (ids.isEmpty) return {};
    final rows = await store.database.query(
      'message_senders',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      limit: ids.length,
    );
    return {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
  }

  Future<Map<String, DevelopmentProject>> projects(
    List<Conversation> items,
  ) async {
    final ids = items.map((item) => item.projectId).nonNulls.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await store.database.query(
      'development_projects',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      limit: ids.length,
    );
    return {
      for (final row in rows)
        row['id'] as String: DevelopmentProject.fromRow(row),
    };
  }
}
