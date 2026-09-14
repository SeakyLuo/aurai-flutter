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
      final id = pending.first['conversation_id'] as String;
      final members = pending
          .where((r) => r['conversation_id'] == id)
          .map((r) => r['sender_id'] as String)
          .toSet();
      await wake(id, members);
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

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _changes?.cancel();
  }
}
