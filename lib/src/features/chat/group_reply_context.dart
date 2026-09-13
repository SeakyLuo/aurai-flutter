part of 'chat_controller.dart';

extension GroupReplyContext on ChatController {
  Future<({String senderId, ModelConfig config, String? systemPrompt})>
  _replyContext(Conversation conversation) async {
    final settings = modelSettings;
    if (conversation.kind == ConversationKind.direct) {
      return (
        senderId: MessageSender.aurai.id,
        config: settings.activeConfig,
        systemPrompt: settings.systemPrompt,
      );
    }
    final message = conversation.messages.lastWhere(
      (message) => message.role == AgentMessageRole.user,
    );
    final recipients = await _store.groups.recipients(message.id);
    final sender = recipients.single;
    final profile = await _store.groups.loadAi(sender.id);
    final selection = profile.modelSelection;
    final runConfig = selection == null
        ? settings.activeConfig
        : ModelConfig(
            apiKey: settings.profile(selection.provider).apiKey,
            service: selection.provider,
            model: selection.model,
            baseUrl: selection.baseUrl,
          );
    return (
      senderId: sender.id,
      config: runConfig,
      systemPrompt: [
        settings.systemPrompt ?? agentSystemPrompt,
        '你在群聊中的名字是 ${sender.name}。',
        if (profile.instructions.isNotEmpty) profile.instructions,
      ].join('\n\n'),
    );
  }
}
