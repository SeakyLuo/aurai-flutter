part of 'chat_page.dart';

extension _ChatGroupNavigation on _ChatPageState {
  Widget _groupStatus(Conversation conversation) => GroupStatusBuilder(
    key: ValueKey(conversation.id),
    controller: widget.controller,
    conversationId: conversation.id,
    includeThoughts: false,
    builder: (context, activities) => GroupActivityAvatars(
      activities: activities
          .where((a) => !a.stopping && !a.waitingForUser)
          .toList(),
      onPressed: () {
        _focusNode.unfocus();
        showGroupActivitySheet(
          context,
          controller: widget.controller,
          conversationId: conversation.id,
        );
      },
    ),
  );

  Widget _groupIntroduction(
    List<ChatTimelineEntry> timeline,
    double top,
    double bottom,
  ) => ListView(
    key: ValueKey('introduction:$_conversationId'),
    primary: false,
    padding: EdgeInsets.only(top: top, bottom: bottom + 16),
    children: [for (final entry in timeline) entry.builder(context)],
  );
}
