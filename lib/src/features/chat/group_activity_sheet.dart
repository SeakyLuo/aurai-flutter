import 'package:flutter/material.dart';

import '../../domain/error_message.dart';
import 'chat_controller.dart';
import 'member_avatar.dart';
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
  late final _updates = Listenable.merge([
    widget.controller,
    widget.controller.groupActivityChanges,
  ]);

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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _updates,
    builder: (context, _) {
      final activities = widget.controller.groupActivitiesFor(
        widget.conversationId,
      );
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ActivitySheetHeader(title: '思考状态'),
              Flexible(
                child: activities.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                        child: Text(
                          '当前没有成员在思考',
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

  @override
  void initState() {
    super.initState();
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
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
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
            const _ActivitySheetHeader(title: '思考详情'),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 16),
              child: Row(
                children: [
                  MemberAvatar(sender: _activity.sender, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activity.sender.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ThinkingIndicator(
                          label: status,
                          fontSize: 13,
                          singleLine: true,
                          animate:
                              _running &&
                              !_activity.stopping &&
                              !_activity.waitingForUser,
                        ),
                      ],
                    ),
                  ),
                  if (_running)
                    _StopMemberButton(
                      controller: widget.controller,
                      conversationId: widget.conversationId,
                      activity: _activity,
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
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
  const _ActivitySheetHeader({required this.title});
  final String title;

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
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 40),
      ],
    ),
  );
}
