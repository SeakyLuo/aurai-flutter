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
  });
  final ChatController controller;
  final String conversationId;
  final bool includeThoughts;
  final Widget Function(BuildContext, List<GroupMemberActivity>) builder;

  @override
  State<GroupStatusBuilder> createState() => _GroupStatusBuilderState();
}

class _GroupStatusBuilderState extends State<GroupStatusBuilder> {
  Map<String, MessageSender> _members = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await widget.controller.groupStore.members(
        widget.conversationId,
      );
      if (mounted)
        setState(
          () => _members = {for (final m in members) m.sender.id: m.sender},
        );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成员状态加载失败：${errorMessage(error)}')),
        );
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
      final activities = widget.controller.groupActivitiesFor(
        widget.conversationId,
        includeThoughts: widget.includeThoughts,
      );
      final active = activities.map((a) => a.sender.id).toSet();
      final sleeps = widget.controller.groupSleepTimes(widget.conversationId);
      return widget.builder(context, [
        ...activities,
        for (final member in _members.values)
          if (sleeps.containsKey(member.id) && !active.contains(member.id))
            GroupMemberActivity(
              sender: member,
              runId: 'sleep:${member.id}',
              elapsed: Duration.zero,
              sleepingUntil: sleeps[member.id],
              description: '睡眠中',
            ),
      ]);
    },
  );
}
