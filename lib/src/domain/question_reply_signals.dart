import 'dart:async';

/// A live task consumes its answer directly; other cards use stored callbacks.
class QuestionReplySignals {
  static final _waiting = <String, Completer<Map<String, Object?>>>{};
  static final _blocking = <String>{};
  static bool isWaiting(String messageId) => _blocking.contains(messageId);
  static Future<Map<String, Object?>> wait(
    String messageId, {
    required bool blocking,
  }) {
    if (blocking) _blocking.add(messageId);
    return (_waiting[messageId] = Completer<Map<String, Object?>>()).future;
  }

  static void release(String messageId) {
    _waiting.remove(messageId);
    _blocking.remove(messageId);
  }

  static void complete(String messageId, List answers) {
    final pending = _waiting.remove(messageId);
    _blocking.remove(messageId);
    pending?.complete({
      'answers': answers,
      if (answers.every((a) => a['skipped'] == true)) 'skipped': true,
    });
  }
}
