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
    // Names describe choices; the card's unique option IDs identify submissions.
    // Selection cards use clickInteractiveMessage so multiple cards can be
    // submitted in the same run without an exclusive, turn-ending decision.
    return null;
  }
}
