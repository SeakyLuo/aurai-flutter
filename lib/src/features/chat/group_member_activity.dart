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
    this.activities = const [],
    this.preview = '',
    this.thinkingHidden = false,
    this.sleepingUntil,
    this.autoReplyPaused = false,
    this.autoReplyPauseReason,
    this.idle = false,
    this.mute,
  });

  final bool autoReplyPaused;
  final GroupMute? mute;
  bool get isMuted => mute?.isActive == true;
  final String? autoReplyPauseReason;
  final bool idle;
  final DateTime? sleepingUntil;
  bool get sleeping => sleepingUntil != null;
  final MessageSender sender;
  final String runId;
  final Duration elapsed;
  final String description;
  final bool stopping;
  final bool waitingForUser;
  final List<String> thoughts;
  final List<AgentTaskActivity> activities;
  final String preview;
  final bool thinkingHidden;
}

class _GroupMemberThoughts {
  _GroupMemberThoughts(this.runId);
  final String runId;
  final turns = <Object, AgentTaskActivity>{};
  final steps = <int, AgentStep>{};
  Object? latest;
}

extension GroupMemberActivities on ChatController {
  Future<void> setGroupMemberAutoReply(
    String groupId,
    String senderId, {
    required bool paused,
  }) async {
    await groupStore.requireManager(
      _store.database,
      groupId,
      MessageSender.localUser.id,
    );
    await groupStore.requireCanSpeak(groupId, senderId);
    await GroupParticipation(_store.database).set(
      groupId,
      senderId,
      paused,
      reason: paused ? '${MessageSender.localUser.name}暂停了自动接话' : null,
    );
    await _applyPrivateGroupParticipation(groupId, senderId, paused);
    groupActivityChanges.value++;
    notifyListeners();
  }

  Future<void> stopAllGroupReplies(String conversationId) async {
    final current = groupActivitiesFor(
      conversationId,
      includeThoughts: false,
    ).where((activity) => !activity.stopping).toList();
    await Future.wait([
      for (final activity in current)
        stopGroupMember(
          conversationId: conversationId,
          senderId: activity.sender.id,
          runId: activity.runId,
          currentOnly: true,
        ),
    ]);
  }

  Future<void> resumeGroupAutoReply(String groupId, String senderId) async {
    await groupStore.requireCanSpeak(groupId, senderId);
    await GroupParticipation(_store.database).set(groupId, senderId, false);
    await _applyPrivateGroupParticipation(groupId, senderId, false);
    groupActivityChanges.value++;
    notifyListeners();
  }

  Future<int> pauseAllGroupAutoReply(String groupId) async {
    await groupStore.requireManager(
      _store.database,
      groupId,
      MessageSender.localUser.id,
    );
    final ids = await GroupParticipation(
      _store.database,
    ).pauseAll(groupId, reason: '${MessageSender.localUser.name}暂停了全部成员的自动接话');
    final dispatcher = _executionStates[groupId]?.groupDispatcher;
    for (final id in ids) {
      dispatcher?.pause(id);
    }
    await Future.wait([stopAllGroupReplies(groupId), _groupSleeps.reload()]);
    groupActivityChanges.value++;
    notifyListeners();
    return ids.length;
  }

  Future<int> resumeAllGroupAutoReply(String groupId) async {
    await groupStore.requireManager(
      _store.database,
      groupId,
      MessageSender.localUser.id,
    );
    final ids = await GroupParticipation(_store.database).resumeAll(groupId);
    _executionStates[groupId]?.groupDispatcher?.paused.removeAll(ids);
    groupActivityChanges.value++;
    notifyListeners();
    return ids.length;
  }

  List<AgentTool> _thinkingTools(
    Conversation member,
    Conversation? parent,
    _ReplyContext reply,
  ) {
    member.thinkingHidden =
        parent != null &&
        _execution.hiddenThinkingMembers.contains(reply.senderId);
    final candidates = parent == null ? {reply.senderId: reply} : _groupReplies;
    final tool = HideThinkingTool((targets, excluded, all) {
      final unknown = {
        ...targets,
        ...excluded,
      }.difference(candidates.keys.toSet());
      if (unknown.isNotEmpty) throw StateError('只能隐藏当前会话中的 AI 成员思考');
      final requested = all
          ? candidates.keys.toSet()
          : targets.isEmpty
          ? {reply.senderId}
          : targets;
      final selected = requested.difference(excluded);
      final hidden = selected
          .where((id) => !_removedGroupMembers.contains(id))
          .toSet();
      if (parent == null) {
        if (hidden.contains(reply.senderId)) member.thinkingHidden = true;
      } else {
        _execution.hiddenThinkingMembers.addAll(hidden);
        for (final id in hidden) {
          final running = _groupRuns[id];
          if (running != null) running.thinkingHidden = true;
        }
      }
      _notifyMember(member, parent);
      groupActivityChanges.value++;
      return {
        'hiddenSenderIds': hidden.toList(),
        'excludedSenderIds': requested.intersection(excluded).toList(),
        'scope': parent == null ? 'current_task' : 'current_group_task',
      };
    });
    return [
      PeerAccessTool(tool, (call) async {
        final targets = (call.arguments['senderIds'] as List)
            .cast<String>()
            .toSet();
        final excluded = (call.arguments['excludeSenderIds'] as List)
            .cast<String>()
            .toSet();
        if ({
          ...targets,
          ...excluded,
        }.difference(candidates.keys.toSet()).isNotEmpty) {
          throw StateError('只能隐藏当前会话中的 AI 成员思考');
        }
        final selected =
            (call.arguments['all'] == true
                    ? candidates.keys.toSet()
                    : targets.isEmpty
                    ? {reply.senderId}
                    : targets)
                .difference(excluded);
        final sorted = selected.toList()..sort();
        return (
          approval: selected.any((id) => id != reply.senderId),
          scope: jsonEncode([parent?.id ?? member.id, sorted]),
          description:
              '隐藏${sorted.map((id) => candidates[id]!.sender.name).join('、')}本轮任务的可见思考',
        );
      }),
    ];
  }

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
    String text, {
    bool isReasoning = true,
    int messageIndex = 0,
  }) {
    if (_callbacksDisposed) return;
    final cache = _execution.groupThoughts;
    if (cache[senderId]?.runId != runId) {
      cache[senderId] = _GroupMemberThoughts(runId);
    }
    final thoughts = cache[senderId]!;
    final key = (turn, messageIndex, isReasoning);
    thoughts.turns[key] = AgentTaskActivity(
      text: text,
      isReasoning: isReasoning,
    );
    thoughts.latest = key;
    groupActivityChanges.value++;
  }

  void _recordGroupSteps(String senderId, String runId, List<AgentStep> steps) {
    if (_callbacksDisposed) return;
    final cache = _execution.groupThoughts;
    if (cache[senderId]?.runId != runId) {
      cache[senderId] = _GroupMemberThoughts(runId);
    }
    final thoughts = cache[senderId]!;
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (identical(thoughts.steps[i], step)) continue;
      thoughts.steps[i] = step;
      thoughts.turns[i] = AgentTaskActivity(
        text: step.title,
        toolName: step.toolName,
        status: step.status,
        requestJson: step.requestJson,
        resultJson: step.resultJson,
        startedAt: step.startedAt,
        finishedAt: step.finishedAt,
      );
      thoughts.latest = i;
    }
    groupActivityChanges.value++;
  }

  String _groupActivityPreview(String text) {
    final latest = text.trimRight();
    final lineStart = latest.lastIndexOf('\n') + 1;
    // Keep the growing end visible instead of repeating a truncated first line.
    final start = latest.length - lineStart > 120
        ? latest.length - 120
        : lineStart;
    return latest.substring(start).trim();
  }

  List<AgentTaskActivity>? groupRunActivities(
    String conversationId,
    String senderId,
    String runId,
  ) {
    final state = _executionStates[conversationId];
    final thoughts = state?.groupThoughts[senderId];
    if (thoughts == null || thoughts.runId != runId) return null;
    final hidden =
        state!.hiddenThinkingMembers.contains(senderId) ||
        state.groupRuns[senderId]?.thinkingHidden == true;
    return thoughts.turns.values
        .where((activity) => !hidden || !activity.isReasoning)
        .toList();
  }

  List<GroupMemberActivity> groupActivitiesFor(
    String conversationId, {
    bool includeThoughts = true,
    Set<String> pausedMembers = const {},
    Map<String, String> pausedReasons = const {},
    Map<String, GroupMute> mutedMembers = const {},
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
      final thoughts = state.groupThoughts[entry.key];
      final hasThoughts = thoughts?.runId == member.activeRunId;
      final step = (hasThoughts ? thoughts!.steps.values : member.steps)
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
      final visibleActivities = includeThoughts && hasThoughts
          ? thoughts!.turns.values
                .where(
                  (activity) => !member.thinkingHidden || !activity.isReasoning,
                )
                .toList()
          : const <AgentTaskActivity>[];
      final latest = hasThoughts ? thoughts!.turns[thoughts.latest] : null;
      final showStatus =
          stopping ||
          confirming ||
          waitingForAction ||
          step != null ||
          member.reconnectAttempt > 0;
      activities.add(
        GroupMemberActivity(
          sender: entry.value,
          runId: member.activeRunId!,
          elapsed: member.executionWatch!.elapsed,
          stopping: stopping,
          autoReplyPaused: pausedMembers.contains(entry.key),
          mute: mutedMembers[entry.key],
          autoReplyPauseReason: pausedReasons[entry.key],
          thinkingHidden: member.thinkingHidden,
          waitingForUser:
              confirming || waitingForAction || step?.toolName == 'askUser',
          activities: List.unmodifiable(visibleActivities),
          thoughts: List.unmodifiable(
            visibleActivities
                .where((activity) => activity.toolName == null)
                .map((activity) => activity.text),
          ),
          preview:
              !includeThoughts ||
                  showStatus ||
                  latest == null ||
                  (member.thinkingHidden && latest.isReasoning)
              ? ''
              : _groupActivityPreview(latest.text),
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
              : step?.title ?? '正在思考',
        ),
      );
    }
    return activities;
  }

  Future<void> stopGroupMember({
    required String conversationId,
    required String senderId,
    required String runId,
    bool currentOnly = false,
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
      if (!currentOnly) _groupDispatcher?.interrupt(senderId);
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
        if (!currentOnly) _groupSleeps.remove(conversationId, senderId),
        if (confirming && _groupToolQueue.isOwnedBy(_execution))
          _platform.cancelPendingInteraction(),
      ]);
    });
  }
}
