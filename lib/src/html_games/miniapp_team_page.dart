import 'dart:async';

import 'package:flutter/material.dart';

import '../app/ui_action.dart';
import '../domain/message_sender.dart';
import '../features/chat/delete_confirmation_dialog.dart';
import '../features/chat/member_avatar.dart';
import '../features/chat/header_action_menu.dart';
import '../scheduling/task_action_menu.dart';
import '../features/chat/pagination_listener.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
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
    final members = await Navigator.push<List<MessageSender>>(
      context,
      MaterialPageRoute(
        builder: (_) => MiniappTeamPicker(store: widget.store, appId: _id),
      ),
    );
    if (members == null || !mounted) return;
    setState(() => _busy = true);
    await runUiAction(
      context,
      () => widget.store.addMembers(
        _id,
        MessageSender.localUser.id,
        members.map((member) => member.id).toSet(),
      ),
    );
    if (mounted) setState(() => _busy = false);
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

  Future<void> _memberMenu(BuildContext anchor, MessageSender member) async {
    final action = await showHeaderActionMenu(
      anchor,
      items: [
        (
          value: 'remove',
          label: '移出开发团队',
          icon: const SettingsIcon(type: SettingsIconType.remove),
        ),
      ],
    );
    if (mounted && action == 'remove') await _remove(member);
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _memberRow(
    MessageSender member, {
    required bool creator,
    required bool manager,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: settingsFieldColor(context),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            MemberAvatar(sender: member, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (!creator && manager)
              Builder(
                builder: (anchor) => IconButton(
                  tooltip: '更多',
                  icon: const TaskActionIcon('more'),
                  onPressed: _busy ? null : () => _memberMenu(anchor, member),
                ),
              ),
          ],
        ),
      ),
    ),
  );

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
                    if (creator != null) ...[
                      _sectionLabel('创建人'),
                      _memberRow(creator, creator: true, manager: manager),
                    ],
                    if (_members.isNotEmpty) _sectionLabel('开发成员'),
                    for (final member in _members)
                      _memberRow(member, creator: false, manager: manager),
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
