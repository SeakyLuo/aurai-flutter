import 'app_bottom_sheet.dart';
import 'private_goal_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import '../../storage/private_task_state.dart';
import 'chat_controller.dart';
import 'conversation_menu_icon.dart';
import 'delete_confirmation_dialog.dart';
import 'header_action_menu.dart';
import 'task_playback_icon.dart';
import 'private_task_list.dart';
import 'settings_icon.dart';
import 'composer_more_action.dart';
import 'task_elapsed.dart';

/// Listens to persisted goal changes for the composer and chat header.
/// The independent task list uses the same subscription and initial read.
class PrivateGoalPanel extends StatefulWidget {
  const PrivateGoalPanel({
    super.key,
    required this.store,
    required this.controller,
    required this.builder,
    this.showTasks = true,
  });
  final bool showTasks;
  final PrivateTaskState? store;
  final ChatController controller;
  final Widget Function(BuildContext, Widget?) builder;

  @override
  State<PrivateGoalPanel> createState() => _PrivateGoalPanelState();
}

class _PrivateGoalPanelState extends State<PrivateGoalPanel> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Map<String, dynamic> _state = {};
  int _revision = 0;
  Timer? _ticker;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _listen();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state['runningSince'] != null) setState(() {});
    });
  }

  @override
  void didUpdateWidget(PrivateGoalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store?.conversationId != widget.store?.conversationId ||
        oldWidget.store?.senderId != widget.store?.senderId) {
      _listen();
    }
  }

  void _listen() {
    _subscription?.cancel();
    _state = {};
    final revision = ++_revision;
    final store = widget.store;
    if (store == null) return;
    _subscription = store.changes.listen((state) {
      ++_revision;
      if (mounted) setState(() => _state = state);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || revision != _revision) return;
      await runUiAction(context, () async {
        final state = await store.read();
        if (mounted && revision == _revision) setState(() => _state = state);
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = (_state['steps'] as List? ?? const []).cast<Map>();
    if (_state['objective'] == null && steps.isEmpty) {
      return widget.builder(context, null);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showTasks && steps.isNotEmpty)
          PrivateTaskList(
            key: ValueKey((
              widget.store!.conversationId,
              widget.store!.senderId,
            )),
            steps: steps,
            store: widget.store!,
          ),
        widget.builder(
          context,
          _state['objective'] != null ? _goalHeader(context) : null,
        ),
      ],
    );
  }

  Widget _goalHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = switch (_state['status']) {
      'active' => '进行中',
      'paused' => '已暂停',
      'blocked' => '已停滞',
      'budget_limited' => '预算已用完',
      'complete' => '已完成',
      _ => '目标',
    };
    final elapsed =
        (_state['elapsedMs'] as int? ?? 0) +
        (_state['runningSince'] == null
            ? 0
            : DateTime.now().millisecondsSinceEpoch -
                  (_state['runningSince'] as int));
    final duration = Duration(milliseconds: elapsed);
    final time = taskDuration(duration);
    return Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: SettingsIcon(
            type: SettingsIconType.goal,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                TextSpan(
                  text: _state['objective'] as String,
                  style: TextStyle(color: colors.onSurface),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        Builder(
          builder: (anchor) => ComposerMoreAction(
            label: '目标操作',
            onPressed: _acting ? null : () => _more(anchor),
          ),
        ),
      ],
    );
  }

  Future<void> _more(BuildContext anchor) async {
    final store = widget.store!;
    final status = _state['status'];
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'edit',
          label: '编辑目标',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.rename,
          ),
        ),
        (
          value: 'detail',
          label: '查看详情',
          icon: const SettingsIcon(type: SettingsIconType.info),
        ),
        if (status == 'active')
          (
            value: 'pause',
            label: '暂停目标',
            icon: TaskPlaybackIcon(
              paused: false,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        if (status == 'paused' ||
            status == 'blocked' ||
            status == 'budget_limited')
          (
            value: 'resume',
            label: '继续目标',
            icon: const SettingsIcon(type: SettingsIconType.play),
          ),
        (
          value: 'clear',
          label: '清除目标',
          icon: const ConversationMenuIcon(
            type: ConversationMenuIconType.delete,
          ),
        ),
      ],
      destructiveValues: const {'clear'},
    );
    if (!mounted ||
        action == null ||
        widget.store?.conversationId != store.conversationId)
      return;
    if (action == 'edit') {
      await _showGoal(editing: true);
      return;
    }
    if (action == 'detail') {
      await _showGoal();
      return;
    }
    await _controlGoal(action, store);
  }

  Future<bool> _controlGoal(String action, PrivateTaskState store) async {
    if (action == 'clear') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const DeleteConfirmationDialog(
          title: '删除目标？',
          description: '停止当前目标并移除目标提示，保留执行计划和聊天记录。',
          confirmLabel: '删除',
        ),
      );
      if (!mounted ||
          confirmed != true ||
          widget.store?.conversationId != store.conversationId)
        return false;
    }
    setState(() => _acting = action != 'resume');
    final succeeded = await runUiAction(
      context,
      () => widget.controller.controlPrivateGoal(
        action,
        conversationId: store.conversationId,
      ),
    );
    if (mounted) setState(() => _acting = false);
    return succeeded;
  }

  Future<void> _showGoal({bool editing = false}) => showAppBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    builder: (_) => PrivateGoalSheet(
      store: widget.store!,
      controller: widget.controller,
      initialState: _state,
      initiallyEditing: editing,
      onControl: (action) => _controlGoal(action, widget.store!),
    ),
  );
}
