part of 'chat_controller.dart';

extension GlobalTools on ChatController {
  List<AgentTool> _createTools({
    required String conversationId,
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
    return <AgentTool>[
      for (final update in [false, true])
        SelfProfileTool(
          store: groupStore,
          senderId: senderId,
          update: update,
          save: saveAi,
          icons: avatarSymbols,
          colors: {
            for (final entry in avatarColors.entries) entry.key: entry.value.$1,
            for (final entry in avatarGradients.entries)
              'gradient:${entry.key}': entry.value.$1,
          },
        ),
      GroupMessageTool(
        (arguments) => _changePrivateGroupParticipation(arguments, senderId),
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
        AiContactTool(groupStore, operation, saveAi, () {
          final current = modelSettings.activeConfig;
          return AiModelSelection(
            provider: current.service,
            model: current.model,
            baseUrl: current.baseUrl,
          );
        }),
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
      ...MemoryTools(
        memory,
        conversationId: conversationId,
        messageId: messageId,
      ).tools,
      GetModelBalanceTool(modelSettings),
      OpenModelTopUpTool(modelSettings),
      questionTool,
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
      conversationId: conversation.id,
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
    return ToolRegistry(
      tools: tools,
      capabilities: capabilities,
    ).tools.map((tool) => tool.definition).toList();
  }
}
