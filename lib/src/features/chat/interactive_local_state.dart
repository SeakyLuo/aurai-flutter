import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../storage/interactive_selection_drafts.dart';

/// Shared by simultaneous views of the same message, scoped to the viewer.
class InteractiveLocalState extends ChangeNotifier {
  InteractiveLocalState._(
    this.id,
    this.messageId,
    this.actorId,
    this.version,
    this.values,
  );
  static final _mounted = <String, InteractiveLocalState>{};
  final String? id, messageId;
  final String actorId, version;
  Map<String, Object?> values;
  int _users = 1;
  bool busy = false;

  static InteractiveLocalState acquire({
    required String? messageId,
    required String actorId,
    required Map<String, Object?> initial,
    required bool persist,
  }) {
    final version = jsonEncode(initial);
    final id = persist && messageId != null
        ? jsonEncode([messageId, actorId, version])
        : null;
    final existing = _mounted[id];
    if (existing != null) {
      existing._users++;
      return existing;
    }
    final raw = id == null
        ? null
        : InteractiveSelectionDrafts.instance.readOtherText(
            messageId!,
            actorId,
            '@local',
            version,
          );
    final state = InteractiveLocalState._(
      id,
      messageId,
      actorId,
      version,
      raw == null
          ? Map.of(initial)
          : Map<String, Object?>.from(jsonDecode(raw) as Map),
    );
    if (id != null) _mounted[id] = state;
    return state;
  }

  Future<void> update(
    Future<Map<String, Object?>> Function(Map<String, Object?>) change,
  ) async {
    if (busy) throw StateError('正在保存上一次操作');
    busy = true;
    notifyListeners();
    try {
      final next = await change(Map.of(values));
      if (id != null && jsonEncode(next) != jsonEncode(values)) {
        await InteractiveSelectionDrafts.instance.save(
          messageId!,
          actorId,
          '@local',
          version,
          {},
          otherText: jsonEncode(next),
        );
      }
      values = next;
    } finally {
      busy = false;
      if (_users > 0)
        notifyListeners();
      else {
        if (id != null) _mounted.remove(id);
        super.dispose();
      }
    }
  }

  void release() {
    _users--;
    if (_users == 0) {
      if (!busy) {
        if (id != null) _mounted.remove(id);
        super.dispose();
      }
    }
  }
}
