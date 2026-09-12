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
  bool _saving = false;
  bool _allowPop = false;
  bool get _dirty =>
      _name.text.trim() != widget.memory.nickname ||
      _job.text.trim() != widget.memory.occupation ||
      _about.text.trim() != widget.memory.about;

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
    for (final field in [_name, _job, _about]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('个人信息的修改尚未保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃修改'),
          ),
        ],
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
      await widget.memory.saveProfile(
        _name.text.trim(),
        _job.text.trim(),
        _about.text.trim(),
      );
      if (mounted) _notice('个人信息已保存');
    } on Object {
      if (mounted) _notice('保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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
    canPop: _allowPop || (!_saving && !_dirty),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving) _leave();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '个人信息',
        onBack: _saving ? null : () => Navigator.maybePop(context),
        actions: [
          SettingsGlassAction(
            label: _saving ? '正在保存' : '保存',
            icon: Icons.check_rounded,
            onPressed: _dirty && !_saving ? _save : null,
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
