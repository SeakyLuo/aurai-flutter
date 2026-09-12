import 'package:flutter/material.dart';

import '../features/chat/glass_surface.dart';
import '../features/chat/message_composer.dart';
import '../features/chat/settings_appearance.dart';
import 'memory_controller.dart';
import 'memory_editor.dart';
import 'memory_page.dart' show memoryToast;

class MemorySummaryPage extends StatefulWidget {
  const MemorySummaryPage({super.key, required this.memory});
  final MemoryController memory;

  @override
  State<MemorySummaryPage> createState() => _MemorySummaryPageState();
}

class _MemorySummaryPageState extends State<MemorySummaryPage> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;
  bool _allowPop = false;
  MemoryController get memory => widget.memory;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (_text.text.trim().isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃未保存的记忆？'),
          content: const Text('输入的内容尚未保存。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _edit(Map<String, Object?> entry) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => MemoryEditor(memory: memory, entry: entry),
    );
  }

  Future<void> _add() async {
    setState(() => _saving = true);
    try {
      await memory.saveEntry(null, _text.text.trim());
      if (!mounted) return;
      _text.clear();
      _focus.unfocus();
      memoryToast(context, '记忆已保存');
    } on Object catch (error) {
      if (mounted) {
        memoryToast(context, error is StateError ? error.message : '无法保存，请重试');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: memory,
    builder: (context, _) {
      final overview = [
        if (memory.nickname.isNotEmpty) '你希望 Aurai 称呼你为${memory.nickname}。',
        if (memory.occupation.isNotEmpty) '你的职业是${memory.occupation}。',
        if (memory.about.isNotEmpty) memory.about,
      ].join('\n\n');
      return PopScope(
        canPop: _allowPop || (!_saving && _text.text.trim().isEmpty),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_saving) _leave();
        },
        child: Scaffold(
          appBar: SettingsAppBar(
            title: '记忆摘要',
            onBack: _saving ? null : _leave,
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                        children: [
                          const _Heading('概览'),
                          Text(
                            overview.isNotEmpty
                                ? overview
                                : memory.entries.isEmpty
                                ? '这里会逐渐记录 Aurai 对你的了解。你可以在下方补充希望记住的信息。'
                                : '以下是你在对话中分享、或主动保存的信息。',
                            style: const TextStyle(fontSize: 16, height: 1.8),
                          ),
                          if (memory.entries.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            const _Heading('记忆'),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                '点按段落可编辑或删除',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            for (final entry in memory.entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Semantics(
                                  button: true,
                                  hint: '编辑或删除这条记忆',
                                  child: InkWell(
                                    onTap: _saving ? null : () => _edit(entry),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Text(
                                      entry['text'] as String,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    MessageComposer(
                      controller: _text,
                      focusNode: _focus,
                      enabled: !_saving,
                      hintText: '补充记忆',
                      maxLength: 300,
                      onChanged: (_) => setState(() {}),
                      action: RoundAction(
                        label: _saving ? '正在保存' : '保存记忆',
                        icon: Icons.arrow_upward_rounded,
                        primary: true,
                        compact: true,
                        onPressed: _saving || _text.text.trim().isEmpty
                            ? null
                            : _add,
                        iconWidget: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
    ),
  );
}
