import '../../widgets/empty_data_view.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import 'app_confirmation_dialog.dart';
import 'group_mute_duration_page.dart';
import 'chat_controller.dart';
import 'member_avatar.dart';
import 'group_mute_selection.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupMutePage extends StatefulWidget {
  const GroupMutePage({
    super.key,
    required this.controller,
    required this.groupId,
  });
  final ChatController controller;
  final String groupId;
  @override
  State<GroupMutePage> createState() => _GroupMutePageState();
}

class _GroupMutePageState extends State<GroupMutePage> {
  List<ConversationMember> _members = [];
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await runUiAction(context, () async {
      final members = await widget.controller.groupStore.members(
        widget.groupId,
      );
      if (!mounted) return;
      setState(() => _members = members);
      _scheduleExpiry();
    });
    if (mounted)
      setState(() {
        _loading = false;
        _failed = !loaded;
      });
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final deadlines = _members
        .where((m) => m.isMuted && m.mute!.until != null)
        .map((m) => m.mute!.until!)
        .toList();
    if (deadlines.isEmpty) return;
    final next = deadlines.reduce((a, b) => a.isBefore(b) ? a : b);
    _expiry = Timer(next.difference(DateTime.now()), () {
      if (mounted) {
        setState(() {});
        _scheduleExpiry();
      }
    });
  }

  Future<void> _change(ConversationMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: '解除禁言？',
        description: '解除 ${member.sender.name} 的单独禁言。全群禁言仍按禁言设置生效。',
        confirmLabel: '解除禁言',
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    final saved = await runUiAction(
      context,
      () => widget.controller.setGroupMemberMute(
        widget.groupId,
        member.sender.id,
        duration: Duration.zero,
      ),
    );
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('已解除单独禁言')));
      await _load();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add() async {
    final role = _members
        .firstWhere((m) => m.sender.id == MessageSender.localUser.id)
        .role;
    final candidates = _members
        .where(
          (m) => !m.isMuted && m.canBeMutedBy(role, MessageSender.localUser.id),
        )
        .toList();
    final choice =
        await Navigator.push<({Set<String> members, Duration? duration})>(
          context,
          MaterialPageRoute(
            builder: (_) => GroupMuteSelection(
              members: candidates,
              chooseDuration: (selectionContext, count) =>
                  Navigator.push<({Duration? duration})>(
                    selectionContext,
                    MaterialPageRoute(
                      builder: (_) => const GroupMuteDurationPage(),
                    ),
                  ),
            ),
          ),
        );
    if (!mounted || choice == null) return;
    setState(() => _busy = true);
    final saved = await runUiAction(
      context,
      () => widget.controller.setGroupMembersMute(
        widget.groupId,
        choice.members,
        duration: choice.duration,
      ),
    );
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('已设置成员禁言')));
      await _load();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final role = _members.isEmpty
        ? null
        : _members
              .firstWhere((m) => m.sender.id == MessageSender.localUser.id)
              .role;
    final canAdd =
        role != null &&
        _members.any(
          (m) => !m.isMuted && m.canBeMutedBy(role, MessageSender.localUser.id),
        );
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '单独禁言成员',
          onBack: _busy ? null : () => Navigator.pop(context),
          actions: [
            if (!_loading &&
                !_failed &&
                role != null &&
                _members.any((m) => m.isMuted) &&
                _members.any(
                  (m) =>
                      !m.isMuted &&
                      m.canBeMutedBy(role, MessageSender.localUser.id),
                ))
              SettingsGlassAction(
                label: '添加',
                icon: Icons.add_rounded,
                iconWidget: const SettingsIcon(type: SettingsIconType.add),
                onPressed: _busy ? null : _add,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
              ? Center(
                  child: TextButton(onPressed: _load, child: const Text('重试')),
                )
              : !_members.any((m) => m.isMuted)
              ? Padding(
                  padding: EdgeInsets.only(top: settingsHeaderHeight(context)),
                  child: EmptyDataView(
                    title: '暂无禁言成员',
                    actionText: canAdd ? '添加成员' : null,
                    actionIcon: SettingsIcon(
                      type: SettingsIconType.add,
                      color: colors.onPrimary,
                    ),
                    onAction: _busy ? null : _add,
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    settingsHeaderHeight(context) + 16,
                    16,
                    24,
                  ),
                  children: [
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(26),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final member in _members.where((m) => m.isMuted))
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              minTileHeight: 64,
                              leading: MemberAvatar(
                                sender: member.sender,
                                size: 42,
                              ),
                              title: Text(
                                member.sender.name,
                                style: const TextStyle(fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '已${member.mute!.description}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              trailing:
                                  role != null &&
                                      member.canBeMutedBy(
                                        role,
                                        MessageSender.localUser.id,
                                      )
                                  ? TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _change(member),
                                      child: const Text('解除禁言'),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
