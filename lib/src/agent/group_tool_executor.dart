import 'dart:async';
import '../domain/ui_tool_actions.dart';
import '../domain/tool_models.dart';
import 'tool_executor.dart';

class GroupToolQueue {
  Future<void> _tail = Future.value();
  Object? _owner;
  late final mutations = GroupToolQueue();
  int surfaceRevision = 0;
  final observations = Expando<int>();
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
    this.surfaceOwner,
  });
  final GroupToolQueue queue;
  final Object? owner;
  final Object? surfaceOwner;
  final _stopped = Completer<void>();
  Future<void> get cancellation => _stopped.future;
  final bool Function() cancelled;
  final Future<void> Function() waitForInteraction;

  @override
  Future<ToolResult> execute(ToolCall call) {
    Future<ToolResult> perform() => cancelled() || _stopped.isCompleted
        ? Future.value(
            ToolResult(
              callId: call.id,
              toolName: call.name,
              status: ToolResultStatus.cancelled,
              output: const {'cancelled': true, 'performed': false},
            ),
          )
        : super.execute(call);
    if (call.name == 'askUser') {
      return Future.any([
        queue.questionsFor(owner ?? this).run(() async {
          await waitForInteraction();
          return perform();
        }),
        _stopped.future.then(
          (_) => ToolResult(
            callId: call.id,
            toolName: call.name,
            status: ToolResultStatus.cancelled,
            output: const {'performed': false},
          ),
        ),
      ]);
    }
    return perform();
  }

  @override
  Future<bool> confirmTool(ToolCall call, ToolDefinition definition) async {
    return Future.any([
      queue.questionsFor(owner ?? this).run(() async {
        await waitForInteraction();
        return queue.run(
          () => cancelled() || _stopped.isCompleted
              ? Future.value(false)
              : super.confirmTool(call, definition),
          owner: owner,
        );
      }),
      _stopped.future.then((_) => false),
    ]);
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
        definition.waitsForUser && call.name != 'askUser' || deviceSurface;
    Future<ToolResult> perform() async {
      if (cancelled() || _stopped.isCompleted) {
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: ToolResultStatus.cancelled,
          output: const {'performed': false},
        );
      }
      final actor = surfaceOwner ?? this;
      final observation = const {
        'observeDevice',
        'captureScreen',
        'waitForUi',
      }.contains(call.name);
      final targetingScreen =
          call.name == 'tapScreen' ||
          const {
            'clickUiElement',
            'inputUiText',
            'scrollUiForward',
            'scrollUiBackward',
          }.contains(call.name);
      if (targetingScreen &&
          queue.observations[actor] != queue.surfaceRevision) {
        return ToolResult(
          callId: call.id,
          toolName: call.name,
          status: ToolResultStatus.error,
          output: const {
            'performed': false,
            'error': '手机界面可能已被其他执行者改变，请重新观察后再操作。',
          },
        );
      }
      if (deviceSurface && !observation) queue.surfaceRevision++;
      final result = await action();
      if (observation && result.status == ToolResultStatus.success) {
        queue.observations[actor] = queue.surfaceRevision;
      }
      return result;
    }

    if (exclusive)
      return waitForInteraction().then(
        (_) => queue.mutations.run(() => queue.run(perform, owner: owner)),
      );
    if (definition.safetyFor(call.arguments) != ToolSafety.readOnly &&
        call.name != 'askUser' &&
        call.name != 'runSubagent') {
      return queue.mutations.run(perform);
    }
    return perform();
  }

  @override
  Future<void> cancel() async {
    if (!_stopped.isCompleted) _stopped.complete();
    await super.cancel();
  }
}
