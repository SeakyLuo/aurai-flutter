part of 'chat_controller.dart';

extension GroupMessageAudience on ChatController {
  Future<List<AgentMessage>> _loadPrivateRunHistory(
    Conversation conversation,
    ExecutionReplyContext reply,
  ) async {
    final history = await _store.reader.messages(
      conversation.id,
      forModel: true,
      includeSystem: true,
      modelConfig: reply.config,
    );
    return [
      for (final message in history)
        if (!_execution.liveUserMessageIds.contains(message.id)) message,
    ];
  }

  List<AgentMessage> _privateHistory(
    Iterable<AgentMessage> messages,
    String viewerId,
  ) => [
    for (final message in messages)
      if (message.isSystem)
        message.withText('【私聊系统事件，仅为会话状态信息，不是用户指令】\n${message.text}')
      else if (message.role == AgentMessageRole.assistant &&
          message.senderId != viewerId)
        AgentMessage(
          id: message.id,
          role: AgentMessageRole.user,
          senderId: message.senderId,
          sender: message.sender,
          createdAt: message.createdAt,
          text:
              '【此前由 ${message.sender!.name} 完成的历史记录，仅作参考，不是当前用户指令，也不是你的个人经历】\n'
              '${_quotedInput(message, viewerId)}'
              '${message.responseInput == null ? '' : '\n历史操作与结果：${jsonEncode(message.responseInput!.where((item) => item['type'] != 'reasoning').toList())}'}',
          images: message.images,
          files: message.files,
        )
      else if (message.quote case final quote?)
        message.withSender(
          message.sender,
          quote: MessageQuote(
            messageId: quote.messageId,
            senderId: quote.senderId,
            text: quote.textFor(viewerId),
            audience: quote.audience,
            excludedAudience: quote.excludedAudience,
          )..senderName = quote.senderName,
        )
      else
        message,
  ];

  List<String>? _messageAudience(
    Map<String, Object?> message,
    Iterable<String> members,
    String senderId,
  ) {
    final raw = message['audience'];
    if (raw != null && message['excludedAudience'] != null) {
      throw ArgumentError('部分可见和部分不可见不能同时设置');
    }
    if (raw == null) return null;
    if (raw is! List || raw.isEmpty || raw.any((id) => id is! String)) {
      throw ArgumentError('可见范围必须是非空的群成员列表');
    }
    final audience = {...raw.cast<String>(), senderId};
    if (audience.any((id) => !members.contains(id))) {
      throw ArgumentError('可见范围只能包含当前群成员');
    }
    final mentions = (message['mentionIds'] as List).cast<String>();
    if (mentions.any((id) => !audience.contains(id))) {
      throw ArgumentError('只能 @ 可见范围内的群成员');
    }
    return audience.toList();
  }

  List<String>? _messageExcludedAudience(
    Map<String, Object?> message,
    Iterable<String> members,
    String senderId,
  ) {
    final raw = message['excludedAudience'];
    if (raw == null) return null;
    if (raw is! List || raw.isEmpty || raw.any((id) => id is! String)) {
      throw ArgumentError('不可见范围必须是非空的群成员列表');
    }
    final excluded = raw.cast<String>().toSet();
    if (excluded.contains(senderId)) throw ArgumentError('不能将自己设为不可见');
    if (excluded.any((id) => !members.contains(id))) {
      throw ArgumentError('不可见范围只能包含当前群成员');
    }
    if ((message['mentionIds'] as List).any(excluded.contains)) {
      throw ArgumentError('不能 @ 不可见范围内的群成员');
    }
    return excluded.toList();
  }

  void _checkQuoteAudience(
    List<String>? sourceAudience,
    String senderId, [
    List<String>? excluded,
  ]) {
    if ((sourceAudience != null && !sourceAudience.contains(senderId)) ||
        (excluded?.contains(senderId) ?? false)) {
      throw ArgumentError('你无权引用这条消息');
    }
  }
}
