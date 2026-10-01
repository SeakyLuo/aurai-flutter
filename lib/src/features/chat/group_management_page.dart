import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../domain/ai_profile.dart';
import '../../domain/error_message.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_chat_store.dart';
import 'chat_controller.dart';
import 'delete_confirmation_dialog.dart';
import 'dialog_action_button.dart';
import 'group_administrators_page.dart';
import 'group_mute_settings_page.dart';
import 'group_owner_transfer_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupManagementPage extends StatefulWidget {
  const GroupManagementPage({
    super.key,
    required this.controller,
    required this.groupId,
    required this.groupTitle,
  });

  final ChatController controller;
  final String groupId;
  final String groupTitle;

  @override
  State<GroupManagementPage> createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> {
  List<ConversationMember> _members = [];
  late GroupManagementSettings _settings;
  bool _loading = true;
  bool _busy = false;

  GroupMemberRole get _role => _members
      .firstWhere((member) => member.sender.id == MessageSender.localUser.id)
      .role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object>([
      widget.controller.groupStore.members(widget.groupId),
      widget.controller.groupStore.managementSettings(
        widget.groupId,
        MessageSender.localUser.id,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _members = results[0] as List<ConversationMember>;
      _settings = results[1] as GroupManagementSettings;
      _loading = false;
    });
  }

  Future<void> _updateSettings({
    bool? joinApprovalRequired,
    bool? managersOnlyRename,
  }) async {
    setState(() => _busy = true);
    try {
      await widget.controller.groupStore.updateManagementSettings(
        widget.groupId,
        actorId: MessageSender.localUser.id,
        joinApprovalRequired: joinApprovalRequired,
        managersOnlyRename: managersOnlyRename,
      );
      if (!mounted) return;
      setState(() {
        _settings = GroupManagementSettings(
          joinApprovalRequired:
              joinApprovalRequired ?? _settings.joinApprovalRequired,
          managersOnlyRename:
              managersOnlyRename ?? _settings.managersOnlyRename,
        );
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('设置失败，请重试：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget page) async {
    final transferred = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (!mounted) return;
    await _load();
    if (transferred == true && _role != GroupMemberRole.owner) {
      Navigator.pop(context);
    }
  }

  Future<void> _dissolve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: '解散群聊？',
        description: '“${widget.groupTitle}”的消息、草稿和图片将一并删除，所有成员都将退出，且无法恢复。',
        confirmLabel: '解散',
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.controller.dissolveGroup(widget.groupId);
      if (mounted) Navigator.pop(context, true);
    } on FileSystemException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('群聊已解散，部分图片清理失败：${errorMessage(error)}')),
        );
        Navigator.pop(context, true);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('解散失败，请重试：${errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final administrators = _members
        .where((member) => member.role == GroupMemberRole.admin)
        .length;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '群管理',
          onBack: _busy ? null : () => Navigator.pop(context),
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : AbsorbPointer(
                  absorbing: _busy,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      settingsHeaderHeight(context) + 8,
                      16,
                      32,
                    ),
                    children: [
                      _surface(
                        Column(
                          children: [
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minTileHeight: 60,
                              title: const Text(
                                '进群需要群主/群管理员确认',
                                style: TextStyle(fontSize: 15),
                              ),
                              value: _settings.joinApprovalRequired,
                              onChanged: _role == GroupMemberRole.owner
                                  ? (value) => _updateSettings(
                                      joinApprovalRequired: value,
                                    )
                                  : null,
                            ),
                            SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minTileHeight: 60,
                              title: const Text(
                                '仅群主/群管理员可修改群聊名称',
                                style: TextStyle(fontSize: 15),
                              ),
                              value: _settings.managersOnlyRename,
                              onChanged: _role == GroupMemberRole.owner
                                  ? (value) => _updateSettings(
                                      managersOnlyRename: value,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _surface(
                        Column(
                          children: [
                            _row(
                              '群主管理权转让',
                              _role == GroupMemberRole.owner
                                  ? () => _open(
                                      GroupOwnerTransferPage(
                                        controller: widget.controller,
                                        groupId: widget.groupId,
                                      ),
                                    )
                                  : null,
                            ),
                            _row(
                              '群管理员',
                              _role == GroupMemberRole.owner
                                  ? () => _open(
                                      GroupAdministratorsPage(
                                        controller: widget.controller,
                                        groupId: widget.groupId,
                                      ),
                                    )
                                  : null,
                              detail: administrators == 0
                                  ? '未设置'
                                  : '$administrators 位',
                            ),
                            _row(
                              '禁言设置',
                              _role.canManage
                                  ? () => _open(
                                      GroupMuteSettingsPage(
                                        controller: widget.controller,
                                        groupId: widget.groupId,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      if (_role == GroupMemberRole.owner) ...[
                        const SizedBox(height: 12),
                        DialogActionButton(
                          text: '解散群聊',
                          role: DialogActionRole.reject,
                          onPressed: _busy ? null : _dissolve,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _surface(Widget child) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xff262626)
        : Colors.white,
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _row(String title, VoidCallback? onTap, {String? detail}) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    minTileHeight: 60,
    title: Text(title, style: const TextStyle(fontSize: 15)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (detail != null)
          Text(
            detail,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          const SettingsIcon(type: SettingsIconType.chevron),
        ],
      ],
    ),
    onTap: onTap,
  );
}
