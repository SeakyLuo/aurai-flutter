import '../../domain/contact_name_order.dart';
import 'app_bottom_sheet.dart';
import 'package:flutter/material.dart';
import '../../app/ui_action.dart';
import '../../domain/message_sender.dart';
import '../../widgets/empty_data_view.dart';
import 'chat_controller.dart';
import 'choice_sheet.dart';
import 'delete_confirmation_dialog.dart';
import 'dialog_action_button.dart';
import 'header_action_menu.dart';
import 'group_member_choice.dart';
import 'member_avatar.dart';
import 'menu_press_highlight.dart';
import 'question_icon.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'tool_approval_entry.dart';

class ToolApprovalsPage extends StatefulWidget {
  const ToolApprovalsPage({super.key, required this.controller, this.senderId});
  final ChatController controller;
  final String? senderId;
  @override
  State<ToolApprovalsPage> createState() => _ToolApprovalsPageState();
}

class _ToolApprovalsPageState extends State<ToolApprovalsPage> {
  List<ToolApprovalEntry> _entries = [];
  Map<String, String> _names = {};
  Map<String, MessageSender> _senders = {};
  late String? _selected = widget.senderId;
  bool _loading = true;
  final _removing = <(String, String?)>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await runUiAction(context, () async {
      final store = widget.controller.toolApprovals;
      final entries = [
        for (final e in store.persistent.entries)
          ToolApprovalEntry(e.key, e.value, null),
        for (final s in store.sessions.entries)
          for (final e in s.value.entries)
            ToolApprovalEntry(e.key, e.value, s.key),
      ];
      final ids = {for (final e in entries) ...e.references}.toList();
      final names = <String, String>{};
      final senders = <String, MessageSender>{};
      if (ids.isNotEmpty) {
        final placeholders = List.filled(ids.length, '?').join(',');
        final db = widget.controller.groupStore.database;
        final results = await Future.wait([
          db.query(
            'message_senders',
            where: 'id IN ($placeholders)',
            whereArgs: ids,
          ),
          db.query(
            'conversations',
            columns: ['id', 'title'],
            where: 'id IN ($placeholders)',
            whereArgs: ids,
          ),
        ]);
        for (final r in results[0]) {
          names[r['id'] as String] = r['name'] as String;
          final sender = MessageSender.fromRow(r);
          senders[sender.id] = sender;
        }
        for (final r in results[1]) {
          names[r['id'] as String] = r['title'] as String;
        }
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _names = names;
        _senders = senders;
        for (final e in entries) {
          _names.putIfAbsent(e.sender, () => e.savedSenderName);
        }
        _selected ??= entries.firstOrNull?.sender;
      });
    });
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _chooseAi() async {
    final value = await showChoiceSheet<String>(
      context,
      title: '选择群成员',
      searchHint: '搜索群成员',
      selected: _selected!,
      choices: [
        for (final id
            in _entries
                .map((e) => e.sender)
                .toSet()
                .byContactName((id) => _senders[id]!))
          (value: id, label: _names[id]!),
      ],
      itemBuilder: (choice, selected, onTap) => GroupMemberChoice(
        sender: _senders[choice.value]!,
        selected: selected,
        onTap: onTap,
      ),
    );
    if (mounted && value != null) setState(() => _selected = value);
  }

  Future<bool> _revoke(ToolApprovalEntry e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteConfirmationDialog(
        title: '撤销这项授权？',
        description: '撤销后，再次执行需要授权的操作时会重新询问。',
        confirmLabel: '撤销授权',
      ),
    );
    if (!mounted || yes != true) return false;
    final token = (e.key, e.conversation);
    setState(() => _removing.add(token));
    final ok = await runUiAction(
      context,
      () => widget.controller.toolApprovals.revoke(
        e.key,
        conversation: e.conversation,
      ),
    );
    if (mounted)
      setState(() {
        _removing.remove(token);
        if (ok) _entries.remove(e);
      });
    return ok;
  }

  Future<void> _menu(
    BuildContext anchor,
    ToolApprovalEntry e, {
    Offset? position,
    VoidCallback? onRevoked,
  }) async {
    final action = await showHeaderActionMenu(
      anchor,
      position: position,
      destructiveValues: const {'revoke'},
      items: const [
        (
          value: 'revoke',
          label: '撤销授权',
          icon: SettingsIcon(type: SettingsIconType.remove),
        ),
      ],
    );
    if (!mounted || action != 'revoke') return;
    if (await _revoke(e)) onRevoked?.call();
  }

  Future<void> _details(ToolApprovalEntry e) {
    var revoking = false;
    return showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheet) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    SettingsGlassAction(
                      label: '关闭',
                      icon: Icons.close_rounded,
                      iconWidget: const QuestionIcon(
                        type: QuestionIconType.close,
                      ),
                      onPressed: () => Navigator.pop(sheet),
                    ),
                    const Expanded(
                      child: Text(
                        '授权详情',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    _field('允许操作', e.title),
                    _field(
                      '授权范围',
                      e.summary(_names).isEmpty
                          ? e.description
                          : e.summary(_names),
                    ),
                    if (e.summary(_names).isNotEmpty &&
                        e.summary(_names) != e.description)
                      _field('授权说明', e.description),
                    _field(
                      '有效范围',
                      e.conversation == null
                          ? '始终允许'
                          : '仅限会话：${_names[e.conversation] ?? '已删除的会话'}',
                    ),
                    StatefulBuilder(
                      builder: (context, updateButton) => DialogActionButton(
                        text: '撤销授权',
                        role: DialogActionRole.destructive,
                        loading: revoking,
                        onPressed: () async {
                          updateButton(() => revoking = true);
                          final revoked = await _revoke(e);
                          if (!sheet.mounted) return;
                          if (revoked) {
                            Navigator.pop(sheet);
                          } else {
                            updateButton(() => revoking = false);
                          }
                        },
                      ),
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

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: settingsFieldColor(context),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(value, style: const TextStyle(fontSize: 15, height: 1.5)),
        ),
      ],
    ),
  );
  Widget _section(
    String title,
    List<ToolApprovalEntry> entries, {
    bool first = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(12, first ? 0 : 24, 12, 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Material(
        color: settingsFieldColor(context),
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final e in entries)
              Builder(
                builder: (anchor) {
                  final subtitle = e.summary(_names);
                  final busy = _removing.contains((e.key, e.conversation));
                  return MenuPressHighlight(
                    borderRadius: BorderRadius.circular(18),
                    onLongPressStart: busy
                        ? null
                        : (d) => _menu(anchor, e, position: d.globalPosition),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      title: Text(
                        e.title,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                      trailing: const SettingsIcon(
                        type: SettingsIconType.chevron,
                      ),
                      onTap: busy ? null : () => _details(e),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final entries = _entries.where((e) => e.sender == _selected).toList();
    final permanent = entries.where((e) => e.conversation == null).toList();
    final sessions = <String, List<ToolApprovalEntry>>{};
    for (final e in entries) {
      if (e.conversation != null)
        sessions.putIfAbsent(e.conversation!, () => []).add(e);
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '工具授权',
        onBack: () => Navigator.pop(context),
      ),
      body: SettingsPageBody(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: settingsPagePadding(
                      context,
                      const EdgeInsets.fromLTRB(18, 12, 18, 24),
                    ),
                    sliver: SliverList.list(
                      children: [
                        if (widget.senderId == null && _selected != null)
                          Material(
                            color: settingsFieldColor(context),
                            borderRadius: BorderRadius.circular(26),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 6,
                              ),
                              leading: MemberAvatar(
                                sender: _senders[_selected]!,
                                size: 36,
                              ),
                              title: Text(_names[_selected]!),
                              trailing: const SettingsIcon(
                                type: SettingsIconType.chevronDown,
                              ),
                              onTap: _entries.isEmpty ? null : _chooseAi,
                            ),
                          ),
                        if (permanent.isNotEmpty)
                          _section(
                            '始终允许',
                            permanent,
                            first: widget.senderId != null || _selected == null,
                          ),
                        for (final session in sessions.entries)
                          _section(
                            '会话内允许 · ${_names[session.key] ?? '已删除的会话'}',
                            session.value,
                            first:
                                permanent.isEmpty &&
                                session.key == sessions.keys.first &&
                                (widget.senderId != null || _selected == null),
                          ),
                      ],
                    ),
                  ),
                  if (_loading || entries.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const EmptyDataView(title: '暂无工具授权'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
