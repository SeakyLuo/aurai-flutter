import 'dart:async';

abstract final class MemoryEvents {
  static final _queueChanges = StreamController<void>.broadcast();
  static Stream<void> get queueChanges => _queueChanges.stream;
  static void wakeQueue() => _queueChanges.add(null);
  static final _changes = StreamController<String>.broadcast();
  static Stream<String> get changes => _changes.stream;
  static void changed(String ownerId) => _changes.add(ownerId);
}
