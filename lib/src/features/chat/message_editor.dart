import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import 'chat_controller.dart';
import 'image_attachments.dart';

Future<void> editChatMessage(
  BuildContext context, {
  required ChatController controller,
  required AgentMessage message,
  required bool Function() preparingGoal,
  required Future<void> Function() continueReply,
}) async {
  bool busy() =>
      controller.isBusy ||
      controller.addingImages ||
      controller.changingConversation ||
      controller.loadingEarlierMessages ||
      preparingGoal();
  if (busy()) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先结束当前操作，再编辑消息')));
    return;
  }
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) =>
        _MessageEditor(message: message, controller: controller, busy: busy),
  );
  if (saved == true && context.mounted) await continueReply();
}

class _MessageEditor extends StatefulWidget {
  const _MessageEditor({
    required this.message,
    required this.controller,
    required this.busy,
  });
  final AgentMessage message;
  final ChatController controller;
  final bool Function() busy;

  @override
  State<_MessageEditor> createState() => _MessageEditorState();
}

class _MessageEditorState extends State<_MessageEditor> {
  late final _text = TextEditingController(text: widget.message.text);
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.busy()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先结束当前操作，再编辑消息')));
      return;
    }
    setState(() => _saving = true);
    try {
      final cleaned = await widget.controller.editMessageAndPrepareReply(
        widget.message,
        _text.text.trim(),
      );
      if (!mounted) return;
      if (!cleaned) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('消息已更新，部分旧图片清理失败')));
      }
      Navigator.pop(context, true);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('消息保存失败，请重试')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _text.text.trim();
    final canSave =
        value != widget.message.text &&
        (value.isNotEmpty || widget.message.images.isNotEmpty);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '编辑消息',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  '保存后将替换这条消息之后的所有消息与执行记录，AI 会重新回复。已执行的手机操作不会撤销。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.message.images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final image in widget.message.images)
                        ImageAttachment(
                          image: image,
                          gallery: widget.message.images,
                          size: 64,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _text,
                  autofocus: true,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 8,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '输入消息'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || !canSave ? null : _save,
                        child: Text(_saving ? '正在保存…' : '保存并重新回复'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
