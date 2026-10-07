part of 'chat_controller.dart';

extension AiIdentityController on ChatController {
  Future<void> setContactRemark(String senderId, String value) async {
    await ContactStore(_store.database).setRemark(senderId, value);
    final ai = await groupStore.loadAi(senderId);
    for (final conversation in {
      ..._conversations,
      _activeConversation,
      _pendingAiConversation,
      ..._personalChatDrafts.values,
      ..._executions.sessions.values.map((state) => state.conversation),
    }.nonNulls) {
      if (conversation.isPersonalChat &&
          conversation.defaultSenderId == senderId) {
        conversation.storedTitle = ai.sender.displayName;
      }
    }
    contactsChanged.value = ai;
    _conversationChanged();
  }

  Future<List<Conversation>> personalChatDrafts() async {
    final drafts = await _newDraftStore.personalChats(_imageStore.directory);
    _personalChatDrafts
      ..clear()
      ..addEntries(
        drafts.map(
          (draft) => MapEntry(
            draft.id,
            draft.id == activeConversation.id ? activeConversation : draft,
          ),
        ),
      );
    return _personalChatDrafts.values
        .where((draft) => !draft.isStored && !draft.isArchived)
        .toList();
  }

  void _onLocalProfileChanged() {
    final sender = MessageSender.localUser;
    final name = sender.name;
    _renameLoadedGroupNotices(MessageSender.localUser.id, _lastLocalName, name);
    final conversations = {
      ..._conversations,
      _activeConversation,
      _runningConversation,
      _privateConversation,
      ..._groupRuns.values,
    };
    final histories = [
      for (final conversation in conversations)
        if (conversation != null) ...[
          conversation.messages,
          if (conversation.searchMessages != null) conversation.searchMessages!,
        ],
      if (_groupDispatcher != null) _groupDispatcher!.history,
    ];
    for (final messages in histories) {
      for (var i = 0; i < messages.length; i++) {
        var message = messages[i];
        if (message.senderId == sender.id && message.sender != null) {
          message = message.withSender(sender);
        }
        if (message.quote?.senderId == sender.id) {
          message.quote!.senderName = name;
        }
        if (message.quickReplies.any((reply) => reply.senderId == sender.id)) {
          message = message.withQuickReplies([
            for (final reply in message.quickReplies)
              reply.senderId == sender.id
                  ? MessageQuickReply(
                      id: reply.id,
                      senderId: reply.senderId,
                      senderName: name,
                      key: reply.key,
                      createdAt: reply.createdAt,
                    )
                  : reply,
          ]);
        }
        messages[i] = message;
      }
    }
    for (final conversation in conversations) {
      if (conversation == null) continue;
      conversation.creationUserName = name;
      conversation.creationMembers = [
        for (final member in conversation.creationMembers)
          member.id == sender.id ? sender : member,
      ];
      if (conversation.draftQuote?.senderId == sender.id) {
        conversation.draftQuote!.senderName = name;
      }
    }
    _lastLocalName = name;
    _conversationChanged();
  }

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
      details: modelSettings.profile(selection.provider).details,
      model: selection.model,
      baseUrl: modelSettings.profile(selection.provider).baseUrl,
      apiKey: modelSettings.profile(selection.provider).apiKey,
      reasoning: ai.preferences.reasoning == ModelReasoning.inherit
          ? modelSettings
                .profile(selection.provider)
                .reasoningFor(selection.model)
          : ai.preferences.reasoning,
    );
  }

  Future<MemoryController> aiMemory(AiProfile ai, {String scope = ''}) async {
    if (ai.sender.id == MessageSender.aurai.id && scope.isEmpty) {
      memory.modelConfig = () => modelSettings.activeConfig;
      return memory;
    }
    final key = '${ai.sender.id}:$scope';
    final existing = _aiMemories[key];
    if (existing != null) {
      existing.modelConfig = () => modelSettings.activeConfig;
      return existing;
    }
    final store = MemoryController(
      _store.database,
      () => modelSettings.activeConfig,
      ownerId: ai.sender.id,
      scope: scope,
    );
    await store.initialize();
    _aiMemories[key] = store;
    return store;
  }

  Future<MemoryController> projectMemory(
    DevelopmentProject project, {
    AiProfile? profile,
  }) async {
    final key = 'project-shared:${project.id}';
    final existing = _aiMemories[key];
    if (existing != null) {
      existing.modelConfig = () => modelSettings.activeConfig;
      return existing;
    }
    final store = MemoryController(
      _store.database,
      () => modelSettings.activeConfig,
      ownerId: 'project:${project.id}',
    );
    await store.initialize();
    _aiMemories[key] = store;
    return store;
  }

  Future<
    ({
      DevelopmentProject? project,
      MemoryController memory,
      MemoryController? privateMemory,
    })
  >
  _conversationMemory(
    Conversation conversation,
    AiProfile profile, {
    required String privateScope,
  }) async {
    if (DevelopmentProjects.changingWorktrees.contains(
      conversation.projectId,
    )) {
      throw StateError('正在管理项目工作树，请稍后再发送');
    }
    final project = conversation.projectId == null
        ? null
        : await DevelopmentProjects(
            _store.database,
          ).readWorkspace(conversation.projectId!);
    final ownMemory = await aiMemory(
      profile,
      scope: project == null ? privateScope : 'project:${project.id}',
    );
    return (
      project: project,
      privateMemory: project == null ? null : await projectMemory(project),
      memory: ownMemory,
    );
  }

  String _projectContext(DevelopmentProject project) => [
    '本项目可访问多个工作目录，同一轮可以跨目录读取和修改。命令与 Git 操作必须明确指定目标目录；不同仓库的分支和提交独立。',
    for (final directory in project.directories)
      '目录“${directory.name}”：${directory.uri}${directory.worktree ? '（Git 工作树）' : ''}',
    if (project.directories.isEmpty) '项目尚未关联目录，请用户从项目菜单添加目录。',
    '当前会话属于开发项目“${project.name}”。项目工作目录已经授权，可通过文件工具直接读取和修改；文件操作限于上面列出的目录。',
    if (project.description.isNotEmpty) '项目介绍：${project.description}',
    if (project.instructions.isNotEmpty) '项目自定义指令：\n${project.instructions}',
  ].join('\n');

  void requireProjectIdle(String projectId) {
    if ({_execution, ..._executions.sessions.values}.any(
      (state) =>
          state.conversation?.projectId == projectId &&
          (state.runningConversation != null ||
              state.privateConversation != null ||
              state.submitting),
    )) {
      throw StateError('项目中还有正在运行的任务，请完成或停止后再操作工作树');
    }
  }

  Future<AiDocumentScope> _aiDocuments(
    String senderId,
    DevelopmentProject? project,
  ) async {
    final documents = AiDocumentScope(
      _store.database,
      senderId,
      project: project,
    );
    await documents.initialize();
    return documents;
  }

  Future<void> _saveRunContextSummary(
    Conversation conversation,
    ContextSummary summary,
    int historyVersion, {
    String? senderId,
  }) async {
    await _store.writer.saveContextSummary(
      conversation.id,
      summary,
      historyVersion: historyVersion,
      senderId: senderId,
    );
    if (_store.writer.historyVersion(conversation.id) != historyVersion) return;
    if (senderId == null) {
      conversation.contextSummary = summary;
    } else {
      conversation.privateContextSummaries[senderId] = summary;
    }
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
    bool freshDraft = false,
    ConversationMode mode = ConversationMode.normal,
  }) async {
    if (freshDraft || mode != ConversationMode.normal) {
      final conversation = Conversation.empty()
        ..defaultSenderId = ai.sender.id
        ..mode = mode;
      _pendingAiConversation = conversation;
      return conversation.id;
    }
    if (!newConversation) {
      final rows = await _store.database.query(
        'conversations',
        columns: ['id'],
        where: 'personal_chat = 1 AND default_sender_id = ?',
        whereArgs: [ai.sender.id],
      );
      if (rows.isEmpty) {
        final draft = await _newDraftStore.load(
          _imageStore.directory,
          senderId: ai.sender.id,
          personalChat: true,
        );
        draft.storedTitle = ai.sender.displayName;
        _pendingAiConversation = draft;
        return draft.id;
      }
      final id = rows.single['id'] as String;
      await _store.database.update(
        'conversations',
        {'archived': 0, 'title': ai.sender.displayName},
        where: 'id = ?',
        whereArgs: [id],
      );
      for (final conversation in {
        ..._conversations,
        _activeConversation,
        ..._executions.sessions.values.map((state) => state.conversation),
      }) {
        if (conversation?.id == id) {
          conversation!.storedTitle = ai.sender.displayName;
          conversation.isArchived = false;
        }
      }
      return id;
    }
    final rows = await _store.database.query(
      'conversations',
      columns: ['id'],
      where:
          "kind = 'direct' AND personal_chat = 0 AND mode = 'normal' AND default_sender_id = ? AND archived = 0 AND $localUserConversation"
          "${newConversation ? ' AND ($emptyDirectConversation)' : ''}",
      whereArgs: [ai.sender.id],
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.single['id'] as String;
    var conversation = await _newDraftStore.load(
      _imageStore.directory,
      senderId: ai.sender.id,
    );
    if (await _store.hasMessages(conversation.id)) {
      await _newDraftStore.clear(senderId: ai.sender.id);
      conversation = Conversation.empty()..defaultSenderId = ai.sender.id;
    }
    _pendingAiConversation = conversation;
    return conversation.id;
  }

  Future<void> addAiFriend(
    AiProfile ai, {
    bool create = false,
    bool notifyFriend = true,
  }) async {
    final savedDraft = await _newDraftStore.load(
      _imageStore.directory,
      senderId: ai.sender.id,
      personalChat: true,
    );
    final draft =
        _viewConversation.isPersonalChat &&
            _viewConversation.defaultSenderId == ai.sender.id &&
            !_viewConversation.isStored
        ? _viewConversation
        : savedDraft;
    await _store.writer.flush();
    final result = await groupStore.addAiFriend(
      ai,
      create: create,
      draft: draft,
    );
    final target = result.conversationId == draft.id
        ? draft
        : await _forwardTarget(result.conversationId);
    target.isStored = true;
    target.isArchived = false;
    target.storedTitle = ai.sender.displayName;
    if (!target.messages.any((message) => message.id == result.notice.id)) {
      target.messages.add(result.notice);
      target.messageCount++;
    }
    _store.writer.remember([result.notice]);
    await _store.writer.save(target, makeActive: false, saveDraft: true);
    await _newDraftStore.clear(senderId: ai.sender.id, personalChat: true);
    _personalChatDrafts.remove(draft.id);
    _updateConversationList(target);
    _applySavedAi(ai, previousName: result.previousName);
    if (notifyFriend) {
      unawaited(
        _inConversation(target, () async {
          _execution.queuedUserMessageId = result.notice.id;
          _resumeForwardedReply();
        }),
      );
    }
  }

  Future<void> saveAi(
    AiProfile ai, {
    bool create = false,
    bool addToMyContacts = false,
  }) async {
    String? previousName;
    if (create) {
      await groupStore.createAi(ai);
    } else {
      previousName = await groupStore.updateAi(
        ai,
        addToMyContacts: addToMyContacts,
      );
    }
    await _store.database.update(
      'conversations',
      {'title': ai.sender.displayName},
      where: 'personal_chat = 1 AND default_sender_id = ?',
      whereArgs: [ai.sender.id],
    );
    _applySavedAi(ai, previousName: previousName);
  }

  void _applySavedAi(AiProfile ai, {String? previousName}) {
    if (previousName != null) {
      _renameLoadedGroupNotices(ai.sender.id, previousName, ai.sender.name);
    }
    if (_activeAi?.sender.id == ai.sender.id) _activeAi = ai;
    for (final state in {_execution, ..._executions.sessions.values}) {
      if (state.groupReplies.containsKey(ai.sender.id)) {
        state.groupReplies[ai.sender.id] = _groupReplyContext(ai);
        state.groupSenders[ai.sender.id] = ai.sender;
      }
      final memberRun = state.groupRuns[ai.sender.id];
      if (memberRun != null) memberRun.replyingSenderName = ai.sender.name;
    }
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
      if (conversation.isPersonalChat &&
          conversation.defaultSenderId == ai.sender.id) {
        conversation.storedTitle = ai.sender.displayName;
      }
      conversation.creationMembers = [
        for (final sender in conversation.creationMembers)
          sender.id == ai.sender.id ? ai.sender : sender,
      ];
    }
    for (final store in [memory, ..._aiMemories.values]) {
      if (store.ownerId == ai.sender.id) {
        store.modelConfig = () => modelSettings.activeConfig;
      }
    }
    contactsChanged.value = ai;
    _conversationChanged();
  }

  void _renameLoadedGroupNotices(
    String senderId,
    String previousName,
    String nextName,
  ) {
    if (previousName == nextName) return;
    for (final conversation in {
      ..._conversations,
      _activeConversation,
      _runningConversation,
      _privateConversation,
      ..._groupRuns.values,
    }) {
      if (conversation == null || conversation.kind != ConversationKind.group) {
        continue;
      }
      if (conversation.storedPreviewIsSystem &&
          conversation.storedPreview != null) {
        conversation.storedPreview = conversation.storedPreview!.replaceAll(
          previousName,
          nextName,
        );
      }
      if (!conversation.noticeMembers.containsKey(senderId)) continue;
      final sender = conversation.noticeMembers[senderId]!;
      conversation.noticeMembers[senderId] = MessageSender(
        id: sender.id,
        name: nextName,
        kind: sender.kind,
        avatarIcon: sender.avatarIcon,
        avatarColor: sender.avatarColor,
        avatarPath: sender.avatarPath,
        archived: sender.archived,
      );
      void rename(List<AgentMessage> messages) {
        for (var i = 0; i < messages.length; i++) {
          final message = messages[i];
          if (message.isSystem && message.text.contains(previousName)) {
            messages[i] = message.withText(
              message.text.replaceAll(previousName, nextName),
            );
          }
        }
      }

      rename(conversation.messages);
      if (conversation.searchMessages != null) {
        rename(conversation.searchMessages!);
      }
      if (senderId == MessageSender.localUser.id) {
        conversation.creationUserName = nextName;
      }
    }
    final history = _groupDispatcher?.history;
    if (history != null) {
      for (var i = 0; i < history.length; i++) {
        final message = history[i];
        if (message.isSystem && message.text.contains(previousName)) {
          history[i] = message.withText(
            message.text.replaceAll(previousName, nextName),
          );
        }
      }
    }
    _conversationChanged();
  }

  void _refreshGroupModelConfigs() {
    for (final state in {_execution, ..._executions.sessions.values}) {
      for (final id in state.groupReplies.keys.toList()) {
        state.groupReplies[id] = _groupReplyContext(
          state.groupReplies[id]!.profile,
        );
      }
    }
  }
}
