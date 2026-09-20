import '../../app/glass_notice.dart';
import 'remove_favorite.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/error_message.dart';
import '../../storage/starred_messages.dart';
import 'image_action_scope.dart';
import 'settings_icon.dart';

class MessageStarButton extends StatefulWidget {
  const MessageStarButton({super.key, required this.messageId});
  final String messageId;
  @override
  State<MessageStarButton> createState() => _MessageStarButtonState();
}

class _MessageStarButtonState extends State<MessageStarButton> {
  late StarredMessages _store;
  StreamSubscription? _changes;
  bool? _starred;
  bool _busy = false;
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_changes != null) return;
    _store = StarredMessages(ImageActionScope.of(context).groupStore.database);
    _changes = StarredMessages.changes.stream.listen((event) {
      if (event.owner == 'user:local' && event.message == widget.messageId) {
        _revision++;
        setState(() => _starred = event.starred);
      }
    });
    _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    try {
      final value = await _store.containsBatched(widget.messageId);
      if (mounted && revision == _revision) setState(() => _starred = value);
    } on Object catch (error) {
      if (mounted) _notice(error);
    }
  }

  @override
  void didUpdateWidget(MessageStarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _starred = null;
      _load();
    }
  }

  void _notice(Object error) => ScaffoldMessenger.of(
    context,
  ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));

  Future<void> _toggle() async {
    setState(() => _busy = true);
    final id = widget.messageId;
    try {
      final value = !(_starred ?? await _store.contains(id));
      if (!value) {
        if (!mounted) return;
        await removeFavorite(context, _store, id);
        return;
      }
      await _store.set(id, true);
      if (mounted) {
        if (widget.messageId == id) setState(() => _starred = value);
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text('已收藏')));
      }
    } on Object catch (error) {
      if (mounted) _notice(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _starred == true ? '取消收藏' : '收藏',
    onPressed: _busy ? null : _toggle,
    icon: SettingsIcon(
      type: _starred == true
          ? SettingsIconType.starFilled
          : SettingsIconType.star,
      color: _starred == true
          ? const Color(0xffe5ad24)
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(32),
      minimumSize: const Size.square(32),
      padding: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
