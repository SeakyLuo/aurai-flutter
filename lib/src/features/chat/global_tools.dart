part of 'chat_controller.dart';

extension GlobalTools on ChatController {
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
    String? groupId,
  }) {
    final conversationId = conversation.id;
    return <AgentTool>[
      ExecutionLogTool(),
      for (final name in HtmlMessageUpdateTool.names)
        HtmlMessageUpdateTool(name, (operation, args) async {
          final result = await htmlGames.updateMessage(
            operation,
            conversation.id,
            senderId,
            args,
          );
          if (result['updated'] == true)
            HtmlGameSignals.changes.add(args['messageId'] as String);
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
        if (conversation.kind == ConversationKind.group) {
          _checkGroupStopped(conversation);
          if (_removedGroupMembers.contains(senderId))
            throw const AgentCancelled();
        }
        final profile = await groupStore.loadAi(senderId);
        final message = await htmlGames.create(
          conversationId: conversation.id,
          creator: profile.sender,
          standalone: true,
          groupMessage: conversation.kind == ConversationKind.group,
          args: {
            ...args,
            'state': <String, Object?>{},
            'participants': [senderId, MessageSender.localUser.id],
            'turnSenderId': null,
          },
        );
        _publishInteractiveChange(
          conversation.id,
          message,
          source: conversation,
        );
        HtmlGameSignals.changes.add(message.id);
        return {'sent': true, 'messageId': message.id};
      }),
      if (HtmlGameFeature.enabled &&
          conversation.kind == ConversationKind.group)
        for (final name in HtmlGameTool.names)
          HtmlGameTool(
            name,
            (operation, args) =>
                _htmlGameTool(operation, args, conversation, senderId),
          ),
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
      RecallMessageTool((id) => _recallAiMessage(conversation, senderId, id)),
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
      for (final operation in GroupChatTool.operations)
        GroupChatTool(
          groupStore,
          operation,
          conversationId,
          renameConversation,
          updateGroupMembers,
          _conversationChanged,
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
          ownerId: senderId,
        ),
      AttachmentTool(history.expand((message) => message.files)),
      for (final operation in SkillTool.operations)
        SkillTool(skills, operation),
      RunSkillTool(skills, _platform, conversationId),
      WebTool('searchWeb', webSources),
      SourceDatesTool(webSources),
      ImageSearchTool(),
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
      GetNotificationsTool(_platform, providerLabel),
      SendNotificationTool(_platform, conversationId),
      InspectAndroidApiTool(_platform),
      ExecuteAndroidScriptTool(_platform, conversationId),
      ObserveDeviceTool(_platform),
      CaptureScreenTool(_platform, providerLabel),
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
      for (final name in DeviceExtensionTool.names)
        DeviceExtensionTool(_platform, name),
    ];
  }

  List<ToolDefinition> get globalToolDefinitions {
    final conversation = activeConversation;
    final tools = _createTools(
      conversation: conversation,
      senderId: MessageSender.aurai.id,
      messageId: null,
      providerLabel: config.service.label,
      memory: memory,
      skills: skills,
      documents: AiDocumentScope(_store.database, MessageSender.aurai.id),
      history: conversation.messages,
      questionTool: AskUserTool(conversation.id, (_) {}),
      webSources: WebSourceRegistry(),
    );
    return ToolRegistry(tools: tools, capabilities: capabilities).catalog;
  }
}
