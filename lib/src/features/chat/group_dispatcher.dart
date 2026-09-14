import 'dart:async';
import 'dart:math';

import '../../domain/agent_models.dart';

/// One mailbox per member. A new arrival never restarts an existing delay.
class GroupDispatcher {
  GroupDispatcher({
    required List<AgentMessage> history,
    required Iterable<String> members,
    required this.respond,
    required this.failed,
    required this.paused,
  }) : history = List.of(history) {
    for (final id in members) {
      _members[id] = _Mailbox();
    }
  }

  final List<AgentMessage> history;
  final Future<void> Function(String senderId, List<AgentMessage> history)
  respond;
  final Future<void> Function(String senderId, Object error) failed;
  final Set<String> paused;
  final _members = <String, _Mailbox>{};
  final _random = Random();
  final _done = Completer<void>();
  bool stopped = false;
  int _activeCount = 0;
  int _holds = 0;
  bool get closed => _done.isCompleted;
  void hold() => _holds++;
  void release() {
    _holds--;
    _finishIfIdle();
  }

  Future<void> get done => _done.future;

  void receive(List<AgentMessage> messages, {Set<String> mentions = const {}}) {
    history.addAll(messages);
    final authors = messages.map((m) => m.senderId).toSet();
    for (final entry in _members.entries) {
      if (entry.value.failed || authors.contains(entry.key)) continue;
      if (paused.contains(entry.key) && !mentions.contains(entry.key)) continue;
      _markPending(entry.value);
      _schedule(entry.key, entry.value);
    }
  }

  void start(Iterable<String> recipients) {
    for (final id in recipients) {
      final mailbox = _members[id];
      if (mailbox == null) continue;
      _markPending(mailbox);
      _schedule(id, mailbox);
    }
    _finishIfIdle();
  }

  void pause(String id) {
    paused.add(id);
    final mailbox = _members[id];
    mailbox?.timer?.cancel();
    if (mailbox != null) {
      mailbox.timer = null;
      mailbox.pending = false;
    }
  }

  void remove(String id) {
    final mailbox = _members.remove(id);
    mailbox?.timer?.cancel();
    _finishIfIdle();
  }

  void add(String id) => _members.putIfAbsent(id, _Mailbox.new);

  void stop() {
    stopped = true;
    for (final mailbox in _members.values) {
      mailbox.timer?.cancel();
      mailbox.timer = null;
      mailbox.pending = false;
    }
    _finishIfIdle();
  }

  void _markPending(_Mailbox mailbox) {
    if (!mailbox.pending) {
      mailbox.readyAt = DateTime.now().add(
        Duration(milliseconds: _random.nextInt(15001)),
      );
    }
    mailbox.pending = true;
  }

  void _schedule(String id, _Mailbox mailbox) {
    if (stopped || mailbox.active || mailbox.timer != null) return;
    mailbox.timer = Timer(mailbox.readyAt.difference(DateTime.now()), () {
      mailbox.timer = null;
      mailbox.active = true;
      _activeCount++;
      mailbox.pending = false;
      final snapshot = List<AgentMessage>.unmodifiable(history);
      unawaited(_run(id, mailbox, snapshot));
    });
  }

  Future<void> _run(
    String id,
    _Mailbox mailbox,
    List<AgentMessage> snapshot,
  ) async {
    try {
      await respond(id, snapshot);
    } on Object catch (error) {
      mailbox.pending = false;
      mailbox.failed = !stopped && !paused.contains(id);
      await failed(id, error);
    } finally {
      mailbox.active = false;
      _activeCount--;
      if (!stopped && identical(_members[id], mailbox) && mailbox.pending) {
        _schedule(id, mailbox);
      }
      _finishIfIdle();
    }
  }

  /// A send attempt consumes the latest mailbox snapshot, including new arrivals.
  void acknowledge(String id) {
    _members[id]?.pending = false;
  }

  void _finishIfIdle() {
    if (!_done.isCompleted &&
        _activeCount == 0 &&
        _holds == 0 &&
        _members.values.every((m) => !m.active && m.timer == null)) {
      _done.complete();
    }
  }
}

class _Mailbox {
  Timer? timer;
  DateTime readyAt = DateTime.now();
  bool active = false;
  bool failed = false;
  bool pending = false;
}
