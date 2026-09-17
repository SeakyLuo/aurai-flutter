import 'dart:async';

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
      if (authors.contains(entry.key)) continue;
      if (paused.contains(entry.key) && !mentions.contains(entry.key)) continue;
      if (mentions.contains(entry.key)) {
        entry.value.timer?.cancel();
        entry.value.timer = null;
        entry.value.sleepUntil = null;
      }
      _markPending(entry.value);
      _schedule(entry.key, entry.value);
    }
  }

  void receiveTargeted(
    List<AgentMessage> messages,
    Set<String> recipients,
  ) {
    history.addAll(messages);
    for (final id in recipients) {
      final mailbox = _members[id];
      if (mailbox == null) continue;
      mailbox.timer?.cancel();
      mailbox.timer = null;
      mailbox.sleepUntil = null;
      _markPending(mailbox);
      _schedule(id, mailbox);
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
      mailbox.sleepUntil = null;
    }
    _finishIfIdle();
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

  DateTime? sleepUntil(String id, DateTime? until) {
    if (stopped || closed || !_members.containsKey(id)) {
      throw StateError('群聊已停止');
    }
    if (paused.contains(id)) throw StateError('已暂停自动接话，不能安排唤醒');
    final mailbox = _members[id]!;
    mailbox.sleepUntil = until;
    return until;
  }

  void restoreSleeps(Map<String, DateTime> sleeps) {
    for (final entry in sleeps.entries) {
      final mailbox = _members[entry.key];
      if (mailbox != null && !paused.contains(entry.key)) {
        mailbox.sleepUntil = entry.value;
      }
    }
  }

  bool wokeFromSleep(String id) => _members[id]!.wokeFromSleep;

  void _markPending(_Mailbox mailbox) {
    mailbox.pending = true;
  }

  void _schedule(String id, _Mailbox mailbox) {
    if (stopped || mailbox.active || mailbox.timer != null) return;
    mailbox.timer = Timer(
      mailbox.sleepUntil?.difference(DateTime.now()) ?? Duration.zero,
      () {
        mailbox.wokeFromSleep = mailbox.sleepUntil != null;
        mailbox.sleepUntil = null;
        mailbox.timer = null;
        mailbox.active = true;
        _activeCount++;
        mailbox.pending = false;
        final snapshot = List<AgentMessage>.unmodifiable(history);
        unawaited(_run(id, mailbox, snapshot));
      },
    );
  }

  Future<void> _run(
    String id,
    _Mailbox mailbox,
    List<AgentMessage> snapshot,
  ) async {
    try {
      await respond(id, snapshot);
    } on Object catch (error) {
      mailbox.sleepUntil = null;
      await failed(id, error);
    } finally {
      mailbox.active = false;
      _activeCount--;
      if (!stopped &&
          identical(_members[id], mailbox) &&
          (mailbox.pending || mailbox.sleepUntil != null)) {
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
  DateTime? sleepUntil;
  bool wokeFromSleep = false;
  bool active = false;
  bool pending = false;
}
