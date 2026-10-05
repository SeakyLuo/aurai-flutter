part of 'chat_controller.dart';

extension ConversationExecutionState on ChatController {
  ConversationExecutionSession get _execution => _executions.current;

  Future<T> _inConversation<T>(
    Conversation conversation,
    Future<T> Function() action,
  ) => _executions.run(conversation, action);

  Conversation? _liveConversation(String id) =>
      _executions.liveConversation(id);

  void _disposeExecutions() {
    _callbackMuteExpiry?.cancel();
    _executions.dispose();
  }

  Future<void> _stopNotificationConversation(String? id) async {
    if (id == null) {
      await stop();
      return;
    }
    final conversation = _liveConversation(id);
    if (conversation != null)
      await _inConversation(conversation, _stopConversation);
  }

  Future<void> stop() => _inConversation(activeConversation, _stopConversation);

  Future<void> _stopConversation() async {
    pendingMessageQueue.paused = true;
    _execution.queuedUserMessageId = null;
    _execution.userInputs.clear();
    if (identical(activeConversation, _privateConversation)) {
      _privateConversation!.runState = ChatRunState.stopping;
      await _runtime?.cancel();
      return;
    }
    final conversation = _execution.beginStop();
    if (conversation == null) return;
    _queuedSystemNotices.remove(conversation.id);
    if (conversation.kind == ConversationKind.group) {
      await _groupSleeps.remove(conversation.id);
    }
    await _persistRun(conversation);
    _execution.resolveConfirmation(false);
    _finishAccessibility({'granted': false, 'reason': 'User stopped the task'});
    if (_groupToolQueue.isOwnedBy(_execution)) {
      await _platform.cancelPendingInteraction();
    }
    await _execution.cancelRuntimes();
  }

  bool get _submitting => _execution.submitting;
  set _submitting(bool value) => _execution.submitting = value;
  AgentRuntime? get _runtime => _execution.runtime;
  set _runtime(AgentRuntime? value) => _execution.runtime = value;
  bool get _systemEventLoading => _execution.systemEventLoading;
  set _systemEventLoading(bool value) => _execution.systemEventLoading = value;
  GroupDispatcher? get _groupDispatcher => _execution.groupDispatcher;
  Map<String, ExecutionReplyContext> get _groupReplies =>
      _execution.groupReplies;
  Map<String, MessageSender> get _groupSenders => _execution.groupSenders;
  Map<String, Conversation> get _groupRuns => _execution.groupRuns;
  Set<String> get _removedGroupMembers => _execution.removedGroupMembers;
  String? get _confirmingSenderId => _execution.confirmingSenderId;
  set _confirmingSenderId(String? value) =>
      _execution.confirmingSenderId = value;
  Map<String, AgentRuntime> get _groupRuntimes => _execution.groupRuntimes;
  Map<String, String> get _groupStreaming => _execution.groupStreaming;
  Conversation? get _runningConversation => _execution.runningConversation;
  set _runningConversation(Conversation? value) {
    if (value == null) _callbacksPending = true;
    _execution.setRunningConversation(value);
  }

  Conversation? get _privateConversation => _execution.privateConversation;
  set _privateConversation(Conversation? value) =>
      _execution.setPrivateConversation(value);

  String? get streamingMessageId => _execution.streamingMessageId;
  set streamingMessageId(String? value) =>
      _execution.streamingMessageId = value;
  PendingConfirmation? get pendingConfirmation =>
      _execution.pendingConfirmation;
  UserQuestion? get pendingQuestion => _execution.pendingQuestion;
  set pendingQuestion(UserQuestion? value) =>
      _execution.pendingQuestion = value;
  Completer<Map<String, Object?>>? get _accessibilityRequest =>
      _execution.accessibilityRequest;
  set _accessibilityRequest(Completer<Map<String, Object?>>? value) =>
      _execution.accessibilityRequest = value;
  bool get accessibilityRequestPending =>
      _execution.accessibilityRequestPending;
  set accessibilityRequestPending(bool value) =>
      _execution.accessibilityRequestPending = value;
  Timer? get _accessibilityTimer => _execution.accessibilityTimer;
  set _accessibilityTimer(Timer? value) =>
      _execution.accessibilityTimer = value;
  DateTime? get accessibilityDeadline => _execution.accessibilityDeadline;
  set accessibilityDeadline(DateTime? value) =>
      _execution.accessibilityDeadline = value;
  bool get _accessibilitySettingsOpened =>
      _execution.accessibilitySettingsOpened;
  set _accessibilitySettingsOpened(bool value) =>
      _execution.accessibilitySettingsOpened = value;
  Set<String> get _deniedConfirmations => _execution.deniedConfirmations;
  bool get _accessibilityDeclined => _execution.accessibilityDeclined;
  set _accessibilityDeclined(bool value) =>
      _execution.accessibilityDeclined = value;
}
