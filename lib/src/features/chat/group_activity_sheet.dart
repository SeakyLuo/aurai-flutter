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
  builder: (_) => _GroupActivitySheet(
    controller: controller,
    conversationId: conversationId,
  ),
);

class _GroupActivitySheet extends StatefulWidget {
  const _GroupActivitySheet({
    required this.controller,
    required this.conversationId,
  });
  final ChatController controller;
  final String conversationId;

  @override
  State<_GroupActivitySheet> createState() => _GroupActivitySheetState();
}

class _GroupActivitySheetState extends State<_GroupActivitySheet> {
  final _waking = <String>{};

  Future<void> _wake(GroupMemberActivity activity) async {
    setState(() => _waking.add(activity.sender.id));
    try {
      await widget.controller.wakeGroupMember(
        widget.conversationId,
        activity.sender.id,
      );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('唤醒失败：${errorMessage(error)}')));
    } finally {
      if (mounted) setState(() => _waking.remove(activity.sender.id));
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

  @override
  Widget build(BuildContext context) => GroupStatusBuilder(
    controller: widget.controller,
    conversationId: widget.conversationId,
    builder: (context, activities) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ActivitySheetHeader(title: '成员状态'),
              Flexible(
                child: activities.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                        child: Text(
                          '当前没有成员在思考或睡眠',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          if (activity.sleeping) {
                            final until = activity.sleepingUntil!.toLocal();
                            final time =
                                '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}:${until.second.toString().padLeft(2, '0')}';
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              leading: MemberAvatar(
                                sender: activity.sender,
                                size: 40,
                              ),
                              title: Text(activity.sender.name),
                              subtitle: Text(
                                until.isAfter(DateTime.now())
                                    ? '睡眠中 · 预计 $time 唤醒'
                                    : '睡眠到期 · 等待调度',
                              ),
                              trailing: SettingsGlassAction(
                                label: '唤醒${activity.sender.name}',
                                icon: Icons.play_arrow_rounded,
                                iconWidget: const QuestionIcon(
                                  type: QuestionIconType.play,
                                ),
                                onPressed: _waking.contains(activity.sender.id)
                                    ? null
                                    : () => _wake(activity),
                              ),
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AiContactPage(
                                    controller: widget.controller,
                                    senderId: activity.sender.id,
                                    groupId: widget.conversationId,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Row(
                            key: ValueKey(activity.runId),
                            children: [
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label: '查看${activity.sender.name}的思考详情',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openDetails(activity),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          MemberAvatar(
                                            sender: activity.sender,
                                            size: 40,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  activity.sender.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (activity
                                                        .preview
                                                        .isNotEmpty &&
                                                    !activity.stopping)
                                                  Text(
                                                    activity.preview,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  )
                                                else
                                                  ThinkingIndicator(
                                                    label: activity.description,
                                                    fontSize: 13,
                                                    singleLine: true,
                                                    animate:
                                                        !activity.stopping &&
                                                        !activity
                                                            .waitingForUser,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StopMemberButton(
                                controller: widget.controller,
                                conversationId: widget.conversationId,
                                activity: activity,
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GroupThoughtDetails extends StatefulWidget {
  const _GroupThoughtDetails({
    required this.controller,
    required this.conversationId,
    required this.activity,
  });
  final ChatController controller;
  final String conversationId;
  final GroupMemberActivity activity;

  @override
  State<_GroupThoughtDetails> createState() => _GroupThoughtDetailsState();
}

class _GroupThoughtDetailsState extends State<_GroupThoughtDetails> {
  final _scroll = ScrollController();
  late GroupMemberActivity _activity = widget.activity;
  late final _updates = Listenable.merge([
    widget.controller,
    widget.controller.groupActivityChanges,
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
    final status = _running
        ? _activity.description
        : _activity.stopping
        ? '已终止'
        : '本次思考已结束';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ThinkingIndicator(
                  label: status,
                  fontSize: 13,
                  singleLine: true,
                  animate:
                      _running &&
                      !_activity.stopping &&
                      !_activity.waitingForUser,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    children: [
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
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Center(
                        child: JumpToBottomButton(
                          streaming: false,
                          onPressed: _jumpToBottom,
                        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('终止失败：${errorMessage(error)}')));
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
