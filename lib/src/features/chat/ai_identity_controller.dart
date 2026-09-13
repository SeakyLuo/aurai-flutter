part of 'chat_controller.dart';

extension AiIdentityController on ChatController {
  Future<void> _migrateAiSettings() async {
    final config = modelSettings.activeConfig;
    groupStore.defaultSelection = AiModelSelection(
      provider: config.service,
      model: config.model,
      baseUrl: config.baseUrl,
    );
    final rows = await _store.database.query(
      'ai_profiles',
      where: 'sender_id = ? AND preferences IS NULL',
      whereArgs: [MessageSender.aurai.id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final ai = await groupStore.loadAi(MessageSender.aurai.id);
      await groupStore.updateAi(
        ai.copyWith(
          modelSelection: AiModelSelection(
            provider: config.service,
            model: config.model,
            baseUrl: config.baseUrl,
          ),
          preferences: AiPreferences(
            systemPrompt: modelSettings.systemPrompt ?? agentSystemPrompt,
            customInstructions: modelSettings.customInstructions,
            responses: modelSettings.responsePreferences,
            screenAccess: await _platform.getScreenAccess(),
          ),
        ),
      );
    }
    await _store.database.update('ai_profiles', {
      'provider': config.service.name,
      'model': config.model,
      'base_url': config.baseUrl,
    }, where: 'provider IS NULL');
    await _store.database.update('ai_profiles', {
      'preferences': jsonEncode(const AiPreferences().toJson()),
    }, where: 'preferences IS NULL');
  }

  ModelConfig aiConfig(AiProfile ai) {
    final selection = ai.modelSelection!;
    return ModelConfig(
      service: selection.provider,
      model: selection.model,
      baseUrl: selection.baseUrl,
      apiKey: modelSettings.profile(selection.provider).apiKey,
    );
  }

  Future<MemoryController> aiMemory(AiProfile ai, {String scope = ''}) async {
    if (ai.sender.id == MessageSender.aurai.id && scope.isEmpty) {
      memory.modelConfig = () => aiConfig(ai);
      return memory;
    }
    final key = '${ai.sender.id}:$scope';
    final existing = _aiMemories[key];
    if (existing != null) {
      existing.modelConfig = () => aiConfig(ai);
      return existing;
    }
    final store = MemoryController(
      _store.database,
      () => aiConfig(ai),
      ownerId: ai.sender.id,
      scope: scope,
    );
    await store.initialize();
    _aiMemories[key] = store;
    return store;
  }

  Future<SkillStore> aiSkills(String senderId) async {
    if (senderId == MessageSender.aurai.id) return skills;
    final existing = _aiSkills[senderId];
    if (existing != null) return existing;
    final store = SkillStore(ownerId: senderId);
    await store.initialize(_store.database);
    _aiSkills[senderId] = store;
    return store;
  }

  Future<String> openAiConversation(
    AiProfile ai, {
    bool newConversation = false,
  }) async {
    final rows = await _store.database.query(
      'conversations',
      columns: ['id'],
      where:
          "kind = 'direct' AND default_sender_id = ? AND archived = 0"
          "${newConversation ? ' AND ($emptyDirectConversation)' : ''}",
      whereArgs: [ai.sender.id],
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.single['id'] as String;
    final conversation = Conversation.empty()
      ..defaultSenderId = ai.sender.id
      ..storedTitle = '新会话';
    await _store.writer.save(conversation, makeActive: false);
    _updateConversationList(conversation);
    _conversationChanged();
    return conversation.id;
  }

  Future<void> saveAi(AiProfile ai, {bool create = false}) async {
    if (create) {
      await groupStore.createAi(ai);
    } else {
      await groupStore.updateAi(ai);
    }
    if (_activeAi?.sender.id == ai.sender.id) _activeAi = ai;
    if (_groupReplies.containsKey(ai.sender.id)) {
      _groupReplies[ai.sender.id] = _groupReplyContext(ai);
      _groupSenders[ai.sender.id] = ai.sender;
    }
    final memberRun = _groupRuns[ai.sender.id];
    if (memberRun != null) memberRun.replyingSenderName = ai.sender.name;
    final histories = [
      for (final conversation in {
        ..._conversations,
        _activeConversation,
        _runningConversation,
        _privateConversation,
        ..._groupRuns.values,
      })
        if (conversation != null) conversation.messages,
      if (_groupDispatcher != null) _groupDispatcher!.history,
    ];
    for (final messages in histories) {
      for (var i = 0; i < messages.length; i++) {
        final message = messages[i];
        if (message.senderId == ai.sender.id) {
          messages[i] = message.withSender(ai.sender);
        }
        if (message.quote?.senderId == ai.sender.id) {
          message.quote!.senderName = ai.sender.name;
          messages[i] = messages[i].withSender(messages[i].sender);
        }
      }
    }
    for (final conversation in {..._conversations, _activeConversation}) {
      conversation.creationMembers = [
        for (final sender in conversation.creationMembers)
          sender.id == ai.sender.id ? ai.sender : sender,
      ];
    }
    for (final store in [memory, ..._aiMemories.values]) {
      if (store.ownerId == ai.sender.id) {
        store.modelConfig = () => aiConfig(ai);
      }
    }
    _conversationChanged();
  }
}
