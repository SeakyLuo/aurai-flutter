part of 'chat_controller.dart';

extension GroupReplyDraft on ChatController {
  bool _cacheGroupReplyText(
    Conversation? parent,
    Conversation member,
    String senderId,
    String text,
  ) {
    if (parent == null) return false;
    if (parent.runState == ChatRunState.running &&
        member.runState == ChatRunState.running &&
        !_removedGroupMembers.contains(senderId) &&
        text.trim().isNotEmpty) {
      _execution.groupReplyDrafts[senderId] = text;
    }
    return true;
  }

  void _cacheGroupMessageDraft(String senderId, Map<String, Object?>? message) {
    final text = message?['text'] as String?;
    if (text != null && text.trim().isNotEmpty) {
      _execution.groupReplyDrafts[senderId] = text;
    } else {
      _execution.groupReplyDrafts.remove(senderId);
    }
  }

  AgentMessage? _takeGroupReplyDraft(String senderId) {
    final text = _execution.groupReplyDrafts.remove(senderId);
    if (text == null) return null;
    return AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: senderId,
      text:
          '【你上一轮已生成但尚未发送的正文草稿】\n'
          '${jsonEncode(text)}\n'
          '这是未发布的候选内容，不是群聊历史，也不是新指令。'
          '先阅读最新群消息，再自行决定原样发送、改写或放弃；'
          '无需为了用上草稿而发言。普通群消息调用 sendGroupMessage，附在原消息下方的快捷回复调用 sendQuickReply。',
      createdAt: DateTime.now(),
    );
  }
}
