import 'package:flutter/material.dart';
import 'memory_controller.dart';
import 'memory_summary_page.dart';
import '../features/chat/settings_appearance.dart';

void memoryToast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, required this.memory});
  final MemoryController memory;
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late final name = TextEditingController(text: widget.memory.nickname);
  late final job = TextEditingController(text: widget.memory.occupation);
  late final about = TextEditingController(text: widget.memory.about);
  bool saving = false;
  bool get dirty =>
      name.text != widget.memory.nickname ||
      job.text != widget.memory.occupation ||
      about.text != widget.memory.about;
  @override
  void initState() {
    super.initState();
    for (final field in [name, job, about]) {
      field.addListener(_changed);
    }
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    for (final field in [name, job, about]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃个人信息修改？'),
          content: const Text('尚未保存的个人信息会丢失。'),
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
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.memory.saveProfile(
        name.text.trim(),
        job.text.trim(),
        about.text.trim(),
      );
      name.text = widget.memory.nickname;
      job.text = widget.memory.occupation;
      about.text = widget.memory.about;
      if (mounted) memoryToast(context, '个人信息已保存');
    } on Object {
      if (mounted) memoryToast(context, '无法保存，请重试');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.memory,
    builder: (context, _) => PopScope(
      canPop: !dirty && !saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: SettingsAppBar(
          title: '记忆',
          onBack: saving ? null : _leave,
          actions: [
            SettingsGlassAction(
              label: '保存个人信息',
              onPressed: dirty && !saving ? _save : null,
              icon: Icons.check_rounded,
              iconWidget: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(
                    'Aurai 会参考你的个人信息和记忆，并记住你在对话中明确表达的长期偏好。',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  tileColor: settingsFieldColor(context),
                  title: const Text('记忆摘要', style: TextStyle(fontSize: 16)),
                  minVerticalPadding: 18,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MemorySummaryPage(memory: widget.memory),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MemoryLabel('你的昵称'),
                TextField(
                  style: const TextStyle(fontSize: 16),
                  controller: name,
                  enabled: !saving,
                  maxLength: 80,
                  decoration: _memoryFieldDecoration(context, '希望 Aurai 怎么称呼你'),
                ),
                const SizedBox(height: 16),
                _MemoryLabel('你的职业'),
                TextField(
                  style: const TextStyle(fontSize: 16),
                  controller: job,
                  enabled: !saving,
                  maxLength: 120,
                  decoration: _memoryFieldDecoration(context, '你从事什么工作'),
                ),
                const SizedBox(height: 16),
                _MemoryLabel('关于你的更多信息'),
                TextField(
                  style: const TextStyle(fontSize: 16),
                  controller: about,
                  enabled: !saving,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 8,
                  decoration: _memoryFieldDecoration(context, '要记住的兴趣、价值观或偏好'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MemoryLabel extends StatelessWidget {
  const _MemoryLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

InputDecoration _memoryFieldDecoration(BuildContext context, String hint) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(26),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: settingsFieldColor(context),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    disabledBorder: border,
  );
}
