import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../domain/agent_models.dart';
import 'random_contact.dart';
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
  final _created = <AiProfile>[];
  final _selected = <String>{};
  late final _joined = widget.members
      .where((m) => m.sender.kind == MessageSenderKind.agent)
      .map((m) => m.sender.id)
      .toSet();
  Timer? _debounce;
  int _generation = 0;
  bool _creating = false;
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
      ScaffoldMessenger.of(context).showGlassSnackBar(SnackBar(content: Text(text)));

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
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _failed = true);
        _notice('通讯录加载失败，请重试：${errorMessage(error)}');
      }
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_creating ||
        _joined.length + _selected.length >= GroupChatStore.maxAiMembers)
      return;
    setState(() => _creating = true);
    try {
      final color = await RandomContact.savedAvatarColor();
      if (!mounted) return;
      final rolled = RandomContact.roll(avatarColor: color);
      final now = DateTime.now();
      final config = widget.controller.modelSettings.activeConfig;
      final ai = AiProfile(
        sender: MessageSender(
          id: 'agent:${newMessageId()}',
          name: rolled.name,
          kind: MessageSenderKind.agent,
          avatarIcon: rolled.avatar.icon,
          avatarColor: rolled.avatar.color,
        ),
        description: rolled.description,
        instructions: '',
        isTemporary: true,
        preferences: AiPreferences(
          customInstructions: rolled.role,
          responses: rolled.responses,
        ),
        modelSelection: AiModelSelection(
          provider: config.service,
          model: config.model,
          baseUrl: config.baseUrl,
        ),
        createdAt: now,
        updatedAt: now,
      );
      _debounce?.cancel();
      _search.clear();
      setState(() {
        _created.add(ai);
        _selected.add(ai.sender.id);
      });
      await _load(reset: true);
    } catch (caughtError) {
      if (mounted) _notice('添加失败，请检查头像色库是否有配色后重试：${errorMessage(caughtError)}');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _edit(AiProfile ai) => Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => AiContactEditor(
        controller: widget.controller,
        profile: ai,
        onSaveDraft: (updated) async {
          setState(() {
            final index = _created.indexWhere(
              (member) => member.sender.id == updated.sender.id,
            );
            _created[index] = updated.copyWith(isTemporary: true);
          });
        },
      ),
    ),
  );

  Future<void> _invite() async {
    if (_saving || _creating || _selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.controller.groupStore.inviteMembers(
        widget.conversationId,
        _selected
            .where((id) => !_created.any((ai) => ai.sender.id == id))
            .toList(),
        newMembers: _created
            .where((ai) => _selected.contains(ai.sender.id))
            .toList(),
      );
      if (mounted) {
        _notice('已邀请加入群聊');
        Navigator.pop(context);
      }
    } on Object catch (error) {
      if (mounted)
        _notice(
          error is StateError
              ? error.message.toString()
              : '邀请失败，请重试：${errorMessage(error)}',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_creating,
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '邀请朋友',
        onBack: _saving || _creating ? null : () => Navigator.pop(context),
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
            onPressed: _saving || _creating || _selected.isEmpty
                ? null
                : _invite,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _saving || _creating,
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
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '随机添加成员',
                      onPressed:
                          !_creating &&
                              _joined.length + _selected.length <
                                  GroupChatStore.maxAiMembers
                          ? _create
                          : null,
                      icon: SettingsIcon(
                        type: SettingsIconType.add,
                        color:
                            !_creating &&
                                _joined.length + _selected.length <
                                    GroupChatStore.maxAiMembers
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).disabledColor,
                      ),
                    ),
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
                      for (final ai in [
                        ..._created.where(
                          (ai) => ai.sender.name.toLowerCase().contains(
                            _search.text.trim().toLowerCase(),
                          ),
                        ),
                        ..._profiles,
                      ])
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
                                onEdit:
                                    _created.any(
                                      (member) =>
                                          member.sender.id == ai.sender.id,
                                    )
                                    ? () => _edit(ai)
                                    : null,
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
                      if (!_loading &&
                          !_failed &&
                          _profiles.isEmpty &&
                          _created.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _search.text.trim().isEmpty
                                ? '暂无成员，点击右上方＋添加'
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
