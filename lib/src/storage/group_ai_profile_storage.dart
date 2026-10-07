part of 'group_chat_store.dart';

extension GroupAiProfileStorage on GroupChatStore {
  Future<({String conversationId, AgentMessage notice, String? previousName})>
  addAiFriend(
    AiProfile profile, {
    required bool create,
    required Conversation draft,
  }) => database.transaction((txn) async {
    String? previousName;
    if (create) {
      await _createAi(txn, profile, ownerId: MessageSender.localUser.id);
    } else {
      final friendship = await txn.query(
        'contact_friendships',
        columns: ['friend_id'],
        where: 'owner_id = ? AND friend_id = ?',
        whereArgs: [MessageSender.localUser.id, profile.sender.id],
        limit: 1,
      );
      if (friendship.isNotEmpty) throw StateError('已经是朋友');
      previousName = await _updateAi(txn, profile, addToMyContacts: true);
    }
    final id = await PersonalChats.open(
      txn,
      profile.sender.id,
      profile.sender.displayName,
      draft: draft,
    );
    final notice = await writeSystemNotice(
      txn,
      id,
      '你已添加了${profile.sender.displayName}，现在可以开始聊天了。',
    );
    return (conversationId: id, notice: notice, previousName: previousName);
  });

  Future<void> createAi(AiProfile profile, {String ownerId = 'user:local'}) =>
      database.transaction((txn) => _createAi(txn, profile, ownerId: ownerId));

  Future<void> _createAi(
    DatabaseExecutor txn,
    AiProfile profile, {
    required String ownerId,
  }) async {
    if (profile.sender.kind != MessageSenderKind.agent)
      throw ArgumentError('AI 配置必须属于 AI 身份');
    await txn.insert('message_senders', _senderRow(profile.sender));
    await txn.insert('ai_profiles', _profileRow(profile));
    if (!profile.isTemporary)
      await ContactRelationships.befriend(txn, ownerId, profile.sender.id);
  }

  Future<String> updateAi(AiProfile profile, {bool addToMyContacts = false}) =>
      database.transaction(
        (txn) => _updateAi(txn, profile, addToMyContacts: addToMyContacts),
      );

  Future<String> _updateAi(
    DatabaseExecutor txn,
    AiProfile profile, {
    required bool addToMyContacts,
  }) async {
    if (profile.sender.id == MessageSender.aurai.id &&
        profile.sender.archived) {
      throw StateError('内置 Aurai 不能归档');
    }
    if (profile.sender.kind != MessageSenderKind.agent)
      throw ArgumentError('AI 配置必须属于 AI 身份');
    final previousSender = (await txn.query(
      'message_senders',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [profile.sender.id],
      limit: 1,
    )).single;
    final previousName = previousSender['name'] as String;
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
    await refreshGroupNoticeName(
      txn,
      profile.sender.id,
      previousName,
      profile.sender.name,
    );
    if (addToMyContacts && !profile.isTemporary && !profile.sender.archived) {
      await ContactRelationships.befriend(
        txn,
        MessageSender.localUser.id,
        profile.sender.id,
      );
    }
    return previousName;
  }
}
