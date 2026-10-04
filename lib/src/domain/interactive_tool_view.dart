import 'dart:convert';

import 'interactive_message.dart';

String interactiveActionToken(
  String messageId,
  InteractiveMessage card,
  String actor,
) => base64Url.encode(
  utf8.encode(
    jsonEncode([
      messageId,
      actor,
      card.revision,
      card.participantRevision(actor),
    ]),
  ),
);

Map<String, Object?> interactiveToolView(
  String messageId,
  InteractiveMessage card,
  String actor,
) {
  card.requireViewer(actor);
  final view = card.viewFor(actor);
  final eligible =
      (card.interaction['actors'] as List?)?.contains(actor) ?? true;
  final state = card.hasInteraction ? card.interactionView(actor) : null;
  final submitted = state?['submitted'] == true;
  final callback = card.participants[actor]?['callback'];
  return {
    'messageId': messageId,
    'title': view.title,
    'body': view.body,
    'actionToken': interactiveActionToken(messageId, card, actor),
    'eligible': eligible,
    'closed': card.closed,
    'buttons': [
      for (final button in view.buttons)
        {
          for (final key in [
            'id',
            'label',
            'action',
            'disabled',
            'selection',
            'input',
            'url',
          ])
            if (button.containsKey(key)) key: button[key],
        },
    ],
    if (state != null) 'interactionView': state,
    if (callback != null) 'ownParticipation': {'callback': callback},
    'next': !eligible
        ? '你不是本轮参与者，只能查看获准的信息，不能代投。'
        : card.closed || state?['completed'] == true
        ? '本轮已结束，查看获准结果；不要提交旧轮操作。'
        : submitted
        ? '你已提交。本轮允许修改时可重新选择，否则等待程序调度。'
        : '读取不会提交。需要参与时，调用 clickInteractiveMessage，原样传回 messageId、actionToken、按钮 id；选择按钮另传选项 id 作为 value。确认返回的提交状态后才算完成，文字表达选择不会记录操作。',
  };
}

Map<String, Object?> interactiveChatView(
  String messageId,
  InteractiveMessage card,
  String actor,
) {
  final view = interactiveToolView(messageId, card, actor);
  final state = view['interactionView'] as Map?;
  if (view['eligible'] == false ||
      view['closed'] == true ||
      state?['submitted'] == true ||
      state?['completed'] == true) {
    return {
      'messageId': messageId,
      'title': view['title'],
      'eligible': view['eligible'],
      'closed': view['closed'],
      if (state != null) 'submitted': state['submitted'],
      'next': view['next'],
    };
  }
  return view;
}
