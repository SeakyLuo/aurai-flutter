import '../../domain/quick_reply_option.dart';

enum MessageAction {
  star,
  copy,
  select,
  edit,
  quote,
  recall,
  forward,
  fullscreen,
  statistics,
  history,
}

sealed class MessageMenuResult {
  const MessageMenuResult();
}

class MessageActionResult extends MessageMenuResult {
  const MessageActionResult(this.action);
  final MessageAction action;
}

class MessageQuickReplyResult extends MessageMenuResult {
  const MessageQuickReplyResult(this.option);
  final QuickReplyOption option;
}
