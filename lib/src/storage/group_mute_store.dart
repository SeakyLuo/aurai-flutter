part of 'group_chat_store.dart';

extension GroupMuteStore on GroupChatStore {
  Future<GroupMute?> groupWideMute(String groupId) async {
    final rows = await database.query(
      'conversations',
      columns: ['group_muted_until'],
      where: 'id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return GroupMute.fromStored(rows.single['group_muted_until'] as int);
  }

  Future<void> setGroupWideMute(
    String groupId, {
    required String actorId,
    required Duration? duration,
  }) => database.transaction((txn) async {
    if (duration != null && duration < Duration.zero)
      throw ArgumentError('禁言时长不能为负数');
    if (duration != null && duration > GroupMute.maxDuration)
      throw ArgumentError('限时禁言最长为 30 天');
    final actors = await txn.query(
      'conversation_members',
      columns: ['role'],
      where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
      whereArgs: [groupId, actorId],
      limit: 1,
    );
    if (actors.isEmpty ||
        !GroupMemberRole.values
            .byName(actors.single['role'] as String)
            .canManage)
      throw StateError('只有群主和群管理员可以修改禁言设置');
    await txn.update(
      'conversations',
      {
        'group_muted_until': duration == Duration.zero
            ? 0
            : duration == null
            ? -1
            : DateTime.now().add(duration).microsecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [groupId],
    );
  });

  Future<Map<String, GroupMute>> mutedMembers(String groupId) async {
    final rows = await database.query(
      'conversation_members',
      columns: [
        'sender_id',
        '${effectiveGroupMuteSql('conversation_members')} AS muted_until',
      ],
      where:
          'conversation_id = ? AND left_at IS NULL AND (${effectiveGroupMuteSql('conversation_members')} = -1 OR ${effectiveGroupMuteSql('conversation_members')} > ?)',
      whereArgs: [groupId, DateTime.now().microsecondsSinceEpoch],
      limit: GroupChatStore.pageSize,
    );
    return {
      for (final row in rows)
        row['sender_id'] as String: GroupMute.fromStored(
          row['muted_until'] as int,
        )!,
    };
  }

  Future<void> requireCanSpeak(String groupId, String senderId) async {
    final rows = await database.query(
      'conversation_members',
      columns: [
        '${effectiveGroupMuteSql('conversation_members')} AS muted_until',
      ],
      where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
      whereArgs: [groupId, senderId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('你已不在这个群聊中');
    final mute = GroupMute.fromStored(rows.single['muted_until'] as int);
    if (mute?.isActive == true) {
      throw StateError('你在这个群中处于${mute!.description}状态，不能发送消息；只有群主或管理员可以解除');
    }
  }

  Future<GroupMute?> setMemberMute(
    String groupId,
    String senderId, {
    required String actorId,
    required Duration? duration,
  }) =>
      setMembersMute(groupId, {senderId}, actorId: actorId, duration: duration);

  Future<GroupMute?> setMembersMute(
    String groupId,
    Set<String> senderIds, {
    required String actorId,
    required Duration? duration,
  }) => database.transaction((txn) async {
    if (duration != null && duration < Duration.zero) {
      throw ArgumentError('禁言时长不能为负数');
    }
    if (duration != null && duration > GroupMute.maxDuration) {
      throw ArgumentError('限时禁言最长为 30 天');
    }
    if (senderIds.isEmpty || senderIds.length > GroupChatStore.pageSize)
      throw ArgumentError('请选择群成员');
    final ids = {actorId, ...senderIds}.toList();
    final rows = await txn.query(
      'conversation_members',
      columns: ['sender_id', 'role'],
      where:
          'conversation_id = ? AND sender_id IN (${_slots(ids.length)}) AND left_at IS NULL',
      whereArgs: [groupId, ...ids],
      limit: GroupChatStore.pageSize + 1,
    );
    final actor = rows.where((r) => r['sender_id'] == actorId).firstOrNull;
    if (actor == null || rows.length != ids.length)
      throw StateError('只能管理当前群成员');
    final actorRole = GroupMemberRole.values.byName(actor['role'] as String);
    if (!actorRole.canManage) throw StateError('只有群主和群管理员可以禁言或解除禁言');
    for (final target in rows.where(
      (r) => senderIds.contains(r['sender_id']),
    )) {
      final targetRole = GroupMemberRole.values.byName(
        target['role'] as String,
      );
      if (target['sender_id'] == actorId ||
          targetRole == GroupMemberRole.owner ||
          (actorRole == GroupMemberRole.admin &&
              targetRole == GroupMemberRole.admin)) {
        throw StateError('不能禁言或解除禁言自己、群主或同级管理员');
      }
    }
    final mute = duration == Duration.zero
        ? null
        : GroupMute(
            until: duration == null ? null : DateTime.now().add(duration),
          );
    await txn.update(
      'conversation_members',
      {
        'muted_until': mute == null
            ? 0
            : mute.until?.microsecondsSinceEpoch ?? -1,
      },
      where:
          'conversation_id = ? AND sender_id IN (${_slots(senderIds.length)})',
      whereArgs: [groupId, ...senderIds],
    );
    if (mute != null) {
      await GroupSleepStore.removeMembersIn(txn, groupId, senderIds);
      await txn.delete(
        'app_state',
        where: 'key IN (${_slots(senderIds.length * 2)})',
        whereArgs: [
          for (final id in senderIds) ...[
            'group_sleep_draft:$groupId:$id',
            'group_sleep_reason:$groupId:$id',
          ],
        ],
      );
    }
    return mute;
  });

  Future<String> muteContext(String senderId) async {
    final rows = await database.query(
      'conversation_members',
      columns: [
        'conversation_id',
        '${effectiveGroupMuteSql('conversation_members')} AS muted_until',
      ],
      where:
          'sender_id = ? AND left_at IS NULL AND (${effectiveGroupMuteSql('conversation_members')} = -1 OR ${effectiveGroupMuteSql('conversation_members')} > ?)',
      whereArgs: [senderId, DateTime.now().microsecondsSinceEpoch],
      limit: GroupChatStore.pageSize,
    );
    if (rows.isEmpty) return '';
    final ids = rows.map((r) => r['conversation_id'] as String).toList();
    final groups = await database.query(
      'conversations',
      columns: ['id', 'title'],
      where: "kind = 'group' AND id IN (${_slots(ids.length)})",
      whereArgs: ids,
      limit: GroupChatStore.pageSize,
    );
    final titles = {for (final group in groups) group['id']: group['title']};
    return '【你当前的群禁言状态】\n${rows.map((row) => '群 ${jsonEncode(titles[row['conversation_id']])}（${row['conversation_id']}）：${GroupMute.fromStored(row['muted_until'] as int)!.description}').join('\n')}\n'
        '禁言只限制对应群，私聊仍可继续。不能向被禁言的群发送文字、图片、交互消息或快捷回复；不要通过其他会话、@、自动接话或定时唤醒绕过。只有群主或管理员可以解除。';
  }
}
