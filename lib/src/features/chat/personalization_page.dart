import 'package:flutter/material.dart';

import '../../agent/system_prompt.dart';
import 'chat_controller.dart';
import 'settings_appearance.dart';

class PersonalizationPage extends StatefulWidget {
  const PersonalizationPage({super.key, required this.controller});
  final ChatController controller;

  @override
  State<PersonalizationPage> createState() => _PersonalizationPageState();
}

class _PersonalizationPageState extends State<PersonalizationPage> {
  late final _prompt = TextEditingController(text: _saved);
  bool _saving = false;
  bool _allowPop = false;
  String get _saved =>
      widget.controller.modelSettings.systemPrompt ?? agentSystemPrompt;
  bool get _dirty => _prompt.text != _saved;

  @override
  void initState() {
    super.initState();
    _prompt.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('个性化设置的修改尚未保存。'),
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
      if (_prompt.text != _saved) {
        await widget.controller.saveSystemPrompt(
          _prompt.text == agentSystemPrompt ? null : _prompt.text,
        );
      }
      if (mounted) _notice('个性化设置已保存');
    } on Object {
      if (mounted) _notice('保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_saving && !_dirty),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_saving) _leave();
    },
    child: Scaffold(
      appBar: SettingsAppBar(
        title: '个性化',
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '自定义指令',
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving || _prompt.text == agentSystemPrompt
                            ? null
                            : () => _prompt.text = agentSystemPrompt,
                        child: const Text('恢复默认'),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _prompt,
                  enabled: !_saving,
                  minLines: 8,
                  maxLines: 16,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '输入自定义指令',
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
          ),
        ),
      ),
    ),
  );
}
