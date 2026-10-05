part of 'chat_controller.dart';

extension GlobalTools on ChatController {
  Future<ToolRegistry> _createMemberToolRegistry({
    required String? Function() currentProjectId,
    required List<AgentTool> tools,
    required Conversation? parent,
    required Conversation member,
    required ExecutionReplyContext reply,
    required List<AgentMessage> observed,
    required List<String> publishedIds,
    required VoidCallback onSleep,
    required String? groupId,
  }) async {
    if (parent != null) {
      _bindGroupRunTools(
        tools: tools,
        parent: parent,
        member: member,
        reply: reply,
        observed: observed,
        publishedIds: publishedIds,
        onSleep: onSleep,
      );
    }
    final registry = ToolRegistry(
      currentProjectId: currentProjectId,
      tools: tools,
      capabilities: capabilities,
      groupId: groupId,
    );
    registry.load(await recentConversationTools(_store.database, member.id));
    registry.load([
      'sendGroupMessage',
      if (parent != null) ...[
        'sleepGroupChat',
        'wakeGroupMember',
        'pauseGroupAutoReply',
        'resumeGroupAutoReply',
      ],
    ]);
    return registry;
  }

  List<AgentTool> _createTools({
    required Conversation conversation,
    required String senderId,
    required String? messageId,
    required String providerLabel,
    required MemoryController memory,
    required SkillStore skills,
    required AiDocumentScope documents,
    required Iterable<AgentMessage> history,
    required AskUserTool questionTool,
    required WebSourceRegistry webSources,
    Future<void> Function(ProjectDirectory directory)? onProjectGitBaseChanged,
    String? groupId,
  }) {
    final conversationId = conversation.id;
    return <AgentTool>[
          // Goals/plans are isolated by conversation and member; scheduling remains independent.
          for (final name in PrivateTaskTool.names)
            PrivateTaskTool(
              PrivateTaskState(_store.database, conversationId, senderId),
              name,
            ),
          DeliverFileTool(
            (args, cancelled) =>
                _deliverFile(args, conversation, senderId, cancelled),
          ),
          for (final name in RequestAdapterTool.names)
            RequestAdapterTool(name, requestAdapterTool),
          for (final name in StarredMessageTool.names)
            StarredMessageTool(
              _store.database,
              senderId,
              name,
              () => _store.writer.flush(),
            ),
          QuickReplyTool(
            (id, key) => _sendAiQuickReply(conversation, senderId, id, key),
          ),
          for (final name in HtmlAppPublicationTool.names)
            HtmlAppPublicationTool(
              name,
              MiniappLibraryStore(_store.database),
              senderId,
            ),
          for (final name in HtmlAppEditTool.names)
            HtmlAppEditTool(name, (operation, args) async {
              await _store.writer.flush();
              final result = await HtmlAppStore(
                _store.database,
              ).edit(operation, senderId, args);
              if (result['updated'] == true) {
                HtmlGameSignals.appChanges.add(result['appId'] as String);
                _conversationChanged();
              }
              return result;
            }),
          for (final name in HtmlAppTeamTool.names)
            HtmlAppTeamTool(name, MiniappTeamStore(_store.database), senderId),
          for (final name in HtmlAppDataTool.names)
            HtmlAppDataTool(name, (operation, args) async {
              final apps = HtmlAppStore(_store.database);
              if (operation == 'listHtmlApps') {
                return MiniappAgentCatalog(
                  MiniappLibraryStore(_store.database),
                ).list(args, actor: senderId);
              }
              final appId = args['appId'] as String;
              final result = await apps.data(
                appId,
                args['name'] as String,
                actor: senderId,
                write: operation == 'writeHtmlAppData',
                expectedRevision: args['expectedRevision'] as int?,
                value: args['value'],
              );
              if (operation == 'writeHtmlAppData')
                HtmlGameSignals.appChanges.add(appId);
              return result;
            }),
          ExecutionLogTool(senderId: senderId),
          for (final name in HtmlMessageUpdateTool.names)
            HtmlMessageUpdateTool(name, (operation, args) async {
              await _store.writer.flush();
              final target = await _messageConversation(
                args['messageId'] as String,
                senderId,
                conversation,
              );
              if (operation == 'readHtmlData' ||
                  operation == 'updateHtmlData') {
                return HtmlMessageData(
                  htmlStore,
                ).invoke(operation, target.id, senderId, args);
              }
              if (operation == 'readHtmlProgram') {
                final game = await htmlStore.load(
                  target.id,
                  args['messageId'] as String,
                  viewer: senderId,
                );
                if (!game.state.containsKey('_miniapp'))
                  throw StateError('这条消息不是程序小程序');
                final compaction = await MiniappProgramStore(_store.database)
                    .pendingCompaction(
                      target.id,
                      args['messageId'] as String,
                      senderId,
                    );
                return {
                  'messageId': args['messageId'],
                  'version': game.version,
                  'state': game.state,
                  if (compaction != null) 'contextCompaction': compaction,
                };
              }
              if (operation == 'submitHtmlProgramEvent') {
                final programs = MiniappProgramStore(_store.database);
                if (args['expectedVersion'] == null &&
                    args['action'] != 'context.compact.retry') {
                  throw ArgumentError('新操作必须先读取版本；空版本只用于恢复原上下文压缩请求');
                }
                return programs.event(
                  target.id,
                  args['messageId'] as String,
                  senderId,
                  args,
                );
              }
              final result = await htmlStore.updateMessage(
                operation,
                target.id,
                senderId,
                args,
              );
              if (result['callbackCompleted'] == true) {
                HtmlGameSignals.callbackChanges.add(
                  args['messageId'] as String,
                );
              }
              if (result['updated'] == true) {
                final id = args['messageId'] as String;
                final saved = (await _store.reader.messages(
                  target.id,
                  throughMessageId: id,
                  includeMessageId: id,
                  limit: 1,
                )).single;
                final peer = _peerSessions[target.id];
                final dispatchers = [
                  if (_executions.sessions[target.id]?.groupDispatcher
                      case final dispatcher?)
                    dispatcher,
                  if (peer != null) (await peer).dispatcher,
                ];
                for (final dispatcher in dispatchers) {
                  final index = dispatcher.history.indexWhere(
                    (m) => m.id == id,
                  );
                  if (index >= 0) dispatcher.history[index] = saved;
                }
                for (final value in _interactiveConversations(
                  target.id,
                  target,
                )) {
                  for (final history in [
                    value.messages,
                    if (value.searchMessages != null) value.searchMessages!,
                  ]) {
                    final index = history.indexWhere((m) => m.id == id);
                    if (index >= 0) history[index] = saved;
                  }
                }
                _store.writer.remember([saved]);
                _conversationChanged();
                HtmlGameSignals.appChanges.add(result['appId'] as String);
              }
              return result;
            }),
          for (final name in FriendTool.names)
            FriendTool(
              ContactRelationships(_store.database),
              senderId,
              name,
              _conversationChanged,
            ),
          HtmlMessageTool((args) async {
            await _store.writer.flush();
            final targetId =
                args['conversationId'] as String? ?? conversation.id;
            final access = await _store.database.query(
              'conversation_members',
              columns: ['sender_id'],
              where:
                  'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
              whereArgs: [targetId, senderId],
              limit: 1,
            );
            if (access.isEmpty) throw StateError('会话不存在或你无权访问该会话');
            final target = targetId == conversation.id
                ? conversation
                : await _forwardTarget(targetId);
            if (conversation.kind == ConversationKind.group) {
              _checkGroupStopped(conversation);
              if (_removedGroupMembers.contains(senderId))
                throw const AgentCancelled();
            }
            MiniappTemplate? template;
            if (args['entryKind'] != null) {
              final entry = await MiniappAgentCatalog(
                MiniappLibraryStore(_store.database),
              ).resolve(args['appId'] as String, args['entryKind'] as String);
              if (args['sendMode'] == 'share') {
                final message = await _sendAgentMiniappShare(
                  target,
                  entry,
                  senderId,
                );
                return {
                  'sent': true,
                  'messageId': message.id,
                  'conversationId': target.id,
                  'sendMode': 'share',
                };
              }
              template = await MiniappTemplate.load(_store.database, entry);
            }
            final profile = await groupStore.loadAi(senderId);
            final message = await htmlStore.create(
              newSession: template != null,
              conversationId: target.id,
              creator: profile.sender,
              runId:
                  target.id != conversation.id ||
                      target.kind == ConversationKind.group
                  ? null
                  : conversation.activeRunId,
              standalone: true,
              groupMessage: target.kind == ConversationKind.group,
              args: {
                ...args,
                if (template != null) ...{
                  ...template.definition,
                  'appId': template.appId,
                  'title': template.title,
                },
                'state': <String, Object?>{},
                'participants': target.kind == ConversationKind.group
                    ? (await groupStore.members(
                        target.id,
                      )).map((m) => m.sender.id).toList()
                    : [senderId, MessageSender.localUser.id],
                'turnSenderId': null,
              },
            );
            _publishInteractiveChange(target.id, message, source: target);
            HtmlGameSignals.changes.add(message.id);
            final app = await htmlStore.load(target.id, message.id);
            final ref = app.appId == null
                ? null
                : await HtmlAppStore.load(_store.database, app.appId!);
            return {
              'sent': true,
              'messageId': message.id,
              'conversationId': target.id,
              if (ref != null) ...await HtmlAppStore.reference(ref),
            };
          }),
          for (final name in InteractiveMessageTool.names)
            InteractiveMessageTool(
              name,
              (operation, args) =>
                  _interactiveMessage(operation, args, conversation, senderId),
            ),
          for (final name in AppControlTool.descriptions.keys)
            AppControlTool(
              name,
              (operation, args) =>
                  _controlApp(operation, args, senderId, conversationId),
            ),
          for (final name in AppAssistanceTool.descriptions.keys)
            AppAssistanceTool(
              name,
              (operation, args) => _assistApp(operation, args, senderId),
            ),
          for (final name in ProviderConfigurationTool.descriptions.keys)
            ProviderConfigurationTool(name, _configureProvider),
          RecallMessageTool(
            (id) => _recallAiMessage(conversation, senderId, id),
          ),
          if (conversation.usesPersonalization)
            for (final update in [false, true])
              SelfProfileTool(
                store: groupStore,
                senderId: senderId,
                update: update,
                save: saveAi,
                icons: avatarSymbols,
                colors: {
                  for (final entry in avatarColors.entries)
                    entry.key: entry.value.$1,
                  for (final entry in avatarGradients.entries)
                    'gradient:${entry.key}': entry.value.$1,
                },
              ),
          GroupMessageTool(
            (arguments) => _sendPrivateGroupMessage(arguments, senderId),
          ),
          ..._groupAutoReplyTools(groupId, senderId),
          GroupSleepTool(
            (targetGroupId, duration, draft, reason) => _sleepInTargetGroup(
              targetGroupId,
              senderId,
              duration,
              draft,
              reason,
            ),
            currentGroupId: groupId,
          ),
          _groupWakeTool(groupId, senderId),
          GroupMuteTool(
            (targetGroupId, targetSenderId, duration) => setGroupMemberMute(
              targetGroupId,
              targetSenderId,
              duration: duration,
              actorId: senderId,
            ),
            currentGroupId: groupId,
          ),
          for (final operation in GroupChatTool.operations)
            GroupChatTool(
              groupStore,
              operation,
              conversationId,
              (id, title) => renameConversation(id, title, actorId: senderId),
              (id, members) =>
                  updateGroupMembers(id, members, actorId: senderId),
              (id, actorId) => dissolveGroup(id, actorId: actorId),
              _conversationChanged,
              senderId: senderId,
            ),
          for (final operation in ProjectTool.operations)
            ProjectTool(
              operation: operation,
              projects: projects,
              conversation: conversation,
              createManaged: createManagedProject,
              setConversationProject: (target, projectId) async {
                await setConversationProject(
                  target,
                  projectId,
                  actorId: senderId,
                );
                documents.project = projectId == null
                    ? null
                    : await projects.readWorkspace(projectId);
              },
              changed: _conversationChanged,
            ),
          for (final name in GroupMessageMarksTool.names)
            GroupMessageMarksTool(
              GroupMessageMarks(groupStore, actorId: senderId),
              name,
              groupId ??
                  (conversation.kind == ConversationKind.group
                      ? conversationId
                      : null),
              () => _store.writer.flush(),
            ),
          GroupNoticeTool(groupStore, senderId, groupId),
          for (final write in [false, true])
            GroupAnnouncementTool(
              GroupAnnouncementStore(groupStore),
              senderId,
              groupId ?? conversationId,
              write: write,
            ),
          for (final update in [false, true])
            DefaultModelTool(
              update: update,
              settings: () => modelSettings,
              imageGeneration: () => imageGeneration,
              save: (purpose, selection) async {
                if (purpose != ModelPurpose.imageGeneration) {
                  await saveDefaultModel(purpose, selection);
                  return;
                }
                final client = ImageGenerationClient();
                try {
                  final models = await client.models(
                    modelSettings.profile(selection.service),
                  );
                  final model = models
                      .where((m) => m.id == selection.model)
                      .firstOrNull;
                  if (model == null) {
                    throw ArgumentError(
                      '该供应商可用的生图模型：${models.map((m) => m.id).join(', ')}',
                    );
                  }
                  await saveImageGeneration(
                    ImageGenerationConfig(
                      service: selection.service,
                      model: model,
                    ),
                  );
                } finally {
                  client.close();
                }
              },
            ),
          for (final operation in AiContactTool.operations)
            AiContactTool(
              groupStore,
              operation,
              (ai, {bool create = false}) async {
                if (create) {
                  await groupStore.createAi(ai, ownerId: senderId);
                  _conversationChanged();
                } else {
                  await saveAi(ai, addToMyContacts: false);
                }
              },
              () {
                final current = modelSettings.activeConfig;
                return AiModelSelection(
                  provider: current.service,
                  model: current.model,
                  baseUrl: current.baseUrl,
                );
              },
              modelSettings: () => modelSettings,
              ownerId: senderId,
            ),
          AttachmentTool((call) async {
            await _store.writer.flush();
            return HistoryMessageTool(
              _store.database,
              _store.reader.imageDirectory,
              senderId: senderId,
              name: 'readAttachment',
              inGroup: groupId != null,
            ).execute(call);
          }),
          for (final operation in SkillTool.operations)
            SkillTool(
              skills,
              operation,
              groupId: groupId,
              currentProjectId: () => documents.project?.id,
            ),
          RunSkillTool(
            skills,
            _platform,
            conversationId,
            groupId: groupId,
            currentProjectId: () => documents.project?.id,
          ),
          WebTool('searchWeb', webSources),
          SourceDatesTool(webSources),
          ImageSearchTool(),
          ImageGenerationTool(
            (args, client) =>
                _generateImage(args, client, conversation, senderId),
            configuration: () => imageGeneration,
          ),
          MusicGenerationTool(
            (args, client) =>
                _generateMusic(args, client, conversation, senderId),
            configured: () => modelSettings.firstAvailableMusicModel != null,
          ),
          WebTool('readWebPage', webSources),
          if (scheduledTasks.supported)
            for (final operation in ScheduleTaskTool.operations)
              ScheduleTaskTool(
                scheduledTasks,
                conversationId,
                operation,
                senderId: senderId,
              ),
          if (conversation.usesPersonalization)
            ...MemoryTools(
              memory,
              conversationId: conversationId,
              messageId: messageId,
            ).tools.where(
              (tool) =>
                  !conversation.isTemporary ||
                  tool.definition.name == 'listMemories' ||
                  tool.definition.name == 'readMemory',
            ),
          GetModelBalanceTool(modelSettings),
          OpenModelTopUpTool(modelSettings),
          questionTool,
          for (final name in HistoryMessageTool.names)
            HistoryMessageTool(
              _store.database,
              _store.reader.imageDirectory,
              senderId: senderId,
              name: name,
              inGroup: groupId != null,
            ),
          ReadGroupMessagesTool(
            groupStore,
            senderId: senderId,
            currentGroupId: groupId,
          ),
          for (final name in ['searchConversations', 'searchMessages'])
            LocalHistoryTool(
              _store.database.path,
              name,
              senderId: senderId,
              groupId: groupId,
            ),
          GetNetworkStateTool(_platform),
          GetNetworkEventsTool(_platform),
          DnsLookupTool(_platform),
          TlsProbeTool(_platform),
          HttpProbeTool(_platform),
          GetNotificationsTool(_platform),
          SendNotificationTool(_platform, conversationId),
          InspectAndroidApiTool(_platform),
          ExecuteAndroidScriptTool(_platform, conversationId),
          ObserveDeviceTool(_platform),
          CaptureScreenTool(_platform),
          TapScreenTool(_platform, providerLabel),
          WaitTool(),
          WaitForUiTool(_platform),
          RequestAccessibilityAccessTool(_requestAccessibility),
          for (final name in uiToolActions.keys)
            ActTool(_platform, providerLabel, name),
          FindAppsTool(_platform),
          LaunchAppTool(_platform),
          StartIntentTool(_platform),
          OpenSettingsTool(_platform),
          AppShellTool(_platform),
          for (final name in DocumentTool.names)
            DocumentTool(_platform, name, access: documents),
          for (final update in [false, true])
            GitConfigurationTool(_platform, update),
          if (documents.project case final project?
              when project.directories.any((directory) => directory.managed))
            for (final name in ProjectDevelopmentTool.names)
              ProjectDevelopmentTool(
                _platform,
                project,
                name,
                onGitBaseChanged: onProjectGitBaseChanged,
              ),
          for (final name in DeviceExtensionTool.names)
            DeviceExtensionTool(_platform, name),
        ]
        .map(
          (tool) => _withGroupMemberAccess(
            _withUserDataReadAccess(tool, conversation, senderId, groupId),
            senderId,
            groupId,
          ),
        )
        .toList();
  }

  List<ToolDefinition> get globalToolDefinitions {
    final conversation = activeConversation;
    final tools = _createTools(
      conversation: conversation,
      senderId: MessageSender.aurai.id,
      messageId: null,
      providerLabel: config.displayName,
      memory: memory,
      skills: skills,
      documents: AiDocumentScope(_store.database, MessageSender.aurai.id),
      history: conversation.messages,
      questionTool: AskUserTool(
        conversation.id,
        (_) {},
        sender: MessageSender.aurai,
      ),
      webSources: WebSourceRegistry(),
    );
    return [
      ...ToolRegistry(
        tools: tools,
        capabilities: capabilities,
        management: true,
      ).catalog,
      ...ResponseDecision.catalog.map(ToolCustomizations.apply),
    ];
  }
}
