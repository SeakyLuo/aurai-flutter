import 'header_action_menu.dart';
import 'ai_contact_actions.dart';
import 'conversation_menu_icon.dart';
import 'conversation_icon.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/ai_profile.dart';
import '../../domain/avatar_style.dart';
import 'chat_controller.dart';
import 'ai_contact_editor.dart';
import 'ai_contact_page.dart';
import 'profile_avatar.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'pagination_listener.dart';
import 'glass_surface.dart';

class AiContactsPage extends StatefulWidget {
  const AiContactsPage({
    super.key,
    required this.controller,
    this.archived = false,
    this.root = false,
  });
  final ChatController controller;
  final bool archived;
  final bool root;
  @override
  State<AiContactsPage> createState() => _AiContactsPageState();
}

class _AiContactsPageState extends State<AiContactsPage> {
  final _search = TextEditingController();
  final _items = <AiProfile>[];
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false, _more = true;
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

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      if (reset) _items.clear();
    });
    try {
      final page = await widget.controller.groupStore.contacts(
        _search.text.trim(),
        archived: widget.archived,
        offset: _items.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _more = page.length == 50;
      });
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('朋友加载失败'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _load(reset: true),
            ),
          ),
        );
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _open(String id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            AiContactPage(controller: widget.controller, senderId: id),
      ),
    );
    if (mounted) _load(reset: true);
  }

  Future<void> _create() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => AiContactEditor(controller: widget.controller),
      ),
    );
    if (!mounted) return;
    if (id != null) await _open(id);
    if (mounted) _load(reset: true);
  }

  Future<void> _menu(AiProfile ai) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: GlassSurface(
          radius: 26,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in [
                  ('open', '查看资料', SettingsIconType.personalInfo),
                  if (!ai.sender.archived)
                    ('message', '发消息', SettingsIconType.personalization),
                  ('edit', '编辑', SettingsIconType.filter),
                  (
                    'archive',
                    ai.sender.archived ? '恢复朋友' : '归档朋友',
                    SettingsIconType.filter,
                  ),
                ])
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    leading: item.$1 == 'message'
                        ? const ConversationIcon()
                        : item.$1 == 'edit'
                        ? ConversationMenuIcon(
                            type: ConversationMenuIconType.rename,
                            color: Theme.of(context).colorScheme.onSurface,
                          )
                        : item.$1 == 'archive'
                        ? ConversationMenuIcon(
                            type: ai.sender.archived
                                ? ConversationMenuIconType.unarchive
                                : ConversationMenuIconType.archive,
                            color: Theme.of(context).colorScheme.onSurface,
                          )
                        : SettingsIcon(type: item.$3),
                    title: Text(item.$2),
                    onTap: () => Navigator.pop(context, item.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'message') {
      await openAiChat(context, widget.controller, ai);
      if (mounted) _load(reset: true);
      return;
    }
    if (action == 'archive') {
      await changeAiArchive(context, widget.controller, ai);
      if (mounted) _load(reset: true);
      return;
    }
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              AiContactEditor(controller: widget.controller, profile: ai),
        ),
      );
      if (mounted) _load(reset: true);
    } else {
      await _open(ai.sender.id);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SettingsAppBar(
      title: widget.archived ? '已归档朋友' : '通讯录',
      root: widget.root,
      onBack: () => Navigator.pop(context),
      actions: [
        if (!widget.archived)
          Builder(
            builder: (buttonContext) => SettingsGlassAction(
              label: '更多',
              icon: Icons.more_horiz_rounded,
              onPressed: () async {
                final action = await showHeaderActionMenu(
                  buttonContext,
                  items: [
                    const (
                      value: 'create',
                      label: '添加朋友',
                      icon: SettingsIcon(type: SettingsIconType.add),
                    ),
                    (
                      value: 'archive',
                      label: '已归档朋友',
                      icon: ConversationMenuIcon(
                        type: ConversationMenuIconType.archive,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                );
                if (!mounted || action == null) return;
                if (action == 'create') {
                  await _create();
                  return;
                }
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiContactsPage(
                      controller: widget.controller,
                      archived: true,
                    ),
                  ),
                );
                if (mounted) _load(reset: true);
              },
            ),
          ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '搜索朋友',
              filled: true,
              fillColor: settingsFieldColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) {
              _generation++;
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 250),
                () => _load(reset: true),
              );
            },
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(
                          _search.text.isNotEmpty
                              ? '没有找到朋友'
                              : widget.archived
                              ? '没有已归档朋友'
                              : '点击右上角，创建你的第一个 AI',
                        ),
                )
              : PaginationListener(
                  hasMore: _more,
                  loadMore: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final ai = _items[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        leading: ProfileAvatar(
                          style: AvatarStyle(
                            icon: ai.sender.avatarIcon,
                            color: ai.sender.avatarColor,
                            path: ai.sender.avatarPath,
                          ),
                          name: ai.sender.name,
                          size: 44,
                        ),
                        title: Text(
                          ai.sender.name,
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: ai.description.isEmpty
                            ? null
                            : Text(
                                ai.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => _open(ai.sender.id),
                        onLongPress: () => _menu(ai),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}
