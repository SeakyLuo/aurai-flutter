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
  late final _members = widget.members
      .where((member) => member.sender.kind == MessageSenderKind.agent)
      .toList();
  final _selected = <String>{};
  bool _saving = false;
  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
        _notice('已移除成员');
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted)
        _notice(
          error is StateError
              ? error.message.toString()
              : '移除失败，请重试：${errorMessage(error)}',
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
        gradientBackground: true,
        title: '移除成员',
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
            View.of(context).padding.top / View.of(context).devicePixelRatio +
                76 +
                8,
            16,
            24,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '已选择 ${_selected.length} 位',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final member in _members)
              GroupMemberChoice(
                sender: member.sender,
                selected: _selected.contains(member.sender.id),
                onTap: _saving
                    ? null
                    : () {
                        if (!_selected.contains(member.sender.id) &&
                            _selected.length == _members.length - 1) {
                          _notice('群聊至少保留一位 AI');
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
