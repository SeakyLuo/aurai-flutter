import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import 'chat_controller.dart';
import 'delete_confirmation_dialog.dart';
import 'group_member_choice.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupRemoveMembersPage extends StatefulWidget {
  const GroupRemoveMembersPage({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.members,
  });
  final ChatController controller;
  final String conversationId;
  final List<ConversationMember> members;
  @override
  State<GroupRemoveMembersPage> createState() => _GroupRemoveMembersPageState();
}

class _GroupRemoveMembersPageState extends State<GroupRemoveMembersPage> {
  late final _localRole = widget.members
      .firstWhere((member) => member.sender.id == MessageSender.localUser.id)
      .role;
  late final _members = widget.members
      .where(
        (member) =>
            member.sender.kind == MessageSenderKind.agent &&
            member.role != GroupMemberRole.owner &&
            (_localRole == GroupMemberRole.owner ||
                member.role == GroupMemberRole.member),
      )
      .toList();
  final _selected = <String>{};
  bool _saving = false;
  void _notice(String text, {ToastKind kind = ToastKind.info}) =>
      ScaffoldMessenger.of(
        context,
      ).showToast(SnackBar(content: Text(text)), kind: kind);

  Future<void> _remove() async {
    if (_saving || _selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: '移除所选成员？',
        description: '将移除 ${_selected.length} 位 AI，保留已有聊天记录。',
        confirmLabel: '移除',
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    try {
      await widget.controller.groupStore.removeMembers(
        widget.conversationId,
        _selected.toList(),
      );
      if (mounted) {
        _notice('已移除成员', kind: ToastKind.success);
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted)
        _notice(
          error is StateError
              ? error.message.toString()
              : '移除失败，请重试：${errorMessage(error)}',
          kind: ToastKind.error,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: _selected.isEmpty ? '移除成员' : '移除成员（${_selected.length}）',
        onBack: _saving ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '移除所选成员',
            icon: Icons.check_rounded,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.check),
            onPressed: _saving || _selected.isEmpty ? null : _remove,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            settingsHeaderHeight(context) + 8,
            16,
            24,
          ),
          children: [
            for (final member in _members)
              GroupMemberChoice(
                sender: member.sender,
                selected: _selected.contains(member.sender.id),
                onTap: _saving
                    ? null
                    : () {
                        if (!_selected.contains(member.sender.id) &&
                            _selected.length == _members.length - 1) {
                          _notice('群聊至少保留一位 AI', kind: ToastKind.warning);
                          return;
                        }
                        setState(() {
                          if (!_selected.remove(member.sender.id))
                            _selected.add(member.sender.id);
                        });
                      },
              ),
          ],
        ),
      ),
    ),
  );
}
