import '../../app/glass_notice.dart';
import 'dart:async';
import '../../domain/ai_profile.dart';
import '../../storage/group_participation.dart';
import 'package:flutter/material.dart';
import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import 'chat_controller.dart';

class GroupStatusBuilder extends StatefulWidget {
  const GroupStatusBuilder({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.builder,
    this.includeThoughts = true,
    this.includeInactive = false,
  });
  final ChatController controller;
  final String conversationId;
  final bool includeThoughts;
  final bool includeInactive;
  final Widget Function(BuildContext, List<GroupMemberActivity>) builder;

  @override
  State<GroupStatusBuilder> createState() => _GroupStatusBuilderState();
}

class _GroupStatusBuilderState extends State<GroupStatusBuilder> {
  Map<String, MessageSender> _members = {};
  Set<String> _paused = {};
  bool _loaded = false;
  bool _failed = false;
  late final StreamSubscription<String> _participation;

  @override
  void dispose() {
    _participation.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _participation = GroupParticipation.changes.stream.listen((id) {
      if (id == widget.conversationId) _load();
    });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.controller.groupStore.members(widget.conversationId),
        GroupParticipation(
          widget.controller.groupStore.database,
        ).paused(widget.conversationId),
      ]);
      final members = results[0] as List<ConversationMember>;
      if (mounted)
        setState(() {
          _members = {for (final m in members) m.sender.id: m.sender};
          _paused = results[1] as Set<String>;
          _loaded = true;
          _failed = false;
        });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(
            content: Text('成员状态加载失败：${errorMessage(error)}'),
            action: SnackBarAction(label: '重试', onPressed: _load),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.controller.groupActivityChanges,
      widget.controller.groupSleepChanges,
    ]),
    builder: (context, _) {
      if (widget.includeInactive && !_loaded) {
        return Center(
          child: _failed
              ? TextButton(onPressed: _load, child: const Text('重试'))
              : const CircularProgressIndicator(),
        );
      }
      final activities = widget.controller.groupActivitiesFor(
        widget.conversationId,
        includeThoughts: widget.includeThoughts,
        pausedMembers: _paused,
      );
      final active = activities.map((a) => a.sender.id).toSet();
      final sleeps = widget.controller.groupSleepTimes(widget.conversationId);
      final bySender = {for (final a in activities) a.sender.id: a};
      return widget.builder(context, [
        if (!widget.includeInactive) ...activities,
        for (final member in _members.values)
          if (member.kind == MessageSenderKind.agent)
            if (widget.includeInactive && active.contains(member.id))
              bySender[member.id]!
            else if (!active.contains(member.id) &&
                (widget.includeInactive ||
                    sleeps.containsKey(member.id) ||
                    _paused.contains(member.id)))
              GroupMemberActivity(
                sender: member,
                runId: 'inactive:${member.id}',
                elapsed: Duration.zero,
                sleepingUntil: sleeps[member.id],
                idle: !sleeps.containsKey(member.id),
                autoReplyPaused: _paused.contains(member.id),
                description: _paused.contains(member.id)
                    ? '自动接话已关闭'
                    : sleeps.containsKey(member.id)
                    ? '睡眠中'
                    : '等待新消息',
              ),
      ]);
    },
  );
}
