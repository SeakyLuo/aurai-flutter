import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../app/glass_notice.dart';
import '../../app/global_ui.dart';
import '../../app/ui_action.dart';
import '../../domain/message_sender.dart';
import '../../platform/aurai_platform.dart';
import '../../storage/group_announcement_store.dart';
import '../../scheduling/task_unsaved_dialog.dart';
import 'chat_controller.dart';
import 'cjk_strong_syntax.dart';
import 'markdown_link_underlines.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';
import 'conversation_menu_icon.dart';
import 'member_avatar.dart';
import 'ai_contact_page.dart';
import 'personal_info_page.dart';

class GroupAnnouncementPage extends StatefulWidget {
  const GroupAnnouncementPage({
    super.key,
    required this.controller,
    required this.groupId,
  });
  final ChatController controller;
  final String groupId;
  @override
  State<GroupAnnouncementPage> createState() => _GroupAnnouncementPageState();
}

class _GroupAnnouncementPageState extends State<GroupAnnouncementPage> {
  late final _store = GroupAnnouncementStore(widget.controller.groupStore);
  GroupAnnouncement? _announcement;
  MessageSender? _editor;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final ok = await runUiAction(context, () async {
      final value = await _store.read(
        widget.groupId,
        MessageSender.localUser.id,
      );
      final editorRows = value == null
          ? null
          : await widget.controller.groupStore.database.query(
              'message_senders',
              where: 'id = ?',
              whereArgs: [value.editorId],
              limit: 1,
            );
      if (mounted)
        setState(() {
          _announcement = value;
          _editor = editorRows == null
              ? null
              : MessageSender.fromRow(editorRows.single);
        });
    });
    if (mounted)
      setState(() {
        _loading = false;
        _failed = !ok;
      });
  }

  Future<void> _edit() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _AnnouncementEditor(
          store: _store,
          groupId: widget.groupId,
          content: _announcement?.content ?? '',
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openProfile() async {
    final senderId = _editor!.id;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => senderId == MessageSender.localUser.id
            ? PersonalInfoPage(memory: widget.controller.memory)
            : AiContactPage(
                controller: widget.controller,
                senderId: senderId,
                groupId: widget.groupId,
              ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openLink(String? href) async {
    final uri = Uri.tryParse(href ?? '');
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('无法打开此链接')));
      return;
    }
    await runUiAction(
      context,
      () => AuraiPlatform.instance.startIntent({
        'action': 'android.intent.action.VIEW',
        'data': uri.toString(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _announcement;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: SettingsAppBar(
          title: '群公告',
          onBack: _busy ? null : () => Navigator.pop(context),
          actions: [
            if (!_loading && !_failed)
              SettingsGlassAction(
                label: '编辑群公告',
                icon: Icons.edit_rounded,
                iconWidget: ConversationMenuIcon(
                  type: ConversationMenuIconType.rename,
                  color: SettingsGlassAction.foregroundColor(
                    context,
                    enabled: !_busy,
                  ),
                ),
                onPressed: _busy ? null : _edit,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failed
                  ? Center(
                      child: TextButton(
                        onPressed: _load,
                        child: const Text('重试'),
                      ),
                    )
                  : value == null
                  ? Center(
                      child: Text(
                        '暂无群公告',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        settingsHeaderHeight(context) + 16,
                        20,
                        32,
                      ),
                      children: [
                        Row(
                          children: [
                            Semantics(
                              button: true,
                              label: '查看${_editor!.name}的资料',
                              child: InkWell(
                                onTap: _openProfile,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: MemberAvatar(
                                    sender: _editor!,
                                    size: 44,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    value.editorName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _time(value.updatedAt),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Divider(
                            height: 1,
                            thickness: .5,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        MediaQuery.removePadding(
                          context: context,
                          removeBottom: true,
                          child: SelectionArea(
                            child: MarkdownLinkUnderlines(
                              child: MarkdownBody(
                                data: value.content,
                                selectable: false,
                                inlineSyntaxes: [CjkStrongSyntax()],
                                onTapLink: (text, href, title) =>
                                    _openLink(href),
                                styleSheet:
                                    MarkdownStyleSheet.fromTheme(
                                      Theme.of(context),
                                    ).copyWith(
                                      a: GlobalUI.linkStyle(context),
                                      p: TextStyle(
                                        fontSize: 17,
                                        height: 1.55,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                      tableColumnWidth:
                                          const IntrinsicColumnWidth(),
                                      tableScrollbarThumbVisibility: true,
                                    ),
                              ),
                            ),
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

String _time(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _AnnouncementEditor extends StatefulWidget {
  const _AnnouncementEditor({
    required this.store,
    required this.groupId,
    required this.content,
  });
  final GroupAnnouncementStore store;
  final String groupId;
  final String content;
  @override
  State<_AnnouncementEditor> createState() => _AnnouncementEditorState();
}

class _AnnouncementEditorState extends State<_AnnouncementEditor> {
  late final _text = TextEditingController(text: widget.content);
  bool _busy = false;
  bool _leaving = false;
  bool get _dirty => _text.text != widget.content;
  bool get _canPublish =>
      _dirty &&
      !_busy &&
      (widget.content.isNotEmpty || _text.text.trim().isNotEmpty);
  String get _publishLabel =>
      _text.text.trim().isEmpty && widget.content.isNotEmpty
      ? '保存'
      : widget.content.isEmpty
      ? '发布'
      : '发布更新';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    final ok = await runUiAction(
      context,
      () => widget.store.write(
        widget.groupId,
        MessageSender.localUser.id,
        _text.text,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _close();
  }

  void _close() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _back() async {
    if (_busy) return;
    if (!_dirty) {
      _close();
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (_) => TaskUnsavedDialog(
        title: _text.text.trim().isEmpty && widget.content.isNotEmpty
            ? '保存修改？'
            : '发布群公告？',
        description: '公告还有未发布的修改。',
        saveLabel: _publishLabel,
        canSave: _canPublish,
      ),
    );
    if (!mounted) return;
    if (result == 'save') await _publish();
    if (result == 'discard') _close();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SettingsAppBar(
        title: '编辑群公告',
        onBack: _busy ? null : _back,
        actions: [
          SettingsGlassAction(
            label: _busy ? '正在发布' : _publishLabel,
            icon: Icons.check_rounded,
            iconWidget: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SettingsIcon(
                    type: SettingsIconType.check,
                    color: SettingsGlassAction.foregroundColor(
                      context,
                      enabled: _canPublish,
                    ),
                  ),
            onPressed: _canPublish ? _publish : null,
          ),
        ],
      ),
      body: SettingsPageBody(
        avoidHeader: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: TextField(
                  controller: _text,
                  enabled: !_busy,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 16, height: 1.7),
                  decoration: const InputDecoration(
                    hintText: '填写群公告，支持 Markdown',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
