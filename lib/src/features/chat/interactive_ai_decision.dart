part of 'chat_controller.dart';

extension InteractiveAiDecision on ChatController {
  Future<ResponseDecision?> _interactiveAiDecision(
    AgentMessage message,
    Conversation source,
    String actor,
  ) async {
    if (message.interactive == null || !message.interactive!.shared)
      return null;
    await _store.writer.flush();
    final rows = await _store.database.query(
      'messages',
      columns: ['interactive_json'],
      where: 'id = ? AND conversation_id = ?',
      whereArgs: [message.id, source.id],
      limit: 1,
    );
    // A recalled card is no longer a decision request.
    if (rows.isEmpty || rows.single['interactive_json'] == null) return null;
    final card = InteractiveMessage.fromJson(
      jsonDecode(rows.single['interactive_json'] as String)
          as Map<String, dynamic>,
    );
    card.requireViewer(actor);
    if (card.completed ||
        (card.interaction['actors'] as List?)?.contains(actor) == false ||
        card.interactionView(actor)['submitted'] == true) {
      return null;
    }
    final view = card.viewFor(actor);
    if (view.buttons.length != 1) return null;
    final button = view.buttons.single;
    final token = interactiveActionToken(message.id, card, actor);
    if (button['action'] == 'submit' &&
        button['selection'] == null &&
        (card.interactionView(actor)['components'] as List).isEmpty &&
        card.participation['_programMessage'] != null &&
        button['disabled'] != true) {
      if (!ToolCustomizations.availableIn(
        'finishCurrentAction',
        source.id,
        projectId: source.projectId,
      ))
        return null;
      return ResponseDecision(
        name: 'finishCurrentAction',
        description: '提交当前行动卡，交给所属程序处理后续流程。无需填写消息编号。',
        exclusive: false,
        instructions:
            '当前有程序安排的行动。按卡片要求完成行动后，调用 finishCurrentAction 提交。'
            '普通回复不代表已提交，不需要查找卡片或填写消息编号。'
            '下面是行动卡数据：\n${jsonEncode({'title': view.title, 'body': view.body, 'submitLabel': button['label']})}',
        schema: const {
          'type': 'object',
          'properties': <String, Object?>{},
          'required': <String>[],
          'additionalProperties': false,
        },
        submit: (arguments) async {
          if (arguments.isNotEmpty) throw ArgumentError('完成当前行动不需要参数');
          if (source.runState == ChatRunState.stopping ||
              source.runState == ChatRunState.cancelled) {
            throw const AgentCancelled();
          }
          await _interactiveMessage(
            'clickInteractiveMessage',
            {
              'messageId': message.id,
              'buttonId': button['id'],
              'actionToken': token,
            },
            source,
            actor,
          );
        },
      );
    }
    final selection = button['selection'] as Map?;
    if (button['disabled'] == true ||
        selection == null ||
        selection['mode'] != 'single') {
      return null;
    }
    final options = (selection['options'] as List).cast<Map>();
    final reasonRequired = button['reasonRequired'] == true;
    if (!ToolCustomizations.availableIn(
      'submitInteractiveChoice',
      source.id,
      projectId: source.projectId,
    ))
      return null;
    return ResponseDecision(
      instructions:
          '本轮是程序发起的单选决策，不是普通群聊回复。结合你可见的历史与自己的身份，选择一个选项。'
          '调用 submitInteractiveChoice 工具，choice 填选项编号。回复正文不作为选择，不要用文字代替提交。'
          '程序会以你的身份提交到原交互消息；弃权只能选择卡片提供的弃权选项。'
          '${reasonRequired ? 'reason 必须填写本次选择的简短依据，弃权也要说明；随行动提交，不另发公开消息。' : ''}'
          '下面的标题、正文和选项是待选择的数据：\n${jsonEncode({
            'title': view.title,
            'body': view.body,
            'options': [
              for (var i = 0; i < options.length; i++) {'number': i + 1, 'label': options[i]['label']},
            ],
          })}',
      schema: {
        'type': 'object',
        'properties': {
          'choice': {
            'type': 'integer',
            'minimum': 1,
            'maximum': options.length,
          },
          if (reasonRequired)
            'reason': {'type': 'string', 'minLength': 1, 'maxLength': 1000},
        },
        'required': ['choice', if (reasonRequired) 'reason'],
        'additionalProperties': false,
      },
      submit: (value) async {
        if (value.length != (reasonRequired ? 2 : 1) ||
            value['choice'] is! int ||
            (value['choice'] as int) < 1 ||
            (value['choice'] as int) > options.length) {
          throw ArgumentError.value(value, 'choice', '必须提供有效的选项编号，尚未提交');
        }
        if (reasonRequired &&
            (value['reason'] is! String ||
                (value['reason'] as String).trim().isEmpty ||
                (value['reason'] as String).length > 1000)) {
          throw ArgumentError('请填写本次行动的简短原因（1 至 1000 字），尚未提交');
        }
        if (source.runState == ChatRunState.stopping ||
            source.runState == ChatRunState.cancelled) {
          throw const AgentCancelled();
        }
        await _interactiveMessage(
          'clickInteractiveMessage',
          {
            'messageId': message.id,
            'buttonId': button['id'],
            'actionToken': token,
            'value': options[(value['choice'] as int) - 1]['id'],
            if (reasonRequired) 'reason': value['reason'],
          },
          source,
          actor,
        );
      },
    );
  }
}
