part of 'chat_controller.dart';

extension GeneratedFileActions on ChatController {
  Future<Map<String, Object?>> _deliverFile(
    Map<String, Object?> arguments,
    Conversation conversation,
    String senderId,
    bool Function() cancelled,
  ) async {
    if (conversation.kind == ConversationKind.group) {
      _checkGroupStopped(conversation);
      if (_removedGroupMembers.contains(senderId)) throw const AgentCancelled();
    }
    final file = await GeneratedFileStore(
      _imageStore.directory,
      conversation.id,
    ).snapshot(arguments['path'] as String, arguments['name'] as String);
    var sent = false;
    try {
      if (cancelled()) throw const AgentCancelled();
      if (conversation.kind == ConversationKind.group)
        _checkGroupStopped(conversation);
      final result = await _sendPrivateGroupMessage(
        {
          'groupId': conversation.id,
          'message': {
            'text': arguments['caption'] as String,
            '_images': <MessageImage>[],
            '_files': [file],
            'mentionIds': <String>[],
          },
          'participation': 'unchanged',
        },
        senderId,
        requireGroup: false,
        sourceId: conversation.id,
      );
      sent = result['sent'] == true;
      return {
        ...result,
        'fileName': file.name,
        'mimeType': file.mimeType,
        'size': file.size,
        'instruction': '文件已作为附件显示在当前会话，不要重复发送。',
      };
    } finally {
      if (!sent) await File(file.path).delete();
    }
  }
}
