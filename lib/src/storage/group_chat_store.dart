import 'package:sqflite/sqflite.dart';

import '../domain/ai_profile.dart';
import '../domain/message_sender.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';

class GroupChatStore {
  GroupChatStore(this.database);
  final Database database;
  static const pageSize = 50;
  static const maxAiMembers = 32;

  Future<List<AiProfile>> listAi({
    int offset = 0,
    bool includeArchived = false,
  }) async {
    final rows = await database.query(
      'ai_profiles',
      where: includeArchived
          ? 'is_temporary = 0'
          : 'is_temporary = 0 AND sender_id IN (SELECT id FROM message_senders WHERE archived = 0)',
      orderBy: 'created_at DESC, sender_id DESC',
      limit: pageSize,
      offset: offset,
    );
    if (rows.isEmpty) return [];
    final ids = rows.map((row) => row['sender_id'] as String).toList();
    final senders = await _senders(database, ids);
    return [
      for (final row in rows)
        AiProfile.fromRows(senders[row['sender_id']]!, row),
    ];
  }

  Future<AiProfile> loadAi(String senderId) async {
    final rows = await Future.wait([
      database.query(
        'ai_profiles',
        where: 'sender_id = ?',
        whereArgs: [senderId],
        limit: 1,
      ),
      database.query(
        'message_senders',
        where: 'id = ?',
        whereArgs: [senderId],
        limit: 1,
      ),
    ]);
    return AiProfile.fromRows(
      MessageSender.fromRow(rows[1].single),
      rows[0].single,
    );
  }

  Future<void> createAi(AiProfile profile) => database.transaction((txn) async {
    if (profile.sender.kind != MessageSenderKind.agent)
      throw ArgumentError('AI 配置必须属于 AI 身份');
    await txn.insert('message_senders', _senderRow(profile.sender));
    await txn.insert('ai_profiles', _profileRow(profile));
  });

  Future<void> updateAi(AiProfile profile) => database.transaction((txn) async {
    if (profile.sender.kind != MessageSenderKind.agent)
      throw ArgumentError('AI 配置必须属于 AI 身份');
    final count = await txn.update(
      'ai_profiles',
      {..._profileRow(profile)..remove('created_at')},
      where: 'sender_id = ?',
      whereArgs: [profile.sender.id],
    );
    if (count != 1) throw StateError('AI 已不存在');
    await txn.update(
      'message_senders',
      _senderRow(profile.sender),
      where: 'id = ? AND kind = ?',
      whereArgs: [profile.sender.id, 'agent'],
    );
  });

  // Archive an identity rather than deleting the author of historical messages.
  Future<void> archiveAi(String senderId) => database.transaction((txn) async {
    if (senderId == MessageSender.aurai.id) throw StateError('默认助手不能归档');
    final active = await txn.query(
      'conversation_members',
      columns: ['conversation_id'],
      where: 'sender_id = ? AND left_at IS NULL',
      whereArgs: [senderId],
      limit: 1,
    );
    if (active.isNotEmpty) throw StateError('请先将 AI 移出正在参与的会话');
    await txn.update(
      'message_senders',
      {'archived': 1},
      where: "id = ? AND kind = 'agent'",
      whereArgs: [senderId],
    );
  });

  Future<void> restoreAi(String senderId) async {
    await database.update(
      'message_senders',
      {'archived': 0},
      where: "id = ? AND kind = 'agent'",
      whereArgs: [senderId],
    );
  }

  Future<Conversation> createGroup({
    required String title,
    required List<String> aiIds,
    String? defaultSenderId,
    int temporaryCount = 0,
  }) async {
    final total = aiIds.length + temporaryCount;
    if (temporaryCount < 0 || total < 1 || total > maxAiMembers) {
      throw ArgumentError('群聊需要 1–32 位 AI');
    }
    final conversation = Conversation.empty()
      ..kind = ConversationKind.group
      ..storedTitle = title;
    final temporary = [
      for (var i = 0; i < temporaryCount; i++)
        AiProfile(
          sender: MessageSender(
            id: 'agent:${conversation.id}:$i',
            name: '临时 AI ${i + 1}',
            kind: MessageSenderKind.agent,
          ),
          description: '',
          instructions: '',
          isTemporary: true,
          createdAt: conversation.createdAt,
          updatedAt: conversation.createdAt,
        ),
    ];
    final allIds = [...aiIds, ...temporary.map((ai) => ai.sender.id)];
    conversation.defaultSenderId = defaultSenderId ?? allIds.first;
    if (!allIds.contains(conversation.defaultSenderId)) {
      throw ArgumentError('默认回复者必须在成员中');
    }
    await database.transaction((txn) async {
      if (aiIds.isNotEmpty) await _validateMembers(txn, aiIds, aiIds.first);
      final profiles = txn.batch();
      for (final profile in temporary) {
        profiles.insert('message_senders', _senderRow(profile.sender));
        profiles.insert('ai_profiles', _profileRow(profile));
      }
      await profiles.commit(noResult: true);
      await txn.insert('conversations', conversationRow(conversation));
      final batch = txn.batch();
      for (final (position, senderId) in [
        MessageSender.localUser.id,
        ...allIds,
      ].indexed) {
        batch.insert('conversation_members', {
          'conversation_id': conversation.id,
          'sender_id': senderId,
          'position': position,
          'joined_at': conversation.createdAt.microsecondsSinceEpoch,
        });
      }
      await batch.commit(noResult: true);
    });
    return conversation;
  }

  Future<List<ConversationMember>> members(
    String conversationId, {
    bool includeDeparted = false,
    int offset = 0,
  }) async {
    final rows = await database.query(
      'conversation_members',
      where:
          'conversation_id = ?${includeDeparted ? '' : ' AND left_at IS NULL'}',
      whereArgs: [conversationId],
      orderBy: 'position, sender_id',
      limit: pageSize,
      offset: offset,
    );
    if (rows.isEmpty) return [];
    final senders = await _senders(
      database,
      rows.map((row) => row['sender_id'] as String).toList(),
    );
    return [
      for (final row in rows)
        ConversationMember(
          sender: senders[row['sender_id']]!,
          position: row['position'] as int,
          joinedAt: DateTime.fromMicrosecondsSinceEpoch(
            row['joined_at'] as int,
          ),
          leftAt: row['left_at'] == null
              ? null
              : DateTime.fromMicrosecondsSinceEpoch(row['left_at'] as int),
        ),
    ];
  }

  Future<void> updateMembers(
    String conversationId,
    List<String> aiIds, {
    required String defaultSenderId,
  }) => database.transaction((txn) async {
    await _validateMembers(
      txn,
      aiIds,
      defaultSenderId,
      conversationId: conversationId,
    );
    final changed = await txn.update(
      'conversations',
      {'default_sender_id': defaultSenderId},
      where: "id = ? AND kind = 'group'",
      whereArgs: [conversationId],
    );
    if (changed != 1) throw StateError('群聊已不存在');
    final active = await txn.query(
      'conversation_members',
      columns: ['sender_id'],
      where: 'conversation_id = ? AND left_at IS NULL',
      whereArgs: [conversationId],
      limit: maxAiMembers + 1,
    );
    final activeIds = active.map((row) => row['sender_id'] as String).toSet();
    final now = DateTime.now().microsecondsSinceEpoch;
    final batch = txn.batch();
    batch.update(
      'conversation_members',
      {'left_at': now},
      where:
          'conversation_id = ? AND left_at IS NULL AND sender_id NOT IN (${_slots(aiIds.length + 1)})',
      whereArgs: [conversationId, MessageSender.localUser.id, ...aiIds],
    );
    for (final (index, id) in aiIds.indexed) {
      if (activeIds.contains(id)) {
        batch.update(
          'conversation_members',
          {'position': index + 1},
          where: 'conversation_id = ? AND sender_id = ?',
          whereArgs: [conversationId, id],
        );
      } else {
        batch.rawInsert(
          '''INSERT INTO conversation_members
          (conversation_id, sender_id, position, joined_at, left_at) VALUES (?, ?, ?, ?, NULL)
          ON CONFLICT(conversation_id, sender_id) DO UPDATE SET
          position = excluded.position, joined_at = excluded.joined_at, left_at = NULL''',
          [conversationId, id, index + 1, now],
        );
      }
    }
    await batch.commit(noResult: true);
  });

  // Capture the resolved @ targets once; later roster changes do not rewrite them.
  Future<void> recordRecipients(
    String messageId,
    List<String> senderIds,
  ) => database.transaction((txn) async {
    if (senderIds.isEmpty ||
        senderIds.length > maxAiMembers ||
        senderIds.toSet().length != senderIds.length) {
      throw ArgumentError('请选择不重复的 AI 回复对象');
    }
    final messages = await txn.query(
      'messages',
      columns: ['conversation_id'],
      where: "id = ? AND role = 'user'",
      whereArgs: [messageId],
      limit: 1,
    );
    if (messages.isEmpty) throw StateError('待回复消息已不存在');
    final members = await txn.query(
      'conversation_members',
      columns: ['sender_id'],
      where:
          'conversation_id = ? AND left_at IS NULL AND sender_id IN (${_slots(senderIds.length)}) '
          'AND sender_id IN (SELECT sender_id FROM ai_profiles)',
      whereArgs: [messages.single['conversation_id'], ...senderIds],
      limit: maxAiMembers,
    );
    if (members.length != senderIds.length)
      throw StateError('回复对象必须是当前群聊的 AI 成员');
    final existing = await txn.query(
      'message_recipients',
      columns: ['sender_id'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (existing.isNotEmpty) throw StateError('这条消息的回复对象已经确定');
    final batch = txn.batch();
    for (final id in senderIds) {
      batch.insert('message_recipients', {
        'message_id': messageId,
        'sender_id': id,
      });
    }
    await batch.commit(noResult: true);
  });

  Future<List<MessageSender>> recipients(String messageId) async {
    final rows = await database.query(
      'message_senders',
      where:
          'id IN (SELECT sender_id FROM message_recipients WHERE message_id = ?)',
      whereArgs: [messageId],
      orderBy: 'id',
      limit: maxAiMembers,
    );
    return rows.map(MessageSender.fromRow).toList();
  }

  Future<void> _validateMembers(
    DatabaseExecutor db,
    List<String> aiIds,
    String defaultId, {
    String? conversationId,
  }) async {
    if (aiIds.isEmpty ||
        aiIds.length > maxAiMembers ||
        aiIds.toSet().length != aiIds.length ||
        !aiIds.contains(defaultId)) {
      throw ArgumentError('群聊需要 1–32 位不同的 AI，默认回复者必须在成员中');
    }
    final rows = await db.query(
      'ai_profiles',
      columns: ['sender_id'],
      where:
          'sender_id IN (${_slots(aiIds.length)}) AND sender_id IN '
          '(SELECT id FROM message_senders WHERE archived = 0) AND '
          '(is_temporary = 0 OR sender_id IN '
          '(SELECT sender_id FROM conversation_members WHERE conversation_id = ?))',
      whereArgs: [...aiIds, conversationId],
      limit: maxAiMembers,
    );
    if (rows.length != aiIds.length) throw StateError('选择的 AI 已归档或不存在');
  }

  Future<Map<String, MessageSender>> _senders(
    DatabaseExecutor db,
    List<String> ids,
  ) async {
    final rows = await db.query(
      'message_senders',
      where: 'id IN (${_slots(ids.length)})',
      whereArgs: ids,
    );
    return {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
  }

  Map<String, Object?> _senderRow(MessageSender sender) => {
    'id': sender.id,
    'name': sender.name,
    'kind': sender.kind.name,
    'avatar_icon': sender.avatarIcon,
    'avatar_color': sender.avatarColor,
    'avatar_path': sender.avatarPath,
    'archived': sender.archived ? 1 : 0,
  };
  Map<String, Object?> _profileRow(AiProfile profile) => {
    'sender_id': profile.sender.id,
    'description': profile.description,
    'instructions': profile.instructions,
    'is_temporary': profile.isTemporary ? 1 : 0,
    'provider': profile.modelSelection?.provider.name,
    'model': profile.modelSelection?.model,
    'base_url': profile.modelSelection?.baseUrl,
    'created_at': profile.createdAt.microsecondsSinceEpoch,
    'updated_at': profile.updatedAt.microsecondsSinceEpoch,
  };
}

String _slots(int count) => List.filled(count, '?').join(',');
