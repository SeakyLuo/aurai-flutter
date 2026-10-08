part of 'chat_page.dart';

extension _ChatGroupNavigation on _ChatPageState {
  Widget _privateStatus(Conversation conversation) {
    final controller = widget.controller;
    final runId = conversation.activeRunId;
    final active = conversation.runState == ChatRunState.running;
    if (!active ||
        runId == null ||
        controller.pendingConfirmation != null ||
        controller.pendingQuestion?.conversationId == conversation.id ||
        controller.accessibilityRequestPending) {
      return const SizedBox.shrink();
    }
    final sender = controller.activeAi!.sender;
    return GroupActivityAvatars(
      key: ValueKey('private:$runId'),
      compact: true,
      activities: [
        GroupMemberActivity(
          sender: sender,
          runId: runId,
          elapsed: conversation.executionWatch?.elapsed ?? Duration.zero,
          description: '正在思考',
        ),
      ],
      onPressed: () {
        _focusNode.unfocus();
        showTaskRunTimelineSheet(
          context,
          controller: controller,
          runId: runId,
          sender: sender,
          live: true,
        );
      },
    );
  }

  Widget _groupStatus(Conversation conversation) => GroupStatusBuilder(
    key: ValueKey(conversation.id),
    controller: widget.controller,
    conversationId: conversation.id,
    includeThoughts: false,
    builder: (context, activities) => GroupActivityAvatars(
      compact: true,
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
    padding: EdgeInsets.only(top: top, bottom: bottom + 56),
    children: [for (final entry in timeline) entry.builder(context)],
  );
}
