part of 'chat_controller.dart';

extension GroupRunTools on ChatController {
  List<AgentTool> _groupRunTools({
    required Conversation parent,
    required Conversation member,
    required _ReplyContext reply,
    required List<AgentMessage> observed,
    required List<String> publishedIds,
    required void Function() onSleep,
  }) {
    // Bind tools to the dispatcher that owns this run, including after awaits.
    final dispatcher = _groupDispatcher!;
    return [
      _groupWakeTool(parent.id, reply.senderId),
      GroupSleepTool((duration, draft, reason) async {
        final until = await _scheduleMemberSleep(
          parent,
          member,
          reply.senderId,
          duration,
          draft,
          reason,
          dispatcher,
        );
        onSleep();
        return until;
      }),
      GroupMessageTool(
        (arguments) => _deliverGroupMessage(
          arguments: arguments,
          member: member,
          parent: parent,
          reply: reply,
          observed: observed,
          publishedIds: publishedIds,
          dispatcher: dispatcher,
        ),
      ),
    ];
  }
}
