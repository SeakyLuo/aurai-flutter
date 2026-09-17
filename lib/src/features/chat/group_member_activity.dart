part of 'chat_controller.dart';

class GroupMemberActivity {
  const GroupMemberActivity({
    required this.sender,
    required this.runId,
    required this.elapsed,
    required this.description,
  });

  final MessageSender sender;
  final String runId;
  final Duration elapsed;
  final String description;
}

extension GroupMemberActivities on ChatController {
  List<GroupMemberActivity> get groupMemberActivities {
    final conversation = activeConversation;
    final state = _viewExecution;
    if (conversation.kind != ConversationKind.group ||
        conversation.runState != ChatRunState.running ||
        state.runningConversation?.id != conversation.id) {
      return const [];
    }
    final activities = <GroupMemberActivity>[];
    for (final entry in state.groupSenders.entries) {
      final member = state.groupRuns[entry.key];
      if (member == null ||
          member.runState != ChatRunState.running ||
          member.activeRunId == null ||
          member.executionWatch?.isRunning != true ||
          state.removedGroupMembers.contains(entry.key) ||
          state.confirmingSenderId == entry.key) {
        continue;
      }
      final step = member.steps
          .where((step) => step.status == AgentStepStatus.running)
          .lastOrNull;
      if (step?.toolName == 'askUser' || step?.toolName == 'sleepGroupChat') {
        continue;
      }
      if (step?.resultJson != null) {
        final result = jsonDecode(step!.resultJson!) as Map;
        if ((result['userAction'] as Map?)?['pending'] == true) continue;
      }
      activities.add(
        GroupMemberActivity(
          sender: entry.value,
          runId: member.activeRunId!,
          elapsed: member.executionWatch!.elapsed,
          description: member.reconnectAttempt > 0
              ? '正在重新连接'
              : switch (step?.toolName) {
                  'searchWeb' || 'readWebPage' || 'searchImages' => '正在查看资料',
                  null => '正在思考',
                  _ => '正在处理操作',
                },
        ),
      );
    }
    return activities;
  }
}
