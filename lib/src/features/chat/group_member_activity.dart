part of 'chat_controller.dart';

class GroupMemberActivity {
  const GroupMemberActivity({
    required this.sender,
    required this.runId,
    required this.elapsed,
    required this.description,
    this.stopping = false,
    this.waitingForUser = false,
    this.thoughts = const [],
    this.preview = '',
    this.sleepingUntil,
  });

  final DateTime? sleepingUntil;
  bool get sleeping => sleepingUntil != null;
  final MessageSender sender;
  final String runId;
  final Duration elapsed;
  final String description;
  final bool stopping;
  final bool waitingForUser;
  final List<String> thoughts;
  final String preview;
}

class _GroupMemberThoughts {
  _GroupMemberThoughts(this.runId);
  final String runId;
  final turns = <int, String>{};
  String preview = '';
}

extension GroupMemberActivities on ChatController {
  Listenable get groupSleepChanges => _groupSleeps;
  Map<String, DateTime> groupSleepTimes(String conversationId) =>
      _groupSleeps.forGroup(conversationId);
  List<GroupMemberActivity> get groupMemberActivities =>
      groupActivitiesFor(activeConversation.id, includeThoughts: false)
          .where((activity) => !activity.stopping && !activity.waitingForUser)
          .toList();

  void _recordGroupThought(
    String senderId,
    String runId,
    int turn,
    String text,
  ) {
    if (_callbacksDisposed) return;
    final cache = _execution.groupThoughts;
    if (cache[senderId]?.runId != runId) {
      cache[senderId] = _GroupMemberThoughts(runId);
    }
    final thoughts = cache[senderId]!;
    thoughts.turns[turn] = text;
    final latest = text.trimRight();
    final lineStart = latest.lastIndexOf('\n') + 1;
    // Keep the growing end visible instead of repeating a truncated first line.
    final start = latest.length - lineStart > 120
        ? latest.length - 120
        : lineStart;
    thoughts.preview = latest.substring(start).trim();
    groupActivityChanges.value++;
  }

  List<GroupMemberActivity> groupActivitiesFor(
    String conversationId, {
    bool includeThoughts = true,
  }) {
    final state = _executionStates[conversationId];
    final conversation = state?.runningConversation;
    if (conversation?.kind != ConversationKind.group ||
        conversation?.runState != ChatRunState.running) {
      return const [];
    }
    final activities = <GroupMemberActivity>[];
    for (final entry in state!.groupSenders.entries) {
      final member = state.groupRuns[entry.key];
      if (member == null ||
          (member.runState != ChatRunState.running &&
              member.runState != ChatRunState.stopping) ||
          member.activeRunId == null ||
          member.executionWatch?.isRunning != true ||
          state.removedGroupMembers.contains(entry.key)) {
        continue;
      }
      final step = member.steps
          .where((step) => step.status == AgentStepStatus.running)
          .lastOrNull;
      if (step?.toolName == 'sleepGroupChat') continue;
      final confirming = state.confirmingSenderId == entry.key;
      var waitingForAction = false;
      if (step?.resultJson != null) {
        final result = jsonDecode(step!.resultJson!) as Map;
        waitingForAction = (result['userAction'] as Map?)?['pending'] == true;
      }
      final stopping = member.runState == ChatRunState.stopping;
      final thoughts = state.groupThoughts[entry.key];
      final hasThoughts =
          includeThoughts && thoughts?.runId == member.activeRunId;
      activities.add(
        GroupMemberActivity(
          sender: entry.value,
          runId: member.activeRunId!,
          elapsed: member.executionWatch!.elapsed,
          stopping: stopping,
          waitingForUser:
              confirming || waitingForAction || step?.toolName == 'askUser',
          thoughts: hasThoughts
              ? List.unmodifiable(thoughts!.turns.values)
              : const [],
          preview: hasThoughts ? thoughts!.preview : '',
          description: stopping
              ? '正在终止'
              : confirming
              ? '等待你的授权'
              : waitingForAction
              ? '等待你的操作'
              : step?.toolName == 'askUser'
              ? '等待你的回答'
              : member.reconnectAttempt > 0
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

  Future<void> stopGroupMember({
    required String conversationId,
    required String senderId,
    required String runId,
  }) async {
    final state = _executionStates[conversationId];
    final member = state?.groupRuns[senderId];
    // A row can finish or start a new run between rendering and the tap.
    if (state?.runningConversation == null ||
        member == null ||
        member.activeRunId != runId ||
        member.executionWatch?.isRunning != true ||
        (member.runState != ChatRunState.running &&
            member.runState != ChatRunState.stopping)) {
      return;
    }
    await _inConversation(state!.runningConversation!, () async {
      final runtime = _groupRuntimes[senderId];
      member.runState = ChatRunState.stopping;
      _execution.groupReplyDrafts.remove(senderId);
      _groupDispatcher?.interrupt(senderId);
      final confirming = _confirmingSenderId == senderId;
      if (confirming && pendingConfirmation != null) resolveConfirmation(false);
      if (runtime?.activeToolName == 'requestAccessibilityAccess') {
        _finishAccessibility({
          'granted': false,
          'reason': 'User stopped the task',
        });
      }
      notifyListeners();
      await Future.wait([
        if (runtime != null) runtime.cancel(),
        _groupSleeps.remove(conversationId, senderId),
        if (confirming && _groupToolQueue.isOwnedBy(_execution))
          _platform.cancelPendingInteraction(),
      ]);
    });
  }
}
