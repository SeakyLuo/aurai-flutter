import '../../domain/contact_name_order.dart';
import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../domain/ai_profile.dart';
import '../../storage/group_chat_store.dart';
import 'chat_controller.dart';
import 'group_member_choice.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupAdministratorsPage extends StatefulWidget {
  const GroupAdministratorsPage({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final ChatController controller;
  final String groupId;

  @override
  State<GroupAdministratorsPage> createState() =>
      _GroupAdministratorsPageState();
}

class _GroupAdministratorsPageState extends State<GroupAdministratorsPage> {
  List<ConversationMember> _members = [];
  Set<String> _selected = {};
  Set<String> _initial = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await widget.controller.groupStore.members(widget.groupId);
    if (!mounted) return;
    final selected = {
      for (final member in members)
        if (member.role == GroupMemberRole.admin) member.sender.id,
    };
    setState(() {
      _members = members
          .where((member) => member.role != GroupMemberRole.owner)
          .byContactName((member) => member.sender);
      _selected = selected;
      _initial = {...selected};
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await runUiAction(
      context,
      () => widget.controller.groupStore.setAdministrators(
        widget.groupId,
        _selected.toList(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '群管理员',
        onBack: _saving ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '保存群管理员',
            icon: Icons.check_rounded,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.check),
            onPressed:
                _saving ||
                    (_selected.difference(_initial).isEmpty &&
                        _initial.difference(_selected).isEmpty)
                ? null
                : _save,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  settingsHeaderHeight(context) + 16,
                  20,
                  24,
                ),
                children: [
                  Text(
                    '管理员可协助群主管理群聊，可以发布群公告、邀请和移除普通成员。最多可设置 ${GroupChatStore.maxAdministrators} 位管理员。',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final member in _members)
                    GroupMemberChoice(
                      selected: _selected.contains(member.sender.id),
                      sender: member.sender,
                      onTap: _saving
                          ? null
                          : () {
                              setState(() {
                                if (!_selected.remove(member.sender.id)) {
                                  if (_selected.length >=
                                      GroupChatStore.maxAdministrators) {
                                    ScaffoldMessenger.of(context).showToast(
                                      const SnackBar(
                                        content: Text('最多可设置 3 位管理员'),
                                      ),
                                    );
                                    return;
                                  }
                                  _selected.add(member.sender.id);
                                }
                              });
                            },
                    ),
                ],
              ),
      ),
    ),
  );
}
