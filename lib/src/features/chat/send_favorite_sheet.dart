import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/glass_notice.dart';
import '../../domain/agent_models.dart';
import '../../domain/error_message.dart';
import '../../html_games/miniapp_favorites.dart';
import '../../html_games/miniapp_forward.dart';
import '../../html_games/miniapp_icon.dart';
import '../../storage/group_message_search.dart';
import '../../storage/starred_messages.dart';
import 'chat_controller.dart';
import 'dialog_action_button.dart';
import 'starred_message_tile.dart';
import 'question_icon.dart';
import 'retained_tab_view.dart';
import 'search_skeleton.dart';
import 'search_type_segment.dart';
import 'settings_appearance.dart';
import 'settings_icon.dart';

Future<bool?> showSendFavoriteSheet(
  BuildContext context,
  ChatController controller,
) {
  final target = controller.activeConversation;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) =>
        _SendFavoriteSheet(controller: controller, targetId: target.id),
  );
}

class _SendFavoriteSheet extends StatefulWidget {
  const _SendFavoriteSheet({required this.controller, required this.targetId});
  final ChatController controller;
  final String targetId;
  @override
  State<_SendFavoriteSheet> createState() => _SendFavoriteSheetState();
}

class _SendFavoriteSheetState extends State<_SendFavoriteSheet> {
  bool _miniapps = false, _sending = false;
  AgentMessage? _selected;

  void _selectTab(bool value) {
    if (_sending || _miniapps == value) return;
    setState(() {
      _miniapps = value;
      _selected = null;
    });
  }

  Future<void> _send() async {
    final message = _selected!;
    setState(() => _sending = true);
    try {
      await widget.controller.forwardMessage(widget.targetId, message, '');
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SafeArea(
        top: false,
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
                    onPressed: _sending ? null : () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: SearchTypeSegment(
                        files: _miniapps,
                        labels: const ['消息', '小程序'],
                        onChanged: _selectTab,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: RetainedTabView(
                index: _miniapps ? 1 : 0,
                swipeEnabled: !_sending,
                onChanged: (index) => _selectTab(index == 1),
                children: [
                  for (final miniapps in [false, true])
                    _FavoriteChoices(
                      controller: widget.controller,
                      miniapps: miniapps,
                      selected: _selected?.id,
                      enabled: !_sending,
                      onSelected: (message) =>
                          setState(() => _selected = message),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: DialogActionButton(
                  text: '发送',
                  loading: _sending,
                  liquidGlass: true,
                  onPressed: _selected == null || _sending ? null : _send,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FavoriteChoice {
  const _FavoriteChoice(this.message, this.title, this.subtitle, this.icon);
  final AgentMessage message;
  final String title, subtitle;
  final Widget icon;
}

class _FavoriteChoices extends StatefulWidget {
  const _FavoriteChoices({
    required this.controller,
    required this.miniapps,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });
  final ChatController controller;
  final bool miniapps, enabled;
  final String? selected;
  final ValueChanged<AgentMessage> onSelected;
  @override
  State<_FavoriteChoices> createState() => _FavoriteChoicesState();
}

class _FavoriteChoicesState extends State<_FavoriteChoices> {
  final _scroll = ScrollController();
  final _items = <_FavoriteChoice>[];
  bool _loading = false, _more = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240 && !_failed) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final database = widget.controller.groupStore.database;
      final choices = <_FavoriteChoice>[];
      int count;
      if (widget.miniapps) {
        final rows = await MiniappFavorites(
          database,
        ).page(offset: _items.length);
        count = rows.length;
        for (final row in rows) {
          final entry = row.entry;
          choices.add(
            _FavoriteChoice(
              miniappForwardMessage(entry),
              entry.title,
              entry.description.isEmpty ? entry.publisher : entry.description,
              MiniappIcon(
                path: entry.iconPath,
                asset: entry.iconAsset,
                size: 36,
              ),
            ),
          );
        }
      } else {
        final rows = await StarredMessages(
          database,
        ).page(offset: _items.length);
        count = rows.length;
        final directory = await getApplicationSupportDirectory();
        final messages = await GroupMessageSearch(
          database,
          '${directory.path}/message_images',
        ).hydrate(rows);
        for (var index = 0; index < messages.length; index++) {
          final result = messages[index];
          choices.add(
            _FavoriteChoice(
              AgentMessage(
                id: result.id,
                role: result.role,
                senderId: result.sender.id,
                sender: result.sender,
                text: result.text,
                createdAt: result.createdAt,
                images: result.images,
                files: result.files,
                htmlGame: result.html,
                interactive: result.interactive,
              ),
              result.sender.name,
              '',
              StarredMessageTile(
                result: result,
                conversationId: rows[index]['conversation_id'] as String,
                conversationTitle: '',
                controller: widget.controller,
                onLocate: () {},
                onRemove: () {},
                selectionMode: true,
              ),
            ),
          );
        }
      }
      if (mounted)
        setState(() {
          _items.addAll(choices);
          _more = count == 50;
        });
    } on Object catch (error) {
      if (mounted) {
        _failed = true;
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _selectionIndicator(BuildContext context, bool selected) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.onSurface : Colors.transparent,
        border: Border.all(
          color: selected ? colors.onSurface : colors.outline,
          width: 1.4,
        ),
      ),
      child: selected
          ? SettingsIcon(type: SettingsIconType.check, color: colors.surface)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading)
      return const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: SearchSkeleton(label: '正在加载收藏', avatarSize: 36),
      );
    if (_items.isEmpty && !_failed)
      return Center(
        child: Text(
          widget.miniapps ? '还没有收藏的小程序' : '还没有收藏的消息',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length + ((_loading || _more || _failed) ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _load,
                      child: Text(_failed ? '重试' : '加载更多'),
                    ),
            ),
          );
        final item = _items[index];
        final selected = widget.selected == item.message.id;
        if (!widget.miniapps) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled
                ? () => widget.onSelected(item.message)
                : null,
            child: Stack(
              children: [
                IgnorePointer(child: item.icon),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _selectionIndicator(context, selected),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: selected
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .08)
                : settingsFieldColor(context),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              leading: item.icon,
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              selected: selected,
              selectedColor: Theme.of(context).colorScheme.onSurface,
              trailing: _selectionIndicator(context, selected),
              onTap: widget.enabled
                  ? () => widget.onSelected(item.message)
                  : null,
            ),
          ),
        );
      },
    );
  }
}
