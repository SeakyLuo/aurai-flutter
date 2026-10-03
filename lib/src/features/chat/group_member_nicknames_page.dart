import 'package:flutter/material.dart';

import '../../app/ui_action.dart';
import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_member_details.dart';
import 'chat_controller.dart';
import 'group_personal_details.dart';
import 'member_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupMemberNicknamesPage extends StatefulWidget {
  const GroupMemberNicknamesPage({
    super.key,
    required this.controller,
    required this.groupId,
  });

  final ChatController controller;
  final String groupId;

  @override
  State<GroupMemberNicknamesPage> createState() =>
      _GroupMemberNicknamesPageState();
}

class _GroupMemberNicknamesPageState extends State<GroupMemberNicknamesPage> {
  List<ConversationMember> _members = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    runUiAction(context, _load);
  }

  Future<void> _load() async {
    final members = await widget.controller.groupStore.members(widget.groupId);
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _edit(ConversationMember member) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => GroupDetailEditor(
        title: '群昵称',
        description: '仅在这个群使用，清空后使用原名。',
        initialValue: member.sender.name,
        maxLength: 32,
      ),
    );
    if (!mounted || value == null) return;
    setState(() => _saving = true);
    await runUiAction(context, () async {
      await GroupMemberDetailsStore(
        widget.controller.groupStore.database,
      ).setNickname(
        widget.groupId,
        actorId: MessageSender.localUser.id,
        senderId: member.sender.id,
        nickname: value,
      );
      await widget.controller.refreshConversations();
      await _load();
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: SettingsAppBar(
      title: '成员群昵称',
      onBack: () => Navigator.pop(context),
    ),
    body: SettingsPageBody(
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: settingsPagePadding(
                  context,
                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                ),
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: MemberAvatar(sender: member.sender),
                    title: Text(
                      member.sender.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const SettingsIcon(
                      type: SettingsIconType.chevron,
                    ),
                    onTap: _saving ? null : () => _edit(member),
                  );
                },
              ),
      ),
    ),
  );
}
