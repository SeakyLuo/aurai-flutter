import '../../domain/quick_reply_option.dart';

enum MessageAction {
  retry,
  readAloud,
  star,
  pin,
  groupFavorite,
  copy,
  select,
  edit,
  quote,
  recall,
  forward,
  fullscreen,
  splitRun,
  history,
  timeline,
}

sealed class MessageMenuResult {
  const MessageMenuResult();
}

class MessageMenuDismissResult extends MessageMenuResult {
  const MessageMenuDismissResult();
}

class MessageActionResult extends MessageMenuResult {
  const MessageActionResult(this.action);
  final MessageAction action;
}

class MessageQuickReplyResult extends MessageMenuResult {
  const MessageQuickReplyResult(this.option);
  final QuickReplyOption option;
}
