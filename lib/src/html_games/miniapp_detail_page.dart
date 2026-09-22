import 'miniapp_favorites.dart';
import '../features/chat/header_action_menu.dart';
import '../features/chat/attachment_action_icon.dart';
import 'miniapp_forward.dart';
import 'miniapp_icon.dart';
import 'miniapp_launcher.dart';

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
import 'miniapp_library_store.dart';
import 'miniapp_publish_dialog.dart';

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
  bool _menuBusy = false;
  bool _opening = false;
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

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _opening = true;
    });
    try {
      await openMiniapp(
        context,
        _entry,
        widget.store,
        onReady: () => setState(() => _opening = false),
      );
      if (mounted) await _reload();
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _opening = false;
        });
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

  Future<void> _more(BuildContext anchor) async {
    if (_busy || _menuBusy) return;
    setState(() => _menuBusy = true);
    try {
      final favorites = MiniappFavorites(widget.store.database);
      final starred = await favorites.contains(_entry);
      if (!anchor.mounted) return;
      final action = await showHeaderActionMenu(
        anchor,
        items: [
          if (_entry.canEditMetadata)
            (value: 'edit', label: '编辑', icon: const TaskActionIcon('edit')),
          (
            value: 'forward',
            label: '转发',
            icon: const AttachmentActionIcon(
              type: AttachmentActionIconType.forward,
            ),
          ),
          (
            value: 'favorite',
            label: starred ? '取消收藏' : '收藏',
            icon: SettingsIcon(
              type: starred
                  ? SettingsIconType.starFilled
                  : SettingsIconType.star,
              color: starred ? const Color(0xffe5ad24) : null,
            ),
          ),
        ],
      );
      if (!mounted) return;
      switch (action) {
        case 'edit':
          await _edit();
        case 'forward':
          await forwardMiniapp(context, _entry);
        case 'favorite':
          if (starred) {
            await favorites.remove(_entry);
          } else {
            await favorites.add(_entry);
          }
          if (mounted) _notice(starred ? '已取消收藏' : '已收藏小程序');
      }
    } on Object catch (error) {
      if (mounted) _notice(errorMessage(error));
    } finally {
      if (mounted) setState(() => _menuBusy = false);
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
    return Scaffold(
      appBar: SettingsAppBar(
        title: '小程序详情',
        onBack: () => Navigator.pop(context),
        actions: [
          Builder(
            builder: (anchor) => SettingsGlassAction(
              label: '更多',
              icon: Icons.more_vert_rounded,
              iconWidget: const TaskActionIcon('more'),
              onPressed: _busy || _menuBusy ? null : () => _more(anchor),
            ),
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
                  text: !canOpen ? '已撤下' : '打开',
                  onPressed: _busy || !canOpen ? null : _open,
                  loading: _opening,
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: settingsFieldColor(context),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: MiniappIcon(
                      path: entry.iconPath,
                      asset: entry.iconAsset,
                      size: entry.iconPath == null && entry.iconAsset == null
                          ? 36
                          : 96,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  entry.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (entry.publisherProfile != null) ...[
                      MemberAvatar(sender: entry.publisherProfile!, size: 24),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        entry.publisher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(
                    entry.description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
