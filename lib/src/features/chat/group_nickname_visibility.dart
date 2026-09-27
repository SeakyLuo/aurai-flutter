import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/ui_action.dart';

class GroupNicknamePreference extends ValueNotifier<bool> {
  GroupNicknamePreference._(this.groupId) : super(true);
  final String groupId;
  static final _groups = <String, GroupNicknamePreference>{};
  static GroupNicknamePreference forGroup(String id) =>
      _groups.putIfAbsent(id, () => GroupNicknamePreference._(id));
  final _preferences = SharedPreferencesAsync();
  Future<void>? _loading;

  Future<void> load() => _loading ??= _read();
  Future<void> _read() async {
    value = await _preferences.getBool('groupShowMemberNames:$groupId') ?? true;
  }

  Future<void> save(bool show) async {
    await _preferences.setBool('groupShowMemberNames:$groupId', show);
    value = show;
  }
}

class GroupNicknameVisibility extends StatefulWidget {
  const GroupNicknameVisibility({
    super.key,
    required this.groupId,
    required this.builder,
  });
  final String groupId;
  final Widget Function(BuildContext, bool) builder;
  @override
  State<GroupNicknameVisibility> createState() =>
      _GroupNicknameVisibilityState();
}

class _GroupNicknameVisibilityState extends State<GroupNicknameVisibility> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GroupNicknameVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) _load();
  }

  void _load() {
    runUiAction(context, GroupNicknamePreference.forGroup(widget.groupId).load);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: GroupNicknamePreference.forGroup(widget.groupId),
    builder: (context, show, _) => widget.builder(context, show),
  );
}
