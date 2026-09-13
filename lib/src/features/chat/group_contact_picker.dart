import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../storage/group_chat_store.dart';
import 'chat_controller.dart';
import 'group_member_choice.dart';
import 'pagination_listener.dart';
import 'settings_appearance.dart';

class GroupContactPicker extends StatefulWidget {
  const GroupContactPicker({
    super.key,
    required this.controller,
    required this.initial,
    required this.limit,
  });
  final ChatController controller;
  final List<AiProfile> initial;
  final int limit;
  @override
  State<GroupContactPicker> createState() => _GroupContactPickerState();
}

class _GroupContactPickerState extends State<GroupContactPicker> {
  final _profiles = <AiProfile>[];
  late final _selected = {for (final ai in widget.initial) ai.sender.id: ai};
  bool _loading = false, _more = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.controller.groupStore.listAi(
        offset: _profiles.length,
      );
      if (mounted)
        setState(() {
          _profiles.addAll(page);
          _more = page.length == GroupChatStore.pageSize;
        });
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('通讯录读取失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: '从通讯录选择',
      onBack: () => Navigator.pop(context),
      actions: [
        SettingsGlassAction(
          label: '完成',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context, _selected.values.toList()),
        ),
      ],
    ),
    body: PaginationListener(
      hasMore: _more && !_failed,
      loadMore: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final ai in _profiles)
            GroupMemberChoice(
              selected: _selected.containsKey(ai.sender.id),
              sender: ai.sender,
              onTap: () => setState(() {
                if (_selected.containsKey(ai.sender.id)) {
                  _selected.remove(ai.sender.id);
                } else if (_selected.length < widget.limit) {
                  _selected[ai.sender.id] = ai;
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('群成员已达上限')));
                }
              }),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_failed) TextButton(onPressed: _load, child: const Text('重试')),
          if (!_loading && !_failed && _profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('通讯录还没有朋友，可返回随机添加成员。', textAlign: TextAlign.center),
            ),
        ],
      ),
    ),
  );
}
