import '../features/chat/delete_confirmation_dialog.dart';
import '../domain/error_message.dart';
import 'package:flutter/material.dart';

import 'memory_controller.dart';
import 'memory_toast.dart';
import '../features/chat/settings_appearance.dart';
import '../features/chat/settings_icon.dart';

class MemoryEditor extends StatefulWidget {
  const MemoryEditor({super.key, required this.memory, this.entry});
  final MemoryController memory;
  final Map<String, Object?>? entry;

  @override
  State<MemoryEditor> createState() => MemoryEditorState();
}

class MemoryEditorState extends State<MemoryEditor> {
  late final original = widget.entry?['text'] as String? ?? '';
  late final text = TextEditingController(text: original);
  bool busy = false;
  bool allowPop = false;
  bool get dirty => text.text.trim() != original.trim();

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _close() {
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _leave() async {
    if (busy) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => const DeleteConfirmationDialog(
          title: '放弃修改？',
          description: '尚未保存的记忆修改会丢失。',
          confirmLabel: '放弃修改',
          cancelLabel: '继续编辑',
        ),
      );
      if (discard != true || !mounted) return;
    }
    _close();
  }

  Future<void> _commit() async {
    setState(() => busy = true);
    try {
      await widget.memory.saveEntry(
        widget.entry?['id'] as String?,
        text.text,
        original: widget.entry,
      );
      if (!mounted) return;
      memoryToast(context, '记忆已保存');
      _close();
    } on Object catch (error) {
      if (mounted) {
        memoryToast(
          context,
          error is StateError
              ? error.message
              : '操作失败，请重试：${errorMessage(error)}',
        );
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: allowPop || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: SettingsAppBar(
          title: widget.entry == null ? '添加记忆' : '编辑记忆',
          onBack: busy ? null : _leave,
          actions: [
            SettingsGlassAction(
              label: busy ? '正在保存' : '保存',
              icon: Icons.check_rounded,
              onPressed:
                  !busy &&
                      dirty &&
                      text.text.trim().isNotEmpty &&
                      text.text.length <= 300
                  ? () => _commit()
                  : null,
              iconWidget: Opacity(
                opacity:
                    !busy &&
                        dirty &&
                        text.text.trim().isNotEmpty &&
                        text.text.length <= 300
                    ? 1
                    : .3,
                child: const SettingsIcon(type: SettingsIconType.check),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextField(
                    controller: text,
                    autofocus: widget.entry == null,
                    enabled: !busy,
                    minLines: 5,
                    maxLines: null,
                    maxLength: 300,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                      color: colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: '想让 Aurai 记住什么？',
                      hintStyle: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: settingsFieldColor(context),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
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
}
