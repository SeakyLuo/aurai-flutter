import 'package:flutter/material.dart';
import 'memory_controller.dart';
import 'memory_page.dart' show memoryToast;
import '../features/chat/settings_appearance.dart';

class MemoryEditor extends StatefulWidget {
  const MemoryEditor({required this.memory, this.entry});
  final MemoryController memory;
  final Map<String, Object?>? entry;
  @override
  State<MemoryEditor> createState() => MemoryEditorState();
}

class MemoryEditorState extends State<MemoryEditor> {
  late final text = TextEditingController(
    text: widget.entry?['text'] as String? ?? '',
  );
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _commit(bool delete) async {
    setState(() => busy = true);
    try {
      if (delete) {
        await widget.memory.deleteEntry(widget.entry!['id'] as String);
      } else {
        await widget.memory.saveEntry(
          widget.entry?['id'] as String?,
          text.text,
        );
      }
      if (mounted) {
        memoryToast(context, delete ? '记忆已删除' : '记忆已保存');
        setState(() => busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } on Object catch (error) {
      if (mounted)
        memoryToast(context, error is StateError ? error.message : '无法保存，请重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.entry == null ? '添加记忆' : '编辑记忆',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: text,
            autofocus: true,
            enabled: !busy,
            minLines: 2,
            maxLines: 6,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 16),
            decoration: memoryFieldDecoration(context, '想让 Aurai 记住什么？'),
          ),
          Row(
            children: [
              if (widget.entry != null)
                TextButton(
                  onPressed: busy ? null : () => _commit(true),
                  child: const Text('删除'),
                ),
              const Spacer(),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy || text.text.trim().isEmpty
                    ? null
                    : () => _commit(false),
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

InputDecoration memoryFieldDecoration(BuildContext context, String hint) {
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
