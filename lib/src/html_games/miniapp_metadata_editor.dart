import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/agent_models.dart';
import 'miniapp_icon.dart';

import 'package:flutter/material.dart';

import '../app/glass_notice.dart';
import '../domain/error_message.dart';
import '../features/chat/member_avatar.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';
import '../scheduling/task_unsaved_dialog.dart';
import 'miniapp_library_store.dart';
import 'miniapp_metadata_store.dart';

class MiniappMetadataEditor extends StatefulWidget {
  const MiniappMetadataEditor({
    super.key,
    required this.entry,
    required this.store,
  });
  final MiniappEntry entry;
  final MiniappLibraryStore store;

  @override
  State<MiniappMetadataEditor> createState() => _MiniappMetadataEditorState();
}

class _MiniappMetadataEditorState extends State<MiniappMetadataEditor> {
  late MiniappEntry _saved = widget.entry;
  late final _name = TextEditingController(text: _saved.title);
  late final _description = TextEditingController(text: _saved.description);
  bool _busy = false, _leaving = false;
  late String? _iconPath = _saved.iconPath;
  final _draftIcons = <String>{};
  bool get _dirty =>
      _name.text != _saved.title ||
      _description.text != _saved.description ||
      _iconPath != _saved.iconPath;

  @override
  void dispose() {
    for (final path in _draftIcons) {
      unawaited(File(path).delete().catchError((Object _) => File(path)));
    }
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;
      final codec = await ui.instantiateImageCodec(await image.readAsBytes());
      late final List<int> bytes;
      try {
        final frame = await codec.getNextFrame();
        try {
          bytes = (await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      final root = await getApplicationSupportDirectory();
      final folder = await Directory(
        '${root.path}/miniapp_icons',
      ).create(recursive: true);
      final file = await File(
        '${folder.path}/${newMessageId()}.png',
      ).writeAsBytes(bytes, flush: true);
      if (!mounted) {
        await file.delete();
        return;
      }
      _draftIcons.add(file.path);
      setState(() => _iconPath = file.path);
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showGlassSnackBar(
          SnackBar(content: Text('无法选择图标：${errorMessage(error)}')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _save() async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await MiniappMetadataStore(
        widget.store.database,
      ).save(_saved, _name.text, _description.text, iconPath: _iconPath);
      _draftIcons.remove(_iconPath);
      if (!mounted) return true;
      setState(() {
        _saved = _saved.withMetadata(
          _name.text.trim(),
          _description.text.trim(),
          _saved.metadataRevision + 1,
          iconPath: _iconPath,
          replaceIcon: true,
        );
        _name.text = _saved.title;
        _description.text = _saved.description;
      });
      ScaffoldMessenger.of(
        context,
      ).showGlassSnackBar(const SnackBar(content: Text('小程序资料已保存')));
      return true;
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showGlassSnackBar(SnackBar(content: Text(errorMessage(error))));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy || _leaving) return;
    if (_dirty) {
      final choice = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .24),
        builder: (_) => const TaskUnsavedDialog(description: '小程序资料还有未保存的修改。'),
      );
      if (!mounted || choice == null) return;
      if (choice == 'save' && !await _save()) return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Widget _field(
    String label,
    TextEditingController controller,
    int limit, {
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextField(
          controller: controller,
          enabled: !_busy,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 8 : 1,
          maxLength: limit,
          keyboardType: multiline
              ? TextInputType.multiline
              : TextInputType.text,
          textInputAction: multiline
              ? TextInputAction.newline
              : TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: settingsFieldColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(26),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '编辑小程序',
        onBack: _close,
        actions: [
          SettingsGlassAction(
            label: _busy ? '正在保存' : '保存',
            icon: Icons.check_rounded,
            iconWidget: Opacity(
              opacity: _dirty && !_busy ? 1 : .3,
              child: const SettingsIcon(type: SettingsIconType.check),
            ),
            onPressed: _dirty && !_busy ? _save : null,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Text(
                    '图标',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: '选择小程序图标',
                        child: GestureDetector(
                          onTap: _busy ? null : _pickIcon,
                          child: MiniappIcon(path: _iconPath, size: 64),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _busy ? null : _pickIcon,
                        child: Text(_iconPath == null ? '选择图片' : '更换图片'),
                      ),
                      if (_iconPath != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _iconPath = null),
                          child: const Text('移除'),
                        ),
                    ],
                  ),
                ),
                _field('名称', _name, 100),
                _field('简介', _description, 500, multiline: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Text(
                    '创建人',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      if (_saved.publisherProfile != null) ...[
                        MemberAvatar(
                          sender: _saved.publisherProfile!,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: Text(_saved.publisher)),
                    ],
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
