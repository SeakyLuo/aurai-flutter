import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_chat_store.dart';
import 'ai_contact_editor.dart';
import 'chat_controller.dart';
import 'group_member_choice.dart';
import 'pagination_listener.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

class GroupInvitePage extends StatefulWidget {
  const GroupInvitePage({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.members,
  });
  final ChatController controller;
  final String conversationId;
  final List<ConversationMember> members;
  @override
  State<GroupInvitePage> createState() => _GroupInvitePageState();
}

class _GroupInvitePageState extends State<GroupInvitePage> {
  final _search = TextEditingController();
  final _profiles = <AiProfile>[];
  final _selected = <String>{};
  late final _joined = widget.members
      .where((m) => m.sender.kind == MessageSenderKind.agent)
      .map((m) => m.sender.id)
      .toSet();
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false, _hasMore = true, _failed = false, _saving = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _profiles.clear();
        _hasMore = true;
      }
    });
    try {
      final page = await widget.controller.groupStore.contacts(
        _search.text.trim().toLowerCase(),
        archived: false,
        offset: _profiles.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _profiles.addAll(page);
        _hasMore = page.length == GroupChatStore.pageSize;
      });
    } on Object {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
        _notice('通讯录加载失败，请重试');
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AiContactEditor(controller: widget.controller),
      ),
    );
    if (!mounted) return;
    _debounce?.cancel();
    _search.clear();
    await _load(reset: true);
  }

  Future<void> _invite() async {
    if (_saving || _selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.controller.groupStore.inviteMembers(
        widget.conversationId,
        _selected.toList(),
      );
      if (mounted) {
        _notice('已邀请加入群聊');
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted)
        _notice(error is StateError ? error.message.toString() : '邀请失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '邀请朋友',
        onBack: _saving ? null : () => Navigator.pop(context),
        actions: [
          SettingsGlassAction(
            label: '邀请',
            icon: Icons.check_rounded,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SettingsIcon(type: SettingsIconType.check),
            onPressed: _saving || _selected.isEmpty ? null : _invite,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _saving,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: '搜索通讯录',
                    filled: true,
                    fillColor: settingsFieldColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 250),
                      () => _load(reset: true),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已选择 ${_selected.length} 位',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(onPressed: _create, child: const Text('创建 AI')),
                  ],
                ),
              ),
              Expanded(
                child: PaginationListener(
                  hasMore: _hasMore && !_failed,
                  loadMore: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final ai in _profiles)
                        _joined.contains(ai.sender.id)
                            ? Row(
                                children: [
                                  Expanded(
                                    child: GroupMemberChoice(
                                      selected: true,
                                      sender: ai.sender,
                                      onTap: null,
                                    ),
                                  ),
                                  Text(
                                    '已加入',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              )
                            : GroupMemberChoice(
                                selected: _selected.contains(ai.sender.id),
                                sender: ai.sender,
                                onTap: () {
                                  if (!_selected.contains(ai.sender.id) &&
                                      _joined.length + _selected.length >=
                                          GroupChatStore.maxAiMembers) {
                                    _notice('群聊最多可加入 32 位 AI');
                                    return;
                                  }
                                  setState(() {
                                    if (!_selected.remove(ai.sender.id))
                                      _selected.add(ai.sender.id);
                                  });
                                },
                              ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_failed)
                        TextButton(
                          onPressed: () => _load(reset: _profiles.isEmpty),
                          child: const Text('重试'),
                        ),
                      if (!_loading && !_failed && _profiles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _search.text.trim().isEmpty
                                ? '通讯录暂无 AI，可先创建 AI 再邀请'
                                : '没有找到匹配的 AI',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
