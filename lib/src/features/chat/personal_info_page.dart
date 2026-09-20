import '../../app/glass_notice.dart';
import 'delete_confirmation_dialog.dart';
import '../../domain/error_message.dart';
import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/avatar_style.dart';
import 'profile_avatar_editor.dart';
import 'custom_avatar_page.dart';
import 'package:flutter/material.dart';

import '../../memory/memory_controller.dart';
import 'settings_appearance.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key, required this.memory});
  final MemoryController memory;

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  late final _name = TextEditingController(text: widget.memory.nickname);
  late final _job = TextEditingController(text: widget.memory.occupation);
  late final _about = TextEditingController(text: widget.memory.about);
  late AvatarStyle _avatar = widget.memory.avatar;
  final _draftPaths = <String>{};
  bool _picking = false;
  bool _saving = false;
  bool _allowPop = false;
  bool get _dirty =>
      _avatar != widget.memory.avatar ||
      _name.text.trim() != widget.memory.nickname ||
      _job.text.trim() != widget.memory.occupation ||
      _about.text.trim() != widget.memory.about;

  Future<void> _pickAvatar(AvatarSource source) async {
    if (source == AvatarSource.custom) {
      final result = await Navigator.push<AvatarStyle>(
        context,
        MaterialPageRoute(
          builder: (_) => CustomAvatarPage(initial: _avatar, name: _name.text),
        ),
      );
      if (mounted && result != null) setState(() => _avatar = result);
      return;
    }
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source == AvatarSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (image == null || !mounted) return;
      final support = await getApplicationSupportDirectory();
      final directory = await Directory(
        '${support.path}/profile_avatars',
      ).create(recursive: true);
      final path =
          '${directory.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(image.path).copy(path);
      if (!mounted) {
        await File(path).delete();
        return;
      }
      _draftPaths.add(path);
      setState(
        () => _avatar = AvatarStyle(
          icon: _avatar.icon,
          color: _avatar.color,
          path: path,
        ),
      );
    } catch (caughtError) {
      if (mounted) _notice('头像读取失败，请重试：${errorMessage(caughtError)}');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _cleanDrafts() async {
    for (final path in _draftPaths.toList()) {
      if (path == widget.memory.avatar.path) continue;
      try {
        await File(path).delete();
        _draftPaths.remove(path);
      } on FileSystemException catch (error, stack) {
        developer.log(
          'Avatar draft cleanup failed',
          name: 'aurai.avatar',
          error: error,
          stackTrace: stack,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    for (final field in [_name, _job, _about]) {
      field.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    unawaited(_cleanDrafts());
    for (final field in [_name, _job, _about]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteConfirmationDialog(
        title: '放弃未保存的修改？',
        description: '个人信息的修改尚未保存。',
        confirmLabel: '放弃修改',
        cancelLabel: '继续编辑',
      ),
    );
    if (!mounted || discard != true) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final oldPath = widget.memory.avatar.path;
      await widget.memory.saveProfile(
        _name.text.trim(),
        _job.text.trim(),
        _about.text.trim(),
        avatar: _avatar,
      );
      if (oldPath != null && oldPath != _avatar.path) _draftPaths.add(oldPath);
      _draftPaths.remove(_avatar.path);
      await _cleanDrafts();
      if (mounted) _notice('个人信息已保存');
    } on Object catch (error) {
      if (mounted) _notice('保存失败，请重试：${errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showGlassSnackBar(SnackBar(content: Text(text)));

  Widget _profileField(
    String label,
    TextEditingController controller,
    String hint,
    int maxLength, {
    bool multiline = false,
  }) => Column(
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
        enabled: !_saving,
        maxLength: maxLength,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 8 : 1,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        textInputAction: multiline
            ? TextInputAction.newline
            : TextInputAction.next,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
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
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_saving && !_picking && !_dirty),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving && !_picking) _leave();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '个人信息',
        onBack: _saving ? null : () => Navigator.maybePop(context),
        actions: [
          SettingsGlassAction(
            label: _saving ? '正在保存' : '保存',
            icon: Icons.check_rounded,
            onPressed: _dirty && !_saving && !_picking ? _save : null,
            iconWidget: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
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
                ProfileAvatarEditor(
                  style: _avatar,
                  name: _name.text,
                  onSelected: _saving || _picking ? null : _pickAvatar,
                ),
                _profileField('你的昵称', _name, '希望 Aurai 怎么称呼你', 80),
                const SizedBox(height: 16),
                _profileField('你的职业', _job, '你从事什么工作', 120),
                const SizedBox(height: 16),
                _profileField(
                  '关于你的更多信息',
                  _about,
                  '要记住的兴趣、价值观或偏好',
                  2000,
                  multiline: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
