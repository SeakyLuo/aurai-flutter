part of 'group_chat_store.dart';

class GroupManagementSettings {
  const GroupManagementSettings({
    required this.joinApprovalRequired,
    required this.managersOnlyRename,
  });

  final bool joinApprovalRequired;
  final bool managersOnlyRename;
}

extension GroupManagementStore on GroupChatStore {
  Future<GroupManagementSettings> managementSettings(
    String conversationId,
    String actorId,
  ) async {
    final rows = await database.query(
      'conversations',
      columns: ['join_approval_required', 'managers_only_rename'],
      where:
          "id = ? AND kind = 'group' AND EXISTS (SELECT 1 FROM conversation_members WHERE conversation_id = ? AND sender_id = ? AND left_at IS NULL)",
      whereArgs: [conversationId, conversationId, actorId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('群聊不存在或你已不在群中');
    return GroupManagementSettings(
      joinApprovalRequired: rows.single['join_approval_required'] == 1,
      managersOnlyRename: rows.single['managers_only_rename'] == 1,
    );
  }

  Future<void> updateManagementSettings(
    String conversationId, {
    required String actorId,
    bool? joinApprovalRequired,
    bool? managersOnlyRename,
  }) => database.transaction((txn) async {
    await requireOwner(txn, conversationId, actorId);
    final values = <String, Object?>{
      if (joinApprovalRequired != null)
        'join_approval_required': joinApprovalRequired ? 1 : 0,
      if (managersOnlyRename != null)
        'managers_only_rename': managersOnlyRename ? 1 : 0,
    };
    final changed = await txn.update(
      'conversations',
      values,
      where: "id = ? AND kind = 'group'",
      whereArgs: [conversationId],
    );
    if (changed != 1) throw StateError('群聊已不存在');
  });

  Future<void> requireInvitePermission(
    DatabaseExecutor db,
    String conversationId,
    String actorId,
  ) async {
    final role = await _activeRole(db, conversationId, actorId);
    if (role.canManage) return;
    final settings = await db.query(
      'conversations',
      columns: ['join_approval_required'],
      where: "id = ? AND kind = 'group'",
      whereArgs: [conversationId],
      limit: 1,
    );
    if (settings.isEmpty) throw StateError('群聊已不存在');
    if (settings.single['join_approval_required'] == 1) {
      throw StateError('进群需要群主或群管理员确认');
    }
  }

  Future<void> requireRenamePermission(
    DatabaseExecutor db,
    String conversationId,
    String actorId,
  ) async {
    final role = await _activeRole(db, conversationId, actorId);
    if (role.canManage) return;
    final settings = await db.query(
      'conversations',
      columns: ['managers_only_rename'],
      where: "id = ? AND kind = 'group'",
      whereArgs: [conversationId],
      limit: 1,
    );
    if (settings.isEmpty) throw StateError('群聊已不存在');
    if (settings.single['managers_only_rename'] == 1) {
      throw StateError('只有群主和群管理员可以修改群聊名称');
    }
  }

  Future<GroupMemberRole> _activeRole(
    DatabaseExecutor db,
    String conversationId,
    String actorId,
  ) async {
    final rows = await db.query(
      'conversation_members',
      columns: ['role'],
      where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
      whereArgs: [conversationId, actorId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('群聊不存在或你已不在群中');
    return GroupMemberRole.values.byName(rows.single['role'] as String);
  }

  Future<GroupMemberRole> memberRole(
    String conversationId,
    String senderId,
  ) async {
    final rows = await database.query(
      'conversation_members',
      columns: ['role'],
      where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
      whereArgs: [conversationId, senderId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('群聊不存在或你已不在群中');
    return GroupMemberRole.values.byName(rows.single['role'] as String);
  }

  Future<void> requireManager(
    DatabaseExecutor db,
    String conversationId,
    String actorId,
  ) async {
    final rows = await db.query(
      'conversation_members',
      columns: ['role'],
      where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
      whereArgs: [conversationId, actorId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('群聊不存在或你已不在群中');
    if (!GroupMemberRole.values
        .byName(rows.single['role'] as String)
        .canManage) {
      throw StateError('只有群主和群管理员可以进行此操作');
    }
  }

  Future<void> requireOwner(
    DatabaseExecutor db,
    String conversationId,
    String actorId,
  ) async {
    final rows = await db.query(
      'conversation_members',
      columns: ['role'],
      where:
          "conversation_id = ? AND sender_id = ? AND left_at IS NULL AND role = 'owner'",
      whereArgs: [conversationId, actorId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('只有群主可以进行此操作');
  }

  Future<void> setAdministrators(
    String conversationId,
    List<String> administratorIds, {
    String actorId = 'user:local',
  }) => database
      .transaction((txn) async {
        await requireOwner(txn, conversationId, actorId);
        if (administratorIds.length > GroupChatStore.maxAdministrators ||
            administratorIds.toSet().length != administratorIds.length ||
            administratorIds.contains(actorId)) {
          throw ArgumentError('最多可设置 3 位不同的群管理员');
        }
        if (administratorIds.isNotEmpty) {
          final rows = await txn.query(
            'conversation_members',
            columns: ['sender_id'],
            where:
                "conversation_id = ? AND left_at IS NULL AND role != 'owner' AND sender_id IN (${_slots(administratorIds.length)})",
            whereArgs: [conversationId, ...administratorIds],
          );
          if (rows.length != administratorIds.length) {
            throw StateError('只能将当前群成员设置为管理员');
          }
        }
        await txn.update(
          'conversation_members',
          {'role': GroupMemberRole.member.name},
          where: "conversation_id = ? AND role = 'admin'",
          whereArgs: [conversationId],
        );
        if (administratorIds.isNotEmpty) {
          await txn.update(
            'conversation_members',
            {'role': GroupMemberRole.admin.name},
            where:
                'conversation_id = ? AND sender_id IN (${_slots(administratorIds.length)})',
            whereArgs: [conversationId, ...administratorIds],
          );
        }
        final actor =
            (await txn.query(
                  'message_senders',
                  columns: ['name'],
                  where: 'id = ?',
                  whereArgs: [actorId],
                  limit: 1,
                )).single['name']
                as String;
        return writeGroupNotice(txn, conversationId, '$actor 更新了群管理员');
      })
      .then((notice) => _notifySystem(conversationId, notice));

  Future<void> transferOwnership(
    String conversationId,
    String nextOwnerId, {
    String actorId = 'user:local',
  }) => database
      .transaction((txn) async {
        await requireOwner(txn, conversationId, actorId);
        if (nextOwnerId == actorId) throw ArgumentError('请选择新的群主');
        final target = await txn.query(
          'message_senders',
          columns: ['name'],
          where:
              'id = ? AND id IN (SELECT sender_id FROM conversation_members WHERE conversation_id = ? AND left_at IS NULL)',
          whereArgs: [nextOwnerId, conversationId],
          limit: 1,
        );
        if (target.isEmpty) throw StateError('请选择当前群成员');
        await txn.update(
          'conversation_members',
          {'role': GroupMemberRole.member.name},
          where: 'conversation_id = ? AND sender_id = ?',
          whereArgs: [conversationId, actorId],
        );
        await txn.update(
          'conversation_members',
          {'role': GroupMemberRole.owner.name},
          where: 'conversation_id = ? AND sender_id = ?',
          whereArgs: [conversationId, nextOwnerId],
        );
        return writeGroupNotice(
          txn,
          conversationId,
          '${target.single['name']} 已成为新群主',
        );
      })
      .then((notice) => _notifySystem(conversationId, notice));

  Future<void> leaveGroup(
    String conversationId, {
    String actorId = 'user:local',
  }) => database
      .transaction((txn) async {
        final membership = await txn.query(
          'conversation_members',
          columns: ['role'],
          where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
          whereArgs: [conversationId, actorId],
          limit: 1,
        );
        if (membership.isEmpty) throw StateError('群聊不存在或你已不在群中');
        final role = GroupMemberRole.values.byName(
          membership.single['role'] as String,
        );
        if (role == GroupMemberRole.owner) {
          throw StateError('请先转让群主，或在群管理中解散群聊');
        }
        final sender = (await txn.query(
          'message_senders',
          columns: ['name'],
          where: 'id = ?',
          whereArgs: [actorId],
          limit: 1,
        )).single;
        final now = DateTime.now().microsecondsSinceEpoch;
        await txn.update(
          'conversation_members',
          {'left_at': now, 'role': GroupMemberRole.member.name},
          where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
          whereArgs: [conversationId, actorId],
        );
        await txn.update(
          'conversations',
          {'updated_at': now},
          where: 'id = ?',
          whereArgs: [conversationId],
        );
        return writeGroupNotice(txn, conversationId, '${sender['name']}退出了群聊');
      })
      .then((notice) => _notifySystem(conversationId, notice));

  Future<void> updateMembers(
    String conversationId,
    List<String> aiIds, {
    String actorId = 'user:local',
  }) => database
      .transaction((txn) async {
        await requireManager(txn, conversationId, actorId);
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
          columns: ['sender_id', 'role'],
          where: 'conversation_id = ? AND left_at IS NULL',
          whereArgs: [conversationId],
          limit: GroupChatStore.maxAiMembers + 1,
        );
        final activeIds = active
            .map((row) => row['sender_id'] as String)
            .toSet();
        final actorRole = GroupMemberRole.values.byName(
          (await txn.query(
                'conversation_members',
                columns: ['role'],
                where: 'conversation_id = ? AND sender_id = ?',
                whereArgs: [conversationId, actorId],
                limit: 1,
              )).single['role']
              as String,
        );
        if (active.any(
          (row) =>
              row['role'] == GroupMemberRole.owner.name &&
              !aiIds.contains(row['sender_id']) &&
              row['sender_id'] != MessageSender.localUser.id,
        )) {
          throw StateError('不能移除群主');
        }
        if (actorRole != GroupMemberRole.owner &&
            active.any(
              (row) =>
                  row['role'] == GroupMemberRole.admin.name &&
                  !aiIds.contains(row['sender_id']),
            )) {
          throw StateError('群管理员不能移除其他管理员');
        }
        final now = DateTime.now().microsecondsSinceEpoch;
        final batch = txn.batch();
        batch.update(
          'conversation_members',
          {'left_at': now, 'role': GroupMemberRole.member.name},
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
}
