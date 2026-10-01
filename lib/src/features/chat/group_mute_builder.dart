import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/message_sender.dart';
import '../../domain/group_mute.dart';
import '../../storage/group_chat_store.dart';
import '../../storage/group_participation.dart';

class GroupMuteBuilder extends StatefulWidget {
  const GroupMuteBuilder({
    super.key,
    required this.store,
    required this.groupId,
    required this.builder,
  });
  final GroupChatStore store;
  final String? groupId;
  final Widget Function(BuildContext context, bool blocked, String hint)
  builder;
  @override
  State<GroupMuteBuilder> createState() => _GroupMuteBuilderState();
}

class _GroupMuteBuilderState extends State<GroupMuteBuilder> {
  GroupMute? _mute;
  bool _loaded = false;
  bool _failed = false;
  Timer? _expiry;
  late final StreamSubscription<String> _changes;

  @override
  void initState() {
    super.initState();
    _load();
    _changes = GroupParticipation.changes.stream.listen((id) {
      if (id == widget.groupId) _load();
    });
  }

  @override
  void didUpdateWidget(GroupMuteBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _loaded = false;
      _failed = false;
      _mute = null;
      _expiry?.cancel();
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.groupId;
    if (id == null) return;
    final loaded = await runUiAction(context, () async {
      final muted = await widget.store.mutedMembers(id);
      if (!mounted || id != widget.groupId) return;
      final mute = muted[MessageSender.localUser.id];
      setState(() {
        _loaded = true;
        _mute = mute;
      });
      _expiry?.cancel();
      final until = mute?.until;
      if (until != null) {
        _expiry = Timer(until.difference(DateTime.now()), () {
          if (mounted) _load();
        });
      }
    });
    if (mounted && id == widget.groupId) setState(() => _failed = !loaded);
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) return widget.builder(context, false, '');
    if (!_loaded && _failed)
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: _load, child: const Text('重试')),
          widget.builder(context, true, ''),
        ],
      );
    if (!_loaded) return widget.builder(context, true, '正在加载发言状态');
    final muted = _mute?.isActive == true;
    final hint = muted ? '已${_mute!.description}' : '';
    return widget.builder(context, muted, hint);
  }
}
