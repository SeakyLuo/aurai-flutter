part of 'chat_controller.dart';

final _executionZoneKey = Object();

/// Each asynchronous run retains its own state even when the visible chat changes.
class _ConversationExecutionState {
  Conversation? conversation;
  int leases = 0;
  bool forwardedReplyPending = false;
  bool submitting = false;
  AgentRuntime? runtime;
  bool systemEventLoading = false;
  GroupDispatcher? groupDispatcher;
  Map<String, _ReplyContext> groupReplies = {};
  Map<String, MessageSender> groupSenders = {};
  Map<String, Conversation> groupRuns = {};
  Set<String> removedGroupMembers = {};
  String? confirmingSenderId;
  Map<String, AgentRuntime> groupRuntimes = {};
  Map<String, String> groupStreaming = {};
  Conversation? runningConversation;
  Conversation? privateConversation;
  String? streamingMessageId;
  PendingConfirmation? pendingConfirmation;
  UserQuestion? pendingQuestion;
  Completer<Map<String, Object?>>? accessibilityRequest;
  bool accessibilityRequestPending = false;
  Timer? accessibilityTimer;
  DateTime? accessibilityDeadline;
  bool accessibilitySettingsOpened = false;
  Set<String> deniedConfirmations = {};
  bool accessibilityDeclined = false;
}

extension ConversationExecutionState on ChatController {
  _ConversationExecutionState get _execution =>
      Zone.current[_executionZoneKey] as _ConversationExecutionState? ??
      _viewExecution;

  Future<T> _inConversation<T>(
    Conversation conversation,
    Future<T> Function() action,
  ) {
    final state = _executionStates.putIfAbsent(
      conversation.id,
      _ConversationExecutionState.new,
    );
    state.conversation = conversation;
    return runZoned(() async {
      state.leases++;
      try {
        return await action();
      } finally {
        state.leases--;
        if (state.leases == 0 &&
            state.runningConversation == null &&
            !identical(state, _viewExecution))
          _executionStates.remove(conversation.id);
      }
    }, zoneValues: {_executionZoneKey: state});
  }

  Conversation? _liveConversation(String id) {
    final state = _executionStates[id];
    return state != null &&
            (state.runningConversation != null ||
                state.submitting ||
                state.systemEventLoading)
        ? state.conversation
        : null;
  }

  void _disposeExecutions() {
    for (final state in _executionStates.values) {
      state.groupDispatcher?.stop();
      unawaited(state.runtime?.cancel());
      for (final runtime in state.groupRuntimes.values) {
        unawaited(runtime.cancel());
      }
      state.accessibilityTimer?.cancel();
    }
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
    if (identical(activeConversation, _privateConversation)) {
      _privateConversation!.runState = ChatRunState.stopping;
      await _runtime?.cancel();
      return;
    }
    final conversation = _runningConversation;
    if (conversation == null || conversation.runState != ChatRunState.running) {
      return;
    }
    conversation.runState = ChatRunState.stopping;
    _execution.forwardedReplyPending = false;
    _queuedSystemNotices.remove(conversation.id);
    _groupDispatcher?.stop();
    if (conversation.kind == ConversationKind.group)
      await _groupSleeps.remove(conversation.id);
    for (final member in _groupRuns.values) {
      if (member.runState == ChatRunState.running)
        member.runState = ChatRunState.stopping;
    }

    notifyListeners();
    await _persistRun(conversation);
    pendingConfirmation?.completer.complete(false);
    pendingConfirmation = null;
    _finishAccessibility({'granted': false, 'reason': 'User stopped the task'});
    if (_groupToolQueue.isOwnedBy(_execution)) {
      await _platform.cancelPendingInteraction();
    }
    await Future.wait([
      if (_runtime != null && _privateConversation == null) _runtime!.cancel(),
      for (final runtime in _groupRuntimes.values) runtime.cancel(),
    ]);
  }

  bool get _submitting => _execution.submitting;
  set _submitting(bool value) => _execution.submitting = value;
  AgentRuntime? get _runtime => _execution.runtime;
  set _runtime(AgentRuntime? value) => _execution.runtime = value;
  bool get _systemEventLoading => _execution.systemEventLoading;
  set _systemEventLoading(bool value) => _execution.systemEventLoading = value;
  GroupDispatcher? get _groupDispatcher => _execution.groupDispatcher;
  set _groupDispatcher(GroupDispatcher? value) =>
      _execution.groupDispatcher = value;
  Map<String, _ReplyContext> get _groupReplies => _execution.groupReplies;
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
    _execution.runningConversation = value;
    if (value == null) _callbacksPending = true;
  }

  Conversation? get _privateConversation => _execution.privateConversation;
  set _privateConversation(Conversation? value) =>
      _execution.privateConversation = value;
  String? get streamingMessageId => _execution.streamingMessageId;
  set streamingMessageId(String? value) =>
      _execution.streamingMessageId = value;
  PendingConfirmation? get pendingConfirmation =>
      _execution.pendingConfirmation;
  set pendingConfirmation(PendingConfirmation? value) =>
      _execution.pendingConfirmation = value;
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
