import 'dart:async';
import '../domain/tool_models.dart';
import 'deferred_tool.dart';

/// Owns deferred result delivery for one runtime, including UI persistence.
class DeferredToolResults {
  DeferredToolResults(this.onUpdate);
  final Future<void> Function(ToolResult) onUpdate;
  final _watching = <DeferredAgentTool, Future<void>>{};
  final _results = <ToolResult>[];
  final _errors = <(Object, StackTrace)>[];
  Completer<void> _changed = Completer<void>();
  bool _closed = false;

  bool get hasPending => _watching.isNotEmpty;
  bool get hasUpdates => _results.isNotEmpty || _errors.isNotEmpty;

  void watch(DeferredAgentTool tool) {
    if (_closed || _watching.containsKey(tool)) return;
    final job = _drain(tool);
    _watching[tool] = job;
    unawaited(
      job.then(
        (_) {
          _watching.remove(tool);
          wake();
        },
        onError: (Object error, StackTrace stack) {
          // Storage/update failures are rethrown at the parent runtime boundary.
          _errors.add((error, stack));
          _watching.remove(tool);
          wake();
        },
      ),
    );
  }

  Future<void> _drain(DeferredAgentTool tool) async {
    while (tool.hasPending || tool.hasUpdates) {
      final updates = tool.takeUpdates();
      for (final result in updates) {
        await onUpdate(result);
        if (result.output['pending'] != true) {
          _results.add(result);
          wake();
        }
      }
      if (tool.hasPending && !tool.hasUpdates) await tool.waitForPending();
    }
  }

  List<ToolResult> takeUpdates() {
    throwIfFailed();
    final result = List<ToolResult>.of(_results);
    _results.clear();
    return result;
  }

  void throwIfFailed() {
    if (_errors.isNotEmpty) {
      final (error, stack) = _errors.removeAt(0);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> waitForChange() => hasUpdates ? Future.value() : _changed.future;
  void wake() {
    _changed.complete();
    _changed = Completer<void>();
  }

  Future<void> close() async {
    _closed = true;
    final pending = Map.of(_watching);
    await Future.wait([for (final tool in pending.keys) tool.cancel()]);
    await Future.wait(pending.values);
    throwIfFailed();
  }
}
