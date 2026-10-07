import 'dart:async';

abstract final class MemoryEvents {
  static final _changes = StreamController<String>.broadcast();
  static Stream<String> get changes => _changes.stream;
  static void changed(String ownerId) => _changes.add(ownerId);
}
