import 'dart:async';
import '../domain/ui_tool_actions.dart';
import '../domain/tool_models.dart';
import 'tool_executor.dart';

class GroupToolQueue {
  Future<void> _tail = Future.value();
  Object? _owner;
  final _conversationQuestions = Expando<GroupToolQueue>();

  GroupToolQueue questionsFor(Object owner) =>
      _conversationQuestions[owner] ??= GroupToolQueue();
  bool isOwnedBy(Object owner) => identical(_owner, owner);

  Future<T> run<T>(Future<T> Function() action, {Object? owner}) {
    final next = _tail.then((_) async {
      _owner = owner;
      try {
        return await action();
      } finally {
        _owner = null;
      }
    });
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
}

class GroupToolExecutor extends ToolExecutor {
  GroupToolExecutor({
    required super.registry,
    required super.confirm,
    required this.queue,
    required this.cancelled,
    required this.waitForInteraction,
    this.owner,
  });
  final GroupToolQueue queue;
  final Object? owner;
  final bool Function() cancelled;
  final Future<void> Function() waitForInteraction;

  @override
  Future<ToolResult> execute(
    ToolCall call, {
    void Function(ToolResult)? onWaitingForUser,
  }) {
    Future<ToolResult> perform() => cancelled()
        ? Future.value(
            ToolResult(
              callId: call.id,
              toolName: call.name,
              status: ToolResultStatus.cancelled,
              output: const {'cancelled': true, 'performed': false},
            ),
          )
        : super.execute(call, onWaitingForUser: onWaitingForUser);
    if (call.name == 'askUser' && call.userAction == null) {
      return queue.questionsFor(owner ?? this).run(() async {
        await waitForInteraction();
        return perform();
      });
    }
    return perform();
  }

  @override
  Future<bool> confirmTool(ToolCall call, ToolDefinition definition) async {
    await waitForInteraction();
    return queue.run(
      () => cancelled()
          ? Future.value(false)
          : super.confirmTool(call, definition),
      owner: owner,
    );
  }

  @override
  Future<ToolResult> runAuthorizedTool(
    ToolCall call,
    ToolDefinition definition,
    Future<ToolResult> Function() action,
  ) {
    // Device mutations and user dialogs share one surface; read-only work can overlap.
    // Hold the shared surface only during device work and explicit handoff.
    final deviceSurface =
        isScreenTool(call.name) ||
        const {
          'observeDevice',
          'waitForUi',
          'launchApp',
          'startIntent',
          'openSettings',
          'openAppPage',
          'executeAndroidScript',
          'executeShizuku',
          'runSkill',
          'requestAccessibilityAccess',
        }.contains(call.name);
    final exclusive =
        call.userAction != null ||
        definition.waitsForUser && call.name != 'askUser' ||
        deviceSurface;
    return exclusive
        ? waitForInteraction().then((_) => queue.run(action, owner: owner))
        : action();
  }
}
