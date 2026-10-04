class MessageLookupError extends StateError {
  MessageLookupError.notFound() : code = 'message_not_found', super('指定的消息不存在');

  MessageLookupError.accessDenied()
    : code = 'conversation_access_denied',
      super('你不是该会话的当前成员，无权访问其中的消息');

  final String code;
}
