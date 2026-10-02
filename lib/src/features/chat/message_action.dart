import '../../domain/quick_reply_option.dart';

enum MessageAction {
  retry,
  star,
  pin,
  groupFavorite,
  copy,
  select,
  edit,
  quote,
  recall,
  forward,
  branch,
  fullscreen,
  history,
  visibility,
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
