import 'dart:async';
import 'dart:collection';

import '../conversation.dart';
import '../pending_message_queue.dart';
import 'conversation_execution_session.dart';

/// Owns execution sessions independently of the currently displayed conversation.
class ConversationExecutionManager {
  ConversationExecutionManager({required this.onChanged});

  final void Function() onChanged;
  final _zoneKey = Object();
  final _sessions = <String, ConversationExecutionSession>{};
  final _pendingMessageQueues = <String, PendingMessageQueue>{};
  PendingMessageQueue pendingMessages(String id) =>
      _pendingMessageQueues.putIfAbsent(id, PendingMessageQueue.new);

  void restorePendingMessages(String id, PendingMessageQueue queue) {
    _pendingMessageQueues[id] = queue;
  }

  void removePendingMessages(String id) => _pendingMessageQueues.remove(id);

  final _leases = <String, int>{};
  bool _disposed = false;
  late ConversationExecutionSession _visible = _createSession();

  Map<String, ConversationExecutionSession> get sessions =>
      UnmodifiableMapView(_sessions);
  ConversationExecutionSession get visible => _visible;
  ConversationExecutionSession get current =>
      Zone.current[_zoneKey] as ConversationExecutionSession? ?? _visible;

  ConversationExecutionSession _createSession() =>
      ConversationExecutionSession(() {
        if (!_disposed) onChanged();
      });

  bool _canRelease(String id, ConversationExecutionSession session) =>
      (_leases[id] ?? 0) == 0 &&
      _pendingMessageQueues[id]?.busy != true &&
      session.runningConversation == null &&
      session.privateConversation == null &&
      !session.submitting &&
      session.attachmentJobs == 0 &&
      !session.forwardingMessage &&
      !session.systemEventLoading;

  void show(Conversation conversation) {
    final retired = _sessions.entries
        .where(
          (entry) =>
              entry.key != conversation.id &&
              _canRelease(entry.key, entry.value),
        )
        .toList();
    for (final entry in retired) {
      _sessions.remove(entry.key);
      entry.value.dispose();
    }
    _visible = _sessions.putIfAbsent(conversation.id, _createSession)
      ..conversation = conversation;
  }

  Future<T> run<T>(Conversation conversation, Future<T> Function() action) {
    if (_disposed)
      throw StateError('Conversation execution manager is disposed');
    final session = _sessions.putIfAbsent(conversation.id, _createSession)
      ..conversation = conversation;
    return runZoned(() async {
      _leases.update(conversation.id, (count) => count + 1, ifAbsent: () => 1);
      try {
        return await action();
      } finally {
        final remaining = _leases[conversation.id]! - 1;
        if (remaining == 0) {
          _leases.remove(conversation.id);
        } else {
          _leases[conversation.id] = remaining;
        }
        if (!identical(session, _visible) &&
            _canRelease(conversation.id, session)) {
          _sessions.remove(conversation.id);
          session.dispose();
        }
      }
    }, zoneValues: {_zoneKey: session});
  }

  Conversation? liveConversation(String id) {
    final session = _sessions[id];
    return session != null &&
            (session.runningConversation != null ||
                session.privateConversation != null ||
                _pendingMessageQueues[id]?.busy == true ||
                session.submitting ||
                session.attachmentJobs > 0 ||
                session.forwardingMessage ||
                session.systemEventLoading)
        ? session.conversation
        : null;
  }

  void dispose() {
    _disposed = true;
    for (final session in _sessions.values) {
      session.dispose();
    }
  }
}
