import 'package:flutter/material.dart';
import 'chat_controller.dart';

class ConversationRenameDialog extends StatefulWidget {
  const ConversationRenameDialog({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.initialTitle,
  });
  final ChatController controller;
  final String conversationId;
  final String initialTitle;

  @override
  State<ConversationRenameDialog> createState() =>
      _ConversationRenameDialogState();
}

class _ConversationRenameDialogState extends State<ConversationRenameDialog> {
  late final _text = TextEditingController(text: widget.initialTitle);
  bool _saving = false;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _notice(String text) =>
      _messenger.currentState!.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    if (_saving) return;
    if (_text.text.trim().isEmpty) {
      _notice('请输入会话名称');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.renameConversation(
        widget.conversationId,
        _text.text,
      );
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        _notice('重命名失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: AlertDialog(
          title: const Text('重命名会话'),
          content: TextField(
            controller: _text,
            autofocus: true,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '会话名称'),
            onSubmitted: (_) => _save(),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    ),
  );
}
