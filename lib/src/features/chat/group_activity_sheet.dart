import 'header_action_menu.dart';
import '../../app/glass_notice.dart';
import 'group_status_builder.dart';
import 'package:flutter/material.dart';

import '../../domain/error_message.dart';
import 'chat_controller.dart';
import 'ai_contact_page.dart';
import 'member_avatar.dart';
import 'jump_to_bottom_button.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'thinking_indicator.dart';

Future<void> showGroupActivitySheet(
  BuildContext context, {
  required ChatController controller,
  required String conversationId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (_) => GroupActivityPage._sheet(
    controller: controller,
    conversationId: conversationId,
  ),
);

class GroupActivityPage extends StatefulWidget {
  const GroupActivityPage({
    super.key,
    required this.controller,
    required this.conversationId,
  }) : _asSheet = false;

  const GroupActivityPage._sheet({
    required this.controller,
    required this.conversationId,
  }) : _asSheet = true;

  final bool _asSheet;
  final ChatController controller;
  final String conversationId;

  @override
  State<GroupActivityPage> createState() => _GroupActivitySheetState();
}

class _GroupActivitySheetState extends State<GroupActivityPage> {
  final _waking = <String>{};

  bool _wakingAll = false;

  bool _resumingAll = false;

  Future<void> _resumeAll() async {
    setState(() => _resumingAll = true);
    try {
      final count = await widget.controller.resumeAllGroupAutoReply(
        widget.conversationId,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text(count == 0 ? '当前没有需要恢复接话的成员' : '已恢复 $count 位成员的自动接话'),
          ),
        );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('恢复接话失败：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _resumingAll = false);
    }
  }

  Widget _batchActions() => Builder(
    builder: (buttonContext) {
      final busy =
          _wakingAll ||
          _resumingAll ||
          _waking.isNotEmpty ||
          _resuming.isNotEmpty;
      return _MemberAction(
        label: '更多',
        icon: Icons.more_vert_rounded,
        onPressed: busy
            ? null
            : () async {
                final action = await showHeaderActionMenu(
                  buttonContext,
                  items: const [
                    (
                      value: 'wake',
                      label: '全部唤醒',
                      icon: QuestionIcon(type: QuestionIconType.play),
                    ),
                    (
                      value: 'resume',
                      label: '全部恢复接话',
                      icon: QuestionIcon(type: QuestionIconType.play),
                    ),
                  ],
                );
                if (!mounted) return;
                if (action == 'wake') await _wakeAll();
                if (action == 'resume') await _resumeAll();
              },
      );
    },
  );

  Future<void> _wakeAll() async {
    setState(() => _wakingAll = true);
    try {
      final count = await widget.controller.wakeAllGroupMembers(
        widget.conversationId,
      );
      if (mounted && count == 0) {
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(const SnackBar(content: Text('当前没有需要唤醒的成员')));
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('唤醒失败：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _wakingAll = false);
    }
  }

  Future<void> _wake(GroupMemberActivity activity) async {
    setState(() => _waking.add(activity.sender.id));
    try {
      await widget.controller.wakeGroupMember(
        widget.conversationId,
        activity.sender.id,
      );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('唤醒失败：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _waking.remove(activity.sender.id));
    }
  }

  Future<void> _openSleepDetails(GroupMemberActivity activity) async {
    try {
      final rows = await widget.controller.groupStore.database.query(
        'app_state',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [
          'group_sleep_reason:${widget.conversationId}:${activity.sender.id}',
        ],
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (_) => _GroupThoughtDetails(
          controller: widget.controller,
          conversationId: widget.conversationId,
          activity: activity,
          sleepReason: rows.isEmpty
              ? '本次睡眠未记录原因'
              : rows.single['value'] as String,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('读取睡眠原因失败：${errorMessage(error)}')),
      );
    }
  }

  Future<void> _openDetails(GroupMemberActivity activity) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (_) => _GroupThoughtDetails(
          controller: widget.controller,
          conversationId: widget.conversationId,
          activity: activity,
        ),
      );

  final _resuming = <String>{};

  Future<void> _resume(GroupMemberActivity activity) async {
    setState(() => _resuming.add(activity.sender.id));
    try {
      await widget.controller.resumeGroupAutoReply(
        widget.conversationId,
        activity.sender.id,
      );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('恢复接话失败：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _resuming.remove(activity.sender.id));
    }
  }

  Widget _avatar(GroupMemberActivity activity) => Semantics(
    button: true,
    label: '查看${activity.sender.name}的资料',
    child: GestureDetector(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AiContactPage(
            controller: widget.controller,
            senderId: activity.sender.id,
            groupId: widget.conversationId,
          ),
        ),
      ),
      child: MemberAvatar(sender: activity.sender, size: 40),
    ),
  );

  Widget _row(GroupMemberActivity activity) {
    final running = !activity.idle && !activity.sleeping;
    final colors = Theme.of(context).colorScheme;
    var description = activity.description;
    if (activity.sleeping) {
      final until = activity.sleepingUntil!.toLocal();
      final time =
          '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}:${until.second.toString().padLeft(2, '0')}';
      description = '睡眠中 · 预计 $time 唤醒';
    }
    return Padding(
      key: ValueKey(activity.sender.id),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _avatar(activity),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:
                  running &&
                      activity.thoughts.any((text) => text.trim().isNotEmpty)
                  ? () => _openDetails(activity)
                  : activity.sleeping
                  ? () => _openSleepDetails(activity)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.sender.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (running && activity.preview.isEmpty)
                    ThinkingIndicator(
                      label: description,
                      fontSize: 13,
                      singleLine: true,
                      animate: !activity.stopping && !activity.waitingForUser,
                    )
                  else
                    Text(
                      running && !activity.stopping
                          ? activity.preview
                          : description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  if (running && activity.autoReplyPaused)
                    Text(
                      '自动接话已关闭',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (activity.autoReplyPaused)
            SettingsGlassAction(
              label: _resuming.contains(activity.sender.id) ? '恢复中' : '恢复接话',
              icon: Icons.play_arrow_rounded,
              iconWidget: _resuming.contains(activity.sender.id)
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.65,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : const QuestionIcon(type: QuestionIconType.play),
              onPressed:
                  _resumingAll ||
                      _wakingAll ||
                      _resuming.contains(activity.sender.id)
                  ? null
                  : () => _resume(activity),
            ),
          if (running)
            _StopMemberButton(
              controller: widget.controller,
              conversationId: widget.conversationId,
              activity: activity,
            )
          else if (activity.sleeping && !activity.autoReplyPaused)
            SettingsGlassAction(
              label: _waking.contains(activity.sender.id) ? '唤醒中' : '唤醒',
              icon: Icons.play_arrow_rounded,
              iconWidget: _waking.contains(activity.sender.id)
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.65,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : const QuestionIcon(type: QuestionIconType.play),
              onPressed:
                  _resumingAll ||
                      _wakingAll ||
                      _waking.contains(activity.sender.id)
                  ? null
                  : () => _wake(activity),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = GroupStatusBuilder(
      controller: widget.controller,
      conversationId: widget.conversationId,
      includeInactive: !widget._asSheet,
      builder: (context, activities) {
        final visible = widget._asSheet
            ? activities.where((a) => !a.stopping && !a.waitingForUser).toList()
            : activities;
        return visible.isEmpty
            ? Center(
                child: Text(
                  widget._asSheet ? '当前没有成员在思考或睡眠' : '群内暂无 AI 成员',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [for (final activity in visible) _row(activity)],
              );
      },
    );
    if (widget._asSheet) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _ActivitySheetHeader(title: '群成员状态', trailing: _batchActions()),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: SettingsAppBar(
        title: '群成员状态',
        actions: [_batchActions()],
        onBack: () => Navigator.pop(context),
      ),
      body: SafeArea(top: false, child: content),
    );
  }
}

class _GroupThoughtDetails extends StatefulWidget {
  const _GroupThoughtDetails({
    required this.controller,
    required this.conversationId,
    required this.activity,
    this.sleepReason,
  });
  final ChatController controller;
  final String conversationId;
  final GroupMemberActivity activity;
  final String? sleepReason;

  @override
  State<_GroupThoughtDetails> createState() => _GroupThoughtDetailsState();
}

class _GroupThoughtDetailsState extends State<_GroupThoughtDetails> {
  final _scroll = ScrollController();
  late GroupMemberActivity _activity = widget.activity;
  late final _updates = Listenable.merge([
    widget.controller,
    widget.controller.groupActivityChanges,
    widget.controller.groupSleepChanges,
  ]);
  bool _running = true;
  bool _showJumpToBottom = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateJumpButton);
    _updates.addListener(_sync);
    _sync();
  }

  void _sync() {
    final current = widget.controller
        .groupActivitiesFor(widget.conversationId)
        .where((activity) => activity.runId == widget.activity.runId)
        .firstOrNull;
    final follow = !_scroll.hasClients || _scroll.position.extentAfter < 48;
    setState(() {
      _running = current != null;
      if (current != null) _activity = current;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (follow) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _updateJumpButton();
    });
  }

  void _updateJumpButton() {
    final threshold = _showJumpToBottom ? 120.0 : 160.0;
    final show = _scroll.position.extentAfter > threshold;
    if (show != _showJumpToBottom) {
      setState(() => _showJumpToBottom = show);
    }
  }

  void _jumpToBottom() {
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  void dispose() {
    _updates.removeListener(_sync);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _ActivitySheetHeader(
              title: _activity.sender.name,
              avatar: Semantics(
                button: true,
                label: '查看${_activity.sender.name}的资料',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AiContactPage(
                        controller: widget.controller,
                        senderId: _activity.sender.id,
                        groupId: widget.conversationId,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: MemberAvatar(sender: _activity.sender, size: 24),
                  ),
                ),
              ),
              trailing: _running
                  ? _StopMemberButton(
                      controller: widget.controller,
                      conversationId: widget.conversationId,
                      activity: _activity,
                    )
                  : null,
            ),
            Expanded(
              child: ScrollAwareJumpStack(
                fit: StackFit.expand,
                children: [
                  ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    children: [
                      if (widget.sleepReason != null) ...[
                        const Text(
                          '睡眠原因',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          widget.sleepReason!,
                          style: const TextStyle(fontSize: 15, height: 1.65),
                        ),
                      ],
                      if (_activity.thoughts.isNotEmpty)
                        SelectableText(
                          _activity.thoughts.join('\n\n'),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.65,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (_showJumpToBottom)
                    Positioned(
                      right: 16,
                      bottom: 8,
                      child: Center(
                        child: JumpToBottomButton(onPressed: _jumpToBottom),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopMemberButton extends StatefulWidget {
  const _StopMemberButton({
    required this.controller,
    required this.conversationId,
    required this.activity,
  });
  final ChatController controller;
  final String conversationId;
  final GroupMemberActivity activity;

  @override
  State<_StopMemberButton> createState() => _StopMemberButtonState();
}

class _StopMemberButtonState extends State<_StopMemberButton> {
  bool _busy = false;
  bool _retry = false;

  Future<void> _stop() async {
    setState(() {
      _busy = true;
      _retry = false;
    });
    try {
      await widget.controller.stopGroupMember(
        conversationId: widget.conversationId,
        senderId: widget.activity.sender.id,
        runId: widget.activity.runId,
      );
    } on Object catch (error) {
      if (mounted) {
        _retry = true;
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('终止失败：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stopping = _busy || (widget.activity.stopping && !_retry);
    final colors = Theme.of(context).colorScheme;
    return SettingsGlassAction(
      label: stopping ? '终止中' : '终止思考',
      icon: Icons.stop_rounded,
      onPressed: stopping ? null : _stop,
      iconWidget: SizedBox.square(
        dimension: 20,
        child: Center(
          child: stopping
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.65,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MemberAction extends StatelessWidget {
  const _MemberAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    icon: Icon(icon, size: 24),
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(40),
      minimumSize: const Size.square(40),
      padding: const EdgeInsets.all(8),
      shape: const CircleBorder(),
    ),
  );
}

class _ActivitySheetHeader extends StatelessWidget {
  const _ActivitySheetHeader({required this.title, this.avatar, this.trailing});
  final String title;
  final Widget? avatar;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        SettingsGlassAction(
          label: '关闭',
          icon: Icons.close_rounded,
          iconWidget: const QuestionIcon(type: QuestionIconType.close),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (avatar != null) ...[avatar!, const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        trailing ?? const SizedBox(width: 40),
      ],
    ),
  );
}
