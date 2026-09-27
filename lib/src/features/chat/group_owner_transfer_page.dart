import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import '../../domain/ai_profile.dart';
import '../../storage/group_chat_store.dart';
import 'app_confirmation_dialog.dart';
import 'chat_controller.dart';
import 'dialog_action_button.dart';
import 'group_member_choice.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupOwnerTransferPage extends StatefulWidget {
  const GroupOwnerTransferPage({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final ChatController controller;
  final String groupId;

  @override
  State<GroupOwnerTransferPage> createState() => _GroupOwnerTransferPageState();
}

class _GroupOwnerTransferPageState extends State<GroupOwnerTransferPage> {
  List<ConversationMember> _members = [];
  ConversationMember? _selected;
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
    setState(() {
      _members = members
          .where((member) => member.role != GroupMemberRole.owner)
          .toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final member = _selected!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: '转让群主？',
        description: '转让后，${member.sender.name} 将成为群主，你将变为普通成员。',
        confirmLabel: '确认转让',
        confirmRole: DialogActionRole.primary,
        regular: true,
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    final saved = await runUiAction(
      context,
      () => widget.controller.groupStore.transferOwnership(
        widget.groupId,
        member.sender.id,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '群主管理权转让',
        onBack: _saving ? null : () => Navigator.pop(context),
        actions: [
          if (_selected != null)
            SettingsGlassAction(
              label: '确认转让群主',
              icon: Icons.check_rounded,
              iconWidget: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const SettingsIcon(type: SettingsIconType.check),
              onPressed: _saving ? null : _save,
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
                  settingsHeaderHeight(context) + 12,
                  20,
                  24,
                ),
                children: [
                  Text(
                    '选择一位群成员作为新的群主。转让后，只有新群主可以设置管理员和解散群聊。',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final member in _members)
                    GroupMemberChoice(
                      selected: _selected?.sender.id == member.sender.id,
                      sender: member.sender,
                      onTap: _saving
                          ? null
                          : () => setState(() => _selected = member),
                    ),
                ],
              ),
      ),
    ),
  );
}
