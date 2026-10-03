import '../../app/glass_notice.dart';
import 'dart:async';
import '../../domain/ai_profile.dart';
import '../../storage/group_participation.dart';
import '../../storage/group_chat_store.dart';
import 'package:flutter/material.dart';
import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import 'chat_controller.dart';
import 'settings_icon.dart';

class GroupStatusBuilder extends StatefulWidget {
  const GroupStatusBuilder({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.builder,
    this.onMemberCount,
    this.onMembersLoaded,
    this.includeThoughts = true,
    this.includeInactive = false,
  });
  final ChatController controller;
  final String conversationId;
  final bool includeThoughts;
  final bool includeInactive;
  final Widget Function(BuildContext, List<GroupMemberActivity>) builder;
  final ValueChanged<int>? onMemberCount;
  final ValueChanged<List<ConversationMember>>? onMembersLoaded;

  @override
  State<GroupStatusBuilder> createState() => _GroupStatusBuilderState();
}

class _GroupStatusBuilderState extends State<GroupStatusBuilder> {
  Map<String, MessageSender> _members = {};
  Set<String> _paused = {};
  Map<String, String> _pauseReasons = {};
  Map<String, GroupMute> _mutedUntil = {};
  Timer? _sleepExpiry;
  bool _loaded = false;
  bool _failed = false;
  late final StreamSubscription<String> _participation;

  @override
  void dispose() {
    _sleepExpiry?.cancel();
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
        ).pausedWithReasons(widget.conversationId),
        widget.controller.groupStore.mutedMembers(widget.conversationId),
      ]);
      final members = results[0] as List<ConversationMember>;
      if (mounted)
        setState(() {
          _members = {for (final m in members) m.sender.id: m.sender};
          _mutedUntil = results[2] as Map<String, GroupMute>;
          _pauseReasons = results[1] as Map<String, String>;
          _paused = _pauseReasons.keys.toSet();
          _loaded = true;
          _failed = false;
        });
      if (mounted) widget.onMemberCount?.call(members.length);
      if (mounted) widget.onMembersLoaded?.call(members);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(context).showToast(
          SnackBar(content: Text('成员状态加载失败：${errorMessage(error)}')),
          kind: ToastKind.error,
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
              ? TextButton.icon(
                  onPressed: _load,
                  icon: const SizedBox.square(
                    dimension: 18,
                    child: SettingsIcon(type: SettingsIconType.reset),
                  ),
                  label: const Text('重新加载成员状态'),
                )
              : const CircularProgressIndicator(),
        );
      }
      final activities = widget.controller.groupActivitiesFor(
        widget.conversationId,
        includeThoughts: widget.includeThoughts,
        pausedMembers: _paused,
        pausedReasons: _pauseReasons,
        mutedMembers: _mutedUntil,
      );
      final active = activities.map((a) => a.sender.id).toSet();
      final now = DateTime.now();
      final sleeps = {
        for (final entry
            in widget.controller.groupSleepTimes(widget.conversationId).entries)
          if (entry.value.isAfter(now)) entry.key: entry.value,
      };
      _sleepExpiry?.cancel();
      final deadlines = [
        ...sleeps.values,
        ..._mutedUntil.values
            .map((mute) => mute.until)
            .whereType<DateTime>()
            .where((until) => until.isAfter(now)),
      ];
      if (deadlines.isNotEmpty) {
        final nextExpiry = deadlines.reduce((a, b) => a.isBefore(b) ? a : b);
        _sleepExpiry = Timer(nextExpiry.difference(now), () => setState(() {}));
      }
      final bySender = {for (final a in activities) a.sender.id: a};
      return widget.builder(context, [
        if (!widget.includeInactive) ...activities,
        for (final member in _members.values) ...[
          if (member.kind == MessageSenderKind.agent) ...[
            if (widget.includeInactive && active.contains(member.id))
              bySender[member.id]!
            else if (!active.contains(member.id) &&
                (widget.includeInactive ||
                    sleeps.containsKey(member.id) ||
                    _paused.contains(member.id)))
              GroupMemberActivity(
                sender: member,
                mute: _mutedUntil[member.id],
                runId: 'inactive:${member.id}',
                elapsed: Duration.zero,
                sleepingUntil: sleeps[member.id],
                idle: !sleeps.containsKey(member.id),
                autoReplyPaused: _paused.contains(member.id),
                autoReplyPauseReason: _pauseReasons[member.id],
                description: _mutedUntil[member.id]?.isActive == true
                    ? '已${_mutedUntil[member.id]!.description}'
                    : _paused.contains(member.id)
                    ? _pauseReasons[member.id]!.isEmpty
                          ? '接话已关闭'
                          : '接话已关闭 · ${_pauseReasons[member.id]}'
                    : sleeps.containsKey(member.id)
                    ? '睡眠中'
                    : '等待新消息',
              ),
          ] else if (widget.includeInactive)
            GroupMemberActivity(
              sender: member,
              mute: _mutedUntil[member.id],
              runId: 'member:${member.id}',
              elapsed: Duration.zero,
              description: _mutedUntil[member.id]?.isActive == true
                  ? '已${_mutedUntil[member.id]!.description}'
                  : '群成员',
              idle: true,
            ),
        ],
      ]);
    },
  );
}
