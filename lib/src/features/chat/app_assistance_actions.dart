part of 'chat_controller.dart';

extension AppAssistanceActions on ChatController {
  Future<Map<String, Object?>> _assistApp(
    String operation,
    Map<String, Object?> args,
    String senderId,
  ) async {
    if (operation == 'getModelConfiguration' ||
        operation == 'openModelConfiguration') {
      final profile = await groupStore.loadAi(senderId);
      final model = aiConfig(profile);
      final endpoint = Uri.tryParse(model.baseUrl);
      final missing = <String>[
        if (model.apiKey.trim().isEmpty) 'apiKey',
        if (model.model.trim().isEmpty) 'model',
        if (endpoint == null ||
            !['http', 'https'].contains(endpoint.scheme) ||
            endpoint.host.isEmpty)
          'baseUrl',
      ];
      final page = missing.contains('apiKey')
          ? 'providerConfiguration'
          : 'modelConfiguration';
      if (operation == 'openModelConfiguration') {
        final navigate = openAppPage;
        if (navigate == null) throw StateError('当前无法打开设置，请先回到 Aurai');
        await navigate({
          'page': page,
          'senderId': senderId,
          'service': model.service.name,
        });
      }
      return {
        'provider': model.service.name,
        'providerName': model.displayName,
        'model': model.model,
        'configured': missing.isEmpty,
        'missing': missing,
        'settingsPage': page,
        'guidance': missing.contains('apiKey')
            ? '请在供应商设置中填写 API Key，再选择模型'
            : missing.isNotEmpty
            ? '请在模型设置中补全模型和服务地址'
            : '配置字段完整；连接、额度和模型可用性尚未验证',
        if (operation == 'openModelConfiguration') 'opened': true,
      };
    }
    final messageId = args['messageId'] as String;
    await _store.writer.flush();
    final rows = await _store.database.query(
      'messages',
      columns: ['id', 'conversation_id', 'kind'],
      where:
          'id = ? AND conversation_id IN (SELECT conversation_id FROM conversation_members WHERE sender_id = ? AND left_at IS NULL)',
      whereArgs: [messageId, senderId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('消息不存在或你无权访问');
    final sourceId = rows.single['conversation_id'] as String;
    if (operation == 'locateMessage') {
      await _controlApp(
        'openAppPage',
        {
          'page': 'conversation',
          'conversationId': sourceId,
          'messageId': messageId,
        },
        senderId,
        sourceId,
      );
      return {
        'opened': true,
        'conversationId': sourceId,
        'messageId': messageId,
      };
    }
    if (operation != 'forwardMessage') throw ArgumentError('不支持的操作');
    if (rows.single['kind'] == 'system') throw StateError('系统消息或已撤回消息不能转发');
    final targetId = args['conversationId'] as String;
    final access = await Future.wait([
      _store.database.query(
        'conversation_members',
        columns: ['sender_id'],
        where:
            'conversation_id = ? AND sender_id IN (?, ?) AND left_at IS NULL',
        whereArgs: [targetId, senderId, MessageSender.localUser.id],
      ),
      _store.database.query(
        'conversation_members',
        columns: ['sender_id'],
        where: 'conversation_id = ? AND sender_id = ? AND left_at IS NULL',
        whereArgs: [sourceId, MessageSender.localUser.id],
      ),
    ]);
    if (access[0].length != 2 || access[1].isEmpty)
      throw StateError('只能转发用户和你均可访问的消息与会话');
    final note = (args['note'] as String).trim();
    if (note.length > 20000) throw ArgumentError('留言不能超过 20000 字');
    final messages = await _store.reader.messages(
      sourceId,
      throughMessageId: messageId,
      includeMessageId: messageId,
      limit: 1,
    );
    if (messages.isEmpty ||
        messages.single.id != messageId ||
        messages.single.isSystem)
      throw StateError('原消息已删除或撤回');
    final forwardedId = await forwardMessage(targetId, messages.single, note);
    return {'sent': true, 'conversationId': targetId, 'messageId': forwardedId};
  }
}
