import 'dart:async';
import 'package:flutter/material.dart';
import '../../platform/preview_image_actions.dart';
import 'chat_controller.dart';
import 'conversation_icon.dart';
import 'image_forward_dialog.dart';
import 'attachment_action_icon.dart';
import 'settings_appearance.dart';

class ImageForwardPage extends StatefulWidget {
  const ImageForwardPage({
    super.key,
    required this.controller,
    required this.image,
  });
  final ChatController controller;
  final ImageProvider image;
  @override
  State<ImageForwardPage> createState() => _ImageForwardPageState();
}

class _ImageForwardPageState extends State<ImageForwardPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _items = <({String id, String title})>[];
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false, _more = true, _sharing = false;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 240 && _more && !_loading) _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      if (reset) _items.clear();
    });
    try {
      final page = await widget.controller.imageForwardTargets(
        _search.text.trim(),
        _items.length,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _more = page.length == 30;
      });
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('会话加载失败，请重新搜索')));
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _select(String? id, String title) async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImageForwardDialog(
        controller: widget.controller,
        image: widget.image,
        targetId: id,
        title: title,
      ),
    );
    if (sent == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _external() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await PreviewImageActions.perform(widget.image, 'share');
    } on Object {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开分享，请重试')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('转发图片'),
      leading: SettingsGlassAction(
        label: '返回',
        icon: Icons.arrow_back_rounded,
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: '搜索会话',
              filled: true,
              fillColor: settingsFieldColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
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
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            children: [
              _row(
                '其他应用',
                const AttachmentActionIcon(
                  type: AttachmentActionIconType.forward,
                ),
                _sharing ? null : _external,
              ),
              _row(
                '新建会话',
                const ConversationIcon(),
                () => _select(null, '新建会话'),
              ),
              for (final item in _items)
                _row(
                  item.title,
                  const ConversationIcon(),
                  () => _select(item.id, item.title),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              if (!_loading && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('没有找到会话')),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _row(String title, Widget icon, VoidCallback? action) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    leading: icon,
    title: Text(
      title,
      style: const TextStyle(fontSize: 15),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    onTap: action,
  );
}
