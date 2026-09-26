import '../../app/glass_notice.dart';
import '../../domain/error_message.dart';
import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../domain/ai_profile.dart';
import '../../domain/message_sender.dart';
import '../../storage/group_chat_store.dart';
import '../../storage/new_group_draft.dart';
import 'ai_contact_editor.dart';
import 'chat_controller.dart';
import 'group_member_choice.dart';
import 'random_contact.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'dialog_action_button.dart';
import 'glass_surface.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key, required this.controller});
  final ChatController controller;
  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _name = TextEditingController();
  final _draft = NewGroupDraft();
  List<AiProfile> _contacts = [], _members = [];
  final _directory = <AiProfile>[];
  bool _directoryLoading = false,
      _directoryMore = true,
      _directoryFailed = false;
  bool _loading = true, _saving = false, _changing = false;
  bool _leaving = false, _allowPop = false;
  Set<String> _excluded = {};
  int get _newCount =>
      _members.where((ai) => !_excluded.contains(ai.sender.id)).length;
  int get _count => _contacts.length + _newCount;
  bool get _enabled => !_loading && !_saving && !_changing && !_leaving;
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

  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));
  Future<void> _load() async {
    try {
      final saved = await _draft.load();
      final contacts = await widget.controller.groupStore.selectedContacts(
        saved.contacts,
      );
      if (!mounted) return;
      setState(() {
        _name.text = saved.title;
        _contacts = contacts;
        _members = saved.members;
        _excluded = saved.excluded.toSet();
        _loading = false;
      });
      if (contacts.length != saved.contacts.length) {
        _notice('已移除不可用的通讯录成员');
        await _persist();
      }
      await _loadDirectory();
    } catch (caughtError) {
      if (mounted) {
        _notice('群聊草稿读取失败：${errorMessage(caughtError)}');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _persist() => _draft.save(
    _name.text,
    _contacts.map((ai) => ai.sender.id).toList(),
    _members,
    excluded: _excluded.toList(),
  );
  Future<void> _changedName() async {
    try {
      await _persist();
    } catch (caughtError) {
      if (mounted) _notice('草稿保存失败，请重试：${errorMessage(caughtError)}');
    }
  }

  Future<void> _change(
    List<AiProfile> contacts,
    List<AiProfile> members,
  ) async {
    setState(() => _changing = true);
    try {
      await _draft.save(
        _name.text,
        contacts.map((ai) => ai.sender.id).toList(),
        members,
        excluded: _excluded.toList(),
      );
      if (mounted)
        setState(() {
          _contacts = contacts;
          _members = members;
        });
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _roll() async {
    setState(() => _changing = true);
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
      await _change(_contacts, [..._members, ai]);
    } catch (caughtError) {
      if (mounted) _notice('添加失败，请检查头像色库是否有配色后重试：${errorMessage(caughtError)}');
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _loadDirectory() async {
    if (_directoryLoading || !_directoryMore) return;
    setState(() {
      _directoryLoading = true;
      _directoryFailed = false;
    });
    try {
      final page = await widget.controller.groupStore.listAi(
        offset: _directory.length,
      );
      if (mounted)
        setState(() {
          _directory.addAll(page);
          _directoryMore = page.length == GroupChatStore.pageSize;
        });
    } catch (caughtError) {
      if (mounted) {
        setState(() => _directoryFailed = true);
        _notice('通讯录读取失败，请重试：${errorMessage(caughtError)}');
      }
    } finally {
      if (mounted) setState(() => _directoryLoading = false);
    }
  }

  Future<void> _toggle(AiProfile ai) async {
    final selected = _contacts.any((p) => p.sender.id == ai.sender.id);
    if (!selected && _count == GroupChatStore.maxAiMembers) {
      _notice('群成员已达上限');
      return;
    }
    try {
      await _change(
        selected
            ? [
                for (final p in _contacts)
                  if (p.sender.id != ai.sender.id) p,
              ]
            : [..._contacts, ai],
        _members,
      );
    } catch (caughtError) {
      if (mounted) _notice('成员保存失败，请重试：${errorMessage(caughtError)}');
    }
  }

  Future<void> _edit(AiProfile ai) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AiContactEditor(
          controller: widget.controller,
          profile: ai,
          onSaveDraft: (updated) => _change(_contacts, [
            for (final member in _members)
              if (member.sender.id == updated.sender.id) updated else member,
          ]),
        ),
      ),
    );
  }

  Future<void> _toggleNew(AiProfile ai) async {
    final excluded = {..._excluded};
    if (excluded.contains(ai.sender.id)) {
      if (_count == GroupChatStore.maxAiMembers) {
        _notice('群成员已达上限');
        return;
      }
      excluded.remove(ai.sender.id);
    } else {
      excluded.add(ai.sender.id);
    }
    setState(() => _changing = true);
    try {
      await _draft.save(
        _name.text,
        _contacts.map((p) => p.sender.id).toList(),
        _members,
        excluded: excluded.toList(),
      );
      if (mounted) setState(() => _excluded = excluded);
    } catch (caughtError) {
      if (mounted) _notice('成员保存失败，请重试：${errorMessage(caughtError)}');
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      await _persist();
      final group = await widget.controller.groupStore.createGroup(
        title: _name.text.trim(),
        aiIds: _contacts.map((ai) => ai.sender.id).toList(),
        newMembers: [
          for (final ai in _members)
            if (!_excluded.contains(ai.sender.id)) ai,
        ],
      );
      try {
        await _draft.clear();
      } catch (caughtError) {
        if (mounted) _notice('群聊已创建，但草稿清理失败：${errorMessage(caughtError)}');
      }
      if (mounted) Navigator.pop(context, group.id);
    } catch (caughtError) {
      if (mounted) {
        setState(() => _saving = false);
        _notice('创建失败，请重试：${errorMessage(caughtError)}');
      }
    }
  }

  Future<void> _leave() async {
    if (!_enabled) return;
    setState(() => _leaving = true);
    if (_members.isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: GlassSurface(
              radius: 28,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '放弃创建群聊？',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '已生成的成员和本次群聊设置将被丢弃，下次进入不会恢复。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: DialogActionButton(
                            text: '继续编辑',
                            role: DialogActionRole.secondary,
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DialogActionButton(
                            text: '放弃创建',
                            role: DialogActionRole.destructive,
                            onPressed: () => Navigator.pop(context, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (discard != true) {
        setState(() => _leaving = false);
        return;
      }
    }
    try {
      await _draft.clear();
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (caughtError) {
      if (mounted) {
        setState(() => _leaving = false);
        _notice('草稿清理失败，请重试：${errorMessage(caughtError)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: _count == 0 ? '新建群聊' : '新建群聊（$_count 人）',
        onBack: _enabled ? _leave : null,
        actions: [
          SettingsGlassAction(
            label: _saving ? '正在创建' : '创建',
            icon: Icons.check_rounded,
            onPressed: _enabled && _count > 0 ? _create : null,
          ),
        ],
      ),
      body: SettingsPageBody(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: settingsPagePadding(
                        context,
                        const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      ),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        TextField(
                          controller: _name,
                          enabled: _enabled,
                          maxLength: 80,
                          onChanged: (_) => _changedName(),
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: '群名称（选填）',
                            counterText: '',
                            contentPadding: const EdgeInsets.all(18),
                            filled: true,
                            fillColor: settingsFieldColor(context),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '选择成员',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '随机添加成员',
                                onPressed:
                                    _enabled &&
                                        _count < GroupChatStore.maxAiMembers
                                    ? _roll
                                    : null,
                                icon: SettingsIcon(
                                  type: SettingsIconType.add,
                                  color:
                                      _enabled &&
                                          _count < GroupChatStore.maxAiMembers
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                      : Theme.of(context).disabledColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final ai in _members) _member(ai),
                        for (final ai in [
                          ..._contacts.where(
                            (selected) => !_directory.any(
                              (p) => p.sender.id == selected.sender.id,
                            ),
                          ),
                          ..._directory,
                        ])
                          GroupMemberChoice(
                            selected: _contacts.any(
                              (p) => p.sender.id == ai.sender.id,
                            ),
                            sender: ai.sender,
                            onTap: _enabled ? () => _toggle(ai) : null,
                          ),
                        if (_directoryLoading)
                          const Center(child: CircularProgressIndicator()),
                        if (!_directoryLoading && _directoryMore)
                          TextButton(
                            onPressed: _loadDirectory,
                            child: Text(_directoryFailed ? '重试' : '加载更多朋友'),
                          ),
                        if (!_directoryLoading &&
                            !_directoryFailed &&
                            _directory.isEmpty &&
                            _contacts.isEmpty &&
                            _members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('暂无成员，点击右上方＋添加'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
  Widget _member(AiProfile ai) => GroupMemberChoice(
    selected: !_excluded.contains(ai.sender.id),
    sender: ai.sender,
    onTap: _enabled ? () => _toggleNew(ai) : null,
    onEdit: _enabled ? () => _edit(ai) : null,
  );
}
