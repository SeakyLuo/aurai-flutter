import 'dart:async';

import '../../../agent/agent_runtime.dart';
import '../../../agent/ask_user_tool.dart';
import '../../../domain/agent_models.dart';
import '../../../domain/ai_profile.dart';
import '../../../domain/model_provider.dart';
import '../../../domain/message_sender.dart';
import '../../../domain/live_project_changes.dart';
import '../conversation.dart';
import '../group_dispatcher.dart';
import 'pending_confirmation.dart';

typedef ExecutionReplyContext = ({
  String senderId,
  MessageSender sender,
  ModelConfig config,
  String? systemPrompt,
  AiProfile profile,
});

class GroupMemberThoughts {
  GroupMemberThoughts(this.runId);
  final String runId;
  final turns = <Object, AgentTaskActivity>{};
  final steps = <int, AgentStep>{};
  Object? latest;
}

/// Each asynchronous run retains its own state even when the visible chat changes.
class ConversationExecutionSession {
  ConversationExecutionSession(this._onChanged);

  final void Function() _onChanged;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) _onChanged();
  }

  Conversation? conversation;
  int attachmentJobs = 0;
  bool forwardingMessage = false;
  bool forwardedReplyPending = false;
  String? queuedUserMessageId;
  bool submitting = false;
  Completer<void>? _runFinished;
  Future<void>? get runFinished => _runFinished?.future;
  Completer<void>? _privateRunFinished;
  Future<void>? get privateRunFinished => _privateRunFinished?.future;
  AgentRuntime? runtime;
  final userInputs = <Future<List<Map<String, Object?>>>>[];
  final liveUserMessageIds = <String>{};
  bool systemEventLoading = false;
  GroupDispatcher? _groupDispatcher;
  GroupDispatcher? get groupDispatcher => _groupDispatcher;
  String? groupNotificationStep;
  Map<String, ExecutionReplyContext> groupReplies = {};
  Map<String, MessageSender> groupSenders = {};
  Map<String, Conversation> groupRuns = {};
  Map<String, GroupMemberThoughts> groupThoughts = {};
  Set<String> hiddenThinkingMembers = {};
  final liveProjectChanges = <String, List<LiveProjectChanges>>{};
  Map<String, String> groupReplyDrafts = {};
  final groupContinuationRuns = <String, String>{};
  Set<String> removedGroupMembers = {};
  String? confirmingSenderId;
  Map<String, AgentRuntime> groupRuntimes = {};
  Map<String, String> groupStreaming = {};
  Conversation? _runningConversation;
  Conversation? get runningConversation => _runningConversation;
  Conversation? _privateConversation;
  Conversation? get privateConversation => _privateConversation;
  String? streamingMessageId;
  PendingConfirmation? _pendingConfirmation;
  PendingConfirmation? get pendingConfirmation => _pendingConfirmation;
  UserQuestion? pendingQuestion;
  Completer<Map<String, Object?>>? accessibilityRequest;
  bool accessibilityRequestPending = false;
  Timer? accessibilityTimer;
  DateTime? accessibilityDeadline;
  bool accessibilitySettingsOpened = false;
  Set<String> deniedConfirmations = {};
  bool accessibilityDeclined = false;

  void setRunningConversation(Conversation? value) {
    if (value != null) {
      _runFinished ??= Completer<void>();
    } else {
      if (_runningConversation?.kind == ConversationKind.direct) {
        userInputs.clear();
        liveUserMessageIds.clear();
      }
      _runFinished?.complete();
      _runFinished = null;
    }
    _runningConversation = value;
    _notify();
  }

  void setPrivateConversation(Conversation? value) {
    if (value != null) {
      _privateRunFinished ??= Completer<void>();
    } else {
      userInputs.clear();
      liveUserMessageIds.clear();
      _privateRunFinished?.complete();
      _privateRunFinished = null;
    }
    _privateConversation = value;
    _notify();
  }

  bool submitInput(Future<List<Map<String, Object?>>> input) {
    if (_disposed) return false;
    if (runtime == null && conversation!.runState == ChatRunState.running) {
      userInputs.add(input);
      return true;
    }
    return runtime?.enqueueUserInput(input) == true;
  }

  Future<String> requestConfirmation(PendingConfirmation request) async {
    if (_disposed) return 'deny';
    _pendingConfirmation = request;
    _notify();
    final seconds = request.call.confirmationTimeoutSeconds;
    final timer = seconds == null
        ? null
        : Timer(Duration(seconds: seconds), () {
            if (identical(_pendingConfirmation, request)) {
              resolveConfirmation(false);
            }
          });
    try {
      final approved = await request.completer.future;
      return approved ? request.scope : 'deny';
    } finally {
      timer?.cancel();
    }
  }

  void resolveConfirmation(bool approved) {
    final request = _pendingConfirmation;
    if (request == null) return;
    _pendingConfirmation = null;
    request.completer.complete(approved);
    _notify();
  }

  GroupDispatcher startGroup({
    required List<AgentMessage> history,
    required Iterable<String> members,
    required Set<String> paused,
    required Map<String, GroupMute> mutedUntil,
    required Future<void> Function(String, List<AgentMessage>) respond,
    required Future<void> Function(String, Object) failed,
  }) {
    groupRuns.clear();
    groupThoughts.clear();
    hiddenThinkingMembers.clear();
    groupReplyDrafts.clear();
    return _groupDispatcher = GroupDispatcher(
      history: history,
      members: members,
      paused: paused,
      mutedUntil: mutedUntil,
      respond: respond,
      failed: failed,
    );
  }

  void finishGroup() {
    _groupDispatcher?.stop();
    _groupDispatcher = null;
    groupReplies.clear();
    groupSenders.clear();
    groupRuns.clear();
    groupThoughts.clear();
    hiddenThinkingMembers.clear();
    groupReplyDrafts.clear();
    groupContinuationRuns.clear();
    groupRuntimes.clear();
    groupStreaming.clear();
    _notify();
  }

  /// Mark stopping before any persistence or platform operation can yield.
  Conversation? beginStop() {
    queuedUserMessageId = null;
    userInputs.clear();
    final target = runningConversation;
    if (target == null || target.runState != ChatRunState.running) return null;
    target.runState = ChatRunState.stopping;
    groupReplyDrafts.clear();
    forwardedReplyPending = false;
    groupDispatcher?.stop();
    for (final member in groupRuns.values) {
      if (member.runState == ChatRunState.running) {
        member.runState = ChatRunState.stopping;
      }
    }
    _notify();
    return target;
  }

  Future<void> cancelRuntimes({bool includePrivate = false}) => Future.wait([
    if (runtime != null && (includePrivate || privateConversation == null))
      runtime!.cancel(),
    for (final runtime in groupRuntimes.values) runtime.cancel(),
  ]);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    groupDispatcher?.stop();
    resolveConfirmation(false);
    final question = pendingQuestion;
    if (question != null && !question.result.isCompleted) {
      question.result.complete({'cancelled': true});
    }
    accessibilityTimer?.cancel();
    accessibilityRequest?.complete({
      'granted': false,
      'reason': 'Conversation execution disposed',
    });
    accessibilityRequest = null;
    unawaited(cancelRuntimes(includePrivate: true));
  }
}
