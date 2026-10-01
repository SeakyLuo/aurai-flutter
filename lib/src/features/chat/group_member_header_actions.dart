import '../../storage/group_chat_store.dart';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import 'chat_controller.dart';
import 'glass_surface.dart';
import 'group_invite_page.dart';
import 'group_remove_members_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupMemberHeaderActions extends StatefulWidget {
  const GroupMemberHeaderActions({
    super.key,
    required this.controller,
    required this.groupId,
    required this.moreBuilder,
    required this.onChanged,
  });
  final VoidCallback onChanged;
  final ChatController controller;
  final String groupId;
  final Widget Function(VoidCallback? onRemove) moreBuilder;

  @override
  State<GroupMemberHeaderActions> createState() =>
      _GroupMemberHeaderActionsState();
}

class _GroupMemberHeaderActionsState extends State<GroupMemberHeaderActions> {
  List<ConversationMember> _members = [];
  bool _canInvite = false;
  bool _canRemove = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => runUiAction(context, () async {
    final (members, settings) = await (
      widget.controller.groupStore.members(widget.groupId),
      widget.controller.groupStore.managementSettings(
        widget.groupId,
        MessageSender.localUser.id,
      ),
    ).wait;
    if (!mounted) return;
    final role = members
        .firstWhere((m) => m.sender.id == MessageSender.localUser.id)
        .role;
    setState(() {
      _members = members;
      _canRemove = role.canManage;
      _canInvite = role.canManage || !settings.joinApprovalRequired;
    });
  }).then((_) {});

  Future<void> _open(bool invite) async {
    setState(() => _opening = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => invite
              ? GroupInvitePage(
                  controller: widget.controller,
                  conversationId: widget.groupId,
                  members: _members,
                )
              : GroupRemoveMembersPage(
                  controller: widget.controller,
                  conversationId: widget.groupId,
                  members: _members,
                ),
        ),
      );
      if (mounted) {
        await _load();
        widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsGlassActionSurface(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canInvite) ...[
          RoundAction(
            label: '邀请成员',
            icon: Icons.add_rounded,
            iconWidget: const SettingsIcon(type: SettingsIconType.add),
            onPressed: _opening ? null : () => _open(true),
          ),
          SizedBox(
            height: 20,
            child: VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ],
        widget.moreBuilder(_canRemove && !_opening ? () => _open(false) : null),
      ],
    ),
  );
}
