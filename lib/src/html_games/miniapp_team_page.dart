import 'dart:async';

import 'package:flutter/material.dart';

import '../app/ui_action.dart';
import '../domain/message_sender.dart';
import '../features/chat/app_confirmation_dialog.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/member_avatar.dart';
import '../features/chat/pagination_listener.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import 'miniapp_requests_page.dart';
import 'miniapp_team_picker.dart';
import 'miniapp_team_store.dart';

class MiniappTeamPage extends StatefulWidget {
  const MiniappTeamPage({super.key, required this.store, required this.appId});
  final MiniappTeamStore store;
  final String appId;
  @override
  State<MiniappTeamPage> createState() => _MiniappTeamPageState();
}

class _MiniappTeamPageState extends State<MiniappTeamPage> {
  Map<String, Object?>? _data;
  final _members = <MessageSender>[];
  bool _loading = false, _failed = false, _busy = false, _more = false;
  int _generation = 0;
  late final StreamSubscription<String> _changes;
  String get _id => _data?['appId'] as String? ?? widget.appId;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _changes = MiniappTeamStore.changes.stream.listen((id) {
      if (id == _id) _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = await runUiAction(context, () async {
      final data = await widget.store.read(
        _id,
        MessageSender.localUser.id,
        offset: reset ? 0 : _members.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        if (reset) _members.clear();
        _members.addAll([
          for (final row in data['entries'] as List)
            MessageSender.fromRow(
              (row['profile'] as Map).cast<String, Object?>(),
            ),
        ]);
        _more = data['hasMore'] as bool;
      });
    });
    if (mounted && generation == _generation)
      setState(() {
        _loading = false;
        _failed = !ok;
      });
  }

  Future<void> _add() async {
    final member = await Navigator.push<MessageSender>(
      context,
      MaterialPageRoute(
        builder: (_) => MiniappTeamPicker(store: widget.store, appId: _id),
      ),
    );
    if (member == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: '添加开发成员',
        description: '允许 ${member.name} 编辑此小程序？',
        confirmLabel: '添加',
      ),
    );
    if (confirmed == true && mounted) await _manage('add', member);
  }

  Future<void> _remove(MessageSender member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(
        title: '移出开发团队',
        description: '移出后，${member.name} 将无法继续编辑此小程序。',
        confirmLabel: '移出',
      ),
    );
    if (confirmed == true && mounted) await _manage('remove', member);
  }

  Future<void> _manage(String action, MessageSender member) async {
    setState(() => _busy = true);
    await runUiAction(
      context,
      () => widget.store.manage(
        _id,
        MessageSender.localUser.id,
        action,
        member.id,
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final creator = data == null
        ? null
        : MessageSender.fromRow(
            (data['creator'] as Map).cast<String, Object?>(),
          );
    final manager = data?['canManage'] == true;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '开发团队',
        onBack: () => Navigator.pop(context),
        actions: [
          if (manager)
            SettingsGlassAction(
              label: '添加成员',
              icon: Icons.add_rounded,
              iconWidget: const SettingsIcon(type: SettingsIconType.add),
              onPressed: _busy ? null : _add,
            ),
        ],
      ),
      body: SettingsPageBody(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: PaginationListener(
                hasMore: _more && !_loading && !_failed,
                failed: _failed,
                onRetry: () => _load(reset: true),
                loadMore: _load,
                child: ListView(
                  padding: settingsPagePadding(
                    context,
                    const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  ),
                  children: [
                    if (manager)
                      Material(
                        color: settingsFieldColor(context),
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          title: const Text('修改申请'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((data!['pendingCount'] as int) > 0)
                                Text('${data['pendingCount']}'),
                              const SizedBox(width: 8),
                              const SettingsIcon(
                                type: SettingsIconType.chevron,
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MiniappRequestsPage(
                                store: widget.store,
                                appId: _id,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (creator != null)
                      ListTile(
                        leading: MemberAvatar(sender: creator, size: 44),
                        title: Text(creator.name),
                        trailing: Text(
                          '创建人',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final member in _members)
                      ListTile(
                        leading: MemberAvatar(sender: member, size: 44),
                        title: Text(member.name),
                        trailing: manager
                            ? IconButton(
                                tooltip: '移出开发团队',
                                icon: const SettingsIcon(
                                  type: SettingsIconType.remove,
                                ),
                                onPressed: _busy ? null : () => _remove(member),
                              )
                            : null,
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
