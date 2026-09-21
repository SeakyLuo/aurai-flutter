import 'dart:convert';
import 'dart:developer' as developer;
import 'contact_relationships.dart';
import '../domain/agent_models.dart';
import 'group_system_notice.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/ai_profile.dart';
import '../domain/message_sender.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';

class GroupChatStore {
  GroupChatStore(this.database);
  final Database database;
  Future<void> Function(String groupId, AgentMessage notice)? onSystemNotice;

  Future<void> _notifySystem(String id, AgentMessage? notice) async {
    if (notice == null) return;
    // Membership and its notice have committed; delivery failure cannot undo them.
    try {
      await onSystemNotice?.call(id, notice);
    } on Object catch (error, stack) {
      developer.log(
        'Committed group notice delivery failed',
        name: 'aurai.group',
        error: error,
        stackTrace: stack,
      );
    }
  }

  late AiModelSelection defaultSelection;
  static const pageSize = 50;
  static const maxAiMembers = 32;

  Future<Map<String, List<MessageSender>>> avatarMembers(
    List<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return {};
    final rows = await database.rawQuery('''
      SELECT conversation_id, sender_id FROM (
        SELECT conversation_id, sender_id,
          ROW_NUMBER() OVER (PARTITION BY conversation_id ORDER BY position, sender_id) AS member_rank
        FROM conversation_members
        WHERE conversation_id IN (${_slots(groupIds.length)}) AND left_at IS NULL
      ) WHERE member_rank <= 9 ORDER BY conversation_id, member_rank
    ''', groupIds);
    if (rows.isEmpty) return {};
    final senders = await _senders(
      database,
      rows.map((row) => row['sender_id'] as String).toSet().toList(),
    );
    final result = <String, List<MessageSender>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row['conversation_id'] as String, () => [])
          .add(senders[row['sender_id']]!);
    }
    return result;
  }

  Future<int> contactCount(String query, {required bool archived}) async {
    final rows = await database.query(
      'ai_profiles',
      columns: ['COUNT(*) AS count'],
      where:
          'sender_id IN (SELECT friend_id FROM contact_friendships WHERE owner_id = ?) AND sender_id IN (SELECT id FROM message_senders WHERE archived = ? AND instr(lower(name), ?) > 0)',
      whereArgs: ['user:local', archived ? 1 : 0, query.toLowerCase()],
    );
    return rows.single['count'] as int;
  }

  Future<List<AiProfile>> contacts(
    String query, {
    required bool archived,
    int offset = 0,
    String ownerId = 'user:local',
  }) async {
    final rows = await database.query(
      'ai_profiles',
      where:
          'sender_id IN (SELECT friend_id FROM contact_friendships WHERE owner_id = ?) AND sender_id IN (SELECT id FROM message_senders WHERE archived = ? AND instr(lower(name), ?) > 0)',
      whereArgs: [ownerId, archived ? 1 : 0, query.toLowerCase()],
      orderBy: 'created_at DESC, sender_id DESC',
      limit: pageSize,
      offset: offset,
    );
    if (rows.isEmpty) return [];
    final senders = await _senders(
      database,
      rows.map((r) => r['sender_id'] as String).toList(),
    );
    return [
      for (final row in rows)
        AiProfile.fromRows(senders[row['sender_id']]!, row),
    ];
  }

  Future<List<Map<String, Object?>>> aiGroups(
    String senderId, {
    bool joined = true,
    int offset = 0,
  }) => database.query(
    'conversations',
    columns: ['id', 'title'],
    where:
        "kind = 'group' AND archived = 0 AND id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = 'user:local' AND left_at IS NULL) AND id ${joined ? 'IN' : 'NOT IN'} (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL)",
    whereArgs: [senderId],
    orderBy: 'updated_at DESC, id DESC',
    limit: pageSize,
    offset: offset,
  );

  Future<void> addAiToGroup(String senderId, String conversationId) =>
      inviteMembers(conversationId, [senderId]);

  Future<void> removeMembers(
    String conversationId,
    List<String> ids,
  ) => database
      .transaction((txn) async {
        if (ids.isEmpty ||
            ids.length > maxAiMembers ||
            ids.contains(MessageSender.localUser.id)) {
          throw ArgumentError('请选择要移除的 AI');
        }
        final members = await txn.query(
          'conversation_members',
          columns: ['sender_id'],
          where: 'conversation_id = ? AND left_at IS NULL AND sender_id != ?',
          whereArgs: [conversationId, MessageSender.localUser.id],
          limit: maxAiMembers,
        );
        if (members.every((row) => ids.contains(row['sender_id']))) {
          throw StateError('群聊至少保留一位 AI');
        }
        final now = DateTime.now().microsecondsSinceEpoch;
        final changed = await txn.update(
          'conversations',
          {'updated_at': now},
          where: "id = ? AND kind = 'group'",
          whereArgs: [conversationId],
        );
        if (changed != 1) throw StateError('群聊已不存在');
        await txn.update(
          'conversation_members',
          {'left_at': now},
          where:
              'conversation_id = ? AND left_at IS NULL AND sender_id IN (${_slots(ids.length)})',
          whereArgs: [conversationId, ...ids],
        );
        return writeGroupMemberNotice(txn, conversationId, [], [
          for (final row in members)
            if (ids.contains(row['sender_id'])) row['sender_id'] as String,
        ]);
      })
      .then((notice) => _notifySystem(conversationId, notice));

  Future<void> inviteMembers(
    String conversationId,
    List<String> existingIds, {
    List<AiProfile> newMembers = const [],
  }) => database
      .transaction((txn) async {
        if (existingIds.isNotEmpty) await _validateMembers(txn, existingIds);
        final ids = [...existingIds, ...newMembers.map((ai) => ai.sender.id)];
        if (ids.isEmpty ||
            ids.length > maxAiMembers ||
            ids.toSet().length != ids.length) {
          throw ArgumentError('请选择 1–32 位不同的 AI');
        }
        final profiles = txn.batch();
        for (final ai in newMembers) {
          profiles.insert('message_senders', _senderRow(ai.sender));
          profiles.insert(
            'ai_profiles',
            _profileRow(ai.copyWith(isTemporary: true)),
          );
        }
        await profiles.commit(noResult: true);
        final current = await txn.query(
          'conversation_members',
          columns: ['sender_id', 'position'],
          where: 'conversation_id = ? AND left_at IS NULL',
          whereArgs: [conversationId],
          limit: maxAiMembers + 1,
        );
        final activeIds = current
            .map((row) => row['sender_id'] as String)
            .toSet();
        final added = ids.where((id) => !activeIds.contains(id)).toList();
        if (activeIds.length - 1 + added.length > maxAiMembers) {
          throw StateError('群聊最多可加入 32 位 AI');
        }
        final now = DateTime.now().microsecondsSinceEpoch;
        final changed = await txn.update(
          'conversations',
          {'updated_at': now},
          where: "id = ? AND kind = 'group'",
          whereArgs: [conversationId],
        );
        if (changed != 1) throw StateError('群聊已不存在');
        final position = current.fold<int>(
          0,
          (value, row) =>
              (row['position'] as int) > value ? row['position'] as int : value,
        );
        final batch = txn.batch();
        for (final (index, id) in added.indexed) {
          batch.rawInsert(
            '''INSERT INTO conversation_members
            (conversation_id, sender_id, position, joined_at, left_at)
            VALUES (?, ?, ?, ?, NULL)
            ON CONFLICT(conversation_id, sender_id) DO UPDATE SET
            position = excluded.position, joined_at = excluded.joined_at, left_at = NULL''',
            [conversationId, id, position + index + 1, now],
          );
        }
        await batch.commit(noResult: true);
        return writeGroupMemberNotice(txn, conversationId, added, []);
      })
      .then((notice) => _notifySystem(conversationId, notice));

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

  Future<List<AiProfile>> selectedContacts(List<String> ids) async {
    if (ids.isEmpty) return [];
    if (ids.length > maxAiMembers) throw ArgumentError('群成员过多');
    final rows = await database.query(
      'ai_profiles',
      where:
          'sender_id IN (${_slots(ids.length)}) AND is_temporary = 0 AND sender_id IN (SELECT id FROM message_senders WHERE archived = 0)',
      whereArgs: ids,
      limit: maxAiMembers,
    );
    if (rows.isEmpty) return [];
    final senders = await _senders(
      database,
      rows.map((row) => row['sender_id'] as String).toList(),
    );
    final profiles = {
      for (final row in rows)
        row['sender_id']: AiProfile.fromRows(senders[row['sender_id']]!, row),
    };
    return [
      for (final id in ids)
        if (profiles.containsKey(id)) profiles[id]!,
    ];
  }

  Future<List<AiProfile>> groupProfiles(String conversationId) async {
    final results = await Future.wait([
      database.query(
        'ai_profiles',
        where:
            'sender_id IN (SELECT sender_id FROM conversation_members WHERE conversation_id = ? AND left_at IS NULL)',
        whereArgs: [conversationId],
        limit: maxAiMembers,
      ),
      database.query(
        'message_senders',
        where:
            "kind = 'agent' AND id IN (SELECT sender_id FROM conversation_members WHERE conversation_id = ? AND left_at IS NULL)",
        whereArgs: [conversationId],
        limit: maxAiMembers,
      ),
    ]);
    final senders = {
      for (final row in results[1]) row['id']: MessageSender.fromRow(row),
    };
    return [
      for (final row in results[0])
        AiProfile.fromRows(senders[row['sender_id']]!, row),
    ];
  }

  Future<List<AiProfile>> replyProfiles(String messageId) async {
    final results = await Future.wait([
      database.query(
        'ai_profiles',
        where:
            'sender_id IN (SELECT sender_id FROM message_recipients WHERE message_id = ?)',
        whereArgs: [messageId],
        limit: maxAiMembers,
      ),
      database.query(
        'message_senders',
        where:
            'id IN (SELECT sender_id FROM message_recipients WHERE message_id = ?)',
        whereArgs: [messageId],
        limit: maxAiMembers,
      ),
      database.query(
        'conversation_members',
        columns: ['sender_id'],
        where:
            'conversation_id = (SELECT conversation_id FROM messages WHERE id = ?) '
            'AND sender_id IN (SELECT sender_id FROM message_recipients WHERE message_id = ?)',
        whereArgs: [messageId, messageId],
        orderBy: 'position, sender_id',
        limit: maxAiMembers,
      ),
    ]);
    final profiles = {for (final row in results[0]) row['sender_id']: row};
    final senders = {
      for (final row in results[1]) row['id']: MessageSender.fromRow(row),
    };
    return [
      for (final row in results[2])
        AiProfile.fromRows(
          senders[row['sender_id']]!,
          profiles[row['sender_id']]!,
        ),
    ];
  }

  Future<Set<String>> completedReplySenders(String messageId) async {
    final rows = await database.query(
      'agent_runs',
      columns: ['sender_id'],
      distinct: true,
      where: "user_message_id = ? AND status = 'completed'",
      whereArgs: [messageId],
      limit: maxAiMembers,
    );
    return rows.map((row) => row['sender_id'] as String).toSet();
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

  Future<void> createAi(AiProfile profile, {String ownerId = 'user:local'}) =>
      database.transaction((txn) async {
        if (profile.sender.kind != MessageSenderKind.agent)
          throw ArgumentError('AI 配置必须属于 AI 身份');
        await txn.insert('message_senders', _senderRow(profile.sender));
        await txn.insert('ai_profiles', _profileRow(profile));
        if (!profile.isTemporary)
          await ContactRelationships.befriend(txn, ownerId, profile.sender.id);
      });

  Future<void> updateAi(
    AiProfile profile, {
    bool addToMyContacts = false,
  }) => database.transaction((txn) async {
    if (profile.sender.id == MessageSender.aurai.id &&
        profile.sender.archived) {
      throw StateError('内置 Aurai 不能归档');
    }
    if (profile.sender.kind != MessageSenderKind.agent)
      throw ArgumentError('AI 配置必须属于 AI 身份');
    final count = await txn.update(
      'ai_profiles',
      {..._profileRow(profile)..remove('created_at')},
      where: 'sender_id = ? AND updated_at = ?',
      whereArgs: [
        profile.sender.id,
        (profile.previousUpdatedAt ?? profile.updatedAt).microsecondsSinceEpoch,
      ],
    );
    if (count != 1) throw StateError('AI 资料已变化，请重新打开后修改');
    await txn.update(
      'message_senders',
      _senderRow(profile.sender),
      where: 'id = ? AND kind = ?',
      whereArgs: [profile.sender.id, 'agent'],
    );
    if (addToMyContacts && !profile.isTemporary && !profile.sender.archived) {
      await ContactRelationships.befriend(
        txn,
        MessageSender.localUser.id,
        profile.sender.id,
      );
    }
  });

  // Archive an identity rather than deleting the author of historical messages.
  Future<void> archiveAi(String senderId) => database.transaction((txn) async {
    if (senderId == MessageSender.aurai.id) {
      throw StateError('内置 Aurai 不能归档');
    }
    await txn.update(
      'message_senders',
      {'archived': 1},
      where: "id = ? AND kind = 'agent'",
      whereArgs: [senderId],
    );
    await txn.update(
      'ai_profiles',
      {'updated_at': DateTime.now().microsecondsSinceEpoch},
      where: 'sender_id = ?',
      whereArgs: [senderId],
    );
  });

  Future<void> restoreAi(String senderId) => database.transaction((txn) async {
    await txn.update(
      'message_senders',
      {'archived': 0},
      where: "id = ? AND kind = 'agent'",
      whereArgs: [senderId],
    );
    await txn.update(
      'ai_profiles',
      {'updated_at': DateTime.now().microsecondsSinceEpoch},
      where: 'sender_id = ?',
      whereArgs: [senderId],
    );
  });

  Future<Conversation> createGroup({
    String title = '',
    required List<String> aiIds,
    int temporaryCount = 0,
    List<AiProfile> newMembers = const [],
  }) async {
    final total = aiIds.length + temporaryCount + newMembers.length;
    if (temporaryCount < 0 || total < 1 || total > maxAiMembers) {
      throw ArgumentError('群聊需要 1–32 位 AI');
    }
    final conversation = Conversation.empty()
      ..kind = ConversationKind.group
      ..storedTitle = title;
    final temporary = [
      for (final member in newMembers) member.copyWith(isTemporary: true),
      for (var i = 0; i < temporaryCount; i++)
        AiProfile(
          sender: MessageSender(
            id: 'agent:${conversation.id}:$i',
            name: '临时 AI ${i + 1}',
            kind: MessageSenderKind.agent,
          ),
          modelSelection: defaultSelection,
          description: '',
          instructions: '',
          isTemporary: true,
          createdAt: conversation.createdAt,
          updatedAt: conversation.createdAt,
        ),
    ];
    final allIds = [...aiIds, ...temporary.map((ai) => ai.sender.id)];
    await database.transaction((txn) async {
      if (aiIds.isNotEmpty) await _validateMembers(txn, aiIds);
      final profiles = txn.batch();
      for (final profile in temporary) {
        profiles.insert('message_senders', _senderRow(profile.sender));
        profiles.insert('ai_profiles', _profileRow(profile));
      }
      await profiles.commit(noResult: true);
      final memberIds = [MessageSender.localUser.id, ...allIds];
      final senders = await _senders(txn, memberIds);
      if (title.isEmpty) {
        conversation.storedTitle = memberIds
            .map((id) => senders[id]!.name)
            .join('、');
      }
      conversation.creationUserName = senders[MessageSender.localUser.id]!.name;
      conversation.creationMemberIds = allIds;
      conversation.creationMembers = [for (final id in allIds) senders[id]!];
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
      final notice = await writeGroupNotice(
        txn,
        conversation.id,
        conversation.creationMessage!,
        id: 'group-created:${conversation.id}',
      );
      conversation.messages.add(notice);
      conversation.messageCount++;
    });
    await _notifySystem(conversation.id, conversation.messages.single);
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
    List<String> aiIds,
  ) => database
      .transaction((txn) async {
        await _validateMembers(txn, aiIds, conversationId: conversationId);
        final changed = await txn.update(
          'conversations',
          {'updated_at': DateTime.now().microsecondsSinceEpoch},
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
        final activeIds = active
            .map((row) => row['sender_id'] as String)
            .toSet();
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
        return writeGroupMemberNotice(
          txn,
          conversationId,
          aiIds.where((id) => !activeIds.contains(id)).toList(),
          activeIds
              .where(
                (id) => id != MessageSender.localUser.id && !aiIds.contains(id),
              )
              .toList(),
        );
      })
      .then((notice) => _notifySystem(conversationId, notice));

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
    List<String> aiIds, {
    String? conversationId,
  }) async {
    if (aiIds.isEmpty ||
        aiIds.length > maxAiMembers ||
        aiIds.toSet().length != aiIds.length) {
      throw ArgumentError('群聊需要 1–32 位不同的 AI');
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
    'preferences': jsonEncode(profile.preferences.toJson()),
    'is_temporary': profile.isTemporary ? 1 : 0,
    'provider': profile.modelSelection?.provider.name,
    'model': profile.modelSelection?.model,
    'base_url': profile.modelSelection?.baseUrl,
    'created_at': profile.createdAt.microsecondsSinceEpoch,
    'updated_at': profile.updatedAt.microsecondsSinceEpoch,
  };
}

String _slots(int count) => List.filled(count, '?').join(',');
