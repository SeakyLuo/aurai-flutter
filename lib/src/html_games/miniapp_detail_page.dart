import 'miniapp_icon.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/app_confirmation_dialog.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../features/chat/member_avatar.dart';
import '../features/chat/dialog_action_button.dart';
import '../scheduling/task_action_menu.dart';
import 'miniapp_metadata_editor.dart';
import 'html_game_store.dart';
import 'html_game_view.dart';
import 'miniapp_library_store.dart';
import 'miniapp_publish_dialog.dart';
import 'miniapp_run_page.dart';

class MiniappDetailPage extends StatefulWidget {
  const MiniappDetailPage({
    super.key,
    required this.entry,
    required this.store,
  });
  final MiniappEntry entry;
  final HtmlGameStore store;

  @override
  State<MiniappDetailPage> createState() => _MiniappDetailPageState();
}

class _MiniappDetailPageState extends State<MiniappDetailPage> {
  bool _busy = true;
  late MiniappEntry _entry = widget.entry;
  late final _library = MiniappLibraryStore(widget.store.database);

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    try {
      await _reload();
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    final entry = await _library.refresh(_entry);
    if (mounted)
      setState(() {
        _entry = entry;
      });
  }

  void _notice(String text) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(text)));

  Future<void> _publish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final published = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => MiniappPublishDialog(entry: _entry, store: _library),
      );
      if (published == true && mounted) {
        await _reload();
        if (mounted) _notice('已发布');
      }
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => const AppConfirmationDialog(
          title: '撤下小程序？',
          description: '撤下后不再公开展示。已经添加的版本和存档仍会保留，你也可以重新发布。',
          confirmLabel: '撤下',
        ),
      );
      if (yes != true) return;
      await _library.withdraw(_entry);
      await _reload();
      if (mounted) _notice('已撤下');
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => const AppConfirmationDialog(
          title: '更新小程序？',
          description: '使用最新发布的代码，保留你现有的存档。',
          confirmLabel: '更新',
        ),
      );
      if (yes != true) return;
      await _library.install(_entry);
      await _reload();
      if (mounted) _notice('已更新，存档已保留');
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!Platform.isAndroid) throw StateError('请在 Android 版 Aurai 中打开小程序');
      var id = _entry.runtimeId;
      if (!_entry.draft && _entry.installedId == null) {
        id = await _library.install(_entry);
        await _reload();
      }
      final launcher = _entry.draft ? await _library.launcher(id) : null;
      late final Widget page;
      if (launcher == null) {
        final game = await _library.loadIndependent(id);
        page = MiniappRunPage(game: game, store: widget.store);
      } else {
        final messageId = launcher['message_id'] as String;
        final conversationId = launcher['conversation_id'] as String;
        final card = await widget.store.card(messageId);
        // Validate the original entry before navigating to its existing runtime.
        await widget.store.load(conversationId, messageId);
        page = HtmlGameView(
          card: card,
          messageId: messageId,
          conversationId: conversationId,
          store: widget.store,
          fullscreen: true,
          backLabel: '返回详情',
        );
      }
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MiniappMetadataEditor(entry: _entry, store: _library),
        ),
      );
      if (mounted) await _reload();
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _action(String title, VoidCallback action) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    trailing: const SettingsIcon(type: SettingsIconType.chevron),
    onTap: _busy ? null : action,
  );

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final canOpen = entry.draft || entry.installedId != null || entry.listed;
    final status = entry.installedId != null
        ? '已添加'
        : entry.listed
        ? '已发布'
        : entry.revision > 0
        ? '已撤下'
        : '未发布';
    return Scaffold(
      appBar: SettingsAppBar(
        title: '小程序详情',
        onBack: () => Navigator.pop(context),
        actions: [
          if (entry.canEditMetadata)
            SettingsGlassAction(
              label: '编辑',
              icon: Icons.edit_outlined,
              iconWidget: const TaskActionIcon('edit'),
              onPressed: _busy ? null : _edit,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                child: DialogActionButton(
                  text: !canOpen
                      ? '已撤下'
                      : !entry.draft && entry.installedId == null
                      ? '添加并打开'
                      : '打开',
                  onPressed: _busy || !canOpen ? null : _open,
                  loading: _busy,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    MiniappIcon(path: entry.iconPath),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        entry.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(entry.description),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (entry.publisherProfile != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: MemberAvatar(
                          sender: entry.publisherProfile!,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        entry.publisher,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (entry.hasUpdate) _action('更新', _update),
                if (entry.draft) ...[
                  _action(entry.listed ? '发布更新' : '发布', _publish),
                  if (entry.listed) _action('撤下', _withdraw),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
