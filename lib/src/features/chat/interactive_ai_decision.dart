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
    final selection = button['selection'] as Map?;
    if (button['disabled'] == true ||
        selection == null ||
        selection['mode'] != 'single') {
      return null;
    }
    final options = (selection['options'] as List).cast<Map>();
    final token = interactiveActionToken(message.id, card, actor);
    return ResponseDecision(
      instructions:
          '本轮是程序发起的单选决策，不是普通群聊回复。结合你可见的历史与自己的身份，选择一个选项。'
          '只返回 JSON 对象 {"choice":选项编号}，不调用工具、不输出代码块或解释。'
          '程序会以你的身份提交到原交互消息；弃权只能选择卡片提供的弃权选项。'
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
        },
        'required': ['choice'],
        'additionalProperties': false,
      },
      submit: (response) async {
        final value = jsonDecode(response);
        if (value is! Map ||
            value.length != 1 ||
            value['choice'] is! int ||
            (value['choice'] as int) < 1 ||
            (value['choice'] as int) > options.length) {
          throw FormatException('交互决策必须返回有效的选项编号，尚未提交', response);
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
          },
          source,
          actor,
        );
      },
    );
  }
}
