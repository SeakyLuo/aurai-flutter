import 'package:flutter/material.dart';

import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_chat_store.dart';
import 'chat_controller.dart';
import 'pagination_listener.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'group_member_choice.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key, required this.controller});
  final ChatController controller;
  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _name = TextEditingController();
  final _profiles = <AiProfile>[];
  final _selected = <String>{};
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  bool _saving = false;
  int _temporaryCount = 0;
  int get _memberCount => _selected.length + _temporaryCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.controller.groupStore.listAi(
        offset: _profiles.length,
      );
      if (!mounted) return;
      setState(() {
        _profiles.addAll(page);
        _hasMore = page.length == GroupChatStore.pageSize;
      });
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI 列表加载失败'),
            action: SnackBarAction(label: '重试', onPressed: _load),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (_memberCount == 0) {
      _notice('请选择 AI 成员');
      return;
    }
    setState(() => _saving = true);
    try {
      final group = await widget.controller.groupStore.createGroup(
        title: name.isEmpty ? '群聊' : name,
        aiIds: _selected.toList(),
        defaultSenderId: _selected.firstOrNull,
        temporaryCount: _temporaryCount,
      );
      if (mounted) Navigator.pop(context, group.id);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        _notice('创建失败，请重试');
      }
    }
  }

  Widget _countButton(String label, String text, int? delta) => Tooltip(
    message: label,
    child: TextButton(
      onPressed: _saving || delta == null
          ? null
          : () => setState(() => _temporaryCount += delta),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        text,
        semanticsLabel: label,
        style: const TextStyle(fontSize: 22),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: SettingsAppBar(
          title: '新建群聊',
          onBack: _saving ? null : () => Navigator.pop(context),
          actions: [
            SettingsGlassAction(
              label: _saving ? '正在创建' : '完成',
              icon: Icons.check_rounded,
              onPressed: _saving || _memberCount == 0 ? null : _create,
              iconWidget: SettingsIcon(
                type: SettingsIconType.check,
                color: _saving || _memberCount == 0
                    ? colors.onSurface.withValues(alpha: 0.3)
                    : colors.onSurface,
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: PaginationListener(
              hasMore: _hasMore && !_failed,
              loadMore: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 80,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '群名称（选填）',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: settingsFieldColor(context),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      '选择成员',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final profile in _profiles)
                    GroupMemberChoice(
                      selected: _selected.contains(profile.sender.id),
                      title: profile.sender.name,
                      isAurai: profile.sender.id == MessageSender.aurai.id,
                      onTap: _saving
                          ? null
                          : () => setState(() {
                              if (_selected.contains(profile.sender.id)) {
                                _selected.remove(profile.sender.id);
                              } else if (_memberCount <
                                  GroupChatStore.maxAiMembers) {
                                _selected.add(profile.sender.id);
                              } else {
                                _notice(
                                  '最多选择 ${GroupChatStore.maxAiMembers} 位 AI',
                                );
                              }
                            }),
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('临时 AI', style: TextStyle(fontSize: 16)),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: settingsFieldColor(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _countButton(
                                '减少临时 AI',
                                '−',
                                _temporaryCount > 0 ? -1 : null,
                              ),
                              Semantics(
                                liveRegion: true,
                                label: '$_temporaryCount 位临时 AI',
                                child: SizedBox(
                                  width: 36,
                                  child: Text(
                                    '$_temporaryCount',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              _countButton(
                                '增加临时 AI',
                                '+',
                                _memberCount < GroupChatStore.maxAiMembers
                                    ? 1
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_failed)
                    TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
