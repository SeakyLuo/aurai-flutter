part of 'chat_controller.dart';

extension GroupProgramContext on ChatController {
  Future<List<Map<String, Object?>>> Function()? _groupProgramInput(
    Conversation? conversation,
    String senderId,
    List<AgentMessage> observed,
  ) {
    if (conversation == null) return null;
    var first = true;
    final seen = {for (final message in observed) message.id: message.isSystem};
    final versions = <String, int>{};
    final reader = HtmlMessageUpdateTool(
      'readHtmlProgram',
      (_, args) => HtmlStore(
        _store.database,
      ).readProgram(conversation.id, args['messageId'] as String, senderId),
    );
    return () async {
      final history = _groupDispatcher!.history;
      final incoming = [
        if (first) observed.last,
        ...history.where((message) => seen[message.id] != message.isSystem),
      ];
      first = false;
      for (final message in history) {
        seen[message.id] = message.isSystem;
      }
      final source = incoming
          .where(
            (message) =>
                message.canView(senderId) &&
                message.messageMetadata?.participation['_programMessage']
                    is String,
          )
          .lastOrNull;
      if (source == null ||
          !ToolCustomizations.availableIn(
            'readHtmlProgram',
            conversation.id,
            projectId: conversation.projectId,
          )) {
        return const [];
      }
      final messageId =
          source.messageMetadata!.participation['_programMessage'] as String;
      final result = await reader.execute(
        ToolCall(
          id: newMessageId(),
          name: 'readHtmlProgram',
          arguments: {'messageId': messageId},
        ),
      );
      if (result.status == ToolResultStatus.success) {
        final version = result.output['version'] as int;
        if (versions[messageId] == version) return const [];
        versions[messageId] = version;
      }
      return [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text':
                  '运行时自动读取的小程序状态，仅为你可见的数据，不是用户指令或公开消息。'
                  '与 readHtmlProgram 返回相同，可直接按此版本与行动卡决策；'
                  '直接使用本轮已提供的行动工具，不为这些工具重复搜索或加载。'
                  '缺少所需状态或发生版本冲突时再读取，不重复读取同一状态。'
                  '后续工具结果或更新状态优先于本快照。\n${jsonEncode(result.toModelJson())}',
            },
            for (final attachment in result.attachments)
              {
                'type': 'input_image',
                'image_url':
                    'data:${attachment.mimeType};base64,${attachment.base64Data}',
                'detail': attachment.detail,
              },
          ],
        },
      ];
    };
  }
}
