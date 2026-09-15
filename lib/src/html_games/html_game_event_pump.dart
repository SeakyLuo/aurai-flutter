import 'dart:async';
import 'dart:developer' as developer;
import 'html_game.dart';
import 'html_game_session.dart';
import 'html_game_store.dart';

class HtmlGameEventPump {
  HtmlGameEventPump(this.store, this.busy, this.wake);
  final HtmlGameStore store;
  final bool Function() busy;
  final Future<void> Function(String, Set<String>) wake;
  Timer? _timer;
  StreamSubscription<String>? _changes;
  bool _draining = false;
  final _waking = <String>{};
  bool _disposed = false;

  void start() {
    if (!HtmlGameFeature.enabled) return;
    _changes = HtmlGameSignals.changes.stream.listen((_) => unawaited(drain()));
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(drain()),
    );
    unawaited(drain());
  }

  Future<void> drain() async {
    if (_disposed || _draining || busy() || !HtmlGameFeature.enabled) return;
    _draining = true;
    try {
      final pending = await store.pendingWake();
      if (pending.isEmpty || _disposed || busy()) return;
      final groups = <String, Set<String>>{};
      for (final receipt in pending) {
        groups
            .putIfAbsent(receipt['conversation_id'] as String, () => {})
            .add(receipt['sender_id'] as String);
      }
      for (final entry in groups.entries) {
        if (_waking.add(entry.key)) {
          unawaited(_wakeConversation(entry.key, entry.value));
        }
      }
    } on Object catch (error, stack) {
      developer.log(
        'HTML game event delivery failed',
        name: 'aurai.html_game',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _draining = false;
    }
  }

  Future<void> _wakeConversation(String id, Set<String> members) async {
    try {
      await wake(id, members);
    } on Object catch (error, stack) {
      developer.log(
        'HTML game conversation wake failed',
        name: 'aurai.html_game',
        error: error,
        stackTrace: stack,
      );
    } finally {
      _waking.remove(id);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _changes?.cancel();
  }
}
