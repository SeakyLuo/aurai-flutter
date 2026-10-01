import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/ai_profile.dart';
import '../../storage/group_chat_store.dart';
import 'chat_controller.dart';
import 'group_mute_page.dart';
import 'group_mute_duration_page.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupMuteSettingsPage extends StatefulWidget {
  const GroupMuteSettingsPage({
    super.key,
    required this.controller,
    required this.groupId,
  });
  final ChatController controller;
  final String groupId;
  @override
  State<GroupMuteSettingsPage> createState() => _GroupMuteSettingsPageState();
}

class _GroupMuteSettingsPageState extends State<GroupMuteSettingsPage> {
  GroupMute? _mute;
  int _count = 0;
  bool _loading = true, _failed = false, _busy = false;
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
      final (mute, members) = await (
        widget.controller.groupStore.groupWideMute(widget.groupId),
        widget.controller.groupStore.members(widget.groupId),
      ).wait;
      if (!mounted) return;
      setState(() {
        _mute = mute;
        _count = members.where((m) => m.isMuted).length;
      });
      _expiry?.cancel();
      final deadlines = [
        if (mute?.isActive == true && mute!.until != null) mute.until!,
        ...members
            .where((m) => m.isMuted && m.mute!.until != null)
            .map((m) => m.mute!.until!),
      ];
      if (deadlines.isNotEmpty) {
        final next = deadlines.reduce((a, b) => a.isBefore(b) ? a : b);
        _expiry = Timer(next.difference(DateTime.now()), () {
          if (mounted) _load();
        });
      }
    });
    if (mounted)
      setState(() {
        _loading = false;
        _failed = !loaded;
      });
  }

  Future<void> _set(int mode) async {
    Duration? duration;
    if (mode == 0) duration = Duration.zero;
    if (mode == 2) {
      final choice = await Navigator.push<({Duration? duration})>(
        context,
        MaterialPageRoute(
          builder: (_) => const GroupMuteDurationPage(allowPermanent: false),
        ),
      );
      if (!mounted || choice == null) return;
      duration = choice.duration;
    }
    setState(() => _busy = true);
    final saved = await runUiAction(
      context,
      () => widget.controller.setGroupWideMute(
        widget.groupId,
        duration: duration,
      ),
    );
    if (!mounted) return;
    if (saved) {
      await _load();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _members() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMutePage(
          controller: widget.controller,
          groupId: widget.groupId,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mute?.isActive != true
        ? 0
        : _mute!.until == null
        ? 1
        : 2;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '禁言设置',
          onBack: _busy ? null : () => Navigator.pop(context),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
            ? Center(
                child: TextButton(onPressed: _load, child: const Text('重试')),
              )
            : AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  padding: settingsPagePadding(
                    context,
                    const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  ),
                  children: [
                    _note('设置禁言类型'),
                    _surface(
                      Column(
                        children: [
                          for (final entry in [
                            (0, '未开启禁言'),
                            (1, '始终禁言'),
                            (2, '定时禁言'),
                          ])
                            ListTile(
                              minTileHeight: 60,
                              title: Text(
                                entry.$2,
                                style: const TextStyle(fontSize: 15),
                              ),
                              subtitle: entry.$1 == 2 && mode == 2
                                  ? Text(_mute!.description)
                                  : null,
                              trailing: mode == entry.$1
                                  ? const SettingsIcon(
                                      type: SettingsIconType.check,
                                    )
                                  : null,
                              onTap: () => _set(entry.$1),
                            ),
                        ],
                      ),
                    ),
                    _note('开启后，仅群主和管理员可以发言'),
                    const SizedBox(height: 24),
                    _note('设置单独禁言群成员'),
                    _surface(
                      ListTile(
                        minTileHeight: 60,
                        title: const Text(
                          '单独禁言群成员',
                          style: TextStyle(fontSize: 15),
                        ),
                        onTap: _members,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _count == 0 ? '未设置' : '$_count 位',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SettingsIcon(type: SettingsIconType.chevron),
                          ],
                        ),
                      ),
                    ),
                    _note('未开启全群禁言时，单独禁言成员仍然生效'),
                  ],
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
  Widget _note(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
