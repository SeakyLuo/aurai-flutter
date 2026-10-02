import 'task_playback_icon.dart';
import '../../storage/group_chat_store.dart';
import '../../storage/group_participation.dart';
import '../../domain/ai_profile.dart';
import 'group_member_header_actions.dart';
import 'glass_surface.dart';
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
import '../../app/ui_action.dart';
import '../../domain/message_sender.dart';
import 'settings_icon.dart';

part 'group_thought_details.dart';

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
  int? _memberCount;
  int _membersRevision = 0;

  bool _wakingAll = false;

  bool _pausingAll = false;
  bool _resumingAll = false;
  bool _stoppingAll = false;

  Future<void> _stopAll() async {
    setState(() => _stoppingAll = true);
    try {
      await runUiAction(
        context,
        () => widget.controller.stopAllGroupReplies(widget.conversationId),
      );
    } finally {
      if (mounted) setState(() => _stoppingAll = false);
    }
  }

  Future<void> _pauseAll() async {
    setState(() => _pausingAll = true);
    try {
      await runUiAction(context, () async {
        await widget.controller.pauseAllGroupAutoReply(
          widget.conversationId,
        );
      });
    } finally {
      if (mounted) setState(() => _pausingAll = false);
    }
  }

  Future<void> _resumeAll() async {
    setState(() => _resumingAll = true);
    try {
      await widget.controller.resumeAllGroupAutoReply(
        widget.conversationId,
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

  Widget _batchActions({
    VoidCallback? onRemove,
    bool embedded = false,
  }) => Builder(
    builder: (buttonContext) {
      final busy =
          _pausingAll ||
          _stoppingAll ||
          _wakingAll ||
          _resumingAll ||
          _waking.isNotEmpty ||
          _resuming.isNotEmpty;
      final button = RoundAction(
        label: '更多',
        icon: Icons.more_vert_rounded,
        iconWidget: const SettingsIcon(type: SettingsIconType.more),
        onPressed: busy
            ? null
            : () async {
                var canManage = false;
                var canPauseAll = false;
                var canResumeAll = false;
                final loaded = await runUiAction(context, () async {
                  final results = await Future.wait<Object>([
                    widget.controller.groupStore.members(widget.conversationId),
                    GroupParticipation(
                      widget.controller.groupStore.database,
                    ).paused(widget.conversationId),
                    widget.controller.groupStore.mutedMembers(
                      widget.conversationId,
                    ),
                  ]);
                  final members = results[0] as List<ConversationMember>;
                  final paused = results[1] as Set<String>;
                  final muted = (results[2] as Map<String, GroupMute>).keys;
                  final role = members
                      .firstWhere(
                        (member) =>
                            member.sender.id == MessageSender.localUser.id,
                      )
                      .role;
                  canManage = role.canManage;
                  final controllable = members
                      .where(
                        (member) =>
                            member.sender.kind == MessageSenderKind.agent &&
                            !muted.contains(member.sender.id),
                      )
                      .map((member) => member.sender.id)
                      .toSet();
                  canPauseAll = controllable.any(
                    (senderId) => !paused.contains(senderId),
                  );
                  canResumeAll = controllable.any(paused.contains);
                });
                if (!mounted || !buttonContext.mounted || !loaded) return;
                final action = await showHeaderActionMenu(
                  buttonContext,
                  items: [
                    if (onRemove != null)
                      (
                        value: 'remove',
                        label: '移除成员',
                        icon: const SettingsIcon(type: SettingsIconType.remove),
                      ),
                    (
                      value: 'stop',
                      label: '停止当前回复',
                      icon: QuestionIcon(type: QuestionIconType.stop),
                    ),
                    (
                      value: 'wake',
                      label: '全部唤醒',
                      icon: QuestionIcon(type: QuestionIconType.play),
                    ),
                    if (canManage && canPauseAll)
                      (
                        value: 'pause',
                        label: '全部暂停接话',
                        icon: TaskPlaybackIcon(
                          paused: false,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (canManage && canResumeAll)
                      (
                        value: 'resume',
                        label: '全部恢复接话',
                        icon: QuestionIcon(type: QuestionIconType.play),
                      ),
                  ],
                );
                if (!mounted) return;
                if (action == 'remove') onRemove?.call();
                if (action == 'stop') await _stopAll();
                if (action == 'wake') await _wakeAll();
                if (action == 'pause') await _pauseAll();
                if (action == 'resume') await _resumeAll();
              },
      );
      return embedded ? button : SettingsGlassActionSurface(child: button);
    },
  );

  Future<void> _wakeAll() async {
    setState(() => _wakingAll = true);
    try {
      await widget.controller.wakeAllGroupMembers(
        widget.conversationId,
      );
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
          reasonTitle: '睡眠原因',
          reason: rows.isEmpty ? '本次睡眠未记录原因' : rows.single['value'] as String,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showGlassSnackBar(
        SnackBar(content: Text('读取睡眠原因失败：${errorMessage(error)}')),
      );
    }
  }

  Future<void> _openPauseDetails(GroupMemberActivity activity) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        builder: (_) => _GroupThoughtDetails(
          controller: widget.controller,
          conversationId: widget.conversationId,
          activity: activity,
          reasonTitle: '关闭接话原因',
          reason: activity.autoReplyPauseReason!,
        ),
      );

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

  Widget _avatar(GroupMemberActivity activity) {
    final avatar = MemberAvatar(sender: activity.sender, size: 40);
    if (activity.sender.kind != MessageSenderKind.agent) return avatar;
    return Semantics(
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
        child: avatar,
      ),
    );
  }

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
    if (activity.isMuted) {
      description = '已${activity.mute!.description}';
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
                  : activity.autoReplyPaused &&
                        activity.autoReplyPauseReason!.isNotEmpty
                  ? () => _openPauseDetails(activity)
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
                  if (running && activity.autoReplyPaused && !activity.isMuted)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: activity.autoReplyPauseReason!.isEmpty
                          ? null
                          : () => _openPauseDetails(activity),
                      child: Text(
                        activity.autoReplyPauseReason!.isEmpty
                            ? '自动接话已关闭'
                            : '自动接话已关闭 · ${activity.autoReplyPauseReason}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (activity.autoReplyPaused && !activity.isMuted)
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
                  _pausingAll ||
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
          else if (activity.sleeping &&
              !activity.autoReplyPaused &&
              !activity.isMuted)
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
      key: ValueKey(_membersRevision),
      controller: widget.controller,
      conversationId: widget.conversationId,
      includeInactive: !widget._asSheet,
      onMemberCount: widget._asSheet
          ? null
          : (count) {
              if (mounted && _memberCount != count) {
                setState(() => _memberCount = count);
              }
            },
      builder: (context, activities) {
        final visible = widget._asSheet
            ? activities.where((a) => !a.stopping && !a.waitingForUser).toList()
            : activities;
        final body = visible.isEmpty
            ? Center(
                child: Text(
                  widget._asSheet ? '当前没有成员在思考或睡眠' : '群内暂无 AI 成员',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView(
                padding: widget._asSheet
                    ? const EdgeInsets.fromLTRB(18, 4, 18, 24)
                    : settingsPagePadding(
                        context,
                        const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      ),
                children: [for (final activity in visible) _row(activity)],
              );
        if (!widget._asSheet) return body;
        final header = _ActivitySheetHeader(
          title: '群成员状态',
          trailing: _batchActions(),
        );
        return visible.isEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  body,
                  Align(alignment: Alignment.topCenter, child: header),
                ],
              )
            : Column(
                children: [
                  header,
                  Expanded(child: body),
                ],
              );
      },
    );
    if (widget._asSheet) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: SafeArea(top: false, child: content),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: _memberCount == null ? '群成员' : '群成员（$_memberCount）',
        actions: [
          GroupMemberHeaderActions(
            controller: widget.controller,
            groupId: widget.conversationId,
            onChanged: () => setState(() => _membersRevision++),
            moreBuilder: (onRemove) =>
                _batchActions(onRemove: onRemove, embedded: true),
          ),
        ],
        onBack: () => Navigator.pop(context),
      ),
      body: SettingsPageBody(child: SafeArea(top: false, child: content)),
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
